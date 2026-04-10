---
name: simulink-requirements
description: >
  Use this skill for all requirements-related work in a MATLAB MBSE project using
  the Requirements Toolbox (slreq). Covers creating and populating requirement sets,
  derivation links, test case requirements, verification coverage, reading and tracing
  links across requirement sets and models, checking link health, allocating requirements
  to components (Refine links), and building traceability reports. Trigger when the user
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
| `"Derive"` | Child derived from parent | SR (source) → SN (destination) |
| `"Refine"` | Requirement allocated to architecture component | SR (source) → Component (destination) |
| `"Verify"` | Test case verifies requirement | TC (source) → SR (destination) |
| `"Implement"` | Model block implements requirement | Block (source) → SR (destination) |
| `"Relate"` | Informal relationship | Bidirectional |

---

## Creating Links

```matlab
% Req-to-req derivation
lnk = slreq.createLink(childReq, parentReq);
lnk.Type = 'Derive';

% Model block to req (model must be open in Simulink)
lnk = slreq.createLink(blockHandle, req);
lnk.Type = 'Implement';

% Test case requirement to SR
lnk = slreq.createLink(tc, sr);
lnk.Type = 'Verify';

slreq.saveAll();   % always call after creating cross-artifact links
```

---

## Requirements Script Skeleton

```matlab
function buildMyRequirements()
    rootDir = fileparts(mfilename('fullpath'));   % scripts/ is project root peer
    reqDir  = fullfile(rootDir, '..', 'requirements');
    snFile  = fullfile(reqDir, 'StakeholderNeeds.slreqx');
    srFile  = fullfile(reqDir, 'SystemRequirements.slreqx');

    slreq.clear();
    % Delete files AND their .slmx link files to avoid stale cross-artifact links
    for f = {snFile, srFile, ...
             strrep(snFile, '.slreqx', '~slreqx.slmx'), ...
             strrep(srFile, '.slreqx', '~slreqx.slmx')}
        if isfile(f{1}), delete(f{1}); end
    end

    snSet = slreq.new(snFile);
    sn1 = addReq(snSet, 'SN-SYS-001', 'Title', "The operator shall ...", "Rationale.");
    snSet.save();

    srSet = slreq.new(srFile);
    sr1 = addReq(srSet, 'SR-SYS-001', 'Title', "The system shall ... [criterion].", ...
        "Derived from SN-SYS-001.");
    srSet.save();

    lnk = slreq.createLink(sr1, sn1);
    lnk.Type = 'Derive';
    slreq.saveAll();
end

function req = addReq(rs, id, summary, description, rationale)
    req             = rs.add();
    req.Id          = id;
    req.Summary     = summary;
    req.Description = description;
    req.Rationale   = rationale;
end
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

```matlab
function buildMyTestCases()
    rootDir = fileparts(mfilename('fullpath'));
    reqDir  = fullfile(rootDir, '..', 'requirements');
    srFile  = fullfile(reqDir, 'SystemRequirements.slreqx');
    tcFile  = fullfile(reqDir, 'TestCases.slreqx');
    tcLink  = strrep(tcFile, '.slreqx', '~slreqx.slmx');

    slreq.clear();
    srSet = slreq.load(srFile);   % slreq.load() for scripts; slreq.open() opens the UI
    if isfile(tcFile),  delete(tcFile);  end
    if isfile(tcLink),  delete(tcLink);  end
    tcSet = slreq.new(tcFile);

    % { TC-ID, Summary, Description, SR-ID }
    testCases = {
        'TC-SYS-001', 'Verify SR-001', ...
            'Apply stimulus X. Measure Y. Pass if Y meets criterion Z.', ...
            'SR-SYS-001';
    };

    for i = 1:size(testCases, 1)
        tc             = tcSet.add();
        tc.Id          = testCases{i, 1};
        tc.Summary     = testCases{i, 2};
        tc.Description = testCases{i, 3};
        tc.Rationale   = ['Verifies ', testCases{i, 4}];
        sr             = srSet.find('Id', testCases{i, 4});
        lnk            = slreq.createLink(tc, sr);
        lnk.Type       = 'Verify';
    end
    slreq.saveAll();
end
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

```matlab
% Load a requirement set (idempotent — safe to call on already-loaded files)
rs = slreq.load('path/to/MyReqs.slreqx');

% Find all .slreqx and .slmx files in a project tree
projRoot = 'C:\path\to\project';
reqxFiles = dir(fullfile(projRoot, '**', '*.slreqx'));
slmxFiles = dir(fullfile(projRoot, '**', '*.slmx'));

for i = 1:numel(reqxFiles)
    slreq.load(fullfile(reqxFiles(i).folder, reqxFiles(i).name));
end
for i = 1:numel(slmxFiles)
    try
        slreq.load(fullfile(slmxFiles(i).folder, slmxFiles(i).name));
    catch
        % Skip files that fail to load (missing artifacts, etc.)
    end
end
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
| `r.outLinks()` | Links from this req pointing outward | This req derives from / refines something |
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
SN  ──[Derive inLink]───  SR  ──[Derive outLink]──>  SN
                           SR  ──[Refine outLink]──>  Component
                      Block  ──[Implement]──>  SR    (block has outLink; req has inLink)
                  Test case  ──[Verify]────>  SR    (test has outLink; req has inLink)
```

A requirement is **implemented** when it has `inLinks()` of type `Implement`.
A requirement is **verified** when it has `inLinks()` of type `Verify`.
A requirement **derives from** another when it has `outLinks()` of type `Derive`.

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

```matlab
reqs = rs.find('Type', 'Requirement');
fprintf('%-30s  %-10s  %-8s\n', 'Req ID', 'Impl', 'Verify');
fprintf('%s\n', repmat('-', 1, 55));
for i = 1:numel(reqs)
    r = reqs(i);
    hasImpl   = false;
    hasVerify = false;
    in_ = r.inLinks();
    for k = 1:numel(in_)
        if strcmp(in_(k).Type, 'Implement'); hasImpl   = true; end
        if strcmp(in_(k).Type, 'Verify');    hasVerify = true; end
    end
    fprintf('%-30s  %-10s  %-8s\n', r.Id, ...
        tf2str(hasImpl), tf2str(hasVerify));
end

function s = tf2str(cond)
    if cond; s = 'YES'; else; s = 'no'; end
end
```

---

## Coverage Analysis — Aggregate Across All ReqSets

```matlab
projRoot = 'C:\path\to\project';
for f = dir(fullfile(projRoot, '**', '*.slreqx'))'
    slreq.load(fullfile(f.folder, f.name));
end
for f = dir(fullfile(projRoot, '**', '*.slmx'))'
    try; slreq.load(fullfile(f.folder, f.name)); catch; end
end

allRS = slreq.find('type', 'ReqSet');
fprintf('%-35s  %5s  %7s  %5s  %6s\n', 'ReqSet', 'Reqs', 'Derive', 'Impl', 'Verify');
fprintf('%s\n', repmat('-', 1, 70));
for i = 1:numel(allRS)
    rs_i = allRS(i);
    reqs = rs_i.find('Type', 'Requirement');
    nD = 0; nI = 0; nV = 0;
    for j = 1:numel(reqs)
        r   = reqs(j);
        out = r.outLinks();
        for k = 1:numel(out)
            switch out(k).Type
                case 'Derive';    nD = nD + 1;
                case 'Implement'; nI = nI + 1;
                case 'Verify';    nV = nV + 1;
            end
        end
        in_ = r.inLinks();
        for k = 1:numel(in_)
            switch in_(k).Type
                case 'Derive';    nD = nD + 1;
                case 'Implement'; nI = nI + 1;
                case 'Verify';    nV = nV + 1;
            end
        end
    end
    fprintf('%-35s  %5d  %7d  %5d  %6d\n', rs_i.Name, numel(reqs), nD, nI, nV);
end
```

---

## Link Health Report

```matlab
allLS = slreq.find('type', 'LinkSet');
for i = 1:numel(allLS)
    ls = allLS(i);
    [broken, ~] = ls.getBrokenLinks();
    orphans     = ls.getOrphanLinks();
    if isempty(broken) && isempty(orphans); continue; end
    [~, fname] = fileparts(ls.Filename);
    fprintf('\n%s:\n', fname);
    for j = 1:numel(broken)
        fprintf('  BROKEN  Src="%s" -> Dst="%s"\n', ...
            broken(j).getSourceLabel(), broken(j).getDestinationLabel());
    end
    fprintf('  %d orphan links\n', numel(orphans));
end
```

---

## Full Traceability Chain Trace

```matlab
function traceRequirement(rs, reqId)
    r = rs.find('Id', reqId);
    if isempty(r)
        fprintf('Requirement "%s" not found.\n', reqId);
        return;
    end
    fprintf('=== %s: %s ===\n', r.Id, r.getDescriptionAsText());

    out = r.outLinks();
    if ~isempty(out)
        fprintf('\nDerives from / traces to:\n');
        for k = 1:numel(out)
            lnk = out(k);
            ref = lnk.getReferenceInfo();
            fprintf('  [%s] -> "%s"', lnk.Type, lnk.getDestinationLabel());
            if isstruct(ref)
                fprintf(' (artifact: %s, id: %s)', ref.artifact, ref.id);
            end
            fprintf('\n');
        end
    end

    in_ = r.inLinks();
    if ~isempty(in_)
        fprintf('\nImplemented / verified / derived by:\n');
        for k = 1:numel(in_)
            lnk = in_(k);
            src = lnk.source();
            fprintf('  [%s] <- "%s"', lnk.Type, lnk.getSourceLabel());
            if isstruct(src)
                fprintf(' (domain: %s)', src.domain);
            end
            fprintf('\n');
        end
    end
end
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
