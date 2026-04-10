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

```
Phase 1  Stakeholder Needs           SN-SYS-xxx   informal, operational perspective
           |  (derives)
Phase 2  System Requirements         SR-SYS-xxx   formal shall-statements, testable
           |  (informs)
Phase 3a Functional Architecture     MyFunctional.slx + FunctionalInterfaces.sldd  logical functions
Phase 3b Physical Architecture       MySystem.slx + PhysicalInterfaces.sldd  components + stereotypes
           |  (allocated via)
Phase 4  Functional→Physical         MyAllocation.mldatx  allocation set
           Allocation Set
           |  (refines)
Phase 5  Requirements Allocation     SR --> Component Refine links
           |  (quantifies)
Phase 6  Analysis                    optional — roll-up, trade study, sensitivity
           |  (verifies)
Phase 7  Verification                TC requirements + Simulink Test file
```

---

## Skills by Phase

| Phase | Skill | What it covers |
|---|---|---|
| — | `mbse-new-project` | Guided end-to-end setup for a new project, folder structure, project creation |
| 1–2 | `simulink-requirements` | Requirements creation, Derive links, shall-statement rules |
| 3–4, 6 | `mbse-architecture` | Functional + physical models, two-level interface dictionaries, stereotypes, allocation, analysis |
| — | `system-composer` | Deep System Composer API reference (ports, connections, profiles) |
| 5 | `simulink-requirements` | Requirements → component Refine links |
| 6 | `mbse-architecture` | Quantitative analysis, roll-up, margins |
| 7 (TC reqs) | `simulink-requirements` | TC requirement sets, Verify links, coverage report |
| 7 (Simulink Test) | `simulink-test` | `.mldatx` test files, test suites, system under test |
| Analysis | `simulink-requirements` | Traceability analysis, link health, coverage matrices |
