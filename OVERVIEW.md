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
from scratch. See the [FCS example](examples/fcs/README.md) for what a finished project
looks like.

### Starting a guided session

Just tell Claude what you want to build:
> *"I want to set up a new MBSE project for an eVTOL propulsion system"*

The `mbse-new-project` skill activates automatically and begins the interview.

---

## Skills

Six Claude skills live in `skills/`. `mbse-new-project` drives the conversation;
the others provide the technical API patterns it draws on.

| Skill | Purpose |
|---|---|
| `mbse-new-project` | Guided end-to-end setup — interview, propose, generate, run, confirm |
| `mbse` | Thin workflow index — which skill covers which phase |
| `mbse-architecture` | Physical + functional architecture, profiles/stereotypes, allocation set, analysis |
| `simulink-requirements` | All slreq API — requirements creation, links, traceability analysis, coverage |
| `simulink-test` | Simulink Test `.mldatx` files — test suites, test cases, Tier 2 verification |
| `system-composer` | Deep System Composer API reference — connection syntax, dictionary patterns, profile gotchas, layout |

---

## Workflow

The MBSE workflow runs in seven steps. Each step is a separate idempotent build script.

### Step 1 — Requirements

- Write **Stakeholder Needs** (what the system must do, in operator terms)
- Derive **System Requirements** from stakeholder needs, linked with `Derive`
- Budget constraints (power, mass, cost, etc.) live in requirements; analysis scripts
  read them at run time so values are never hard-coded
- Artifacts: `StakeholderNeeds.slreqx`, `SystemRequirements.slreqx`

### Step 2 — Functional Architecture

- Build a System Composer model for the **logical functions** of the system,
  independent of physical implementation
- Create a **functional interface dictionary** with logical, abstract interfaces —
  semantic names and flows, no physical units or implementation detail
- Artifacts: `Functional.slx`, `FunctionalInterfaces.sldd`

### Step 3 — Physical Architecture + Profile

- Build a System Composer model with typed components and ports
- Create a **physical interface dictionary** with implementation-level interfaces —
  concrete field names, specific types, and physical units
- Define a **profile** with a component properties stereotype capturing the
  engineering attributes relevant to your project — mass, power, cost, reliability,
  latency, or whatever drives design decisions — and apply it to all components
  with initial estimates
- Artifacts: `System.slx`, `PhysicalInterfaces.sldd`, `Profile.xml`

### Step 4 — Functional→Physical Allocation

- Create an allocation set mapping each logical function to the physical component(s)
  that implement it (ARP4754A functional allocation tier)
- Artifact: `Allocation.mldatx`

### Step 5 — Requirements Allocation

- Create `Refine` links from each SR to the component(s) responsible for implementing it
- Navigate forward (requirement → components) and backward (component → requirements)

### Step 6 — Analysis (optional)

- Compute system-level roll-ups and per-component margins from the architecture profile
- Budget caps are read from requirements at run time
- Artifact: `Analysis.mat`

### Step 7 — Test Cases

- Create one TC requirement per SR, each describing a stimulus and measurable pass criterion
- Link each TC to its SR with a `Verify` link
- Generate a coverage report; SRs verified by analysis (Step 6) are expected not covered
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
or programmatically via `req.outLinks()` / `req.inLinks()`.

---

## MATLAB Project Integration

Each project uses a MATLAB project file (`.prj`) created once by `setupProject.m`.
The project provides:

- **Path management** — all project folders are on the MATLAB path, so System Composer
  resolves models by name and tools find artifacts without absolute paths
- **Derived folders** — Simulink cache and codegen outputs are kept out of source control
- **File tracking** — build scripts register the artifacts they create; the project
  stays in sync with the file system automatically
- **Health checks** — `buildAll.m` runs project checks at the end and surfaces any
  issues immediately

---

## FCS Worked Example

The [FCS example](examples/fcs/README.md) demonstrates every step end-to-end.

---

## Design Principles

- **Idempotent scripts** — every script deletes and recreates its artifacts on each
  run; safe to re-run at any point without accumulating stale data
- **Project-integrated** — build scripts keep the MATLAB project in sync; health
  checks run automatically on every full build
- **Skills are organized by API domain** — each skill covers one MATLAB toolbox or
  API surface (`slreq`, System Composer, Simulink Test). When an operation spans
  domains, it lives in the skill that owns the primary API, with a pointer from the other
- **`mbse-new-project` orchestrates; domain skills are reference** — the workflow
  skill handles phase sequencing and user interaction; it draws on the domain skills
  for API patterns rather than duplicating them. The two concerns can evolve independently

