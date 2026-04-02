# MBSE Capability Suite for MATLAB

A family of reusable Claude skills and a full worked example that encode the complete
Model-Based Systems Engineering (MBSE) workflow in MATLAB — from stakeholder needs
through verified test cases, with traceability at every step.

---

## Guided Project Setup

The primary interaction model is a **conversational, phase-by-phase guided workflow**
driven by the `mbse-new-project` skill. A new user does not need to know the MATLAB
APIs or the script patterns — Claude handles all of that.

### How it works

Claude conducts a short interview to understand the system, then works through each
phase one at a time:

```
Phase 0 — Interview
  Claude asks: system name, location, description, subsystems, engineering
  concerns (mass, power, cost, …), analysis needs, simulation model availability.
  Then creates the MATLAB project, folder structure, and registerWithProject helper.

For each subsequent phase (1–9):
  1. Propose  — Claude drafts the content in plain language and shows it to you
  2. Approve  — you review and request changes, or say "looks good"
  3. Generate — Claude writes the build script
  4. Run      — Claude executes the script via MATLAB MCP
  5. Confirm  — Claude shows the output and asks if it looks right before continuing
```

Every script is idempotent, so if you reject a checkpoint, Claude revises and
reruns — no state to undo.

### What you get

A complete MATLAB project with a `.prj` file, 7 idempotent build scripts, all
generated artifacts, and a single `buildAll()` entry point that rebuilds everything
from scratch. See the [FCS example](../examples/fcs/) for what a finished project
looks like.

### Starting a guided session

Just tell Claude what you want to build:
> *"I want to set up a new MBSE project for an eVTOL propulsion system"*

The `mbse-new-project` skill activates automatically and begins the interview.

---

## Skills

Four Claude skills live in `skills/`. `mbse-new-project` drives the conversation;
the others provide the technical API patterns it draws on.

| Skill | Purpose |
|---|---|
| `mbse-new-project` | Guided end-to-end setup — interview, propose, generate, run, confirm |
| `mbse` | Requirements API, two-level hierarchy, derivation/verify links, two-tier verification |
| `mbse-architecture` | Physical + functional architecture, profiles/stereotypes, allocation, analysis |
| `system-composer` | Deep System Composer API reference — connection syntax, dictionary patterns, profile gotchas, layout |

---

## Workflow

The MBSE workflow runs in seven steps. Each step is a separate idempotent build script.

### Step 1 — Requirements

- Write **Stakeholder Needs** (what the system must do, in operator terms)
- Derive **System Requirements** from stakeholder needs, linked with `Derive`
- Budget constraints (power, mass, cost, etc.) live in requirements — scripts read
  them at run time via `parseBudgetValue`; values are never hard-coded in scripts
- `addpath(reqDir)` before `slreq.clear()` ensures `.slmx` link files store relative
  paths, keeping the project portable
- Artifacts: `StakeholderNeeds.slreqx`, `SystemRequirements.slreqx`

### Step 2 — Physical Architecture + Profile

- Build a System Composer model with typed components and ports
- Define interfaces in a shared data dictionary — all elements use `Type="double"`;
  physical units are documented in comments, not as named types
- At the end of the same script, create a **profile** with a `BudgetProperties`
  stereotype and apply it to all components with initial estimates
- `profile.save(archDir)` — always pass the folder, never a `.xml` path
  (passing a `.xml` path silently creates a directory instead of a file)
- Call `open_system(char(modelName))` after `save_system` to show the SC editor
- Artifacts: `System.slx`, `Interfaces.sldd`, `Profile.xml`

### Step 3 — Functional Architecture

- Build a separate System Composer model for the **logical functions** of the system,
  independent of physical implementation
- Share the interface dictionary from the physical model via `physModel.InterfaceDictionary`
- Artifact: `Functional.slx`

### Step 4 — Functional→Physical Allocation

- Create an allocation set mapping each logical function to the physical component(s)
  that implement it (ARP4754A functional allocation tier)
- In-memory allocation set name must differ from the file base name to avoid a
  uniqueness collision when saving
- Artifact: `Allocation.mldatx`

### Step 5 — Requirements Allocation

- Create `Refine` links from each SR to the component(s) responsible for implementing it
- Scripts are idempotent — existing Refine links are removed before rebuild
- Navigate forward (requirement → components) and backward (component → requirements)

### Step 6 — Analysis (optional)

- Create an **analysis instance** from the architecture profile using `instantiate`
- Read property values with `getValue` (returns `double` directly — no str2double)
- Compute system-level roll-ups and per-component margins
- Write computed margins back to the instance with `setValue`
- Budget caps come from requirements (parsed at run time); no magic numbers in scripts
- Save the instance as a `.mat` file for the Analysis Viewer
- Artifact: `Analysis.mat`

### Step 7 — Test Cases

- Create a `TestCases.slreqx` requirement set with one TC requirement per SR
- Each TC describes: setup, stimulus, and measurable pass criterion
- Link each TC to its SR with a `Verify` link
- Generate a coverage report — which SRs are covered, which are not
- Budget cap SRs (verified by analysis in Step 6) are expected NOT COVERED here
- Artifact: `TestCases.slreqx`

---

## Two-Tier Verification

Verification has two distinct tiers:

**Tier 1 — TC requirements (always done):** `TestCases.slreqx` contains testable
shall-statements with Verify links to SRs. These are standalone artifacts that
provide full requirements traceability regardless of whether a simulation model exists.

**Tier 2 — Simulink Test (only with a simulation model):** A `.mldatx` test file
links test cases to a Simulink model under test. This is only meaningful when an
actual simulation model exists — without one, test cases cannot run and provide no
additional value over the TC requirements from Tier 1.

---

## Traceability Chain

Every artifact is traceable up and down the chain:

```
Stakeholder Need  (StakeholderNeeds.slreqx)
    └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                      ├─[Refine]─▶  Architecture Component  (System.slx)
                      │                 ▲
                      │             [Allocate]  (Allocation.mldatx)
                      │                 │
                      │             Logical Function  (Functional.slx)
                      └─[Verify]─▶  TC Requirement  (TestCases.slreqx)
                                        └─[Verify]─▶  Simulink Test Case  (Tier 2, if model exists)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `slreq.outLinks` / `slreq.inLinks`.

---

## MATLAB Project Integration

Each project uses a MATLAB project file (`.prj`) created once by `setupProject.m`.
The project provides:

- **Path management** — `scripts/`, `architecture/`, and `requirements/` are all on
  the project path (required so System Composer resolves models by name and slreq
  stores relative paths in `.slmx` files)
- **Derived folders** — `derived/cache` and `derived/codegen` are set as
  `SimulinkCacheFolder` and `SimulinkCodeGenFolder` using absolute paths
- **File tracking** — `registerWithProject(files)` is called at the end of each
  build script to keep the project in sync with the file system
- **Health checks** — `runChecks(proj)` runs at the end of `buildAll.m` to surface
  issues like untracked files or path inconsistencies immediately

---

## FCS Worked Example

The Flight Control System (`examples/fcs/`) demonstrates every step end-to-end.

```
examples/fcs/
├── FCSSystem.prj               MATLAB project (open before running scripts)
├── scripts/
│   ├── setupFCSProject.m       Create the MATLAB project (run once)
│   ├── registerWithProject.m   Shared helper for project file registration
│   ├── buildFCSAll.m           Run everything in one command
│   ├── buildFCSRequirements.m  Step 1: stakeholder needs + system requirements
│   ├── buildFCSModel.m         Step 2: physical model + interface dict + profile
│   ├── buildFCSFunctional.m    Step 3: functional architecture model
│   ├── buildFCSAllocationSet.m Step 4: function-to-component allocation set
│   ├── buildFCSAllocation.m    Step 5: SR-to-component Refine links
│   ├── rollupAnalysis.m        Step 6: power + mass roll-up analysis
│   └── buildFCSTestCases.m     Step 7: TC requirements + Verify links
├── requirements/
│   ├── StakeholderNeeds.slreqx     6 stakeholder needs (SN-FCS-001 to 006)
│   ├── SystemRequirements.slreqx   15 system requirements (SR-FCS-001 to 015)
│   └── TestCases.slreqx            13 test cases (TC-FCS-001 to 013)
├── architecture/
│   ├── FCSSystem.slx               Physical model: 6 components, 10 connections
│   ├── FCSInterfaces.sldd          6 typed interfaces (all Type="double")
│   ├── FCSBudget.xml               BudgetProperties stereotype profile
│   ├── FCSFunctional.slx           Functional model: 6 logical functions
│   └── FCSAllocation.mldatx        Functional→physical allocation set
├── analysis/
│   └── PowerMassRollup.mat         Analysis instance for Analysis Viewer
└── verification/
    └── (Simulink Test deferred — no simulation model yet)
```

### FCS Analysis Results

| | Budget | Estimate | Margin | Utilisation |
|---|---|---|---|---|
| Power | 450 W | 408 W | +42 W | 90.7% |
| Mass | 35 kg | 33 kg | +2 kg | 94.3% |

### FCS Verification Coverage

13 of 15 SRs covered by TC requirements. SR-FCS-014 (power cap) and SR-FCS-015
(mass cap) are verified by `rollupAnalysis` — expected NOT COVERED in TC report.

---

## Design Principles

- **Idempotent scripts** — every script deletes and recreates its artifacts on each
  run; safe to re-run at any point without accumulating stale data
- **Requirements as the source of truth** — budget caps and quantitative constraints
  live in requirements and are parsed by analysis scripts at run time
- **Profile in the model script** — stereotype creation and application lives at the
  end of `buildModel.m`, not in a separate profile script; both are always in sync
- **Analysis instance pattern** — `instantiate` / `getValue` / `setValue` / `save`
  rather than reading raw stereotype property strings
- **Bidirectional traceability** — every link is navigable in both directions
- **Project-integrated** — `registerWithProject` + `runChecks` keep the MATLAB project
  in sync and surface issues on every build

### Key API Gotchas

| Symptom | Root cause | Fix |
|---|---|---|
| Connections missing silently | `connect(arch, src, dst)` dispatches to Control System Toolbox | Use `connect(src, dst)` — no arch argument |
| "Unable to resolve interface" on reopen | `setInterface` called before `dict.save()` | Always save dict, then re-fetch interfaces before use |
| `addElement` breaks bus compiler | `Type="MyValueType"` creates unresolvable `Simulink.ValueType` | Use `Type="double"` for all elements |
| Profile saved as a directory | `profile.save(fullfile(archDir, 'Name.xml'))` treats path as folder | Pass the folder: `profile.save(archDir)` |
| SC editor doesn't open after build | `createModel` + `save_system` doesn't show SC editor | Call `open_system(char(modelName))` after saving |
| `.slmx` stores absolute paths | `slreq` called before `addpath(reqDir)` | Add `addpath(reqDir)` before `slreq.clear()` |
| `Project:Checks:ProjectPath` failure | Folder on MATLAB path but not on project path | Call `addPath(proj, folder)` in addition to `addFolderIncludingChildFiles` |
