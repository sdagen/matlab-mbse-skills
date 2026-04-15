---
name: mbse
description: >
  Use this skill when the user mentions MBSE, model-based systems engineering, or wants
  a high-level overview of the MATLAB MBSE workflow. Also trigger when the user asks
  which skill covers which phase, or wants to understand how the MBSE skills fit together.
  For hands-on work at any specific phase, delegate to the appropriate phase skill below.
---

# MATLAB MBSE Workflow — Index

MBSE in MATLAB spans Requirements Toolbox (`slreq`) and System Composer
(`systemcomposer`). This skill is a thin index. For hands-on work at any phase,
use the skill listed in the table below.

---

## Workflow Overview

Based on the RFLPV approach (Requirements, Functions, Logical, Physical, Verification).
The Logical layer is the key addition over classic RFLP — it captures design-agnostic
solution principles between what the system *does* (F) and how it is *built* (P).

```
Phase 1   Stakeholder Needs           SN-SYS-xxx   informal, operational perspective
            |  (derives)
Phase 2   System Requirements         SR-SYS-xxx   formal shall-statements, testable
            |  (informs)
Phase 3   Functional Architecture     MyFunctional.slx + FunctionalInterfaces.sldd
            |  what the system does — solution-neutral functions and flows
            |  (solved by)
Phase 4   Logical Architecture        MyLogical.slx + LogicalInterfaces.sldd
            |  design-agnostic solution principles — SensingUnit, ControlUnit, etc.
            |  (implemented by)
Phase 5   Physical Architecture       MyPhysical.slx + PhysicalInterfaces.sldd
            |  concrete hardware/software components with stereotype properties
            |  (allocated via)
Phase 6   F→L Allocation Set          MyFunctionalToLogical.mldatx
Phase 7   L→P Allocation Set          MyLogicalToPhysical.mldatx
            |  (implemented by)
Phase 8   Requirements Allocation     Function→SR (mandatory), Logical→SR, Physical→SR Implement links
            |  (quantifies)
Phase 9   Analysis                    optional — roll-up, trade study, sensitivity
            |  (verifies)
Phase 10  Verification                TC requirements + Simulink Test file
```

---

## Skills by Phase

| Phase | Skill | What it covers |
|---|---|---|
| — | `mbse-new-project` | Guided end-to-end setup for a new project, folder structure, project creation |
| 1–2 | `simulink-requirements` | Requirements creation, Derive links, shall-statement rules |
| 3–5 | `mbse-architecture` | Functional, logical, and physical models; three-level interface dictionaries; stereotypes |
| — | `system-composer` | Deep System Composer API reference (ports, connections, profiles) |
| 6–7 | `mbse-architecture` | F→L and L→P allocation sets |
| 8 | `mbse-architecture` | Requirements → component Implement links (L or P level) |
| 9 | `mbse-architecture` | Quantitative analysis, roll-up, margins |
| 10 (TC reqs) | `simulink-requirements` | TC requirement sets, Verify links, coverage report |
| 10 (Simulink Test) | `simulink-test` | `.mldatx` test files, test suites, system under test |
| Analysis | `simulink-requirements` | Traceability analysis, link health, coverage matrices |
