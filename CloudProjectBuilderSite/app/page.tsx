"use client";

import { ChangeEvent, useEffect, useMemo, useRef, useState } from "react";
import templateData from "./template-data.json";

type Field = {
  kind: "field";
  key: string;
  label: string;
  suggestion?: string;
  help?: string;
  input?: "text" | "textarea" | "select";
  options?: string[];
};
type Group = { kind: "group"; label: string };
type Resource = { id: string; title: string; category: string; fields: Array<Field | Group> };
type Instance = {
  instanceId: string;
  resourceId: string;
  name: string;
  values: Record<string, string>;
  notes: string;
  open: boolean;
};
type Rule = {
  id: string;
  direction: string;
  name: string;
  source: string;
  sourceDetails: string;
  sourcePort: string;
  destination: string;
  destinationDetails: string;
  destinationPort: string;
  protocol: string;
  action: string;
  notes: string;
};
type Project = {
  overview: Record<string, string>;
  tags: Record<string, string>;
  technicalRequirements: string;
  resources: Instance[];
  securityRules: Rule[];
};

const NAMING_URL = "https://wellstarhealthsystem.sharepoint.com/:x:/t/Azure/EZgDr-fU3IBDvJOpURgnmHkBhGZMLmrAQOPBOPsVqWgy6Q?e=eUJTnB";
const PROJECT_STORAGE = "cloud-project-build-draft-v1";
const TEMPLATE_STORAGE = "cloud-project-build-template-v1";
const overviewFields = [
  ["projectName", "Project / build name", "e.g. Patient Access Analytics"],
  ["requestor", "Requestor", "Name and team"],
  ["engineer", "Assigned engineer", "Name or delivery team"],
  ["application", "Application / workload", "Application or platform name"],
  ["environment", "Environment", "Production, Test, Development..."],
  ["subscription", "Target subscription", "Subscription name"],
  ["landingZone", "Landing zone / business unit", "Landing zone or portfolio"],
  ["targetDate", "Target completion date", ""],
  ["workItem", "ADO / ServiceNow reference", "Work item, RITM, or CHG number"],
];
const emptyProject: Project = { overview: {}, tags: {}, technicalRequirements: "", resources: [], securityRules: [] };
const uid = () => crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`;
const safeName = (value: string) => (value || "Azure-Project-Build").replace(/[^a-z0-9-_ ]/gi, "").trim().replace(/\s+/g, "-").slice(0, 80);
const esc = (value: unknown) => String(value ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
function download(contents: BlobPart, filename: string, type: string) {
  const url = URL.createObjectURL(new Blob([contents], { type }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 500);
}
function excelXml(project: Project, definitions: Resource[]) {
  const row = (cells: unknown[], style = "") => `<Row>${cells.map((cell) => `<Cell${style ? ` ss:StyleID="${style}"` : ""}><Data ss:Type="String">${esc(cell)}</Data></Cell>`).join("")}</Row>`;
  const sheet = (name: string, rows: string[]) => `<Worksheet ss:Name="${esc(name.slice(0, 31))}"><Table>${rows.join("")}</Table><WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel"><FreezePanes/><FrozenNoSplit/><SplitHorizontal>1</SplitHorizontal><TopRowBottomPane>1</TopRowBottomPane></WorksheetOptions></Worksheet>`;
  const sheets = [
    sheet("Project Summary", [
      row(["Cloud Project Build Plan"], "Title"),
      ...overviewFields.map(([key, label]) => row([label, project.overview[key] || ""])),
      row(["Project Summary", project.overview.summary || ""]),
      row(["Technical Requirements", project.technicalRequirements]),
      row(["Generated", new Date().toLocaleString()]),
      row(["Security reminder", "No passwords, keys, tokens, or secrets are included."]),
    ]),
    sheet("Tags", [row(["Tag", "Value"], "Header"), ...templateData.tags.map((tag) => row([tag, project.tags[tag] || ""]))]),
    sheet("Security Rules", [
      row(["Direction", "Name", "Source", "Source Details", "Source Port", "Destination", "Destination Details", "Destination Port", "Protocol", "Action", "Notes"], "Header"),
      ...project.securityRules.map((rule) => row([rule.direction, rule.name, rule.source, rule.sourceDetails, rule.sourcePort, rule.destination, rule.destinationDetails, rule.destinationPort, rule.protocol, rule.action, rule.notes])),
    ]),
  ];
  project.resources.forEach((instance, index) => {
    const definition = definitions.find((item) => item.id === instance.resourceId);
    if (!definition) return;
    const rows = [row([instance.name], "Title"), row(["Parameter", "Value", "Guidance"], "Header")];
    definition.fields.forEach((field) => rows.push(field.kind === "group" ? row([field.label], "Subheader") : row([field.label, instance.values[field.key] || "", field.help || field.suggestion || ""])));
    rows.push(row(["Implementation notes", instance.notes]));
    sheets.push(sheet(`${index + 1}-${definition.title}`, rows));
  });
  sheets.push(sheet("Naming Standards", [row(["Resource", "Convention", "Example", "Notes"], "Header"), ...templateData.namingRules.map((rule) => row([rule.resource, rule.convention, rule.example, rule.notes]))]));
  return `<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?><Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"><Styles><Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Top" ss:WrapText="1"/><Font ss:FontName="Aptos" ss:Size="11"/></Style><Style ss:ID="Title"><Font ss:Size="16" ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#123B5D" ss:Pattern="Solid"/></Style><Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#176B87" ss:Pattern="Solid"/></Style><Style ss:ID="Subheader"><Font ss:Bold="1" ss:Color="#123B5D"/><Interior ss:Color="#E8F3F6" ss:Pattern="Solid"/></Style></Styles>${sheets.join("")}</Workbook>`;
}

export default function Home() {
  const [view, setView] = useState<"build" | "naming" | "template">("build");
  const [project, setProject] = useState<Project>(emptyProject);
  const [definitions, setDefinitions] = useState<Resource[]>(templateData.resources as Resource[]);
  const [resourceSearch, setResourceSearch] = useState("");
  const [namingSearch, setNamingSearch] = useState("");
  const [category, setCategory] = useState("All");
  const [templateId, setTemplateId] = useState(templateData.resources[0].id);
  const [hydrated, setHydrated] = useState(false);
  const [savedAt, setSavedAt] = useState("");
  const projectImport = useRef<HTMLInputElement>(null);
  const templateImport = useRef<HTMLInputElement>(null);

  useEffect(() => {
    try {
      const savedProject = localStorage.getItem(PROJECT_STORAGE);
      const savedTemplate = localStorage.getItem(TEMPLATE_STORAGE);
      if (savedProject) setProject(JSON.parse(savedProject));
      if (savedTemplate) setDefinitions(JSON.parse(savedTemplate));
    } catch {}
    setHydrated(true);
  }, []);
  useEffect(() => {
    if (!hydrated) return;
    localStorage.setItem(PROJECT_STORAGE, JSON.stringify(project));
    setSavedAt(new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(new Date()));
  }, [project, hydrated]);
  useEffect(() => {
    if (hydrated) localStorage.setItem(TEMPLATE_STORAGE, JSON.stringify(definitions));
  }, [definitions, hydrated]);

  const categories = useMemo(() => ["All", ...Array.from(new Set(definitions.map((item) => item.category))).sort()], [definitions]);
  const visibleResources = useMemo(() => definitions.filter((item) => (category === "All" || item.category === category) && (!resourceSearch || `${item.title} ${item.category}`.toLowerCase().includes(resourceSearch.toLowerCase()))), [category, definitions, resourceSearch]);
  const namingRules = useMemo(() => templateData.namingRules.filter((rule) => !namingSearch || `${rule.resource} ${rule.convention} ${rule.example} ${rule.notes}`.toLowerCase().includes(namingSearch.toLowerCase())), [namingSearch]);
  const totalValues = project.resources.reduce((sum, item) => sum + (definitions.find((definition) => definition.id === item.resourceId)?.fields.filter((field) => field.kind === "field").length || 0), 0);
  const completeValues = project.resources.reduce((sum, item) => sum + Object.values(item.values).filter(Boolean).length, 0);
  const progress = totalValues ? Math.round(completeValues / totalValues * 100) : 0;
  const activeTemplate = definitions.find((item) => item.id === templateId) || definitions[0];

  const updateOverview = (key: string, value: string) => setProject((current) => ({ ...current, overview: { ...current.overview, [key]: value } }));
  const addResource = (resourceId: string) => {
    const definition = definitions.find((item) => item.id === resourceId);
    if (!definition) return;
    const count = project.resources.filter((item) => item.resourceId === resourceId).length + 1;
    setProject((current) => ({ ...current, resources: [...current.resources, { instanceId: uid(), resourceId, name: `${definition.title} ${count}`, values: {}, notes: "", open: true }] }));
  };
  const updateInstance = (id: string, patch: Partial<Instance>) => setProject((current) => ({ ...current, resources: current.resources.map((item) => item.instanceId === id ? { ...item, ...patch } : item) }));
  const updateValue = (id: string, key: string, value: string) => setProject((current) => ({ ...current, resources: current.resources.map((item) => item.instanceId === id ? { ...item, values: { ...item.values, [key]: value } } : item) }));
  const addRule = () => setProject((current) => ({ ...current, securityRules: [...current.securityRules, { id: uid(), direction: "Inbound", name: "Allow_in_Src_Dest", source: "", sourceDetails: "", sourcePort: "*", destination: "", destinationDetails: "", destinationPort: "", protocol: "TCP", action: "Allow", notes: "" }] }));
  const updateRule = (id: string, key: keyof Rule, value: string) => setProject((current) => ({ ...current, securityRules: current.securityRules.map((rule) => rule.id === id ? { ...rule, [key]: value } : rule) }));
  const exportExcel = () => download(excelXml(project, definitions), `${safeName(project.overview.projectName)}-Build-Plan.xls`, "application/vnd.ms-excel");
  const exportProject = () => download(JSON.stringify({ format: "cloud-project-build", version: 1, project }, null, 2), `${safeName(project.overview.projectName)}.json`, "application/json");
  const importProject = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) file.text().then((text) => { const parsed = JSON.parse(text); setProject(parsed.project || parsed); });
    event.target.value = "";
  };
  const patchTemplate = (patch: Partial<Resource>) => setDefinitions((current) => current.map((item) => item.id === activeTemplate.id ? { ...item, ...patch } : item));
  const patchField = (index: number, patch: Partial<Field>) => patchTemplate({ fields: activeTemplate.fields.map((field, i) => i === index && field.kind === "field" ? { ...field, ...patch } : field) });
  const importTemplate = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) file.text().then((text) => setDefinitions(JSON.parse(text)));
    event.target.value = "";
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand-lockup"><span className="brand-mark">CP</span><div><p className="eyebrow">Cloud Engineering</p><h1>Cloud Project Build Planner</h1></div></div>
        <div className="header-actions">
          <span className="save-state"><i />{savedAt ? `Saved locally ${savedAt}` : "Local draft"}</span>
          <button className="button ghost" onClick={() => { if (confirm("Start a new build plan?")) setProject(emptyProject); }}>New plan</button>
          <button className="button secondary" onClick={() => projectImport.current?.click()}>Open plan</button>
          <button className="button primary" onClick={exportExcel}>Export Excel</button>
          <input ref={projectImport} className="sr-only" type="file" accept=".json" onChange={importProject} />
        </div>
      </header>
      <div className="security-note"><strong>Planning data only.</strong> Do not enter passwords, client secrets, access keys, tokens, or other credentials.</div>
      <nav className="view-tabs">
        <button className={view === "build" ? "active" : ""} onClick={() => setView("build")}>Build workspace</button>
        <button className={view === "naming" ? "active" : ""} onClick={() => setView("naming")}>Naming standards</button>
        <button className={view === "template" ? "active" : ""} onClick={() => setView("template")}>Template editor</button>
      </nav>

      {view === "build" && <main className="workspace">
        <aside className="resource-panel">
          <div className="panel-heading"><div><p className="eyebrow">Resource catalog</p><h2>Add to this build</h2></div><span>{definitions.length}</span></div>
          <label className="search-box"><span>Search</span><input value={resourceSearch} onChange={(e) => setResourceSearch(e.target.value)} placeholder="VM, storage, network..." /></label>
          <div className="category-row">{categories.map((item) => <button key={item} className={category === item ? "active" : ""} onClick={() => setCategory(item)}>{item}</button>)}</div>
          <div className="resource-list">{visibleResources.map((resource) => <button key={resource.id} className="resource-option" onClick={() => addResource(resource.id)}><span><strong>{resource.title}</strong><small>{resource.category}</small></span><b>+</b></button>)}</div>
        </aside>

        <section className="build-canvas">
          <div className="canvas-intro"><div><p className="eyebrow">Build plan</p><h2>{project.overview.projectName || "Untitled cloud project"}</h2><p>Complete the foundation, add only the resources in scope, then export the engineer handoff.</p></div><div className="progress-card"><strong>{progress}%</strong><span>Resource fields completed</span><div><i style={{ width: `${progress}%` }} /></div></div></div>

          <details className="form-card" open><summary><span><b>01</b><span><strong>Project foundation</strong><small>Ownership, scope, environment, and delivery references</small></span></span></summary><div className="form-card-body">
            <div className="field-grid three">{overviewFields.map(([key, label, placeholder]) => <label className="field" key={key}><span>{label}</span><input type={key === "targetDate" ? "date" : "text"} value={project.overview[key] || ""} placeholder={placeholder} onChange={(e) => updateOverview(key, e.target.value)} /></label>)}</div>
            <label className="field full"><span>Project summary / desired outcome</span><textarea rows={4} value={project.overview.summary || ""} placeholder="Describe what is being built, why it is needed, and the expected outcome." onChange={(e) => updateOverview("summary", e.target.value)} /></label>
          </div></details>

          <details className="form-card" open><summary><span><b>02</b><span><strong>Technical requirements</strong><small>Connectivity, access, dependencies, resilience, and operational expectations</small></span></span></summary><div className="form-card-body"><label className="field full"><span>Requirements and architecture notes</span><textarea rows={8} value={project.technicalRequirements} placeholder={"Inbound\n• No external inbound access required\n• Private endpoint for internal users\n\nOutbound\n• Outbound to required Azure platform services only"} onChange={(e) => setProject((current) => ({ ...current, technicalRequirements: e.target.value }))} /></label></div></details>

          <details className="form-card"><summary><span><b>03</b><span><strong>Required tags</strong><small>{templateData.tags.length} standard metadata fields from the workbook</small></span></span></summary><div className="form-card-body field-grid three">{templateData.tags.map((tag) => <label className="field" key={tag}><span>{tag}</span><input value={project.tags[tag] || ""} onChange={(e) => setProject((current) => ({ ...current, tags: { ...current.tags, [tag]: e.target.value } }))} /></label>)}</div></details>

          <details className="form-card"><summary><span><b>04</b><span><strong>Security rules</strong><small>{project.securityRules.length} rules documented</small></span></span></summary><div className="form-card-body">
            {!project.securityRules.length ? <div className="empty-state compact"><strong>No NSG rules added</strong><p>Add inbound or outbound rules when network access is required.</p></div> :
              <div className="rule-stack">{project.securityRules.map((rule, index) => <article className="rule-card" key={rule.id}><div className="rule-title"><strong>Rule {index + 1}</strong><button onClick={() => setProject((current) => ({ ...current, securityRules: current.securityRules.filter((item) => item.id !== rule.id) }))}>Remove</button></div><div className="field-grid four">{([
                ["direction", "Direction"], ["name", "Rule name"], ["source", "Source"], ["sourceDetails", "Source details"], ["sourcePort", "Source port"], ["destination", "Destination"], ["destinationDetails", "Destination details"], ["destinationPort", "Destination port"], ["protocol", "Protocol"], ["action", "Action"], ["notes", "Notes"],
              ] as Array<[keyof Rule, string]>).map(([key, label]) => <label className={`field ${key === "notes" ? "span-two" : ""}`} key={key}><span>{label}</span>{["direction", "protocol", "action"].includes(key) ? <select value={rule[key]} onChange={(e) => updateRule(rule.id, key, e.target.value)}>{(key === "direction" ? ["Inbound", "Outbound"] : key === "protocol" ? ["TCP", "UDP", "ICMP", "Any"] : ["Allow", "Deny"]).map((option) => <option key={option}>{option}</option>)}</select> : <input value={rule[key]} onChange={(e) => updateRule(rule.id, key, e.target.value)} />}</label>)}</div></article>)}</div>}
            <button className="button secondary" onClick={addRule}>+ Add security rule</button>
          </div></details>

          <div className="section-label"><span>05</span><div><h3>Azure resources</h3><p>{project.resources.length ? `${project.resources.length} resource instances in this build` : "Choose resources from the catalog on the left"}</p></div></div>
          {!project.resources.length ? <div className="empty-state"><span className="empty-mark">+</span><strong>Build the resource scope</strong><p>Choose a resource type from the catalog. Add the same type more than once when the project needs multiple instances.</p></div> :
            <div>{project.resources.map((instance) => {
              const definition = definitions.find((item) => item.id === instance.resourceId);
              if (!definition) return null;
              const fieldCount = definition.fields.filter((field) => field.kind === "field").length;
              return <article className="instance-card" key={instance.instanceId}>
                <button className="instance-summary" onClick={() => updateInstance(instance.instanceId, { open: !instance.open })}><span className="instance-badge">{definition.title.slice(0, 2).toUpperCase()}</span><span><strong>{instance.name}</strong><small>{definition.category} · {Object.values(instance.values).filter(Boolean).length} of {fieldCount} fields</small></span><i>{instance.open ? "−" : "+"}</i></button>
                {instance.open && <div className="instance-body"><div className="instance-toolbar"><label className="field grow"><span>Display name in handoff</span><input value={instance.name} onChange={(e) => updateInstance(instance.instanceId, { name: e.target.value })} /></label><button className="danger-link" onClick={() => setProject((current) => ({ ...current, resources: current.resources.filter((item) => item.instanceId !== instance.instanceId) }))}>Remove resource</button></div>
                  <div className="field-grid two">{definition.fields.map((field, index) => field.kind === "group" ? <h4 className="field-group" key={`${field.label}-${index}`}>{field.label}</h4> : <label className={`field ${field.input === "textarea" ? "full" : ""}`} key={field.key}><span>{field.label}</span>{field.input === "select" ? <select value={instance.values[field.key] || ""} onChange={(e) => updateValue(instance.instanceId, field.key, e.target.value)}><option value="">Select...</option>{field.options?.map((option) => <option key={option}>{option}</option>)}</select> : field.input === "textarea" ? <textarea rows={3} value={instance.values[field.key] || ""} placeholder={field.suggestion} onChange={(e) => updateValue(instance.instanceId, field.key, e.target.value)} /> : <input value={instance.values[field.key] || ""} placeholder={field.suggestion} onChange={(e) => updateValue(instance.instanceId, field.key, e.target.value)} />}{field.help && <small>{field.help}</small>}</label>)}</div>
                  <label className="field full"><span>Implementation notes</span><textarea rows={3} value={instance.notes} placeholder="Dependencies, exceptions, Bicep module notes, sequence, or acceptance criteria..." onChange={(e) => updateInstance(instance.instanceId, { notes: e.target.value })} /></label>
                </div>}
              </article>;
            })}</div>}

          <section className="handoff-card"><div><p className="eyebrow">Engineer handoff</p><h3>Ready to package the build plan?</h3><p>Export a formatted multi-sheet Excel workbook, print a presentation-ready PDF, or save the editable project file.</p></div><div className="handoff-actions"><button className="button primary" onClick={exportExcel}>Export Excel</button><button className="button secondary" onClick={() => print()}>Print / PDF</button><button className="button ghost" onClick={exportProject}>Save editable plan</button></div></section>
        </section>
      </main>}

      {view === "naming" && <main className="single-view"><section className="page-heading"><div><p className="eyebrow">Reference library</p><h2>Azure naming standards</h2><p>{templateData.namingRules.length} current conventions included from the attached naming workbook.</p></div><a className="button primary" href={NAMING_URL} target="_blank" rel="noreferrer">Open source document ↗</a></section><label className="search-box wide"><span>Search standards</span><input value={namingSearch} onChange={(e) => setNamingSearch(e.target.value)} placeholder="Search resource, convention, or example..." /></label><div className="naming-table-wrap"><table className="naming-table"><thead><tr><th>Resource</th><th>Convention</th><th>Example</th><th>Notes</th></tr></thead><tbody>{namingRules.map((rule, index) => <tr key={`${rule.resource}-${index}`}><td><strong>{rule.resource}</strong></td><td><code>{rule.convention}</code></td><td><code>{rule.example}</code></td><td>{rule.notes}</td></tr>)}</tbody></table></div></main>}

      {view === "template" && activeTemplate && <main className="template-view"><aside className="template-sidebar"><div><p className="eyebrow">No-code configuration</p><h2>Template editor</h2><p>Adjust the form without changing site code. Changes stay in this browser until exported.</p></div><label className="field"><span>Resource type</span><select value={activeTemplate.id} onChange={(e) => setTemplateId(e.target.value)}>{definitions.map((definition) => <option value={definition.id} key={definition.id}>{definition.title}</option>)}</select></label><div className="template-actions"><button className="button secondary" onClick={() => download(JSON.stringify(definitions, null, 2), "cloud-build-template.json", "application/json")}>Export template</button><button className="button ghost" onClick={() => templateImport.current?.click()}>Import template</button><button className="button ghost" onClick={() => { if (confirm("Restore the original workbook-derived template?")) setDefinitions(templateData.resources as Resource[]); }}>Restore original</button><input ref={templateImport} className="sr-only" type="file" accept=".json" onChange={importTemplate} /></div></aside><section className="template-canvas"><div className="field-grid two template-meta"><label className="field"><span>Resource title</span><input value={activeTemplate.title} onChange={(e) => patchTemplate({ title: e.target.value })} /></label><label className="field"><span>Category</span><input value={activeTemplate.category} onChange={(e) => patchTemplate({ category: e.target.value })} /></label></div><div className="template-list">{activeTemplate.fields.map((field, index) => field.kind === "group" ? <div className="template-group-row" key={`${field.label}-${index}`}><strong>{field.label}</strong><span>Section heading</span></div> : <article className="template-field-row" key={field.key}><div className="drag-handle">⋮⋮</div><div className="field-grid three grow"><label className="field"><span>Field label</span><input value={field.label} onChange={(e) => patchField(index, { label: e.target.value })} /></label><label className="field"><span>Naming hint / default</span><input value={field.suggestion || ""} onChange={(e) => patchField(index, { suggestion: e.target.value })} /></label><label className="field"><span>Help text</span><input value={field.help || ""} onChange={(e) => patchField(index, { help: e.target.value })} /></label></div><button className="remove-field" onClick={() => patchTemplate({ fields: activeTemplate.fields.filter((_, i) => i !== index) })}>Remove</button></article>)}</div><button className="button primary" onClick={() => patchTemplate({ fields: [...activeTemplate.fields, { kind: "field", key: `custom_${uid()}`, label: "New field", input: "text" }] })}>+ Add field</button></section></main>}

      <section className="print-report"><h1>{project.overview.projectName || "Cloud Project Build Plan"}</h1><p>Azure engineering handoff · {new Date().toLocaleDateString()}</p><h2>Project foundation</h2><dl>{overviewFields.map(([key, label]) => project.overview[key] && <div key={key}><dt>{label}</dt><dd>{project.overview[key]}</dd></div>)}</dl>{project.overview.summary && <><h2>Project summary</h2><p>{project.overview.summary}</p></>}<h2>Technical requirements</h2><p className="preline">{project.technicalRequirements || "Not provided"}</p><h2>Tags</h2><table><tbody>{templateData.tags.map((tag) => <tr key={tag}><th>{tag}</th><td>{project.tags[tag] || "—"}</td></tr>)}</tbody></table>{project.resources.map((instance) => { const definition = definitions.find((item) => item.id === instance.resourceId); return definition ? <section key={instance.instanceId}><h2>{instance.name}</h2><table><tbody>{definition.fields.map((field, index) => field.kind === "group" ? <tr key={`${field.label}-${index}`}><th colSpan={2}>{field.label}</th></tr> : <tr key={field.key}><th>{field.label}</th><td>{instance.values[field.key] || "—"}</td></tr>)}</tbody></table></section> : null; })}<p className="print-footer">Planning data only. Handle passwords, secrets, keys, and tokens through approved secure processes.</p></section>
    </div>
  );
}
