---
name: simulink-requirements
description: >
  Use this skill for all requirements-related work in a MATLAB MBSE project using
  the Requirements Toolbox (slreq). Covers creating and populating requirement sets,
  derivation links, test case requirements, verification coverage, reading and tracing
  links across requirement sets and models, checking link health, allocating requirements
  to components (Implement links), and building traceability reports. Trigger when the user
  asks about slreq API, slreqx files, slmx link files, outLinks/inLinks, traceability
  matrices, coverage analysis, broken links, or mapping requirements to architecture
  components. Use proactively for any requirements or traceability task.
---

# MATLAB Requirements Toolbox — Requirements & Traceability

This skill covers everything in the `slreq` API: creating and reading requirements,
managing traceability links, checking verification coverage, allocating requirements
to architecture components, and auditing link health.

For **Simulink Test** file creation (`.mldatx`, `sltest.testmanager`) see the
`simulink-test` skill. For architecture phases (System Composer models, functional
decomposition, functional→physical allocation) see the `mbse-architecture` skill.

See `references/api-quickref.md` in this skill folder for a compact one-page API reference.

---

## The Two File Types

| Extension | Class | Role |
|---|---|---|
| `.slreqx` | `slreq.ReqSet` | Stores requirements (text, hierarchy) |
| `.slmx` | `slreq.LinkSet` | Stores traceability links between artifacts |

Every `.slreqx` file has a paired `.slmx` file (named `MyReqs~slreqx.slmx`).
Model files (`.slx`) also have paired `.slmx` files (named `MyModel~mdl.slmx`).
Test files (`.mldatx`) have `MyTests~mldatx.slmx`.

---

# Requirements (Phases 1–2)

---

## Two-Level Structure

| Level | ID scheme | Character |
|---|---|---|
| Stakeholder Needs | `SN-SYS-001` | Operational, informal — what the user/operator needs |
| System Requirements | `SR-SYS-001` | Formal, testable — what the system shall do |

Each SR traces back to one or more SNs via a `Derive` link.

---

## Well-Formed Shall-Statements

- One obligation per requirement ("shall", not "should" or "will")
- Measurable and testable — include numeric criteria where possible
- Avoid `<` and `>` in Description fields — the Requirements Editor treats them
  as HTML. Use "not exceeding", "at least", "greater than", etc.

**Good:** `The system shall respond with latency not exceeding 100 ms.`
**Avoid:** `The system shall respond with latency < 100 ms.`

---

## Creating Requirement Sets

```matlab
slreq.clear();
if isfile('MyReqs.slreqx'), delete('MyReqs.slreqx'); end
rs = slreq.new('MyReqs.slreqx');        % NOT slreq.createReqSet (does not exist)

req = rs.add();
req.Id          = 'SR-SYS-001';
req.Summary     = 'Short title';
req.Description = 'The system shall ...';
req.Rationale   = 'Why this requirement exists.';

rs.save();
```

### Find a requirement by ID

```matlab
req = rs.find('Id', 'SR-SYS-001');
```

---

## Valid Link Types

| Type | Meaning | Direction |
|---|---|---|
| `"Derive"` | Parent decomposes into derived child | SN (source) → SR (destination) |
| `"Implement"` | Architecture element (or model block) implements requirement | Component/Block (source) → SR (destination) |
| `"Verify"` | Test case verifies requirement | TC (source) → SR (destination) |
| `"Refine"` | Requirement refined into a more specific requirement (same artifact kind, more detail). Not used for SR → architecture in this workflow. | SR (source) → SR (destination) |
| `"Relate"` | Informal relationship | Bidirectional |

---

## Creating Links

```matlab
% Req-to-req derivation: parent (e.g. SN) decomposes into derived child (e.g. SR)
lnk = slreq.createLink(parentReq, childReq);
lnk.Type = 'Derive';

% Model block to req (model must be open in Simulink)
lnk = slreq.createLink(blockHandle, req);
lnk.Type = 'Implement';

% Test case requirement to SR
lnk = slreq.createLink(tc, sr);
lnk.Type = 'Verify';

slreq.saveAll();   % always call after creating cross-artifact links
```

### Side effect: `{modelName}~mdl.slmx` link store

The first time you create a link **into** a Simulink/System Composer model (component,
subsystem, or block as either source or destination), slreq writes a `{modelName}~mdl.slmx`
file next to the `.slx`. This file stores the link data and is required for the links
to survive a reload. After creating links into a model, **always** add this file to the
MATLAB project alongside the `.slx`:

```matlab
addFile(proj, fullfile(archDir, 'MyModel.slx'));
addFile(proj, fullfile(archDir, 'MyModel~mdl.slmx'));   % link store, created automatically
```

Forgetting to register the `.slmx` causes project file-system checks to fail and the
traceability links won't travel when the project is shared.

---

## Requirements Script Skeleton

See [`code/buildMyRequirements.m`](code/buildMyRequirements.m) for the full parameterized function:

```
buildMyRequirements(snFile, srFile)
```

---

## Exporting a Requirement Set to Excel

There is **no public slreq Excel-export API**. `slreq.export` emits ReqIF only,
and the Requirements Editor's File → Export → Microsoft Excel is GUI-only. To
script an xlsx export, build the table yourself with `writetable`.

**Requirement sets can be hierarchical.** `find(rs, 'Type', 'Requirement')`
returns *all* requirements flat in storage order, which silently drops the
parent/child structure the Requirements Editor displays. To preserve hierarchy:

- Find top-level reqs by filtering for `~isa(r.parent(), 'slreq.Requirement')`
  — top-level items have the ReqSet as their parent, not another requirement
- Recurse via the `children()` method (a method, not a property)
- Emit rows depth-first so each parent precedes its children
- Sort siblings with a natural sort on the `Index` string ("1", "1.2", "1.10"
  as numeric tuples — lexicographic string sort would put 1.10 before 1.2)
- Write `Index`, `Depth`, `ParentIndex` columns so the hierarchy is recoverable
  from the xlsx alone

Note also that `r.Id` may be an auto-assigned SID like `#13` if the set was
authored in the Editor without user IDs — always include the `Index` column as
a stable user-meaningful identifier.

Extract parent IDs from incoming `Derive` links so the `DerivedFrom` column is
populated instead of stuffing parent refs into Rationale:

```matlab
function ids = deriveParents(req)
    ids  = strings(0,1);
    lnks = req.inLinks();
    for k = 1:numel(lnks)
        if strcmp(lnks(k).Type, 'Derive')
            % getSourceLabel() returns "ID Summary"; strtok pulls just the ID
            ids(end+1,1) = string(strtok(lnks(k).getSourceLabel())); %#ok<AGROW>
        end
    end
end
```

See [`code/exportRequirementsToExcel.m`](code/exportRequirementsToExcel.m) for the
full parameterized function:

```
exportRequirementsToExcel(slreqxFile)
```

---

## Importing a Requirement Set from Excel

`slreq.import` handles Excel natively, but has three gotchas worth wrapping:
it treats the header row as a requirement (use `rows=[2 lastRow]` to skip it),
it auto-creates a `Container` node wrapping the items, and — most importantly —
it does **not save to disk** (the returned ReqSet is marked `Dirty=1`; call
`.save()` explicitly).

Use `AsReference=false` to get an editable copy rather than read-only references
to the xlsx, and map columns with `idColumn` / `summaryColumn` /
`descriptionColumn` / `rationaleColumn`.

See [`code/importMyRequirements.m`](code/importMyRequirements.m) for a wrapper
that applies the defaults and saves:

```
importMyRequirements(xlsxFile, setName)
```

---

# Verification (Phase 7) — TC Requirements

Test cases live in their own requirement set (`TestCases.slreqx`), separate from
system requirements. Each TC is an `slreq.Requirement` linked to its SR with a
`Verify` link.

```
SR-SYS-001  ←[Verify]─  TC-SYS-001  ←[Verify]─  Simulink Test Case
```

For the Simulink Test file (`.mldatx`) tier, see the `simulink-test` skill.

---

## TC Requirement Fields

| Field | Content |
|---|---|
| `Id` | `TC-SYS-001` |
| `Summary` | Short test name |
| `Description` | Setup + action + pass criterion |
| `Rationale` | `"Verifies SR-SYS-001"` |

A good description answers: **Setup** (initial conditions), **Action** (stimulus
applied), **Pass criterion** (measurable result that constitutes success).

---

## Test Case Script Skeleton

See [`code/buildMyTestCases.m`](code/buildMyTestCases.m) for the full parameterized function:

```
buildMyTestCases(srFile, tcFile)
```

---

## Verification Coverage Report

```matlab
allSRs  = srSet.find('Type', 'Requirement');
covered = 0;
for i = 1:numel(allSRs)
    in_   = allSRs(i).inLinks();     % method on the req object — NOT slreq.inLinks()
    hasTc = false;
    for k = 1:numel(in_)
        if strcmp(in_(k).Type, 'Verify')
            hasTc = true;
            break;
        end
    end
    if hasTc
        covered = covered + 1;
    else
        fprintf('NOT COVERED: %s\n', allSRs(i).Id);
    end
end
fprintf('Coverage: %d / %d (%.0f%%)\n', covered, numel(allSRs), ...
    100 * covered / numel(allSRs));
```

---

# Reading and Tracing Links

---

## Loading Files for Analysis

To load a single file:
```matlab
rs = slreq.load('path/to/MyReqs.slreqx');
```

To load all requirement and link files across a project tree, see
[`code/loadProjectRequirements.m`](code/loadProjectRequirements.m):

```
loadProjectRequirements(projRoot)
```

`slreq.load()` is for scripted analysis (no UI). `slreq.open()` opens the
Requirements Editor UI — avoid it in analysis scripts.

**File discovery note:** `proj.Files` only lists top-level project files. Sub-project
files don't appear. Always use `dir(fullfile(root,'**','*.slreqx'))` to find all files.

---

## Querying Loaded Objects

```matlab
% All loaded ReqSets and LinkSets
allReqSets  = slreq.find('type', 'ReqSet');
allLinkSets = slreq.find('type', 'LinkSet');

% Find a specific ReqSet by name
rs = slreq.find('type', 'ReqSet', 'Name', 'SystemRequirements');

% All requirements in a set (returns ALL node types: Functional, Container, etc.)
reqs = rs.find('Type', 'Requirement');

% Find by ID or SID
r = rs.find('Id', 'SR-SYS-001');
r = rs.find('SID', 5);
```

`rs.find('Type','Requirement')` returns every node — both `Functional` and `Container`
types. Filter by `r.Type` if you only want leaf requirements.

---

## Requirement Node Properties

```matlab
r.Id              % user-assigned ID (string), e.g. 'SR-SYS-001'
r.SID             % internal integer, unique within the file
r.Type            % 'Functional', 'Container', 'Safety', 'Informational'
r.Summary         % one-line summary
r.Description     % HTML string — use getDescriptionAsText() for plain text
r.Rationale       % plain text rationale
r.Index           % hierarchical index, e.g. '2.1.3'

% Clean description (strips HTML formatting)
plainText = r.getDescriptionAsText();

% Navigate hierarchy
kids   = r.children();   % slreq.Requirement array of child nodes
parent = r.parent();     % slreq.Requirement or slreq.ReqSet (if top-level)
```

---

## outLinks and inLinks

Every requirement has two directions of links:

| Method | Returns | Meaning |
|---|---|---|
| `r.outLinks()` | Links from this req pointing outward | This req decomposes into a derived child (Derive outLink) |
| `r.inLinks()` | Links pointing INTO this req | Things that implement, verify, or derive from this req |

```matlab
out = r.outLinks();   % slreq.Link array
in_ = r.inLinks();    % slreq.Link array

% IMPORTANT: cannot vertcat outLinks/inLinks directly — iterate with index
for k = 1:numel(out)
    lnk = out(k);
    fprintf('  -> %s "%s"\n', lnk.Type, lnk.getDestinationLabel());
end
```

---

## Reading Link Data

These methods work even when `isResolved()` is false:

```matlab
lnk.Type                    % 'Derive', 'Implement', 'Verify', 'Relate', 'Refine'
lnk.getSourceLabel()        % human-readable label for the source artifact
lnk.getDestinationLabel()   % human-readable label for the destination artifact

% Resolution status
lnk.isResolved()            % true only if BOTH ends are resolved — often false, do not rely on it
lnk.isResolvedSource()      % source artifact is loaded
lnk.isResolvedDestination() % destination artifact is loaded

% Raw reference struct — ALWAYS readable, even when unresolved
src = lnk.source();           % struct: .domain, .artifact, .id  (source end)
ref = lnk.getReferenceInfo(); % struct: .domain, .artifact, .id  (destination end)
```

---

## Link Domain Types

The `.domain` field identifies what kind of artifact the link points to:

| Domain | Artifact type | ID format |
|---|---|---|
| `linktype_rmi_slreq` | `.slreqx` requirement file | integer SID string, e.g. `"8"` |
| `linktype_rmi_simulink` | `.slx` Simulink model block | SID path, e.g. `":4:27"` |
| `linktype_rmi_testmgr` | `.mldatx` Simulink Test file | UUID string |
| `linktype_rmi_word` | `.docx` Word document | `@Simulink_requirement_item_N` |

---

## Resolving a Req-to-Req Link Destination

```matlab
ref = lnk.getReferenceInfo();
if strcmp(ref.domain, 'linktype_rmi_slreq')
    sid = str2double(ref.id);
    allRS = slreq.find('type', 'ReqSet');
    for i = 1:numel(allRS)
        [~, fn]      = fileparts(allRS(i).Filename);
        [~, artName] = fileparts(ref.artifact);
        if strcmpi(fn, artName)
            destReq = allRS(i).find('SID', sid);
            break;
        end
    end
end
```

---

## Link Direction Semantics

```
SN  ──[Derive]──>  SR    (parent has outLink; derived child has inLink)
        Component  ──[Implement]──>  SR    (component has outLink; req has inLink)
        Test case  ──[Verify]────>  SR    (test has outLink; req has inLink)
```

In this workflow link direction goes **parent/active → child/requirement-end** for all
three types — the parent SN points at the SR it decomposes into, the architecture
element points at the SR it implements, and the test case points at the SR it verifies.

A requirement **derives from** another (parent) when it has `inLinks()` of type `Derive`.
A requirement **is implemented by** an architecture element when it has `inLinks()` of
type `Implement` whose source is a System Composer component (or a Simulink block).
A requirement **is verified by** a test case when it has `inLinks()` of type `Verify`.

---

## LinkSet Methods

```matlab
links = ls.getLinks();                     % all links in a LinkSet
[broken, details] = ls.getBrokenLinks();   % links whose destination is gone
orphans = ls.getOrphanLinks();             % links whose source artifact is gone

ls.Artifact   % full path to the artifact this LinkSet belongs to
ls.Filename   % full path to the .slmx file itself
```

---

## Coverage Analysis — Per-Requirement Status

See [`code/reportCoverageByReq.m`](code/reportCoverageByReq.m):

```
reportCoverageByReq(rs)
```

---

## Coverage Analysis — Aggregate Across All ReqSets

See [`code/reportCoverageAggregate.m`](code/reportCoverageAggregate.m) — loads all files
via `loadProjectRequirements`, then prints a per-ReqSet summary table:

```
reportCoverageAggregate(projRoot)
```

---

## Link Health Report

See [`code/reportLinkHealth.m`](code/reportLinkHealth.m) — operates on all currently loaded
LinkSets; call `loadProjectRequirements` first:

```
reportLinkHealth()
```

---

## Full Traceability Chain Trace

See [`code/traceRequirement.m`](code/traceRequirement.m):

```
traceRequirement(rs, reqId)
```

---

## Common Pitfalls

**`slreq.inLinks(req)` / `slreq.outLinks(req)` do not exist** — these are methods
on the requirement object: `req.inLinks()` and `req.outLinks()`.

**`slreq.open()` in scripts** — use `slreq.load()` for scripted analysis. `slreq.open()`
launches the Requirements Editor UI.

**`isResolved()` is almost always false for model and test links** — this is normal.
Simulink block SIDs and Test Manager UUIDs can't be resolved without opening the model
or test file. Always use `getSourceLabel()`, `getDestinationLabel()`, and
`getReferenceInfo()` instead.

**`outLinks()`/`inLinks()` arrays cannot be vertcat'd** — iterate with index,
or collect into a cell array first.

**`rs.find('Type','Requirement')` returns Containers too** — the `Type` property on
returned objects is `'Container'`, `'Functional'`, etc. Filter if needed:
`reqs(strcmp({reqs.Type}, 'Functional'))`.

**Description contains HTML** — use `r.getDescriptionAsText()` to get clean text.

**`getImplementationStatus()` requires update first** — call `rs.updateImplementationStatus()`
before calling `r.getImplementationStatus()`, otherwise it throws.

**Delete `.slmx` link files alongside `.slreqx` files** when rebuilding requirement
sets. Stale `.slmx` files store cross-artifact links and will auto-open old model
files on load, causing conflicts.

**Don't stuff parent-reference text into `Rationale`.** Writing `"Derived from
SN-SYS-001."` into `req.Rationale` shadows the real purpose of the field AND
collides with the `DerivedFrom` column on xlsx export. Keep `Rationale` for the
*why* (what constraint or judgment picked this value); let the Derive link carry
the parent reference, and extract it from `inLinks()` at export time.

**Getting a parent requirement's Id from a link.** `lnk.source()` returns a
struct with `.domain`, `.artifact`, `.id` — but `.id` is the numeric SID, not
the user-facing Id like `'SN-SYS-001'`. For the Id string, use
`strtok(lnk.getSourceLabel())` — the label format is `"ID Summary"`, so
`strtok` pulls just the Id.

**`slreq.import` does not save to disk.** The function returns
`[refCount, reqSetFilePath, reqSetObj]` — the path is where the file *will*
live, but the ReqSet is only in memory and marked `Dirty=1`. Call
`reqSetObj.save()` (or `slreq.saveAll()`) before closing, or the imported set
vanishes. Observed with `AsReference=false` on Excel import; worth checking
before relying on the default behavior in other modes.

**Excel import treats the header row as a requirement** unless you set
`rows=[firstDataRow lastDataRow]`. Also auto-creates a `Container` node named
`"<File>!<Sheet>"` wrapping the imported items; filter it out with
`r.Type == "Container"` when iterating.
