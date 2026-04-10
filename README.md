# MATLAB MBSE Skills

A collection of Claude skills and a worked example for Model-Based Systems Engineering
(MBSE) in MATLAB — from stakeholder needs through verified test cases, with full
bidirectional traceability.

---

## Getting Started: Guided Project Setup

The primary way to use these skills is through the **`mbse-new-project` guided
workflow**. Tell Claude you want to start a new MBSE project and it will:

1. **Interview you** — system name, location, description, subsystems, engineering
   concerns (mass, power, cost, …), analysis needs, and whether a simulation model exists
2. **Propose content at each phase** — stakeholder needs, system requirements,
   components, interfaces, functions, allocations, test cases — waiting for your
   approval before generating anything
3. **Generate and run each build script** — one phase at a time, showing you the
   output and asking you to confirm before moving on
4. **Produce a complete, runnable MATLAB project** — with a `.prj` file, 7 idempotent
   build scripts, all artifacts, and a `buildAll()` entry point that rebuilds
   everything from scratch

The result is a project like the [FCS example](examples/fcs/) — a full MBSE artifact
set with requirements, architecture, allocation, analysis, and test cases all wired
together with traceable links.

To start, just say something like:
> *"I want to set up a new MBSE project for a [your system]"*

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
│   ├── mbse-new-project/      Guided end-to-end setup (start here for new projects)
│   ├── mbse/                  Thin workflow index — which skill covers which phase
│   ├── mbse-architecture/     Architecture, allocation set, and analysis
│   ├── simulink-requirements/ All slreq API — requirements, links, traceability, coverage
│   ├── simulink-test/         Simulink Test .mldatx files (Tier 2 verification)
│   └── system-composer/       Deep System Composer API reference
└── examples/
    └── fcs/                   Flight Control System — complete reference example
        ├── FCSSystem.prj      MATLAB project (open this first)
        ├── scripts/           All build scripts
        ├── requirements/      SN + SR sets, TC requirements
        ├── architecture/      SC models, interface dict, profile, analysis
        └── verification/      (reserved — Simulink Test deferred)
```

The `mbse-new-project` skill drives the conversation and generates scripts; it draws
on `simulink-requirements`, `mbse-architecture`, `simulink-test`, and `system-composer`
for the technical API patterns.

---

## FCS Reference Example

The FCS example shows what a completed project looks like. Open it and run:

```matlab
openProject('path/to/examples/fcs')
buildFCSAll()
```

Or run steps individually — all scripts are idempotent:

```
Step 1  buildFCSRequirements()    StakeholderNeeds.slreqx, SystemRequirements.slreqx
Step 2  buildFCSFunctional()      FCSFunctional.slx, FCSFunctionalInterfaces.sldd
Step 3  buildFCSModel()           FCSSystem.slx, FCSPhysicalInterfaces.sldd, FCSBudget.xml
Step 4  buildFCSAllocationSet()   FCSAllocation.mldatx
Step 5  buildFCSAllocation()      Refine links: 13 SRs → 25 component links
Step 6  rollupAnalysis()          PowerMassRollup.mat (power 408/450 W, mass 33/35 kg)
Step 7  buildFCSTestCases()       TestCases.slreqx, 13 TCs with Verify links
```

See [OVERVIEW.md](OVERVIEW.md) for a full description of the workflow, artifacts,
and design principles.

---

## Traceability

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
