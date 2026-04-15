# MBSE Analysis Reference (Phase 6)

Analysis is optional — only relevant when the project needs quantitative
roll-up, trade studies, sensitivity analysis, or margin reporting. This file
covers the common `systemcomposer.analysis` API patterns.

---

## The canonical roll-up pattern: analysis function + iterate(PostOrder)

**Always prefer this pattern over manual flat-loop aggregation in MATLAB.** It
matches the MathWorks example (`CostAndWeightRollupAnalysis` in
`SimpleRollUpAnalysisExample/`) and has a big concrete benefit: rolled-up
values are written to **every** parent node in the hierarchy, so the Analysis
Viewer / Instance Viewer shows meaningful aggregated numbers at every level,
not just at the top.

### Shape of an analysis function

Put it in its own file, one function per model. Function name matches the
file name. Signature is fixed:

```matlab
function MySystemRollupAnalysis(instance, varargin)
% Analysis function for the MySystem.slx example

% Calculate total <property>
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('MyProfile.Stereotype.propertyName')
    total = 0;
    for child = instance.Components
        if child.hasValue('MyProfile.Stereotype.propertyName')
           v = child.getValue('MyProfile.Stereotype.propertyName');
           total = total + v;
        end
    end
    instance.setValue('MyProfile.Stereotype.propertyName', total);
end

% ... one such block per property to aggregate
end
```

Each block is guarded by three conditions **in this order**:
- `instance.isComponent()` — skip ports, connectors, the root architecture
  (architecture elements don't have the same property surface)
- `~isempty(instance.Components)` — skip leaves; their estimates come from
  the profile defaults and should not be overwritten
- `instance.hasValue(...)` — skip components whose stereotype doesn't
  include this property

### Invoking it

From the driver script, after `instantiate`:

```matlab
instance = instantiate(arch, profileName, 'MyAnalysis');
iterate(instance, 'PostOrder', @MySystemRollupAnalysis);
```

`'PostOrder'` visits **children before parents**, which is what makes the
rollup work: by the time the function runs on a parent, every child already
has its aggregated value set.

### Non-sum aggregations

The canonical MathWorks example shows sums only. The same guard+loop+setValue
shape works for any aggregation — just change the combiner:

```matlab
% Throughput bottleneck (min across producing children, ignoring zeros so
% controllers/sensors with throughput=0 don't short-circuit the result)
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('MyProfile.Stereotype.throughput')
    bottleneck = inf;
    for child = instance.Components
        if child.hasValue('MyProfile.Stereotype.throughput')
           v = child.getValue('MyProfile.Stereotype.throughput');
           if v > 0 && v < bottleneck, bottleneck = v; end
        end
    end
    if isfinite(bottleneck)
        instance.setValue('MyProfile.Stereotype.throughput', bottleneck);
    end
end

% Mean (e.g. automation level, utilization)
vals = [];
for child = instance.Components
    if child.hasValue(propPath)
       vals(end+1) = child.getValue(propPath); %#ok<AGROW>
    end
end
if ~isempty(vals)
    instance.setValue(propPath, mean(vals));
end
```

### What PostOrder rollup implies about the design model

PostOrder **overwrites** a parent's profile estimate with the sum (or min,
mean, …) of its children. If the children are an incomplete breakdown of the
parent (e.g. you modelled a `CookingStation` with `Pot`, `Stirrer`, and
`Heater` subcomponents, but the station also includes a chassis/plumbing/
wiring that isn't modelled), the rollup total will be **lower** than the
parent's original estimate. That discrepancy is a useful signal: either
complete the decomposition, or add a "balance" sub-part, or deliberately
treat the parent as a leaf by not giving it subcomponents at all. Do not try
to "protect" the parent estimate by skipping aggregation — that defeats the
purpose.

---

## Driver skeleton

```matlab
function runAnalysis()
    proj        = currentProject();
    reqDir      = fullfile(proj.RootFolder, 'requirements');
    archDir     = fullfile(proj.RootFolder, 'architecture');
    analysisDir = fullfile(proj.RootFolder, 'analysis');
    profileName = 'MyProfile';
    modelName   = 'MySystem';
    prefix      = [profileName, '.Stereotype.'];

    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    capPower = parseBudgetValue(srSet, 'SR-SYS-014', 'W');

    addpath(archDir);
    model    = systemcomposer.openModel(modelName);
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'MyAnalysis');

    iterate(instance, 'PostOrder', @MySystemRollupAnalysis);

    % After iterate, every parent (including the top-level architecture's
    % direct children) has aggregated values. Read them straight off.
    totPower = 0;
    for c = instance.Components
        totPower = totPower + c.getValue([prefix, 'power']);
    end

    fprintf('Total power: %.1f / %.1f W  (margin %.1f)\n', ...
        totPower, capPower, capPower - totPower);

    save(instance, fullfile(analysisDir, 'MyAnalysis.mat'));
    fprintf('Open: systemcomposer.analysis.openViewer(''MyAnalysis'')\n');
end

function value = parseBudgetValue(srSet, reqId, unit)
% Extract numeric cap from "shall not exceed X <unit>" in a requirement description.
    req = srSet.find('Id', reqId);
    tok = regexp(req.Description, ['not exceed\s+([\d.]+)\s+', unit], 'tokens', 'once');
    if isempty(tok)
        error('parseBudgetValue:noMatch', 'Cannot parse %s from %s.', unit, reqId);
    end
    value = str2double(tok{1});
end
```

---

## API notes

- `getValue(instance, 'Profile.Stereotype.prop')` returns a **double** — no
  `str2double` wrapper needed (differs from `getPropertyValue` on the design
  model)
- `setValue(...)` writes into the analysis instance only — the design model
  is unchanged
- `hasValue(...)` — **always** guard with this in the analysis function,
  because not every component necessarily has the stereotype applied
- `instance.Components` returns direct children; use `iterate` to descend
- Save the instance to `analysis/`, not `architecture/`. `save(instance, path)`
  writes a `.mat`; the Analysis Viewer opens by instance **name**, not path:
  `systemcomposer.analysis.openViewer('MyAnalysis')`

---

## Declaring computed properties on the stereotype

Any property the analysis writes with `setValue` must exist on the stereotype
(declared in `buildMyModel.m`). For pure rollups over an existing property
(mass, power, …) no extra declaration is needed — the analysis just
overwrites the parent's value. For **derived** values (computed margin, FoM,
utilization), add a separate property:

```matlab
addProperty(st, 'power',          Type="double", Units="W", DefaultValue="0");
addProperty(st, 'computedMargin', Type="double", Units="W", DefaultValue="0"); % written by analysis
```

---

## Property caps belong in requirements

Keep system-level limits in the requirements set, not in the analysis script:

```
SR-SYS-014: "The system shall not exceed 450 W total power consumption."
SR-SYS-015: "The system shall not exceed 35 kg total mass."
```

`parseBudgetValue` above reads these automatically using the phrase
**"not exceed X \<unit\>"**. As long as requirements follow this pattern, the
script stays in sync.

---

## Common analysis types

| Type | Approach |
|---|---|
| Hierarchical roll-up | Analysis function + `iterate(..., 'PostOrder', @fn)` — this file's primary pattern |
| Per-component margin | Derived-property block in the analysis function; `setValue(prop, cap_i - estimate_i)` per leaf |
| Sensitivity | Drive `instantiate` in a loop with varied estimates; replot system-level margin |
| Design alternatives | Two `instantiate` calls with different property sets; compare `.mat` outputs |
| Pareto / scatter | Read arrays of per-component values (one getValue loop), `plot(mass, power)` |
| Monte Carlo | Perturb leaf estimates with `randn` across iterations; histogram the rolled-up top-level value |

---

## When *not* to use the analysis-function pattern

Only bypass it when the computation doesn't fit a child→parent aggregation:
cross-component constraints (e.g. "port A's datarate must be ≥ port B's"),
graph traversals, or analyses that need all leaf values at once (Monte Carlo,
Pareto plots). In those cases, iterate with a custom visitor that collects
into arrays, or do one pass with `iterate(..., 'PostOrder', @fn)` to roll up
what can be rolled up, then a flat-loop pass for the cross-cutting logic.
