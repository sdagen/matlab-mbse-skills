# MBSE Analysis Reference (Phase 6)

Analysis is optional — only relevant when the project needs quantitative
roll-up, trade studies, sensitivity analysis, or margin reporting. Runnable
templates live alongside this file:

- `code/myRollupAnalysis.m` — analysis function template (sum + min + mean blocks)
- `code/runMyAnalysis.m` — driver skeleton (instantiate → iterate → report → save)

**File placement.** The analysis function file (e.g. `myRollupAnalysis.m`) belongs in
the project's `analysis/` folder, not `scripts/`. It's an analysis artifact (consumed
by the driver and persisted alongside the `.mat` output), not a phase build step. The
project path includes `analysis/`, so the function resolves by name. The driver
script itself (`runAnalysis.m`) stays in `scripts/` like the other build steps.

---

## The canonical roll-up pattern: analysis function + iterate(PostOrder)

Always prefer this pattern over flat-loop aggregation in MATLAB. It matches
the MathWorks `CostAndWeightRollupAnalysis` example and writes rolled-up
values to **every** parent in the hierarchy, so the Analysis / Instance
Viewer is useful at every level — not just at the top.

The analysis function is a single file, one per model, with the fixed
signature `function myRollupAnalysis(instance, varargin)` containing one
block per aggregated property. The driver invokes it via:

```matlab
instance = instantiate(arch, profileName, 'MyAnalysis');
iterate(instance, 'PostOrder', @myRollupAnalysis);
```

`'PostOrder'` visits **children before parents** — that is what makes the
roll-up work.

See `code/myRollupAnalysis.m` and `code/runMyAnalysis.m` for the full
templates; the notes below explain the non-obvious parts.

---

## The three-part guard

Every block in the analysis function starts with the same guard:

```matlab
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('MyProfile.Stereotype.prop')
```

Each check is load-bearing:

- `isComponent()` — skip ports, connectors, and the root architecture
  element (they don't have the same property surface)
- `~isempty(Components)` — skip leaves; their estimates come from profile
  defaults and should not be overwritten
- `hasValue(path)` — skip components whose stereotype doesn't include this
  property

Also guard each child read with `child.hasValue(path)` — a child can be
missing the stereotype even when the parent has it.

---

## What PostOrder overwriting implies about the design model

PostOrder **overwrites** a parent's profile estimate with the sum (or min,
mean, …) of its children. If the children are an incomplete breakdown of the
parent — e.g. a `CookingStation` decomposed into `Pot`, `Stirrer`, `Heater`
while the station also contains unmodelled chassis/plumbing/wiring — the
rolled-up total will be **lower** than the parent's original estimate.

Treat this as a signal, not a bug. Either complete the decomposition, add a
"balance" sub-part, or deliberately leave the parent a leaf by giving it no
subcomponents. Do **not** try to protect the parent estimate by skipping
aggregation — that defeats the purpose.

---

## API notes

- `getValue(instance, 'Profile.Stereotype.prop')` returns a **double**. No
  `str2double` wrapper needed (differs from `getPropertyValue` on the design
  model).
- `setValue(...)` writes into the analysis instance only — the design model
  is unchanged.
- Save the instance to `analysis/`, not `architecture/`. `save(instance, path)`
  writes a `.mat`; the Analysis Viewer opens by instance **name**, not file
  path: `systemcomposer.analysis.openViewer('MyAnalysis')`.

---

## Declaring computed properties on the stereotype

For pure roll-ups over an existing property (mass, power, …) no extra
declaration is needed — the analysis just overwrites the parent's value.
For **derived** values (computed margin, figure of merit, utilization ratio)
add a separate property in the build script so the Analysis Viewer can show
it:

```matlab
addProperty(st, 'power',          Type="double", Units="W", DefaultValue="0");
addProperty(st, 'computedMargin', Type="double", Units="W", DefaultValue="0");
```

---

## Caps belong in requirements, not the analysis script

Store system-level limits in the requirements set:

```
SR-SYS-010: "The system shall not exceed 35 kg total mass."
SR-SYS-011: "The system shall not exceed 450 W total power consumption."
```

The `parseBudgetValue` helper in `code/runMyAnalysis.m` reads these
automatically using the phrase **"not exceed X \<unit\>"**. As long as
requirements follow that pattern, the script stays in sync.

---

## Common analysis types

| Type | Approach |
|---|---|
| Hierarchical roll-up | Analysis function + `iterate(..., 'PostOrder', @fn)` — the primary pattern here |
| Per-component margin | Derived-property block in the analysis function; `setValue(margin, cap_i - estimate_i)` per leaf |
| Sensitivity | Call `instantiate` in a loop with varied estimates; replot system-level margin |
| Design alternatives | Two `instantiate` calls with different property sets; compare `.mat` outputs |
| Pareto / scatter | Read arrays of per-component values in one pass, `plot(mass, power)` |
| Monte Carlo | Perturb leaf estimates with `randn` across iterations; histogram the rolled-up top-level value |

---

## When *not* to use the analysis-function pattern

Bypass it only when the computation doesn't fit a child→parent aggregation:
cross-component constraints (e.g. "port A's datarate must be ≥ port B's"),
graph traversals, or analyses that need all leaf values at once (Monte Carlo,
Pareto plots). In those cases, either iterate with a custom visitor that
collects into arrays, or do a PostOrder pass to roll up what can be rolled
up, then a flat pass for the cross-cutting logic.
