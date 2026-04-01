---
name: mbse-new-project
description: >
  Use this skill to guide a user through building a new MBSE project from scratch in
  MATLAB. Trigger when the user wants to start a new systems engineering project, create
  a new MBSE workflow, or set up a Model-Based Systems Engineering project in MATLAB.
  This skill conducts an interview, then walks through each phase one at a time —
  proposing content, waiting for human approval, generating the script, running it, and
  only moving on once the user is satisfied. Use this skill proactively whenever someone
  says they want to start a new MBSE project or set up a system from scratch.
---

# Guided MBSE Project Setup

This skill walks through creating a complete MBSE project, one phase at a time.
At each phase: propose → get approval → generate script → run it → checkpoint.
If the user rejects or wants changes, revise and regenerate — scripts are
idempotent so this is always safe.

Use the other `mbse-*` skills for technical API patterns at each phase. This
skill manages the conversation flow and script generation.

---

## How to conduct this session

Work through the phases in order. Never jump ahead. At each checkpoint, present
what you are about to create in plain language and wait for explicit approval
("looks good", "yes", "proceed") before generating the script. If the user
asks for changes, make them and re-present — do not generate until approved.

After running each script, show the MATLAB output and ask the user to confirm
it looks right before moving to the next phase. Keep proposed content concise
and specific — avoid vague placeholders.

---

## Phase 0: Interview and Project Setup

Ask the following questions (can be in one message):

1. **System name** — what is the system called? (Used for file and model names, e.g. `SatComSystem`)
2. **Project location** — full path to the folder where the project should be created
3. **System description** — one paragraph: what does it do, what problem does it solve?
4. **Major subsystems** — top-level physical components, if the user has them in mind (Claude will propose if not)
5. **Key engineering concerns** — what properties of components matter for design decisions? (e.g. mass, power consumption, cost, reliability, latency, data rate — these become stereotype properties)
6. **Analysis needs** — is any quantitative roll-up or trade study analysis needed? If so, what kind?
7. **Test framework** — will Simulink Test be used for verification? (determines whether Phase 9 runs)

After gathering answers, create the MATLAB Project inline (not as a saved script,
since the scripts/ folder doesn't exist yet):

```matlab
proj = matlab.project.createProject(Name=projectName, Folder=projectFolder);

% Standard MBSE folder structure
for sub = {'requirements', 'architecture', 'verification', 'scripts'}
    mkdir(fullfile(proj.RootFolder, sub{1}));
end

% Track all folders and put scripts/ on the MATLAB path
% Path management is handled entirely by the project — no startup.m needed.
% Each build script handles its own state cleanup (slreq.clear, closeAll, etc.)
% at the top, so there is nothing project-startup-specific to do.
for sub = {'requirements', 'architecture', 'verification', 'scripts'}
    addFolderIncludingChildFiles(proj, fullfile(proj.RootFolder, sub{1}));
end
addPath(proj, fullfile(proj.RootFolder, 'scripts'));

% Shortcuts point to specific tracked files — add them as files are created.
% E.g. after Phase 9: addShortcut(proj, fullfile(proj.RootFolder, 'scripts', 'buildAll.m'))

close(proj);
```

**Do not create a startup.m.** Build scripts are idempotent and self-cleaning —
each one calls `slreq.clear()`, `Profile.closeAll()`, etc. at the top. There is
no shared state that needs clearing on project open.

**Shortcuts** (`addShortcut`) point to individual tracked files and appear in the
MATLAB Project Shortcuts panel. Add them progressively as key files are created:
`buildAll.m`, the main `.slx` model, `SystemRequirements.slreqx`. Shortcuts take
only the file path — no label argument: `addShortcut(proj, filePath)`.

    close(proj);
    fprintf('Project created: %s\n', rootDir);
    fprintf('Open with: openProject(''%s'')\n', rootDir);
end
```

Generate this as `scripts/setupMBSEProject.m`, run it, confirm the project opens correctly, then proceed.

---

## Phase 1: Requirements

### Propose

Based on the interview, draft:
- **Stakeholder Needs (SNs)** — 4–8 operational-perspective statements. Format: `SN-XXX-NNN`. Focus on what users/operators need, not how the system works.
- **System Requirements (SRs)** — 1–3 testable shall-statements per SN, each with a measurable acceptance criterion. Format: `SR-XXX-NNN`. Include at least 2 SRs for any budget/property cap identified in Phase 0.

Present these as a table for the user to review. Wait for approval or changes.

### Generate

After approval, generate `scripts/buildRequirements.m` using patterns from the `mbse-requirements` skill. The script must:
- Delete and recreate both `.slreqx` files and their `.slmx` link files on every run
- Create all SNs, all SRs, and Derive links from each SR back to its parent SN
- Use `slreq.clear()` at the top

### Checkpoint

Show: requirement counts, derivation link count. Ask the user to confirm counts match what was approved.

---

## Phase 2: Physical Architecture

### Propose

Based on the SRs, propose:
- **Components** — typically 4–8 top-level physical components. For each: name, one-sentence role
- **Interfaces** — data/signal types exchanged between components. For each: name, elements with types
- **Connections** — which component ports connect to which

Present as a component list + connection diagram in text. Wait for approval.

### Generate

After approval, generate `scripts/buildModel.m` using patterns from the `mbse-architecture` and `system-composer` skills:
- Creates the interface dictionary (`.sldd`)
- Creates the SC model, adds components, ports, connections
- Applies auto-layout and saves

### Checkpoint

Show: component count, connection count, any unconnected port warnings. Ask user to confirm the model opened in System Composer looks right.

---

## Phase 3: Component Properties

### Propose

Based on the engineering concerns identified in Phase 0, propose one or more stereotypes:

- **Stereotype name** — e.g. `MassProperties`, `PowerProperties`, `PerformanceProperties`
- **Properties** — for each: name, type (double/string/enum), unit, what it represents
- **Which components** each stereotype applies to (usually all, but not always)
- **Initial estimates** — propose plausible starting values per component; user should correct these

Present as a table. Wait for approval.

### Generate

Add stereotype creation and application to `buildModel.m` (at the end, after the architecture is built), following the `mbse-architecture` profile patterns:
- Use `systemcomposer.profile.Profile.createProfile`
- Add stereotypes with `addStereotype`, properties with `addProperty`
- Apply to components with `applyStereotype`, set values with `setProperty`
- `profile.save()` requires a char path — not a string type

Re-run `buildModel.m` (idempotent — it rebuilds from scratch).

### Checkpoint

Show: stereotype name(s), property names and estimates per component. Ask user to confirm values are reasonable starting points.

---

## Phase 4: Functional Architecture

### Propose

Based on the SNs (what the system *does*), propose:
- **Logical functions** — 4–8 functions. For each: name (verb phrase), one-sentence description
- **Function interfaces** — which interfaces from the dictionary each function uses
- **Connections** — data flow between functions

Present as a function list + data flow description. Wait for approval.

Note: functional architecture is independent of physical implementation — functions should reflect operational concepts from the SNs, not the physical components from Phase 2.

### Generate

After approval, generate `scripts/buildFunctional.m` using patterns from the `mbse-architecture` skill:
- Opens the physical model to access the shared interface dictionary via `physModel.InterfaceDictionary`
- Creates a separate SC model for the functional architecture
- Adds function components, typed ports, and connections
- `modelName` must be a double-quoted MATLAB string for `char(modelName) + ".slx"` to work

### Checkpoint

Show: function count, connection count. Ask user to confirm the functional model looks right.

---

## Phase 5: Functional→Physical Allocation

### Propose

Map each logical function to the physical component(s) that implement it. Functions may map to multiple components. Present as a two-column table:

```
Function                    Physical Component(s)
────────────────────────────────────────────────
FunctionA               →   ComponentX
FunctionB               →   ComponentY
FunctionC               →   ComponentX, ComponentZ
```

Wait for approval or corrections.

### Generate

After approval, generate `scripts/buildAllocationSet.m` using patterns from the `mbse-allocation` skill:
- `AllocationSet.closeAll()` then delete the `.mldatx` file before recreating
- `createAllocationSet` name must differ from the file base name (e.g. use `'MyAllocationSet'`, save to `'MyAllocation.mldatx'`) — otherwise `save` fails with "name must be unique"
- Use `createScenario(allocSet, 'FunctionalToPhysical')` not `getScenario`

### Checkpoint

Show the allocation table printed from the script. Ask user to confirm mappings are correct.

---

## Phase 6: Requirements Allocation

### Propose

Map each SR to the physical component(s) responsible for satisfying it. Present as a table. One SR may map to multiple components; one component typically owns multiple SRs.

Wait for approval.

### Generate

After approval, generate `scripts/buildAllocation.m` using patterns from the `mbse-allocation` skill:
- Remove existing Refine links before recreating (idempotent)
- Use `fileparts(fileparts(mfilename('fullpath')))` for the project root — never `'..'` in paths passed to System Composer
- `addpath(archDir)` then `openModel` by model name, not full path
- Call `slreq.saveAll()` at the end

### Checkpoint

Show: total Refine link count, per-component requirement count, any SRs with no allocation (flag these — every SR should be allocated somewhere).

---

## Phase 7: Analysis (Optional)

If the user indicated no analysis is needed in Phase 0, skip this phase entirely.

Otherwise, ask:
- **What to compute** — roll-up sums (mass, power, cost)? Margins against caps? Sensitivity? Pareto?
- **Budget caps** — are any system-level limits defined in SRs? (Parse from requirement descriptions using the `parseBudgetValue` pattern from `mbse-analysis`)
- **What to write back** — computed values (margins, roll-ups) can be written back to the analysis instance via `setValue`

### Generate

Generate `scripts/runAnalysis.m` using patterns from the `mbse-analysis` skill:
- `instantiate(arch, profileName, 'AnalysisName')` creates the instance
- `getValue(ci, [prefix, 'PropertyName'])` returns double — no `str2double` needed
- `save(instance, fullfile(archDir, 'AnalysisName.mat'))` for Analysis Viewer
- Open with `systemcomposer.analysis.openViewer('AnalysisName')` (instance name, not file path)

### Checkpoint

Show the analysis report output. Flag any margins that are negative (over budget). Ask user to confirm.

---

## Phase 8: Test Cases

### Propose

For each SR, propose one test case (TC) with:
- **ID** — `TC-XXX-NNN` matching the SR number
- **Description** — concise test procedure: what stimulus, what measurement, what pass criterion

Present as a table. Wait for approval or edits.

Note: SR-NNN for property/budget caps (e.g. total mass budget) are typically verified by the analysis script, not a test case — it is acceptable for these to show as "NOT COVERED" in the coverage report.

### Generate

After approval, generate `scripts/buildTestCases.m` using patterns from the `mbse-verification` skill:
- Delete the `.slreqx` and `.slmx` link files before recreating
- Create one TC requirement per SR, link with `Verify` type
- Call `slreq.saveAll()` at the end

### Checkpoint

Show: TC count, verification coverage report (SR IDs vs TC IDs). Flag any SRs without a TC other than expected budget-cap SRs.

---

## Phase 9: Simulink Tests and Final Summary

### Generate

Generate `scripts/buildSimulinkTests.m` using patterns from the `mbse-verification` skill:
- Delete the `.mldatx` and its `.slmx` link file before recreating
- Remove the default auto-created test suite before adding named suites
- Group TCs into suites by functional area

Then generate `scripts/buildAll.m` that calls all phase scripts in order with timing output. This is the single entry point for a clean rebuild from scratch.

### Final summary

Present a complete artifact inventory:

```
Project: <Name>  (<root folder>)
├── requirements/
│   ├── StakeholderNeeds.slreqx    (N items)
│   ├── SystemRequirements.slreqx  (N items)
│   └── TestCases.slreqx           (N items)
├── architecture/
│   ├── <Name>System.slx           (physical model)
│   ├── <Name>Functional.slx       (functional model)
│   ├── <Name>Interfaces.sldd      (interface dictionary)
│   ├── <Name>Budget.xml           (stereotype profile)
│   ├── <Name>Allocation.mldatx    (functional→physical allocation)
│   └── <analysis>.mat             (analysis instance, if Phase 7 ran)
├── verification/
│   └── <Name>Tests.mldatx         (Simulink Test file)
└── scripts/
    ├── buildAll.m                  (run this to rebuild everything)
    ├── buildRequirements.m
    ├── buildModel.m
    ├── buildFunctional.m
    ├── buildAllocationSet.m
    ├── buildAllocation.m
    ├── runAnalysis.m               (if Phase 7 ran)
    ├── buildTestCases.m
    └── buildSimulinkTests.m

Traceability:
  SN ─[Derive]─▶ SR ─[Refine]─▶ Component
                              ▲
                          [Allocate]
                              │
                         LogicalFunction
  SR ─[Verify]─▶ TC ─[Verify]─▶ Simulink Test Case
```

Remind the user they can rebuild everything cleanly at any time with `buildAll()`.

---

## Handling rollback

If the user rejects a checkpoint:
1. Ask what specifically needs to change
2. Revise the proposed content
3. Re-present for approval
4. Regenerate the script with the changes
5. Re-run and re-checkpoint

Because every script deletes and recreates its artifacts from scratch, there is no state to undo — just regenerate.
