"use client";

import { useMemo, useState } from "react";

type Session = { id:number; user:string; name:string; host:string; state:"Active"|"Disconnected"; duration:string; latency:number|null };
const sessionsSeed:Session[] = [
  {id:1,user:"Jody.Ingram@wellstar.org",name:"Jody Ingram",host:"SH-itec-p-0.whs.int",state:"Active",duration:"—",latency:null},
  {id:2,user:"ShivaSaketh.Vuppula@wellstar.org",name:"ShivaSaketh Vuppula",host:"SH-itec-p-2.whs.int",state:"Active",duration:"—",latency:null},
  {id:3,user:"Emmanuel.Fumero@wellstar.org",name:"Emmanuel Fumero",host:"SH-itec-p-1.whs.int",state:"Active",duration:"—",latency:null},
  {id:4,user:"Clay.Hall@wellstar.org",name:"Clay Hall",host:"SH-ecct-t-46.whs.int",state:"Active",duration:"—",latency:null},
  {id:5,user:"John.Granado@wellstar.org",name:"John Granado",host:"SH-itec-p-5.whs.int",state:"Active",duration:"—",latency:null},
  {id:6,user:"Geoff.Williams@wellstar.org",name:"Geoff Williams",host:"SH-ecct-t-43.whs.int",state:"Active",duration:"—",latency:null},
  {id:7,user:"Ed.Cooley@wellstar.org",name:"Ed Cooley",host:"SH-ecct-t-33.whs.int",state:"Active",duration:"—",latency:null},
  {id:8,user:"Hansel.Minor@wellstar.org",name:"Hansel Minor",host:"SH-ecct-t-29.whs.int",state:"Active",duration:"—",latency:null},
  {id:9,user:"Doug.Pearce@wellstar.org",name:"Doug Pearce",host:"SH-ecct-t-30.whs.int",state:"Active",duration:"—",latency:null},
  {id:10,user:"Aaron.Watkinson@wellstar.org",name:"Aaron Watkinson",host:"SH-ecct-t-41.whs.int",state:"Active",duration:"—",latency:null},
];
const hosts = [
  {name:"SH-itec-p-0.whs.int",status:"Available",sessions:1},
  {name:"SH-itec-p-2.whs.int",status:"Available",sessions:1},
  {name:"SH-itec-p-1.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-46.whs.int",status:"Available",sessions:1},
  {name:"SH-itec-p-5.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-43.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-33.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-29.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-30.whs.int",status:"Available",sessions:1},
  {name:"SH-ecct-t-41.whs.int",status:"Available",sessions:1},
];
type Tab = "Overview"|"Sessions"|"Session hosts"|"Insights";

export default function Home(){
  const [tab,setTab]=useState<Tab>("Overview");
  const [sessions,setSessions]=useState(sessionsSeed);
  const [query,setQuery]=useState("");
  const [filter,setFilter]=useState("All");
  const [selected,setSelected]=useState<Session|null>(null);
  const [toast,setToast]=useState("");
  const [config,setConfig]=useState(false);
  const [connected,setConnected]=useState(false);
  const [clientId,setClientId]=useState("");
  const [tenantId,setTenantId]=useState("");
  const filtered=useMemo(()=>sessions.filter(s=>(s.name+s.user+s.host).toLowerCase().includes(query.toLowerCase())&&(filter==="All"||s.state===filter)),[sessions,query,filter]);
  const notify=(m:string)=>{setToast(m);setTimeout(()=>setToast(""),3000)};
  const connect=async()=>{
    if(!tenantId||!clientId){notify("Enter the tenant ID and application client ID.");return}
    try{
      const {PublicClientApplication}=await import("@azure/msal-browser");
      const app=new PublicClientApplication({auth:{clientId,authority:`https://login.microsoftonline.com/${tenantId}`,redirectUri:location.origin}});
      await app.initialize();
      await app.loginPopup({scopes:["https://management.azure.com/user_impersonation"],loginHint:"Jody.Ingram@wellstar.org"});
      localStorage.setItem("avd-director-config",JSON.stringify({tenantId,clientId}));
      setConnected(true);setConfig(false);notify("Connected to Azure.");
    }catch{notify("Sign-in did not complete. Check the app registration and redirect URI.")}
  };
  const logoff=()=>{if(!selected)return;setSessions(x=>x.filter(s=>!(s.id===selected.id&&s.host===selected.host)));notify(`${selected.name} was logged off ${selected.host}.`);setSelected(null)};
  return <div className="shell">
    <aside>
      <div className="brand"><b>W</b><span><strong>Wellstar</strong><small>AVD Director</small></span></div>
      <nav>{(["Overview","Sessions","Session hosts","Insights"] as Tab[]).map((x,i)=><button key={x} className={tab===x?"on":""} onClick={()=>setTab(x)}><i>{["⌂","◎","▤","⌁"][i]}</i>{x}{x==="Sessions"&&<em>{sessions.length}</em>}{x==="Session hosts"&&<em>{hosts.length}</em>}</button>)}</nav>
      <section className="resource"><small>CONNECTED RESOURCE</small><strong>WS_AVD_EA</strong><span>vdpool-eus2-ecct-dsk-prs-t-01</span><i>● East US 2 · Healthy</i></section>
      <footer><span className="avatar yellow">JI</span><span><strong>Jody Ingram</strong><small>Cloud Architect</small></span><button onClick={()=>setConfig(true)}>⚙</button></footer>
    </aside>
    <main>
      <header><span>AVD / {tab}</span><div><label className={connected?"live":""}>● {connected?"Live Azure data":"Demo data"}</label><button onClick={()=>notify("Dashboard refreshed.")}>↻ Refresh</button><button className="primary" onClick={()=>setConfig(true)}>{connected?"Azure connected":"Connect Azure"}</button></div></header>
      <div className="content">
        <div className="heading"><div><small>ECCT PERSONAL DESKTOPS</small><h1>{tab}</h1><p>Host pool health and user activity · Updated just now</p></div>{tab==="Sessions"&&<button onClick={()=>notify("CSV export prepared.")}>⇩ Export CSV</button>}</div>
        {tab==="Overview"&&<>
          <div className="metrics">
            <Metric icon="◎" tone="blue" label="ACTIVE SESSIONS" value={sessions.filter(s=>s.state==="Active").length.toString()} note="Current portal snapshot"/>
            <Metric icon="◷" tone="amber" label="DISCONNECTED" value={sessions.filter(s=>s.state==="Disconnected").length.toString()} note="Review idle sessions"/>
            <Metric icon="▤" tone="green" label="SESSION HOSTS" value={hosts.length.toString()} note="All reporting active"/>
            <Metric icon="⌁" tone="purple" label="AVG. LATENCY" value="—" note="Requires Insights"/>
          </div>
          <div className="split">
            <section className="card chart-card"><Title title="Session activity" sub="Last 12 hours"/><div className="chart"><svg viewBox="0 0 600 180" preserveAspectRatio="none"><defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#087f73" stopOpacity=".22"/><stop offset="1" stopColor="#087f73" stopOpacity="0"/></linearGradient></defs><path className="area" d="M0 154 C48 148 55 110 102 116S150 91 196 95S249 60 294 69S354 37 403 47S468 29 516 37S558 18 600 25V180H0Z"/><path className="line" d="M0 154 C48 148 55 110 102 116S150 91 196 95S249 60 294 69S354 37 403 47S468 29 516 37S558 18 600 25"/></svg><div><span>8 PM</span><span>12 AM</span><span>4 AM</span><span>8 AM</span></div></div></section>
            <section className="card"><Title title="Session snapshot" sub="Current Azure portal data"/><Alert icon="✓" title="10 active user sessions" sub="No disconnected sessions in this snapshot" action={()=>setTab("Sessions")}/><Alert icon="▤" title="10 session hosts in use" sub="One active session on each listed host" action={()=>setTab("Session hosts")}/><div className="clear">✓ <span><strong>All listed sessions are active</strong><small>Captured from the supplied Azure portal view</small></span></div></section>
          </div>
          <SessionTable sessions={sessions.slice(0,4)} select={setSelected} view={()=>setTab("Sessions")}/>
        </>}
        {tab==="Sessions"&&<><div className="toolbar"><label>⌕<input placeholder="Search user, email, or host…" value={query} onChange={e=>setQuery(e.target.value)}/></label><select value={filter} onChange={e=>setFilter(e.target.value)}><option>All</option><option>Active</option><option>Disconnected</option></select><span>{filtered.length} results</span></div><SessionTable sessions={filtered} select={setSelected}/></>}
        {tab==="Session hosts"&&<div className="host-grid">{hosts.map(h=><section className="host" key={h.name}><div className="host-title"><b className="ok">▤</b><span><strong>{h.name}</strong><small>● {h.status}</small></span><button>•••</button></div><div className="host-data"><div><small>ACTIVE SESSIONS</small><strong>{h.sessions}</strong></div><div><small>CPU</small><strong>—</strong></div><div><small>MEMORY</small><strong>—</strong></div></div><footer>Metrics available after Insights connection<button onClick={()=>notify("Drain mode requires live Azure connection.")}>Manage →</button></footer></section>)}</div>}
        {tab==="Insights"&&<><section className="card insight"><div><small>AZURE MONITOR INSIGHTS</small><h2>Connection quality at a glance</h2><p>Link the Log Analytics workspace to query AVD Insights for connection success, latency, sign-in duration, and user input delay.</p><button className="primary" onClick={()=>setConfig(true)}>Configure Insights</button></div><div className="donut"><span>98.7%<small>success</small></span></div></section><div className="metrics three"><Metric label="CONNECTION SUCCESS" value="98.7%" note="↑ 0.4% this week"/><Metric label="AVG. SIGN-IN" value="18.2 sec" note="FSLogix included"/><Metric label="USER INPUT DELAY" value="6 ms" note="95th percentile"/></div></>}
      </div>
    </main>
    {selected&&<div className="backdrop" onMouseDown={()=>setSelected(null)}><section className="modal" onMouseDown={e=>e.stopPropagation()}><b className="symbol danger">↪</b><h2>Log off this user?</h2><p><strong>{selected.name}</strong> will be forcibly signed out of <strong>{selected.host}</strong>. Unsaved work may be lost.</p><div className="user"><span className="avatar">{selected.name.split(" ").map(n=>n[0]).join("")}</span><span><strong>{selected.user}</strong><small>Session {selected.id} · {selected.state}</small></span></div><div className="actions"><button onClick={()=>setSelected(null)}>Cancel</button><button className="danger-button" onClick={logoff}>Log off user</button></div></section></div>}
    {config&&<div className="backdrop" onMouseDown={()=>setConfig(false)}><section className="modal config" onMouseDown={e=>e.stopPropagation()}><b className="symbol">A</b><h2>Connect Microsoft Azure</h2><p>Use a delegated Entra app registration. Microsoft handles your credentials; this dashboard never stores your password.</p><label>Tenant ID<input value={tenantId} onChange={e=>setTenantId(e.target.value)} placeholder="Wellstar Entra tenant ID"/></label><label>Application (client) ID<input value={clientId} onChange={e=>setClientId(e.target.value)} placeholder="App registration client ID"/></label><div className="note"><strong>Required setup</strong><span>SPA redirect: <code>{typeof window!=="undefined"?location.origin:"this site URL"}</code></span><span>Delegated API: Azure Service Management / user_impersonation</span><span>RBAC: Desktop Virtualization User Session Operator or Contributor</span></div><div className="actions"><button onClick={()=>setConfig(false)}>Keep demo mode</button><button className="primary" onClick={connect}>Sign in as Jody</button></div></section></div>}
    {toast&&<div className="toast">✓ &nbsp;{toast}</div>}
  </div>
}

function Metric({icon,tone,label,value,note}:{icon?:string;tone?:string;label:string;value:string;note:string}){return <section className="metric">{icon&&<b className={tone}>{icon}</b>}<span><small>{label}</small><strong>{value}</strong><em>{note}</em></span></section>}
function Title({title,sub}:{title:string;sub:string}){return <div className="title"><span><strong>{title}</strong><small>{sub}</small></span></div>}
function Alert({icon,title,sub,action}:{icon:string;title:string;sub:string;action:()=>void}){return <div className="alert"><b>{icon}</b><span><strong>{title}</strong><small>{sub}</small></span><button onClick={action}>Inspect</button></div>}
function SessionTable({sessions,select,view}:{sessions:Session[];select:(s:Session)=>void;view?:()=>void}){return <section className="card table-card"><div className="title"><span><strong>User sessions</strong><small>Current sessions in the selected host pool</small></span>{view&&<button onClick={view}>View all →</button>}</div><div className="table-scroll"><table><thead><tr><th>User</th><th>Session host</th><th>Status</th><th>Connected</th><th>Latency</th><th/></tr></thead><tbody>{sessions.map(s=><tr key={s.host+s.id}><td><span className="avatar">{s.name.split(" ").map(n=>n[0]).join("")}</span><span><strong>{s.name}</strong><small>{s.user}</small></span></td><td><strong>{s.host}</strong><small>Azure Virtual Desktop</small></td><td><i className={s.state==="Active"?"active":"disconnected"}>● {s.state}</i></td><td>{s.duration}</td><td className={s.latency!==null&&s.latency>55?"latency-warn":""}>{s.latency===null?"—":`${s.latency} ms`}</td><td><button onClick={()=>select(s)}>Log off</button></td></tr>)}</tbody></table>{sessions.length===0&&<div className="empty">No sessions match your filters.</div>}</div></section>}
