# MATLAB MBSE Skills

A collection of Claude skills and a worked example for Model-Based Systems Engineering
(MBSE) in MATLAB — from stakeholder needs through verified test cases, with full
bidirectional traceability.

---

## Getting Started: Guided Project Setup

The primary way to use these skills is through the **`mbse-new-project` guided
workflow**. Tell Claude you want to start a new MBSE project and it will:

1. **Interview you** — system name, location, description, subsystems, engineering
   concerns (mass, volume, power, cost, …), analysis needs, and whether a simulation
   model exists
2. **Propose content at each phase** — stakeholder needs, system requirements,
   components, interfaces, functions, allocations, test cases — waiting for your
   approval before generating anything
3. **Generate and run each build script** — one phase at a time, showing you the
   output and asking you to confirm before moving on. Each of the three architecture
   phases (Functional, Logical, Physical) is paired with its own allocation script
   that creates architecture → SR Implement links immediately, so traceability is
   reviewable at every layer instead of deferred to a late-stage consolidation pass
4. **Produce a complete, runnable MATLAB project** — with a `.prj` file, a stereotype
   profile capturing component engineering properties (mass, volume, power, cost,
   …) with initial estimates, idempotent build scripts for each phase, all
   artifacts, and a `buildAll()` entry point that rebuilds everything from scratch

The result is a project like the [GalacticSoup example](examples/GalacticSoup/) — a
full MBSE artifact set with requirements, architecture, allocation, analysis, and test
cases all wired together with traceable links.

To start, just say something like:
> *"I want to set up a new MBSE project for a [your system]"*

---

## Prerequisites

| Toolbox | Used for |
|---|---|
| System Composer | Architecture modeling, profiles, stereotypes, analysis instances |
| Requirements Toolbox | Requirement sets, derivation/implementation/verification links |

MATLAB R2023a or later recommended. The FCS example was developed and tested on R2025b.

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
    └── GalacticSoup/          Intergalactic soup kitchen — complete reference example
        ├── GalacticSoup.prj   MATLAB project (open this first)
        ├── DECISIONS.md       Phase-by-phase record of approved decisions
        ├── scripts/           All build scripts (buildAll, per-phase, allocation)
        ├── requirements/      SN + SR sets, TC requirements
        ├── architecture/      F/L/P SC models, interface dicts, profile
        ├── analysis/          Roll-up analysis outputs
        └── verification/      Simulink Test artifacts
```

The `mbse-new-project` skill drives the conversation and generates scripts; it draws
on `simulink-requirements`, `mbse-architecture`, `simulink-test`, and `system-composer`
for the technical API patterns.

---

## GalacticSoup Reference Example

The GalacticSoup example shows what a completed project looks like. Open it and run:

```matlab
openProject('examples/GalacticSoup/GalacticSoup.prj')
buildAll()
```

See [OVERVIEW.md](OVERVIEW.md) for a full description of the workflow, artifacts,
and design principles, and `examples/GalacticSoup/DECISIONS.md` for the interview
record that produced this project.

---

## Traceability

```
Requirements links:
  Stakeholder Need  (StakeholderNeeds.slreqx)
      └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                        ◀─[Implement]──  Function           (Functional.slx)   mandatory
                        ◀─[Implement]──  Logical Component  (Logical.slx)      non-functional reqs
                        ◀─[Implement]──  Physical Component (Physical.slx)       hardware reqs
                        └─[Verify]─▶  TC Requirement     (TestCases.slreqx)
                                          └─[Verify]─▶  Simulink Test Case  (if behavioral model exists)

Architecture chain (allocation):
  Function  (Functional.slx)
      └─[F→L Allocate]─▶  Logical Element  (Logical.slx)
                               └─[L→P Allocate]─▶  Physical Component  (Physical.slx)
```

All links are bidirectional.
