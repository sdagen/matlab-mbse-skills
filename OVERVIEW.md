# MBSE Capability Suite for MATLAB

A family of reusable skills and a full worked example that encode the complete
Model-Based Systems Engineering (MBSE) workflow in MATLAB — from stakeholder needs
through verified test cases, with traceability at every step.

---

## Skills

Seven Claude skills live in `system-composer-plugin/skills/`. Each encodes the
correct API patterns, common gotchas, and proven script structures for one phase
of the MBSE workflow.

| Skill | Purpose |
|---|---|
| `mbse` | Top-level orchestrator — workflow overview, phase map, folder structure |
| `mbse-requirements` | Requirements Toolbox API, two-level hierarchy, derivation links |
| `mbse-architecture` | System Composer model authoring, interfaces, profiles, stereotypes |
| `mbse-allocation` | Refine links from requirements to components, bidirectional navigation |
| `mbse-trade-studies` | Budget roll-up analysis using the `systemcomposer.analysis` API |
| `mbse-verification` | Test case requirements, Verify links, coverage reporting |
| `system-composer` | Deep API reference — connection syntax, dictionary patterns, layout |

---

## Workflow

The six MBSE phases are executed in sequence. Each phase builds on the artifacts
from the previous one.

### Phase 1 — Requirements (`mbse-requirements`)

- Write **Stakeholder Needs** (what the system must do, in operator terms)
- Derive **System Requirements** from stakeholder needs, linked with `Derive`
- System-level budget constraints (power, mass, etc.) live here as named requirements
  — scripts read them at run time; values are never hard-coded elsewhere
- Artifacts: `StakeholderNeeds.slreqx`, `SystemRequirements.slreqx`

### Phase 2 — Architecture (`mbse-architecture`)

- Build a System Composer model with typed components and ports
- Define interfaces in a data dictionary — all elements use `Type="double"`;
  physical units are documented in comments, not as separate named types
- Create a **profile** with stereotypes and budget properties (power, mass, etc.)
  attached to each component at design time
- Run `update diagram` to catch type resolution errors before proceeding
- Artifacts: `FCSSystem.slx`, `FCSInterfaces.sldd`, `FCSBudget.xml`

### Phase 3 — Allocation (`mbse-allocation`)

- Create `Refine` links from each system requirement to the component(s)
  responsible for implementing it
- Scripts are idempotent — existing links are cleared before rebuild
- Navigate forward (requirement → components) and backward (component → requirements)
- Artifact: `buildFCSAllocation.m`

### Phase 4 — Trade Studies (`mbse-trade-studies`)

- Create an **analysis instance** from the architecture profile using `instantiate`
- Read property values with `getValue` (returns `double` directly — no parsing needed)
- Compute system-level roll-ups and per-component margins
- Write computed results (e.g. `PowerMargin_W`) back to the instance with `setValue`
- Save the instance as a `.mat` file for the Analysis Viewer
- Budget caps come from requirements (parsed at run time); no magic numbers in scripts
- Artifacts: `buildFCSProfile.m`, `rollupAnalysis.m`, `PowerMassRollup.mat`

### Phase 5 — Test Cases (`mbse-verification`)

- Create a `TestCases.slreqx` requirement set with one TC per system requirement
- Each TC requirement describes: setup, stimulus, and pass criterion
- Link each TC to its target SR with a `Verify` link
- Generate a coverage report — which SRs have at least one TC, which don't
- Artifact: `buildFCSTestCases.m`, `TestCases.slreqx`

### Phase 6 — Simulink Test (`buildFCSSimulinkTests`)

- Create a **Simulink Test file** (`.mldatx`) from the TC requirements
- One `sltest` test case per TC requirement, grouped into suites by functional area
- Each test case carries the procedure description from its TC requirement
- Link each sltest test case back to its `slreq` TC requirement with a `Verify` link
- Artifact: `buildFCSSimulinkTests.m`, `FCSTests.mldatx`

---

## Traceability Chain

Every artifact is traceable up and down the chain:

```
Stakeholder Need
    └── System Requirement  (Derive link)
            ├── Architecture Component  (Refine link)
            └── TC Requirement          (Verify link)
                    └── Simulink Test Case  (Verify link)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `slreq.outLinks` / `slreq.inLinks`.

---

## FCS Worked Example

The Flight Control System demonstrates every phase end-to-end.

```
fcs-mbse/
├── requirements/
│   ├── buildFCSRequirements.m      — creates SN + SR sets and Derive links
│   ├── StakeholderNeeds.slreqx     — 6 stakeholder needs (SN-FCS-001 to 006)
│   ├── SystemRequirements.slreqx   — 15 system requirements (SR-FCS-001 to 015)
│   │                                 incl. SR-014 (power cap) and SR-015 (mass cap)
│   ├── buildFCSTestCases.m         — creates TC requirements and Verify links
│   └── TestCases.slreqx            — 13 test cases (TC-FCS-001 to 013)
│
├── architecture/
│   ├── buildFCSModel.m             — builds System Composer model + dictionary
│   ├── FCSSystem.slx               — 6 components: FlightComputer, PilotInterface,
│   │                                 SensorSuite, ActuatorSystem, PowerSystem, DataBus
│   ├── FCSInterfaces.sldd          — 6 typed interfaces (all Type="double")
│   └── FCSBudget.xml               — profile: BudgetProperties stereotype
│
├── allocation/
│   └── buildFCSAllocation.m        — 25 Refine links (13 SRs → 1–4 components each)
│
├── analyses/
│   ├── buildFCSProfile.m           — applies profile + sets per-component estimates
│   ├── rollupAnalysis.m            — power + mass roll-up via analysis instance
│   └── PowerMassRollup.mat         — saved analysis instance for Analysis Viewer
│
└── verification/
    ├── buildFCSTestCases.m         — (see requirements/ above)
    ├── buildFCSSimulinkTests.m     — creates Simulink Test file from TC requirements
    └── FCSTests.mldatx             — 13 sltest cases in 5 suites, all linked to TCs
```

### FCS Analysis Results

| Budget | Allocated | Estimated | Margin | Utilisation |
|---|---|---|---|---|
| Power | 450 W | 408 W | 42 W | 90.7% |
| Mass | 35 kg | 33 kg | 2 kg | 94.3% |

### FCS Verification Coverage

- 13 system requirements → 13 test cases → **100% coverage**
- Simulink Test suites by functional area:

| Suite | Test Cases |
|---|---|
| Command Interface | TC-FCS-001, 002, 003 |
| Stability | TC-FCS-004, 005, 006 |
| Handling Qualities | TC-FCS-007, 008 |
| Failure Safety | TC-FCS-009, 010, 011 |
| Maintainability | TC-FCS-012, 013 |

---

## Design Principles

- **Idempotent scripts** — every script deletes and recreates its artifacts on each run;
  safe to re-run at any point without accumulating stale data
- **Requirements as the source of truth** — budget caps and other quantitative constraints
  live in requirements and are parsed by analysis scripts, not duplicated as constants
- **Analysis instance pattern** — `instantiate` / `getValue` / `setValue` / `save`
  rather than manual stereotype property string parsing
- **Bidirectional traceability** — every link is navigable in both directions
- **Gotchas documented** — the skills capture non-obvious API behaviors so they
  don't have to be rediscovered:
  - `connect(src, dst)` not `connect(arch, src, dst)` — shadowed by Control System Toolbox
  - `dict.save()` required before `setInterface` — interfaces unresolvable until saved
  - `Type="double"` in `addElement` — named value types break the bus compiler
  - `profile.save([charName, '.xml'])` — string concatenation with `+` causes silent failure
  - `instantiate(arch, profileName, instanceName)` — profile name only, no second file arg
