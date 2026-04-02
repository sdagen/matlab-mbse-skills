# MATLAB MBSE Skills

A collection of Claude skills and a worked example for Model-Based Systems Engineering
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

MATLAB R2023a or later recommended. The FCS example was developed and tested on R2025b.

Simulink Test is supported but not required — see [Two-Tier Verification](OVERVIEW.md#two-tier-verification).

---

## Repository Structure

```
matlab-mbse-skills/
├── skills/
│   ├── mbse/                  Requirements + verification API patterns
│   ├── mbse-new-project/      Guided end-to-end new project setup
│   ├── mbse-architecture/     Architecture, allocation, and analysis
│   └── system-composer/       Deep System Composer API reference
└── examples/
    └── fcs/                   Flight Control System — full end-to-end example
        ├── FCSSystem.prj      MATLAB project (open this first)
        ├── scripts/           All build scripts
        ├── requirements/      SN + SR sets, TC requirements
        ├── architecture/      SC models, interface dict, profile, analysis
        └── verification/      (reserved — Simulink Test deferred)
```

---

## Using the Skills

Each folder under `skills/` contains a `SKILL.md` that can be loaded as a Claude
Code skill. Skills are invoked automatically when you describe a task that matches
their trigger conditions, or you can reference them by name.

The `mbse-new-project` skill is the entry point for new projects — it conducts an
interview and walks through each phase one at a time, proposing content, waiting for
approval, generating the script, and running it. The other skills provide the detailed
API patterns that `mbse-new-project` draws on.

---

## Running the FCS Example

Open the project, then run the full build in one command:

```matlab
openProject('path/to/examples/fcs')
buildFCSAll()
```

Or run steps individually — all scripts are idempotent:

```
Step 1  buildFCSRequirements()    StakeholderNeeds.slreqx, SystemRequirements.slreqx
Step 2  buildFCSModel()           FCSSystem.slx, FCSInterfaces.sldd, FCSBudget.xml
Step 3  buildFCSFunctional()      FCSFunctional.slx
Step 4  buildFCSAllocationSet()   FCSAllocation.mldatx
Step 5  buildFCSAllocation()      Refine links: 13 SRs → 25 component links
Step 6  rollupAnalysis()          PowerMassRollup.mat (power 408/450 W, mass 33/35 kg)
Step 7  buildFCSTestCases()       TestCases.slreqx, 13 TCs with Verify links
```

`buildFCSAll()` runs all steps and prints a `runChecks` project health report at the end.

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
                                        └─[Verify]─▶  Simulink Test Case  (Tier 2, if model exists)
```

All links are bidirectional and navigable from either end in the Requirements Editor
or programmatically via `slreq.outLinks` / `slreq.inLinks`.
