# GalacticSoup — MBSE Project Decisions Log

Running log of approved decisions during guided MBSE project setup.

## Phase 0 — Interview (approved)

- **System name:** GalacticSoup
- **Project location:** `examples/GalacticSoup` (within the matlab-mbse-skills repo)
- **Description:** Intergalactic industrial kitchen that cooks, packages, and ships up to 8 soup varieties across the galaxy. Staffed by only 5 beings, so heavy automation is required.
- **Major subsystems (6):**
  - `IngredientStorage` — cold/dry storage, inventory tracking, dispensing
  - `CookingStation` — pots/kettles, heating, stirring, recipe execution (8 recipes)
  - `QualityControl` — taste/temperature/contamination sensing, batch sign-off
  - `PackagingLine` — containers, sealing, labeling by destination
  - `ShippingBay` — routing, manifest generation, loading onto transports
  - `ControlSystem` — orchestration + operator HMI for the 5 beings
- **Stereotype properties:** `mass` (kg), `volume` (m³), `power` (kW), `cost` (credits), `throughput` (bowls/hour), `automationLevel` (0–1)
- **Analysis needs:** mass/power/cost roll-ups, throughput vs demand, staffing check (`sum((1 - automationLevel) * operatorHours)` ≤ 5 beings)
- **Simulink simulation model:** none → Phase 10 (Tier 2) skipped

## Phase 1 — Requirements (approved, built)

- 8 Stakeholder Needs (`SN-GS-001` … `SN-GS-008`), incl. SN-008 gravity range
- 16 System Requirements (`SR-GS-001` … `SR-GS-016`), each with a Derive link to its parent SN
- 16 Derive links total
- Budget caps (drive Phase 7 analysis): SR-011 mass ≤ 15000 kg · SR-012 power ≤ 500 kW · SR-013 cost ≤ 2,000,000 credits · SR-014 volume ≤ 400 m³
- Gravity: SR-015 operating range 0.1 g – 12 g · SR-016 structural 12 g with FoS ≥ 1.5
- Artifacts: `requirements/StakeholderNeeds.slreqx`, `requirements/SystemRequirements.slreqx`

## Phase 2 — Functional architecture (approved, built)

- **11 functions:** StoreIngredients, DispenseIngredients, ProcessProduce, PortionIngredients, CookSoup, InspectQuality, PackageSoup, ShipSoup, TrackInventory, MonitorEnvironment, OrchestrateOperations
- **11 interfaces** (abstract, no physical units): RecipeCommand, RawIngredients, PreparedProduce, PortionedIngredients, CookedSoup, InspectedSoup, PackagedBatch, Manifest, InventoryState, EnvironmentState, SystemStatus
- **23 connections**; **32 Function → SR Implement links** (every SR covered, no orphan functions)
- Added `ProcessProduce` and `PortionIngredients` at user's request (chopping + weighing; gravity-sensitive)
- Artifacts: `architecture/GalacticSoupFunctional.slx`, `GalacticSoupFunctionalInterfaces.sldd`
- Shared helper: `scripts/removeImplementLinksToModel.m` (used by all three per-phase allocation scripts)
- **Note:** `connect(arch, src, dst)` silently dispatches to Control System Toolbox — always use `connect(src, dst)`. The port returned from `addPort(comp.Architecture,…)` is the inside-boundary port; for external `connect()`, use the outside-facing port via `comp.getPort(name)`.

## Phase 2b — CookSoup decomposition (user request)

Added one more level of decomposition inside `CookSoup` (functional) and mirrored inside `CookingUnit` (logical):

| Functional sub-fn | Logical sub-role |
|---|---|
| `ApplyHeat` | `HeatingElement` |
| `ControlHeating` | `HeatingController` |
| `StirContents` | `StirringMechanism` |
| `ExecuteRecipe` | `RecipeExecutor` |

4 new interfaces for internal wiring: `HeatSetpoint`, `StirCommand`, `HeatCommand`, `Temperature`. SR-001/002 retargeted to `ExecuteRecipe`, SR-008 to `ControlHeating`, SR-015 split to `StirContents`/`ControlHeating`. 33 Function → SR Implement links after retargeting.

## Phase 3 — Logical architecture (approved, built)

- **11 logical components:** StorageUnit, DispensingUnit, PrepProcessor, PortioningUnit, CookingUnit (decomposed), QualitySensingUnit, PackagingUnit, ShippingUnit, InventoryTracker, EnvironmentSensor, ControlUnit
- **15 interfaces** (mirrors functional + 4 CookingUnit internals; with some extra typed fields at this level — `priority`, `quantities`, `cutSize`, `masses`, `temperature`, `contamLevel`, `sealStatus`, `carrier`, `reorderFlags`, `humidity`, `alarms`, `operatorLoad`)
- **23 top-level connections + 9 inner** inside CookingUnit
- **21 Logical → SR Implement links** covering non-functional/performance/role-specific (SR-002, 003, 004, 006, 007, 008, 010, 015)
- Artifacts: `architecture/GalacticSoupLogical.slx`, `GalacticSoupLogicalInterfaces.sldd`

## Phase 4 — Physical architecture + profile (approved, built)

- **11 top-level physical components:** CryoPantry, AugerDispenser, RoboPrepStation, PrecisionScale, CookingStation (decomposed), QualitySensorSuite, SealingLine, LoaderArm, InventoryDB, GravityIMU, KitchenController
- **CookingStation sub-parts (4):** InductionHeater (ApplyHeat), ThermalPID (ControlHeating), MagneticStirrer (StirContents), KitchenPLC (ExecuteRecipe)
- **15 physical interfaces** (same shape as logical)
- **23 top-level + 9 inner connections**
- **Profile `GalacticSoupProfile`** with stereotype `ComponentProperties` (mass kg, volume m³, power kW, cost credits, throughput bowls/hour, automationLevel 0–1) applied to all 11 top-level components with initial estimates
- **Roll-ups vs budgets:** mass 13 300 / 15 000 kg ✓ · volume 211.2 / 400 m³ ✓ · power 449.5 / 500 kW ✓ · cost 1 720 000 / 2 000 000 cr ✓ · throughput bottleneck 220 / 200 bowls/h ✓ · avg automation 0.91 / 0.80 ✓
- **65 Physical → SR Implement links** (budget caps SR-011..014 + structural SR-016 mapped to every top-level component since each contributes to the roll-up)
- Artifacts: `architecture/GalacticSoupPhysical.slx`, `GalacticSoupPhysicalInterfaces.sldd`, `GalacticSoupProfile.xml`
- **Note:** `profile.save()` requires a char path, not a string — wrap `archDir` with `char()`.

## Phase 5 — F→L allocation (built)

- 15 allocations: 11 top-level (function → logical role) + 4 inside CookSoup → CookingUnit
- Artifact: `architecture/GalacticSoupFunctionalToLogical.mldatx`
- **Gotcha:** `[stringVal, 'Suffix']` creates a string *array*, not a char concatenation. `char()` the string first, then `[charVal, 'Suffix']` yields a char vector. Bit me in `createAllocationSet` — set name arg silently became a 2-element string array and the internal catalog rejected it with a confusing "no matching signature" error.

## Phase 6 — L→P allocation (built)

- 15 allocations: 11 top-level + 4 sub
- Artifact: `architecture/GalacticSoupLogicalToPhysical.mldatx`

## Phase 7 — Analysis (built, all metrics passing)

- Budget caps parsed at runtime from SR-GS-011..014 descriptions (regex `not exceed (\d+) <unit>`)
- Throughput bottleneck = min across stages with non-zero throughput
- Staffing proxy: `sum(1 - automationLevel)` = 0.97 crew-equivalents if all stations run full manual (budget 5)
- All 7 metrics PASS with initial estimates (mass, volume, power, cost, throughput, automation avg, crew-equiv)
- Artifact: `analysis/GalacticSoupAnalysis.mat` (open with `systemcomposer.analysis.openViewer('GalacticSoupAnalysis')`)

## Phase 8 — Test cases (built)

- 12 TCs with Verify links to their SRs; 4 budget-cap SRs (011..014) intentionally not covered (verified by `runAnalysis`)
- Artifact: `requirements/TestCases.slreqx`
- **Gotcha:** SR's `.slmx` link file auto-loads a stale `TestCases` set, causing `slreq.new` to fail with "name conflict". Fix: after `slreq.load(srFile)`, find and `close()` any existing `TestCases` ReqSet before creating the new one. `slreq.find` requires `'Type','ReqSet'` as first name-value pair.

## Phase 9 — buildAll + final summary (built, all green)

- `scripts/buildAll.m` rebuilds everything in 57 s; all 8 project health checks PASS
- Phase 10 (Simulink Test Tier 2) skipped per Phase 0 — no simulation model
- Project shortcuts added: `buildAll.m`, `GalacticSoupPhysical.slx`, `SystemRequirements.slreqx`
