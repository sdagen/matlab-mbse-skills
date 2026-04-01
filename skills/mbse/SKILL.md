---
name: mbse
description: >
  Use this skill when the user mentions MBSE, model-based systems engineering, or wants a
  structured engineering process in MATLAB — from requirements through architecture,
  traceability, trade studies, and verification. Also trigger when the user asks about
  connecting requirements to an architecture model, setting up traceability, or planning
  a systems engineering workflow. Invoke this skill first to orient the workflow, then hand
  off to the appropriate mbse-* phase skill. Use this skill proactively whenever the user
  is starting a new system design and has not yet asked about requirements or architecture.
---

# MATLAB MBSE Workflow

MBSE in MATLAB spans Requirements Toolbox (`slreq`) and System Composer
(`systemcomposer`). This skill orients the workflow and directs you to the
right phase skill for each step.

---

## Workflow Overview

```
Phase 1  Stakeholder Needs           SN-SYS-xxx   informal, operational perspective
           |  (derives)
Phase 2  System Requirements         SR-SYS-xxx   formal shall-statements, testable
           |  (informs)
Phase 3a Physical Architecture       MySystem.slx  components + interfaces + budget profile
Phase 3b Functional Architecture     MyFunctional.slx  logical functions, same interface dict
           |  (allocated via)
Phase 4  Functional→Physical         MyAllocation.mldatx  allocation set, one scenario
           Allocation Set
           |  (refines)
Phase 5  Requirements Allocation     SR --> Component Refine links, bidirectional
           |  (quantifies)
Phase 6  Trade Studies               roll-up budgets from stereotype properties
           |  (verifies)
Phase 7  Verification                test cases TC-SYS-xxx linked to SRs
```

The functional architecture tier (3b + 4) implements the ARP4754A requirement
for an explicit functional–physical traceability layer. It uses a separate System
Composer model and a System Composer allocation set — distinct from the
requirements `Refine` links in Phase 5.

---

## Phase Skills

| Phase | Skill | What it covers |
|---|---|---|
| 1–2 | `mbse-requirements` | `slreq` API, ID scheme, shall-grammar, derivation links |
| 3a–3b | `mbse-architecture` | Physical + functional SC models, profile/stereotype, allocation set |
| 4–5 | `mbse-allocation` | SC allocation set (functional→physical) + `Refine` links (SR→component) |
| 6 | `mbse-analysis` | Roll-up budgets, trade studies, margin reports, sensitivity analysis |
| 7 | `mbse-verification` | Test cases, `Verify` links, coverage report |

The `system-composer` skill covers the core System Composer API and should
be used alongside `mbse-architecture` for detailed port/connection patterns.

---

## Recommended Folder Structure

```
my-system/
├── requirements/     .slreqx files (StakeholderNeeds, SystemRequirements, TestCases)
├── architecture/     .slx, .sldd, .xml (model, dictionary, profile)
├── allocation/       buildAllocation.m
├── analyses/         rollupAnalysis.m
└── verification/     buildTestCases.m
```

---

## Key Cross-Phase Dependencies

- **Architecture rebuilds break allocation links.** `slreq.createLink` stores
  component references by Simulink SID. If you rebuild the model, SIDs change
  and allocation links become stale. Always rebuild allocation after rebuilding
  the architecture model.

- **Profile setup belongs in the architecture script**, not in a separate
  analysis script. Create and apply the profile at the end of
  `buildMySystemModel()` so estimates travel with the model.

- **`slreq.saveAll()` saves cross-set links.** Call it after any session that
  creates links between different `.slreqx` files.

- **`slreq.clear()` unloads all sets from memory** but does not delete files.
  Call it at the top of each script for a clean slate, then `slreq.open()` the
  files you need.
