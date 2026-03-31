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
│   ├── mbse-requirements/         Requirements Toolbox API and two-level hierarchy
│   ├── mbse-architecture/         System Composer model authoring
│   ├── mbse-allocation/           Refine links and bidirectional navigation
│   ├── mbse-trade-studies/        Budget roll-up with systemcomposer.analysis API
│   ├── mbse-verification/         Test case requirements and Verify links
│   └── system-composer/           Deep System Composer API reference
└── examples/
    └── fcs/                       Flight Control System — full end-to-end example
        ├── requirements/          Phase 1: SN + SR sets, TC requirements
        ├── architecture/          Phase 2: SC model, interface dictionary
        ├── allocation/            Phase 3: Refine links to components
        ├── analyses/              Phase 4: profile, budget roll-up analysis
        └── verification/          Phase 5+6: TC requirements, Simulink Test file
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

The example scripts must be run in phase order. Each script is idempotent — safe
to re-run at any time.

```
Step 1 — Requirements
  >> buildFCSRequirements()        % creates StakeholderNeeds.slreqx,
                                   %         SystemRequirements.slreqx

Step 2 — Architecture
  >> buildFCSModel()               % creates FCSSystem.slx, FCSInterfaces.sldd

Step 3 — Allocation
  >> buildFCSAllocation()          % creates Refine links (25 total)

Step 4 — Trade Studies
  >> buildFCSProfile()             % applies FCSBudget profile to model
  >> rollupAnalysis()              % runs power + mass roll-up, saves instance

Step 5 — Test Case Requirements
  >> buildFCSTestCases()           % creates TestCases.slreqx, Verify links to SRs

Step 6 — Simulink Test
  >> buildFCSSimulinkTests()       % creates FCSTests.mldatx, links to TC requirements
```

Add `examples/fcs` and its subdirectories to the MATLAB path before running.

---

## Workflow Summary

```
Stakeholder Need  (StakeholderNeeds.slreqx)
    └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                      ├─[Refine]─▶  Architecture Component  (FCSSystem.slx)
                      └─[Verify]─▶  TC Requirement  (TestCases.slreqx)
                                        └─[Verify]─▶  Simulink Test Case  (FCSTests.mldatx)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `slreq.outLinks` / `slreq.inLinks`.
