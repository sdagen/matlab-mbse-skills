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

A complete MATLAB project with a `.prj` file, idempotent build scripts for each
phase, all generated artifacts, and a single `buildAll()` entry point that rebuilds
everything from scratch. See the [FCS example](examples/fcs/README.md) for what a
finished project looks like.

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
| `mbse-architecture` | Functional, logical, and physical architecture; three-level interface dictionaries; profiles/stereotypes; F→L and L→P allocation sets; analysis |
| `simulink-requirements` | All slreq API — requirements creation, links, traceability analysis, coverage |
| `simulink-test` | Simulink Test `.mldatx` files — test suites, test cases, Tier 2 verification |
| `system-composer` | Deep System Composer API reference — connection syntax, dictionary patterns, profile gotchas, layout |

---

## Workflow

The MBSE workflow follows the RFLPV methodology (Requirements, Functions, Logical,
Physical, Verification). Each phase is a separate idempotent build script.
Requirements-to-architecture Refine links are created immediately after each
architecture layer is built (via per-phase allocation scripts), so traceability
is reviewable at every step rather than deferred to a single late-stage pass.

### Phase 1 — Requirements

- Write **Stakeholder Needs** (what the system must do, in operator terms)
- Derive **System Requirements** from stakeholder needs, linked with `Derive`
- Budget constraints (power, mass, cost, etc.) live in requirements; analysis scripts
  read them at run time so values are never hard-coded
- Artifacts: `StakeholderNeeds.slreqx`, `SystemRequirements.slreqx`

### Phase 2 — Functional Architecture

- **Functional Analysis first:** work through each SR and identify what the system
  must *do* to satisfy it — producing an SR → Function derivation table before any
  model is built. Every SR must map to at least one function; functions with no SRs
  are flagged as orphaned or undocumented. This table seeds the mandatory SR→Function
  Refine links created by the paired `buildFunctionalAllocation.m` script below.
- Build a System Composer model for the **logical functions** of the system,
  independent of any physical implementation
- Create a **functional interface dictionary** with abstract interfaces —
  semantic names and flows, no physical units or implementation detail
- Create **SR → Function Refine links** (mandatory: every SR traces to at least
  one function) in a paired allocation script generated and run right after the
  model — so requirements traceability is immediately reviewable
- Artifacts: `Functional.slx`, `FunctionalInterfaces.sldd`
- Scripts: `buildFunctional.m`, `buildFunctionalAllocation.m`

### Phase 3 — Logical Architecture

- Build a System Composer model for **design-agnostic solution principles** — the
  "what kind of element" layer between functions and physical hardware
- Components are nouns describing a solution role: `SensingUnit`, `ControlUnit`,
  `ActuationUnit` — no hardware brand names or part numbers
- Create a **logical interface dictionary** with typed, semantically-named fields
  but without datasheet-level specifics (no voltage ranges, baud rates, tolerances)
- Create **SR → Logical Refine links** for non-functional requirements (timing,
  performance, safety, security) or requirements specific to a logical solution
  role, in a paired allocation script
- Artifacts: `Logical.slx`, `LogicalInterfaces.sldd`
- Scripts: `buildLogical.m`, `buildLogicalAllocation.m`

### Phase 4 — Physical Architecture + Profile

- Build a System Composer model with concrete hardware/software components and typed ports
- Create a **physical interface dictionary** with implementation-level interfaces —
  concrete field names, specific types, and physical units
- Define a **profile** with a component properties stereotype capturing the
  engineering attributes relevant to your project — mass, volume, power, cost,
  reliability, latency, throughput, or whatever drives design decisions — and
  apply it to all components with initial estimates. The profile is created and
  applied at the end of the architecture script so estimates travel with the
  model and survive every rebuild.
- Create **SR → Physical Refine links** for hardware-specific requirements
  (connector specs, EMC ratings, operating temperature, packaging, installation)
  and for system-level budget caps on physical properties (mass, volume, power,
  cost) that roll up across components, in a paired allocation script
- Artifacts: `Physical.slx`, `PhysicalInterfaces.sldd`, `Profile.xml`
- Scripts: `buildPhysical.m`, `buildPhysicalAllocation.m`

### Phase 5 — Functional→Logical Allocation

- Create an allocation set mapping each logical function to the logical element(s)
  that realize it
- Artifact: `FunctionalToLogical.mldatx`

### Phase 6 — Logical→Physical Allocation

- Create an allocation set mapping each logical element to the physical component(s)
  that implement it
- Artifact: `LogicalToPhysical.mldatx`

### Phase 7 — Analysis (optional)

- Compute system-level roll-ups and per-component margins from the architecture profile
- Budget caps are read from requirements at run time
- Artifact: `Analysis.mat`
- Script: `runAnalysis.m`

### Phase 8 — Test Cases

- Create one TC requirement per SR, each describing a stimulus and measurable pass criterion
- Link each TC to its SR with a `Verify` link
- Generate a coverage report; SRs verified by analysis (Phase 7) are expected not covered
- Artifact: `TestCases.slreqx`
- Script: `buildTestCases.m`

> **Note on requirements allocation.** SR → Function / Logical / Physical Refine
> links are not a separate phase. They are generated alongside each architecture
> layer (in Phases 2, 3, and 4) by paired per-phase allocation scripts that share
> a `removeRefineLinksToModel` helper. Each script cleans up only its own
> model-scoped links, so they can be re-run in any order without wiping each
> other out.

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
Requirements links:
  Stakeholder Need  (StakeholderNeeds.slreqx)
      └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                        ├─[Refine]─▶  Function           (Functional.slx)   mandatory
                        ├─[Refine]─▶  Logical Component  (Logical.slx)      non-functional reqs
                        ├─[Refine]─▶  Physical Component (Physical.slx)       hardware reqs
                        └─[Verify]─▶  TC Requirement     (TestCases.slreqx)
                                          └─[Verify]─▶  Simulink Test Case  (Tier 2, if model exists)

Architecture chain (allocation):
  Function  (Functional.slx)
      └─[F→L Allocate]─▶  Logical Element  (Logical.slx)
                               └─[L→P Allocate]─▶  Physical Component  (Physical.slx)
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

