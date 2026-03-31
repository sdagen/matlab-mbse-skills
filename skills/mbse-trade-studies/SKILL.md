---
name: mbse-trade-studies
description: >
  Use this skill for MBSE trade studies and budget analyses in MATLAB System Composer —
  reading stereotype property values from components, computing roll-up budgets (power,
  mass, latency, etc.), and reporting margins against system-level caps. Trigger when the
  user wants to analyse budgets across an architecture, compare estimates to allocations,
  or produce a system-level roll-up from component-level property values.
---

# MBSE Phase 5: Trade Studies & Roll-Up Analysis

Roll-up analyses aggregate stereotype property values across components and
compare against system-level budgets. Use the `systemcomposer.analysis` API —
it gives you doubles directly (no `str2double`), lets you write computed results
back to the instance, and produces a saveable artifact for the Analysis Viewer.

---

## Core Pattern: instantiate → getValue → setValue → save

```matlab
% 1. Create analysis instance from the profile
model    = systemcomposer.openModel(fullfile(archDir, modelName));
arch     = model.Architecture;
instance = instantiate(arch, profileName, 'MyAnalysis');

% 2. Read values — returns double, not char
prefix = [profileName, '.MyStereotype.'];
for i = 1:numel(instance.Components)
    ci    = instance.Components(i);
    power = getValue(ci, [prefix, 'PowerEstimate_W']);   % double
    mass  = getValue(ci, [prefix, 'Mass_kg']);            % double
end

% 3. Write computed results back to the instance
setValue(ci, [prefix, 'PowerMargin_W'], budget - power);

% 4. Save for Analysis Viewer
save(instance, fullfile(archDir, 'MyAnalysis.mat'));
% Open with: systemcomposer.analysis.openViewer('path/to/MyAnalysis.mat')
```

Key differences from `getPropertyValue`:
- `getValue` returns **double** — no `str2double` wrapper needed
- `setValue` writes computed results (margins, roll-ups) into the instance without
  modifying the design model
- `instance.Components` iterates all components automatically — no hardcoded name list
- The saved `.mat` is loadable in the Analysis Viewer for visual inspection

---

## Adding a Computed Property to the Stereotype

For every value you intend to write back with `setValue`, declare it as a property
in the stereotype so the Analysis Viewer can display it:

```matlab
% In buildMyProfile.m — add alongside the input properties
addProperty(st, 'PowerBudget_W',   Type="double", Units="W", DefaultValue="0");
addProperty(st, 'PowerEstimate_W', Type="double", Units="W", DefaultValue="0");
addProperty(st, 'PowerMargin_W',   Type="double", Units="W", DefaultValue="0");  % computed
```

Set it to 0 at design time; the analysis script fills it in at run time via `setValue`.

---

## Roll-Up Skeleton

```matlab
function rollupAnalysis()
    reqDir  = fullfile(fileparts(mfilename('fullpath')), '..', 'requirements');
    archDir = fullfile(fileparts(mfilename('fullpath')), '..', 'architecture');
    profileName = 'MyBudget';
    modelName   = 'MySystem';

    % Read system caps from requirements (keep budget values out of the script)
    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    sysPowerCap_W = parseBudgetValue(srSet, 'SR-SYS-014', 'W');
    sysMassCap_kg = parseBudgetValue(srSet, 'SR-SYS-015', 'kg');

    % Create analysis instance
    addpath(archDir);
    model    = systemcomposer.openModel(fullfile(archDir, modelName));
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'PowerMassRollup');

    prefix = [profileName, '.BudgetProperties.'];
    nComp  = numel(instance.Components);

    names           = cell(nComp, 1);
    powerBudget_W   = zeros(nComp, 1);
    powerEstimate_W = zeros(nComp, 1);
    mass_kg         = zeros(nComp, 1);

    for i = 1:nComp
        ci = instance.Components(i);
        names{i}           = ci.Name;
        powerBudget_W(i)   = getValue(ci, [prefix, 'PowerBudget_W']);
        powerEstimate_W(i) = getValue(ci, [prefix, 'PowerEstimate_W']);
        mass_kg(i)         = getValue(ci, [prefix, 'Mass_kg']);

        % Write computed margin back to instance
        setValue(ci, [prefix, 'PowerMargin_W'], powerBudget_W(i) - powerEstimate_W(i));
    end

    % System totals vs caps
    totalPower  = sum(powerEstimate_W);
    totalMass   = sum(mass_kg);
    powerMargin = sysPowerCap_W - totalPower;
    massMargin  = sysMassCap_kg - totalMass;

    fprintf('Power: %.1f / %.1f W  (margin %.1f W)\n', totalPower, sysPowerCap_W, powerMargin);
    fprintf('Mass:  %.2f / %.2f kg (margin %.2f kg)\n', totalMass,  sysMassCap_kg,  massMargin);

    % Save instance — open with systemcomposer.analysis.openViewer()
    save(instance, fullfile(archDir, 'PowerMassRollup.mat'));
end

function value = parseBudgetValue(srSet, reqId, unit)
% Extract numeric limit from "shall not exceed X <unit>" in a requirement description.
    req = srSet.find('Id', reqId);
    tok = regexp(req.Description, ['not exceed\s+([\d.]+)\s+', unit], 'tokens', 'once');
    if isempty(tok)
        error('parseBudgetValue:noMatch', 'Cannot parse %s budget from %s.', unit, reqId);
    end
    value = str2double(tok{1});
end
```

---

## Budget Caps Belong in Requirements

Never hard-code system-level limits (power cap, mass cap, latency budget) in the
analysis script. Store them in named requirements and parse them out:

```
SR-SYS-014: "...shall not exceed 450 W."   ← power cap
SR-SYS-015: "...shall not exceed 35 kg."   ← mass cap
```

The `parseBudgetValue` helper above uses the phrase **"not exceed X \<unit\>"** as
the convention. As long as requirement descriptions follow this pattern, the script
stays in sync with the requirements automatically.

---

## Recommended Budget Properties

| Property | Type | Units | Role |
|---|---|---|---|
| `PowerBudget_W` | double | W | Allocated budget per component (design-time) |
| `PowerEstimate_W` | double | W | Current best estimate (design-time) |
| `PowerMargin_W` | double | W | Budget − Estimate (computed at analysis time) |
| `Mass_kg` | double | kg | Estimated mass incl. mounting (design-time) |
| `LatencyBudget_ms` | double | ms | For timing/latency analyses |

---

## Extending to Trade Studies

Once roll-up works, common next steps:
- **Sensitivity analysis**: vary one component estimate and replot system margin
- **Design alternatives**: compare two architecture options by swapping component budgets
- **Mass-power Pareto**: scatter plot of mass vs power per component
- **Monte Carlo margins**: perturb estimates with uncertainty bands, compute
  probability of exceeding budget

These are standard MATLAB analysis patterns applied to values read from the
instance — no additional System Composer API required beyond what is shown above.
