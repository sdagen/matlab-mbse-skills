# MATLAB MBSE Skills

A collection of Claude skills for Model-Based Systems Engineering in MATLAB — from stakeholder needs through verified test cases, with full bidirectional traceability.

---

## The RFLP Workflow

MBSE projects in this suite follow the RFLP methodology, with Verification as the closing step:

```
R — Requirements   Stakeholder Needs → System Requirements (.slreqx)
F — Functional     What the system does — functions + abstract flows
L — Logical        What kind of element solves each function — design-agnostic principles
P — Physical       How it is built — concrete components, interfaces, stereotypes
                   ──────────────────────────────────────────────────
V — Verification   TC requirements (.slreqx) — testable shall-statements
                   linked to System Requirements via Verify links
```

Each layer implements or is allocated to the layer above; traceability links run back up. The **Logical** layer is the key addition over classic RFLP — design-agnostic solution principles (e.g., `SensingUnit`, `ControlUnit`) that sit between what the system *does* and how it is *built*.

---

## Getting Started

Tell Claude what you want to build:

> *"I want to set up a new MBSE project for a [your system]"*

The `mbse-new-project` skill interviews you, then walks through each phase one at a time — proposing content, waiting for approval, generating the build script, running it, and only moving on once you confirm. The interview covers engineering concerns *and* the review views you'll want on the architecture: the two answers jointly shape the component stereotype (you can only filter views on properties you put on the stereotype). The result is a runnable MATLAB project with idempotent scripts and a single `buildAll()` entry point that rebuilds everything from scratch.

---

## Prerequisites

| Toolbox | Used for |
|---|---|
| System Composer | Architecture modeling, profiles, stereotypes, analysis instances |
| Requirements Toolbox | Requirement sets; Derive / Implement / Verify links |

MATLAB R2023a or later recommended.

---

## Skills

| Skill | Role |
|---|---|
| `matlab-project` | MATLAB Project foundation — `.prj` setup, file tracking, path/health rules, build-script conventions |
| `mbse-new-project` | Orchestrator — interview, propose, generate, run, confirm. Builds on `matlab-project` |
| `mbse` | Workflow index — which skill covers which phase |
| `mbse-architecture` | F/L/P models, interface dictionaries, stereotypes, allocation sets, roll-up analysis, review-dashboard views |
| `simulink-requirements` | slreq API — creation, links, traceability, coverage (incl. TC requirements) |
| `system-composer` | System Composer API reference — ports, connections, profiles, gotchas |

`mbse-new-project` drives the conversation; the others provide the API patterns it draws on. `matlab-project` is reusable for any MATLAB Project work, MBSE or otherwise.

---

## Repository Structure

```
matlab-mbse-skills/
└── skills/
    ├── matlab-project/        MATLAB Project foundation (.prj, tracking, health)
    ├── mbse-new-project/      Guided end-to-end setup (start here)
    ├── mbse/                  Workflow index
    ├── mbse-architecture/     Architecture, allocation, analysis
    ├── simulink-requirements/ slreq API — requirements and traceability
    └── system-composer/       System Composer API reference
```

---

## Traceability

```
Requirements links:
  Stakeholder Need  (StakeholderNeeds.slreqx)
      └─[Derive]─▶  System Requirement  (SystemRequirements.slreqx)
                        ◀─[Implement]──  Function           (Functional.slx)   mandatory
                        ◀─[Implement]──  Logical Component  (Logical.slx)      non-functional reqs
                        ◀─[Implement]──  Physical Component (Physical.slx)     hardware reqs
                        └─[Verify]─▶  TC Requirement     (TestCases.slreqx)

Architecture chain (allocation):
  Function  (Functional.slx)
      └─[F→L Allocate]─▶  Logical Element  (Logical.slx)
                               └─[L→P Allocate]─▶  Physical Component  (Physical.slx)
```

All links are bidirectional.
