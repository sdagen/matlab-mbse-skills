# MBSE Analysis Reference (Phase 6)

Analysis is optional — only relevant when the project needs quantitative
roll-up, trade studies, sensitivity analysis, or margin reporting. The type
of analysis depends on the project; this covers the common `systemcomposer.analysis`
API patterns.

---

## Core Pattern: instantiate → getValue → setValue → save

```matlab
% 1. Create analysis instance from the profile
addpath(archDir);
model    = systemcomposer.openModel(modelName);   % by name, not full path
arch     = model.Architecture;
instance = instantiate(arch, profileName, 'MyAnalysis');

% 2. Read property values — returns double, not char
prefix = [profileName, '.ComponentProperties.'];
for i = 1:numel(instance.Components)
    ci    = instance.Components(i);
    val1  = getValue(ci, [prefix, 'PropertyA']);   % double
    val2  = getValue(ci, [prefix, 'PropertyB']);
end

% 3. Write computed results back to instance (does not modify the design model)
setValue(ci, [prefix, 'ComputedMargin'], budget - val1);

% 4. Save for Analysis Viewer
save(instance, fullfile(archDir, 'MyAnalysis.mat'));
% Open: systemcomposer.analysis.openViewer('MyAnalysis')  ← instance NAME not file path
```

Key differences from `getPropertyValue`:
- `getValue` returns **double** — no `str2double` wrapper needed
- `setValue` writes into the instance only — the design model is unchanged
- `instance.Components` iterates all components — no hardcoded list needed
- The saved `.mat` is loadable in the Analysis Viewer

---

## Adding Computed Properties to the Stereotype

Declare any value you intend to write back with `setValue` as a property in
the stereotype (in `buildMyModel.m`) so the Analysis Viewer can show it:

```matlab
addProperty(st, 'PropertyA',       Type="double", Units="W",  DefaultValue="0");
addProperty(st, 'ComputedMargin',  Type="double", Units="W",  DefaultValue="0");  % computed
```

Set to 0 at design time; the analysis script fills it in at run time.

---

## Roll-Up Skeleton

```matlab
function runAnalysis()
    rootDir     = fileparts(fileparts(mfilename('fullpath')));
    reqDir      = fullfile(rootDir, 'requirements');
    archDir     = fullfile(rootDir, 'architecture');
    profileName = 'MySystemProfile';
    modelName   = 'MySystem';

    % Read system-level caps from requirements — keeps limits out of the script
    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    cap = parseBudgetValue(srSet, 'SR-SYS-014', 'W');

    addpath(archDir);
    model    = systemcomposer.openModel(modelName);
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'MyAnalysis');

    prefix  = [profileName, '.ComponentProperties.'];
    nComp   = numel(instance.Components);
    names   = cell(nComp, 1);
    values  = zeros(nComp, 1);

    for i = 1:nComp
        ci       = instance.Components(i);
        names{i} = ci.Name;
        values(i) = getValue(ci, [prefix, 'PropertyA']);
        setValue(ci, [prefix, 'ComputedMargin'], cap/nComp - values(i));
    end

    total  = sum(values);
    margin = cap - total;
    fprintf('Total: %.1f / %.1f  (margin %.1f)\n', total, cap, margin);

    save(instance, fullfile(archDir, 'MyAnalysis.mat'));
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

## Property Cap Conventions

Store system-level limits in requirements, not in the analysis script:

```
SR-SYS-014: "The system shall not exceed 450 W total power consumption."
SR-SYS-015: "The system shall not exceed 35 kg total mass."
```

The `parseBudgetValue` helper above reads these automatically using the phrase
**"not exceed X \<unit\>"**. As long as requirements follow this pattern, the
script stays in sync with the requirements.

---

## Common Analysis Types

| Type | Approach |
|---|---|
| Roll-up sum | `sum(values)` vs. system cap from requirements |
| Per-component margin | `budget_i - estimate_i`, written back via `setValue` |
| Sensitivity | Vary one estimate, replot system-level margin |
| Design alternatives | Two instantiations with different property sets |
| Pareto / scatter | `plot(mass_kg, power_W)` from values array |
| Monte Carlo | Perturb estimates array with `randn`, compute `sum` distribution |
