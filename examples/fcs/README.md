# FCS MBSE Example

> **Note:** This example was built before the RFLPV workflow update and uses a two-model
> architecture (Functional + Physical) with a single F→P allocation set. It will be rebuilt
> to include the Logical layer (`FCSLogical.slx`), three interface dictionaries, and separate
> F→L and L→P allocation sets. The scripts and artifacts below reflect the pre-RFLPV state.

A complete end-to-end MBSE example for a **Flight Control System (FCS)**, demonstrating
the workflow from stakeholder needs through verified test cases with bidirectional
traceability at every step.

---

## System Overview

The FCS manages pilot inceptor inputs, runs stability and control laws, and drives
control surface actuators. Six top-level physical components:

| Component | Role |
|---|---|
| FlightComputer | Control law computation (dual-redundant) |
| PilotInterface | Sidestick, rudder pedals, trim controls |
| SensorSuite | IMU, air data, GPS/navigation |
| ActuatorSystem | Elevator, aileron, rudder, spoiler actuators |
| PowerSystem | Primary, secondary, and emergency power buses |
| DataBus | ARINC 429 backbone; maintenance interface |

Six logical functions (functional architecture, independent of physical implementation):
SenseAircraftState, ComputeControlLaws, CommandControlSurfaces, DistributePower,
ProvideCrewInterface, MonitorSystemHealth.

---

## Project Setup

This is a MATLAB project (`FCSSystem.prj`). Open it before running build scripts:

```matlab
openProject('path/to/examples/fcs')
```

`setupFCSProject.m` was used to create the project (run once). It configures
`derived/cache` and `derived/codegen` as the Simulink cache and code generation
folders, and registers `scripts/`, `architecture/`, and `requirements/` on the
MATLAB path.

---

## Running the Example

```matlab
% Open the project first, then:
buildFCSAll()
```

All scripts are idempotent — safe to re-run at any time. `buildFCSAll()` runs
all 7 steps in sequence and prints a `runChecks` project health report at the end.

---

## Files

```
examples/fcs/
├── FCSSystem.prj               MATLAB project (open before running scripts)
├── scripts/
│   ├── setupFCSProject.m       Create the MATLAB project (run once)
│   ├── registerWithProject.m   Shared helper for project file registration
│   ├── buildFCSAll.m           Run everything in one command
│   ├── buildFCSRequirements.m  Step 1: stakeholder needs + system requirements
│   ├── buildFCSFunctional.m    Step 2: functional architecture model
│   ├── buildFCSModel.m         Step 3: physical model + interface dict + profile
│   ├── buildFCSAllocationSet.m Step 4: function-to-component allocation set
│   ├── buildFCSAllocation.m    Step 5: SR-to-component Refine links
│   ├── rollupAnalysis.m        Step 6: power + mass roll-up analysis
│   └── buildFCSTestCases.m     Step 7: TC requirements + Verify links
├── requirements/
│   ├── StakeholderNeeds.slreqx
│   ├── SystemRequirements.slreqx
│   └── TestCases.slreqx
├── architecture/
│   ├── FCSFunctional.slx               Functional model: 6 logical functions
│   ├── FCSFunctionalInterfaces.sldd    6 logical interfaces (abstract flows)
│   ├── FCSSystem.slx                   Physical model: 6 components, 10 connections
│   ├── FCSPhysicalInterfaces.sldd      6 typed interfaces (concrete, physical units)
│   ├── FCSBudget.xml                   Component profile (power + mass properties)
│   └── FCSAllocation.mldatx            Functional→physical allocation set
├── analysis/
│   └── PowerMassRollup.mat
└── verification/
    └── (Simulink Test deferred — no simulation model yet)
```

### `scripts/`

All build scripts live here. The project puts this folder on the MATLAB path.

| Script | Creates |
|---|---|
| `setupFCSProject.m` | MATLAB project (run once) |
| `registerWithProject.m` | Shared helper — registers files/folders with open project |
| `buildFCSAll.m` | Orchestrates all 7 steps; runs `runChecks` at the end |
| `buildFCSRequirements.m` | `StakeholderNeeds.slreqx` (6 items), `SystemRequirements.slreqx` (15 items), Derive links |
| `buildFCSFunctional.m` | `FCSFunctional.slx` (6 logical functions), `FCSFunctionalInterfaces.sldd` |
| `buildFCSModel.m` | `FCSSystem.slx`, `FCSPhysicalInterfaces.sldd`, `FCSBudget.xml` (profile) |
| `buildFCSAllocationSet.m` | `FCSAllocation.mldatx` (functional→physical allocation) |
| `buildFCSAllocation.m` | Refine links: 13 SRs → components (25 links total) |
| `rollupAnalysis.m` | `PowerMassRollup.mat` (analysis instance for Analysis Viewer) |
| `buildFCSTestCases.m` | `TestCases.slreqx` (13 TC requirements), Verify links to SRs |

### `requirements/`

Generated artifacts — do not edit by hand.

| File | Description |
|---|---|
| `StakeholderNeeds.slreqx` | 6 stakeholder needs (SN-FCS-001 to 006) |
| `SystemRequirements.slreqx` | 15 system requirements (SR-FCS-001 to 015) — includes SR-014 (power cap: 450 W) and SR-015 (mass cap: 35 kg) used by the roll-up analysis |
| `TestCases.slreqx` | 13 test cases (TC-FCS-001 to 013) |

### `architecture/`

Generated artifacts — do not edit by hand.

| File | Description |
|---|---|
| `FCSFunctional.slx` | Functional System Composer model (6 logical functions) |
| `FCSFunctionalInterfaces.sldd` | 6 logical interfaces — abstract flows, no physical units |
| `FCSSystem.slx` | Physical System Composer model (6 components, 10 connections) |
| `FCSPhysicalInterfaces.sldd` | 6 typed interfaces — concrete fields, physical units |
| `FCSBudget.xml` | Component profile: `BudgetProperties` stereotype with PowerBudget\_W, PowerEstimate\_W, PowerMargin\_W, Mass\_kg applied to all components |
| `FCSAllocation.mldatx` | Functional→physical allocation set (scenario: FunctionalToPhysical) |

### `analysis/`

Generated artifacts — do not edit by hand.

| File | Description |
|---|---|
| `PowerMassRollup.mat` | Analysis instance — open with `systemcomposer.analysis.openViewer('PowerMassRollup')` |

### `verification/`

Reserved for Simulink Test artifacts. Simulink Test (`.mldatx`) is deferred until
a Simulink simulation model exists — the TC requirements in `TestCases.slreqx`
provide full requirements traceability in the meantime.

---

## Analysis Results

Budget caps are read from requirements at run time (SR-FCS-014, SR-FCS-015) —
not hard-coded in scripts.

| | Budget | Estimate | Margin | Utilisation |
|---|---|---|---|---|
| Power | 450 W | 408 W | +42 W | 90.7% |
| Mass | 35 kg | 33 kg | +2 kg | 94.3% |

Per-component power margins are written back to the analysis instance and visible
in the Analysis Viewer.

---

## Verification Coverage

13 of 15 SRs are covered by TC requirements (87%). SR-FCS-014 and SR-FCS-015
(power and mass budget caps) are verified by `rollupAnalysis` — they are
intentionally not covered by test cases.

| SR Range | SN | Test Cases |
|---|---|---|
| SR-001 to 003 | Pilot attitude command | TC-001 to 003 |
| SR-004 to 006 | Aircraft stability | TC-004 to 006 |
| SR-007 to 008 | Handling qualities | TC-007 to 008 |
| SR-009 to 011 | Failure safety | TC-009 to 011 |
| SR-012 to 013 | Maintainability | TC-012 to 013 |
| SR-014 to 015 | SWaP constraints | (verified by rollupAnalysis) |

---

## Traceability

```
SN-FCS-001  Pilot attitude command
    └─[Derive]─▶  SR-FCS-001  Roll rate command range
                      ├─[Refine]─▶  FlightComputer  (FCSSystem.slx)
                      ├─[Refine]─▶  PilotInterface
                      └─[Verify]─▶  TC-FCS-001  Roll rate command acceptance
                                         (TestCases.slreqx)

SN-FCS-001  (continued)
    └─[Derive]─▶  SR-FCS-002  Pitch rate command range
                  └─ ...

Logical function allocation:
    ComputeControlLaws  (FCSFunctional.slx)
        └─[Allocate]─▶  FlightComputer  (FCSSystem.slx)
                            (FCSAllocation.mldatx, scenario: FunctionalToPhysical)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `req.outLinks()` / `req.inLinks()`.
