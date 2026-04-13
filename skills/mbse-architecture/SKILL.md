---
name: mbse-architecture
description: >
  Use this skill for the architecture phases of an MBSE workflow in MATLAB — building
  System Composer physical and functional models, defining component stereotype properties,
  creating functional-to-physical allocation sets, allocating requirements to components,
  and running quantitative analysis on the architecture. Trigger when the user wants to
  create a System Composer model, define stereotypes or component properties, map functions
  to hardware, link requirements to components, or analyse budgets/margins across an
  architecture. Works alongside the system-composer skill for detailed SC API patterns.
---

# MBSE Architecture, Allocation & Analysis (Phases 3–6)

See the `system-composer` skill for the full System Composer API reference
(interfaces, ports, connections, auto-layout). This skill covers the
MBSE-specific decisions and patterns layered on top, plus allocation and analysis.

For analysis details see `references/analysis.md` in this skill folder.

---

## Functional vs Physical Decomposition

Before writing any code, decide whether you need one or two SC models:

- **Single model (simple systems)** — physical components only
- **Two models (recommended for ARP4754A compliance)** — separate functional and
  physical models linked by a System Composer allocation set

Two separate models is the standard MBSE approach. **Functional architecture is
designed first** — it captures *what* the system does as logical functions with
abstract interfaces, independent of any physical realization. **Physical
architecture is designed second** — it captures *how* the system is implemented
in terms of hardware/software components with concrete physical interfaces.

Each model has its own interface dictionary at the appropriate abstraction level:

| Dictionary | Abstraction level | Interface style |
|---|---|---|
| `MyFunctionalInterfaces.sldd` | Logical | Abstract flows — semantic names, minimal elements |
| `MyPhysicalInterfaces.sldd` | Implementation | Concrete types — specific fields, physical units |

The two dictionaries are independent. Neither model script depends on the other
being open.

---

### Functional architecture model (`MyFunctional.slx`) — build first

What the system *does* — logical functions and the abstract information flows
between them. Creates and owns the functional interface dictionary.

See [`code/buildMyFunctional.m`](code/buildMyFunctional.m) for the full parameterized function:

```
buildMyFunctional(modelName, dictFile, archDir)
```

---

### Physical architecture model (`MySystem.slx`) — build second

What the system *implements* — hardware/software components, physical interfaces,
and stereotype properties. Creates and owns the physical interface dictionary.

See [`code/buildMyModel.m`](code/buildMyModel.m) for the full parameterized function:

```
buildMyModel(modelName, dictFile, archDir)
```

**Key gotchas:**
- `modelName` must be a double-quoted MATLAB string so `char(modelName) + ".slx"` concatenates; single-quoted char + char does arithmetic
- `addpath(archDir)` before `createDictionary` and `createModel` — SC resolves files via MATLAB path
- `Simulink.data.dictionary.closeAll("-discard")` before creating a new dictionary — stale handles from a prior run block `createDictionary`
- Re-fetch interfaces after `dict.save()` before calling `setInterface` — handles become stale across a save
- **Before deleting a file that is tracked in a MATLAB project, call `removeFile(proj, filePath)` first.** A bare `delete()` removes the file from disk but leaves a broken reference in the project, which causes health check failures. Pattern:

```matlab
proj = currentProject();
removeFile(proj, fullfile(archDir, 'OldFile.sldd'));  % untrack first
delete(fullfile(archDir, 'OldFile.sldd'));             % then remove from disk
```

If the file no longer exists on disk (already deleted) but is still tracked, call `removeFile` without `delete`. If no project is open, `currentProject()` errors — guard with `matlab.project.rootProject()` if needed.

---

## Component Naming and Domains

Group components by domain — makes the architecture readable and informs interfaces:

```matlab
% Computation
flightComputer = addComponent(arch, 'FlightComputer');

% Sensing
sensorSuite    = addComponent(arch, 'SensorSuite');

% Actuation
actuatorSystem = addComponent(arch, 'ActuatorSystem');

% Power
powerSystem    = addComponent(arch, 'PowerSystem');
```

---

## Stereotype Properties — Set Up in the Architecture Script

Define and apply stereotypes at the **end of `buildMyModel()`** so property
estimates travel with the model and survive every rebuild.

The stereotype can capture any engineering properties relevant to the project —
mass, power, cost, reliability, latency, data rate, etc. Choose property names
and units based on what decisions the project needs to support.

**Naming:** Name the stereotype after what the component *is* or what you are
*characterizing*, not the analysis activity. Good examples: `FlightProperties`,
`HardwareProperties`, `ComponentCharacteristics`. Avoid generic names like
`BudgetProperties` — they imply the stereotype is only for budgeting, when in
practice it often carries performance, reliability, and other attributes too.

```matlab
profileName = 'MySystemProfile';
profileXml  = fullfile(archDir, [profileName, '.xml']);

systemcomposer.profile.Profile.closeAll();
profileFile = fullfile(archDir, [profileName, '.xml']);
if isfile(profileFile), delete(profileFile); end
if isfolder(profileFile), rmdir(profileFile, 's'); end   % clean up old bad saves

profile = systemcomposer.profile.Profile.createProfile(profileName);
st = addStereotype(profile, 'ComponentProperties', AppliesTo="Component");
addProperty(st, 'Mass_kg',         Type="double", Units="kg", DefaultValue="0");
addProperty(st, 'PowerEstimate_W', Type="double", Units="W",  DefaultValue="0");
addProperty(st, 'PowerBudget_W',   Type="double", Units="W",  DefaultValue="0");
addProperty(st, 'PowerMargin_W',   Type="double", Units="W",  DefaultValue="0");  % computed

% CRITICAL: pass the FOLDER, not the file path.
% profile.save(folder)      → saves <profileName>.xml into that folder  ✓
% profile.save(folder/a.xml) → creates a DIRECTORY named a.xml          ✗
profile.save(archDir);

applyProfile(model, profileName);
prefix = [profileName, '.ComponentProperties.'];   % ← char concat, not string +

%         Component        Mass_kg  PwrEstimate  PwrBudget
values = {
    'FlightComputer',   3.5,  120,  150;
    'SensorSuite',      4.0,   45,   50;
    % ...
};

for i = 1:size(values, 1)
    comp = arch.getComponent(values{i, 1});
    applyStereotype(comp, [profileName, '.ComponentProperties']);
    setProperty(comp, [prefix, 'Mass_kg'],         num2str(values{i, 2}));
    setProperty(comp, [prefix, 'PowerEstimate_W'], num2str(values{i, 3}));
    setProperty(comp, [prefix, 'PowerBudget_W'],   num2str(values{i, 4}));
end
```

### Profile path gotcha

`profile.save()` requires a **char array** path:

```matlab
profile.save([profileName, '.xml'])   % OK  — char concat
profile.save(profileName + ".xml")    % FAILS — string type not accepted
```

---

## Connectivity Verification

After building, check for unconnected ports before saving:

```matlab
for i = 1:numel(arch.Components)
    for j = 1:numel(arch.Components(i).Ports)
        if isempty(arch.Components(i).Ports(j).Connectors)
            fprintf('Unconnected: %s.%s\n', ...
                arch.Components(i).Name, arch.Components(i).Ports(j).Name);
        end
    end
end
```

Rebuilding the model invalidates allocation links — always re-run allocation
scripts after rebuilding the architecture.

---

# Allocation (Phases 4–5)

Two distinct allocation steps:

| Phase | What | API |
|---|---|---|
| 4 | Functional → Physical allocation set | `systemcomposer.allocation` |
| 5 | Requirements → Component Refine links | `slreq.createLink` |

---

## Phase 4: Functional-to-Physical Allocation Set

See [`code/buildAllocationSet.m`](code/buildAllocationSet.m) for the full parameterized function.
The allocation set name is derived automatically by appending `'Set'` to the file base name,
ensuring it differs from the file name (required to avoid a "name must be unique" save error):

```
buildAllocationSet(allocFile, funcModelName, physModelName, archDir)
```

### Query allocations

```matlab
allocatedTo = getAllocatedTo(scenario, funcArch.getComponent('FunctionA'));
for i = 1:numel(allocatedTo), fprintf('%s\n', allocatedTo(i).Name); end
```

### Open the Allocation Editor

```matlab
systemcomposer.allocation.editor('path/to/MyAllocation.mldatx')
```

---

## Phase 5: Requirements → Component Refine Links

`Refine` links map system requirements to the physical architecture components
responsible for satisfying them. This is distinct from the functional→physical
allocation set (Phase 4, `systemcomposer.allocation`) — Refine links live in the
requirements toolbox and are queryable via `slreq`.

See [`code/buildAllocation.m`](code/buildAllocation.m) for the full parameterized function:

```
buildAllocation(reqDir, archDir)
```

Never use `'..'` in paths passed to System Composer — use `fileparts` twice to get the
project root, then `addpath` before opening the model by name (shown above).

---

# Analysis (Phase 6)

Analysis is optional and project-specific. Read `references/analysis.md` in
this skill folder when the user needs to set up quantitative analysis
(roll-up, trade study, sensitivity, margins).
