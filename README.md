# MATLAB MBSE Skills

A collection of Claude skills and worked examples for Model-Based Systems Engineering
(MBSE) in MATLAB. The skills encode correct API patterns, proven script structures,
and hard-won gotchas for the full MBSE workflow — from stakeholder needs through
verified test cases.

See [OVERVIEW.md](OVERVIEW.md) for a detailed description of the full capability.

---

## Prerequisites

| Toolbox | Used for |
|---|---|
| System Composer | Architecture modeling, profiles, stereotypes, analysis instances |
| Requirements Toolbox | Requirement sets, derivation/refinement/verification links |
| Simulink Test | Test file authoring, test case–to–requirement traceability |

MATLAB R2023a or later recommended. The FCS example was developed and tested on R2025b.

---

## Repository Structure

```
matlab-mbse-skills/
├── skills/                        Claude skills — one folder per phase
│   ├── mbse/                      Orchestrator: workflow overview and phase map
│   ├── mbse-new-project/          Guided end-to-end setup for a new project
│   ├── mbse-requirements/         Requirements Toolbox API and two-level hierarchy
│   ├── mbse-architecture/         Physical + functional SC models, profile/stereotype
│   ├── mbse-allocation/           SC allocation set (functional→physical) + Refine links
│   ├── mbse-analysis/             Budget roll-up, trade studies, systemcomposer.analysis API
│   ├── mbse-verification/         Test case requirements and Verify links
│   └── system-composer/           Deep System Composer API reference
└── examples/
    └── fcs/                       Flight Control System — full end-to-end example
        ├── requirements/          SN + SR sets, TC requirements
        ├── architecture/          FCSSystem.slx, FCSFunctional.slx, FCSAllocation.mldatx
        └── verification/          TC requirements, Simulink Test file
```

---

## Using the Skills

Each folder under `skills/` contains a `SKILL.md` that can be loaded as a Claude
Code skill. Skills are invoked automatically when you describe a task that matches
their trigger conditions, or you can reference them by name.

The `mbse` skill is the entry point — it describes the full workflow and points to
the right skill for each phase.

---

## Running the FCS Example

Run `buildFCSAll()` to build everything in one command, or run steps individually
in order. All scripts are idempotent — safe to re-run at any time.

```
>> buildFCSAll()    % runs all 9 steps below in sequence

Step 1 — Requirements
  >> buildFCSRequirements()        % StakeholderNeeds.slreqx, SystemRequirements.slreqx

Step 2 — Physical Architecture
  >> buildFCSModel()               % FCSSystem.slx, FCSInterfaces.sldd

Step 3 — Budget Profile
  >> buildFCSProfile()             % FCSBudget profile applied to FCSSystem.slx

Step 4 — Functional Architecture
  >> buildFCSFunctional()          % FCSFunctional.slx (6 logical functions)

Step 5 — Functional→Physical Allocation
  >> buildFCSAllocationSet()       % FCSAllocation.mldatx (allocation set)

Step 6 — Requirements Allocation
  >> buildFCSAllocation()          % Refine links: SR → component (25 total)

Step 7 — Analysis
  >> rollupAnalysis()              % power + mass roll-up, PowerMassRollup.mat

Step 8 — Test Case Requirements
  >> buildFCSTestCases()           % TestCases.slreqx, Verify links to SRs

Step 9 — Simulink Test
  >> buildFCSSimulinkTests()       % FCSTests.mldatx, linked to TC requirements
```

---

## Workflow Summary

```
Stakeholder Need  (StakeholderNeeds.slreqx)
    └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                      ├─[Refine]─▶  Architecture Component  (FCSSystem.slx)
                      │                 ▲
                      │             [Allocate]  (FCSAllocation.mldatx)
                      │                 │
                      │             Logical Function  (FCSFunctional.slx)
                      └─[Verify]─▶  TC Requirement  (TestCases.slreqx)
                                        └─[Verify]─▶  Simulink Test Case  (FCSTests.mldatx)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `slreq.outLinks` / `slreq.inLinks`.
