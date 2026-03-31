# FCS Example

A complete end-to-end MBSE example for a **Flight Control System (FCS)**, covering
all six phases: requirements, architecture, allocation, trade studies, test case
requirements, and Simulink Test.

---

## System Overview

The FCS manages pilot inceptor inputs, runs stability and control laws, and drives
control surface actuators. Six top-level components:

| Component | Role |
|---|---|
| FlightComputer | Control law computation (dual-redundant) |
| PilotInterface | Sidestick, rudder pedals, trim controls |
| SensorSuite | IMU, air data, GPS/navigation |
| ActuatorSystem | Elevator, aileron, rudder, spoiler actuators |
| PowerSystem | Primary, secondary, and emergency power buses |
| DataBus | ARINC 429 backbone; maintenance interface |

---

## Files

### `requirements/`

| File | Description |
|---|---|
| `buildFCSRequirements.m` | Creates stakeholder needs, system requirements, and Derive links. Also defines SR-FCS-014 (power cap: 450 W) and SR-FCS-015 (mass cap: 35 kg) used by the roll-up analysis. |

Generates: `StakeholderNeeds.slreqx` (6 items), `SystemRequirements.slreqx` (15 items)

### `architecture/`

| File | Description |
|---|---|
| `buildFCSModel.m` | Creates the System Composer architecture model and interface dictionary. Always saves the `.slx` to this directory regardless of working folder. |

Generates: `FCSSystem.slx`, `FCSInterfaces.sldd`

### `allocation/`

| File | Description |
|---|---|
| `buildFCSAllocation.m` | Creates Refine links from each SR to the component(s) responsible for it (25 links total). Idempotent — clears existing links before rebuild. Prints a bidirectional traceability report. |

### `analyses/`

| File | Description |
|---|---|
| `buildFCSProfile.m` | Calls `buildFCSModel()` for a clean rebuild, then creates the `FCSBudget` profile with a `BudgetProperties` stereotype (PowerBudget_W, PowerEstimate_W, PowerMargin_W, Mass_kg) and applies it to all components. |
| `rollupAnalysis.m` | Opens the SR set to read budget caps from SR-FCS-014 and SR-FCS-015, creates a System Composer analysis instance, reads property values via `getValue`, computes margins, writes them back via `setValue`, and saves the instance for the Analysis Viewer. |

Generates: `FCSBudget.xml`, `PowerMassRollup.mat`

**Results:**

| Budget | Allocated | Estimated | Margin | Utilisation |
|---|---|---|---|---|
| Power | 450 W | 408 W | 42 W | 90.7% |
| Mass | 35 kg | 33 kg | 2 kg | 94.3% |

### `verification/`

| File | Description |
|---|---|
| `buildFCSTestCases.m` | Creates `TestCases.slreqx` with one TC requirement per SR, each linked with a Verify link. Prints a coverage report (13/13, 100%). |
| `buildFCSSimulinkTests.m` | Creates `FCSTests.mldatx` with 13 Simulink Test cases in 5 suites, each linked (Verify) to its corresponding TC requirement. |

Generates: `TestCases.slreqx`, `FCSTests.mldatx`

**Simulink Test suites:**

| Suite | Test Cases |
|---|---|
| Command Interface | TC-FCS-001, 002, 003 |
| Stability | TC-FCS-004, 005, 006 |
| Handling Qualities | TC-FCS-007, 008 |
| Failure Safety | TC-FCS-009, 010, 011 |
| Maintainability | TC-FCS-012, 013 |

---

## Run Order

```matlab
% Add all subdirectories to path
addpath(genpath('path/to/examples/fcs'))

% Phase 1 — Requirements
buildFCSRequirements()

% Phase 2 — Architecture
buildFCSModel()

% Phase 3 — Allocation
buildFCSAllocation()

% Phase 4 — Trade Studies
buildFCSProfile()
rollupAnalysis()

% Phase 5 — Test Case Requirements
buildFCSTestCases()

% Phase 6 — Simulink Test
buildFCSSimulinkTests()
```

---

## Traceability

```
SN-FCS-001  Pilot attitude command
    └─[Derive]─▶  SR-FCS-001  Roll rate command range
    │                 ├─[Refine]─▶  FlightComputer
    │                 ├─[Refine]─▶  PilotInterface
    │                 └─[Verify]─▶  TC-FCS-001  Roll rate command acceptance
    │                                   └─[Verify]─▶  sltest: TC-FCS-001
    └─[Derive]─▶  SR-FCS-002  Pitch rate command range
                  └─ ...
```
