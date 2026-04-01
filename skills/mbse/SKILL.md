---
name: mbse
description: >
  Use this skill when the user mentions MBSE, model-based systems engineering, or wants a
  structured engineering process in MATLAB — from requirements through architecture,
  traceability, analysis, and verification. Also trigger when the user asks about the slreq
  API, creating requirement sets, derivation or verification links, test case requirements,
  Simulink Test traceability, or checking verification coverage. Invoke for any part of the
  MBSE workflow that involves requirements or verification. Use this skill proactively
  whenever the user is starting a new system design or working anywhere in the MBSE lifecycle.
---

# MATLAB MBSE Workflow

MBSE in MATLAB spans Requirements Toolbox (`slreq`) and System Composer
(`systemcomposer`). This skill covers the workflow overview, the full
requirements API, and the verification/test-case phase.

For architecture, allocation, and analysis see the `mbse-architecture` skill.
For a guided new-project setup see the `mbse-new-project` skill.

---

## Workflow Overview

```
Phase 1  Stakeholder Needs           SN-SYS-xxx   informal, operational perspective
           |  (derives)
Phase 2  System Requirements         SR-SYS-xxx   formal shall-statements, testable
           |  (informs)
Phase 3a Physical Architecture       MySystem.slx  components + interfaces + stereotypes
Phase 3b Functional Architecture     MyFunctional.slx  logical functions, same interface dict
           |  (allocated via)
Phase 4  Functional→Physical         MyAllocation.mldatx  allocation set, one scenario
           Allocation Set
           |  (refines)
Phase 5  Requirements Allocation     SR --> Component Refine links, bidirectional
           |  (quantifies)
Phase 6  Analysis                    optional — roll-up, trade study, sensitivity
           |  (verifies)
Phase 7  Verification                TC requirements + Simulink Test file
```

---

## Starting a new project

Use the `mbse-new-project` skill. It conducts an interview, then walks through
each phase with a propose → approve → generate → validate loop. You end up with
a complete, runnable set of build scripts and a MATLAB Project (`.prj`) that
manages the path automatically.

## Phase Skills

| Phase | Skill | What it covers |
|---|---|---|
| — | `mbse-new-project` | Guided end-to-end setup for a new project |
| 1–2, 7 | `mbse` (this skill) | Requirements API, verification, Simulink Test traceability |
| 3–6 | `mbse-architecture` | Physical + functional models, stereotypes, allocation, analysis |
| — | `system-composer` | Deep System Composer API reference (ports, connections, profiles) |

---

## Recommended Folder Structure

```
my-system/
├── my-system.prj     MATLAB Project file (manages path automatically)
├── startup.m         Runs on project open — clears MATLAB state
├── requirements/     .slreqx files (StakeholderNeeds, SystemRequirements, TestCases)
├── architecture/     .slx, .sldd, .xml, .mldatx (model, dictionary, profile, allocation)
├── verification/     .mldatx (Simulink Test file)
└── scripts/          buildAll.m and all phase build scripts
```

---

## Key Cross-Phase Dependencies

- **Architecture rebuilds break allocation links.** `slreq.createLink` stores
  component references by Simulink SID. If you rebuild the model, SIDs change
  and allocation links become stale. Always rebuild allocation after rebuilding
  the architecture model.

- **Profile setup belongs in the architecture script**, not in a separate
  analysis script. Create and apply the profile at the end of
  `buildMySystemModel()` so estimates travel with the model.

- **`slreq.saveAll()` saves cross-set links.** Call it after any session that
  creates links between different `.slreqx` files.

- **`slreq.clear()` unloads all sets from memory** but does not delete files.
  Call it at the top of each script for a clean slate, then `slreq.open()` the
  files you need.

- **Delete `.slmx` link files alongside `.slreqx` files** when rebuilding
  requirement sets. Stale `.slmx` files store cross-artifact links and will
  auto-open old model files on load, causing conflicts.

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

## slreq API Patterns

### Create and populate a requirement set

```matlab
slreq.clear();
if isfile('MyReqs.slreqx'), delete('MyReqs.slreqx'); end
rs = slreq.new('MyReqs.slreqx');        % NOT slreq.createReqSet (does not exist)

req = rs.add();                          % no Type argument
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

### Valid link types

| Type | Meaning | Direction |
|---|---|---|
| `"Derive"` | Child derived from parent | SR (source) → SN (destination) |
| `"Refine"` | Architecture element implements requirement | SR (source) → Component (destination) |
| `"Verify"` | Test case verifies requirement | TC (source) → SR (destination) |

### Create a derivation link

```matlab
lnk = slreq.createLink(childReq, parentReq);
lnk.Type = 'Derive';
slreq.saveAll();    % saves cross-set links
```

---

## Requirements Skeleton

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

# Verification (Phase 7)

---

## Structure

Test cases live in their own requirement set (`TestCases.slreqx`), separate
from system requirements. Each TC is an `slreq.Requirement` linked to its SR
with a `Verify` link. A separate Simulink Test file (`.mldatx`) holds the
executable test cases, each linked back to the TC requirement.

```
SR-SYS-001  ←[Verify]─  TC-SYS-001  ←[Verify]─  Simulink Test Case
```

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

## Test Case Skeleton

```matlab
function buildMyTestCases()
    rootDir = fileparts(mfilename('fullpath'));
    reqDir  = fullfile(rootDir, '..', 'requirements');
    srFile  = fullfile(reqDir, 'SystemRequirements.slreqx');
    tcFile  = fullfile(reqDir, 'TestCases.slreqx');
    tcLink  = strrep(tcFile, '.slreqx', '~slreqx.slmx');

    slreq.clear();
    srSet = slreq.open(srFile);
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

## Simulink Test Traceability

```matlab
function buildMySimulinkTests()
    rootDir = fileparts(mfilename('fullpath'));
    reqDir  = fullfile(rootDir, '..', 'requirements');
    verDir  = fullfile(rootDir, '..', 'verification');
    tcFile  = fullfile(reqDir,  'TestCases.slreqx');
    mldatx  = fullfile(verDir,  'MyTests.mldatx');
    mldatxLinks = fullfile(verDir, 'MyTests~mldatx.slmx');

    addpath(reqDir);   % ← required: without this, slreq.createLink warns that the .slreqx
                       %   is not on the path and stores an absolute path in the .slmx link
                       %   file instead of a relative one, breaking portability
    slreq.clear();
    tcSet = slreq.open(tcFile);
    sltest.testmanager.clear();
    if isfile(mldatx),      delete(mldatx);      end
    if isfile(mldatxLinks), delete(mldatxLinks); end

    tf = sltest.testmanager.TestFile(mldatx);
    tf.Description = 'System-level verification tests.';

    % Remove the auto-created default suite
    for s = tf.getTestSuites(), remove(s); end

    % { SuiteName, Tag, { TC-IDs... } }
    suites = {
        'Functional Tests', 'functional', { 'TC-SYS-001', 'TC-SYS-002' };
    };

    for s = 1:size(suites, 1)
        suite = createTestSuite(tf, suites{s, 1});
        suite.Tags = suites{s, 2};
        for t = 1:numel(suites{s, 3})
            tcId  = suites{s, 3}{t};
            tcReq = tcSet.find('Id', tcId);
            if isempty(tcReq), warning('TC %s not found — skipped.', tcId); continue; end
            stc             = createTestCase(suite, 'simulation', tcId);
            stc.Description = tcReq.Description;
            stc.Tags        = suites{s, 2};
            lnk             = slreq.createLink(stc, tcReq);
            lnk.Type        = 'Verify';
        end
    end

    saveToFile(tf);
    slreq.saveAll();
end
```

---

## Coverage Report

```matlab
allSRs  = srSet.find();
covered = 0;
for i = 1:numel(allSRs)
    inL   = slreq.inLinks(allSRs(i));
    hasTc = any(strcmp({inL.Type}, 'Verify'));
    if hasTc
        covered = covered + 1;
    else
        fprintf('NOT COVERED: %s\n', allSRs(i).Id);
    end
end
fprintf('Coverage: %d / %d (%.0f%%)\n', covered, numel(allSRs), ...
    100 * covered / numel(allSRs));
```
