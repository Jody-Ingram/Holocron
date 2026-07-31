# Cloud Project Build Planner

An editable Azure project intake and engineering handoff site derived from standardized Microsoft documentation around naming and best practices. 

## Included

- Project foundation, technical requirements, required tags, and NSG rules
- 46 Azure resource templates with workbook-derived fields and guidance
- 97 searchable Azure naming standards
- Browser-local autosave
- Excel-compatible multi-sheet export
- Print / PDF engineer handoff
- Editable project JSON import/export
- No-code resource template editor and template JSON import/export

## Instructions to Run Locally

```bash
npm install
npm run dev
```

## Main files

- `app/page.tsx` — form behavior, exports, and template editor
- `app/globals.css` — visual design, responsive layout, and print styling
- `app/template-data.json` — resource definitions and naming standards

Do not enter passwords, keys, tokens, client secrets, or other credentials into
the planner. Use approved secure processes for secrets.
