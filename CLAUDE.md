# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Claude **skills** (not runnable code) plus a worked MATLAB example for Model-Based Systems Engineering (MBSE). There is no build system, no test runner, no package manifest — the skills are markdown instructions Claude loads to drive MATLAB/System Composer/Requirements Toolbox through the user's installed MATLAB (via the `simulink` MCP server — tool names are `mcp__simulink__*`).

**Prerequisites:** System Composer and Requirements Toolbox. Skills target an R2023a baseline — do not propose APIs introduced after the user's release. The GalacticSoup example was developed and tested on R2025b.

See [OVERVIEW.md](OVERVIEW.md) for the full workflow description, phase-by-phase artifact breakdown, and design rationale.

## Primary entry point

When a user wants to start a new MBSE project, the `mbse-new-project` skill drives a conversational, phase-by-phase guided workflow (interview → propose → approve → generate script → run via MATLAB MCP → confirm). It draws on the other skills for API patterns. Do not skip ahead; each phase waits for user approval before generating the next script.

New projects get a `plan.md` and `decisions.md` at the project root, created by `mbse-new-project` and kept up to date as the workflow progresses. Read them first when resuming work on an in-progress project, and update them as decisions are made.

## Repository layout

```
skills/
  mbse-new-project/   Guided end-to-end workflow — the conversation driver
  mbse/               Thin index mapping workflow phases to other skills
  mbse-architecture/  F/L/P models, interface dictionaries, stereotype profiles, allocation sets, architecture views, roll-up analysis
  simulink-requirements/  slreq API — req sets, Derive/Implement/Verify links, traceability
  simulink-test/      Tier 2 verification — authoring Simulink Test .mldatx files linked to TC requirements
  system-composer/    Deep System Composer API reference
examples/GalacticSoup/  Intergalactic soup kitchen reference project (open GalacticSoup.prj)
```

Each skill is a `SKILL.md` (plus sometimes a `code/` folder with reference scripts). Read the relevant `SKILL.md` before writing MATLAB that uses those APIs.

## Architecture model (RFLPV workflow)

The whole repo is organized around this traceability chain — understand it before editing skills or examples:

```
StakeholderNeed ─Derive─▶ SystemRequirement
                            ◀─Implement── Function          (Functional.slx)
                            ◀─Implement── LogicalComponent  (Logical.slx)
                            ◀─Implement── PhysicalComponent (Physical.slx)
                            └─Verify─▶ TC Requirement ─Verify─▶ Simulink Test Case

Function ─F→L Allocate─▶ LogicalElement ─L→P Allocate─▶ PhysicalComponent
```

Three separate architecture models (F/L/P), two allocation sets (F→L, L→P). Architecture→SR Implement links are created **immediately after each architecture phase**, not deferred — this is a deliberate design decision (see the "Note on requirements allocation" in `OVERVIEW.md`) so traceability is reviewable layer by layer.

## Running the GalacticSoup example

```matlab
openProject('examples/GalacticSoup/GalacticSoup.prj')
buildAll()    % rebuilds every artifact idempotently from scratch
```

Claude runs these through the `simulink` MCP server (the user's MATLAB desktop is visible; figures appear there). Phase scripts in `examples/GalacticSoup/scripts/` are all idempotent and rerunnable independently:

- `buildRequirements.m` — stakeholder needs + system requirements
- `buildFunctional.m` / `buildLogical.m` / `buildPhysical.m` — the three F/L/P architecture models
- `buildFunctionalAllocation.m` / `buildLogicalAllocation.m` / `buildPhysicalAllocation.m` — arch → SR Implement links (one per architecture phase, run immediately after it)
- `removeImplementLinksToModel.m` — shared helper the three allocation scripts call; scopes link cleanup to a single model so the scripts can re-run in any order without wiping each other out
- `buildFunctionalToLogical.m` / `buildLogicalToPhysical.m` — the two cross-layer allocation sets
- `buildTestCases.m`, `runAnalysis.m`, `registerWithProject.m` — verification, roll-up analysis, project registration
- `exportRequirements.m` — YAML/markdown export of requirement sets for review outside MATLAB

`examples/GalacticSoup/DECISIONS.md` records the phase-by-phase decisions from the interview that produced the project.

## MATLAB conventions

User's global MATLAB coding standards, performance rules, and plain-text Live Script format apply (loaded via `~/.claude/CLAUDE.md`). Generated build scripts must be idempotent — re-running must not duplicate requirements, links, components, or allocations. Use `slreq.*` / `systemcomposer.*` "find or create" patterns rather than unconditional adds.

## Memory

Notable auto-memory: `feedback_slreq_traceability.md` contains verified slreq link-analysis API patterns and corrections to common mistakes — consult it before writing new traceability code.
