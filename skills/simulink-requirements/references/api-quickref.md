# slreq Traceability API — Quick Reference

Verified against sim_mission project (MATLAB R2025a, Requirements Toolbox).

---

## Top-Level Functions

| Call | Returns | Notes |
|---|---|---|
| `slreq.load(path)` | `slreq.ReqSet` or `slreq.LinkSet` | Idempotent. Works for `.slreqx` and `.slmx`. Use in scripts (not `slreq.open`). |
| `slreq.find('type','ReqSet')` | `slreq.ReqSet` array | All currently loaded ReqSets |
| `slreq.find('type','LinkSet')` | `slreq.LinkSet` array | All currently loaded LinkSets |
| `slreq.find('type','ReqSet','Name','X')` | `slreq.ReqSet` | Find by name |
| `slreq.clear()` | — | Unload all sets from memory (does not delete files) |
| `slreq.saveAll()` | — | Save all open sets including cross-artifact link files |
| `slreq.new(path)` | `slreq.ReqSet` | Create a new, empty requirement set |
| `slreq.createLink(src, dst)` | `slreq.Link` | Create a new link between two artifacts |
| `slreq.import(docPath, ...)` | `[refCount, path, reqSet]` | Import from Excel / Word / ReqIF. **Does not save** — call `reqSet.save()`. For Excel, pass `rows=[first last]` to skip the header row, and `idColumn`/`summaryColumn`/`descriptionColumn`/`rationaleColumn` to map columns. |
| `slreq.export(reqSet, ...)` | char | Exports **ReqIF only**, not Excel. For xlsx, build a table and use `writetable` (see `code/exportRequirementsToExcel.m`). |

---

## slreq.ReqSet

| Property / Method | Type | Notes |
|---|---|---|
| `.Name` | string | Human name |
| `.Filename` | string | Full path to `.slreqx` file |
| `.Revision` | int | Increments on every save |
| `.ModifiedBy` | string | Last editor username |
| `.find('Type','Requirement')` | `slreq.Requirement[]` | All nodes (Functional + Container) |
| `.find('Id', 'SR-001')` | `slreq.Requirement` | By user ID string |
| `.find('SID', 5)` | `slreq.Requirement` | By integer SID |
| `.add()` | `slreq.Requirement` | Create a new top-level requirement |
| `.children()` | `slreq.Requirement[]` | Top-level children |
| `.save()` | — | Save this set |
| `.close()` | — | Close without saving |
| `.updateImplementationStatus()` | — | Must call before `getImplementationStatus()` |
| `.getImplementationStatus()` | struct | `.implemented`, `.justified`, `.none`, `.total` |

---

## slreq.Requirement

| Property / Method | Type | Notes |
|---|---|---|
| `.Id` | string | User-assigned ID (e.g. `'SR-SYS-001'`) |
| `.SID` | int | Internal ID, unique within file |
| `.Type` | string | `'Functional'`, `'Container'`, `'Safety'`, `'Informational'` |
| `.Summary` | string | One-line summary |
| `.Description` | string | **HTML**. Use `getDescriptionAsText()` for plain text. |
| `.Rationale` | string | Plain text |
| `.Index` | string | Hierarchical position, e.g. `'2.1.3'` |
| `.CreatedBy` / `.ModifiedBy` | string | Username |
| `.getDescriptionAsText()` | string | Strips HTML from Description |
| `.getRationaleAsText()` | string | Strips HTML from Rationale |
| `.outLinks()` | `slreq.Link[]` | Links going OUT from this req |
| `.inLinks()` | `slreq.Link[]` | Links pointing INTO this req |
| `.children()` | `slreq.Requirement[]` | Child requirements |
| `.parent()` | `slreq.Requirement` or `slreq.ReqSet` | Parent node |
| `.add(...)` | `slreq.Requirement` | Add a child requirement |
| `.getImplementationStatus()` | struct | Requires `rs.updateImplementationStatus()` first |
| `.getVerificationStatus()` | struct | Requires test results to be computed |

---

## slreq.LinkSet

| Property / Method | Type | Notes |
|---|---|---|
| `.Filename` | string | Full path to `.slmx` file |
| `.Artifact` | string | Full path to the artifact this LinkSet belongs to |
| `.Domain` | string | Primary domain |
| `.getLinks()` | `slreq.Link[]` | All links in this set |
| `.getBrokenLinks()` | `[slreq.Link[], details]` | Links with missing destinations |
| `.getOrphanLinks()` | `slreq.Link[]` | Links with missing sources |
| `.hasLinks()` | logical | True if any links exist |
| `.deleteOrphanLinks()` | int | Remove all orphan links, returns count |

---

## slreq.Link

| Property / Method | Type | Notes |
|---|---|---|
| `.Type` | string | `'Derive'`, `'Implement'`, `'Verify'`, `'Relate'`, `'Refine'` |
| `.Description` | string | Optional label/description |
| `.SID` | int | Internal link ID |
| `.isResolved()` | logical | True only if BOTH ends are resolved. Often false — do not rely on this. |
| `.isResolvedSource()` | logical | Source end is loaded |
| `.isResolvedDestination()` | logical | Destination end is loaded |
| `.source()` | struct | `{.domain, .artifact, .id}` — source end. Always readable. |
| `.getReferenceInfo()` | struct | `{.domain, .artifact, .id}` — destination end. Always readable. |
| `.getSourceLabel()` | string | Human label for source. Always readable. |
| `.getDestinationLabel()` | string | Human label for destination. Always readable. |
| `.getSourceURL()` | string | Navigate-to URL for source |
| `.getDestinationURL()` | string | Navigate-to URL for destination |
| `.remove()` | — | Delete this link |
| `.linkSet()` | `slreq.LinkSet` | The LinkSet containing this link |

---

## Link Domain Reference

| Domain string | Artifact | ID format | Example |
|---|---|---|---|
| `linktype_rmi_slreq` | `.slreqx` | Integer SID as string | `"8"` |
| `linktype_rmi_simulink` | `.slx` model | `:SID` path | `":4:27"` |
| `linktype_rmi_testmgr` | `.mldatx` test | UUID | `"4ea02da5-..."` |
| `linktype_rmi_word` | `.docx` Word doc | `@Simulink_requirement_item_N` | `"@Simulink_requirement_item_3"` |

---

## Link Direction Semantics

```
Parent req  ──[Derive]─────> Derived child req (parent has outLink; child has inLink)
Component   ──[Implement]──> Requirement       (component has outLink; req has inLink)
Model block ──[Implement]──> Requirement       (block has outLink; req has inLink)
Test case   ──[Verify]─────> Requirement       (test has outLink; req has inLink)
```

In this workflow link direction goes **parent/active → child/requirement-end** for all
three types: the parent SN points at the SR it decomposes into; the architecture
element points at the SR it implements; the test case points at the SR it verifies.

A requirement **derives from** another (parent) when it has `inLinks()` of type `Derive`.
A requirement **is implemented by** an architecture element when it has `inLinks()` of
type `Implement` whose source is a System Composer component (or a Simulink block).
A requirement **is verified by** a test case when it has `inLinks()` of type `Verify`.
`Refine` is reserved for requirement-to-requirement refinement (more specific child
requirement of the same artifact kind) and is not used for requirement → architecture
in this workflow.

---

## File Discovery Pattern

```matlab
projRoot = 'C:\path\to\project';
reqxFiles = dir(fullfile(projRoot, '**', '*.slreqx'));
slmxFiles = dir(fullfile(projRoot, '**', '*.slmx'));

for i = 1:numel(reqxFiles)
    slreq.load(fullfile(reqxFiles(i).folder, reqxFiles(i).name));
end
for i = 1:numel(slmxFiles)
    try
        slreq.load(fullfile(slmxFiles(i).folder, slmxFiles(i).name));
    catch; end  % Skip missing artifacts gracefully
end
```
