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

For analysis details see `references/analysis.md` (prose) plus
`code/myRollupAnalysis.m` and `code/runMyAnalysis.m` (templates).

---

## Three-Model Architecture (RFLPV)

The MBSE workflow uses three separate System Composer models, one per layer:

| Model | Layer | Answers | Interface style |
|---|---|---|---|
| `MyFunctional.slx` | F — Functions | What does the system *do*? | Abstract flows, solution-neutral |
| `MyLogical.slx` | L — Logical | What *kind* of element solves it? | Typed signals, design-agnostic |
| `MyPhysical.slx` | P — Physical | *How* is it built? | Concrete fields, physical units |

Each model has its own interface dictionary at the appropriate abstraction level.
All three dictionaries are independent — no model script depends on another being open.

**Build order: Functional first, Logical second, Physical third.**

The Logical layer is the key distinction from classic RFLP. Logical components are
design-agnostic solution principles (e.g., `SensingUnit`, `ControlUnit`, `ActuationUnit`)
— they commit to *what kind* of element is needed without specifying vendor, geometry,
or implementation. Physical components are the actual realization.

---

### Functional architecture model (`MyFunctional.slx`) — build first

What the system *does* — logical functions and the abstract information flows
between them. Creates and owns the functional interface dictionary.

See [`code/buildMyFunctional.m`](code/buildMyFunctional.m) for the full parameterized function:

```
buildMyFunctional(modelName, dictFile, archDir)
```

---

### Logical architecture model (`MyLogical.slx`) — build second

What kind of element solves each function — solution principles without physical
commitment. Creates and owns the logical interface dictionary.

See [`code/buildMyLogical.m`](code/buildMyLogical.m) for the full parameterized function:

```
buildMyLogical(modelName, dictFile, archDir)
```

**Naming guidance for logical components:** Use nouns that describe the *role* of the
solution element, not the specific hardware. Good: `SensingUnit`, `ControlUnit`,
`ActuationUnit`, `PowerConverter`. Avoid hardware brand names or part numbers — those
belong in the Physical layer.

**Interface guidance:** Logical interfaces sit between functional (abstract flows) and
physical (hardware-spec signals). Include typed fields with semantic meaning but without
datasheet-level specifics — no voltage ranges, baud rates, or tolerance values.

---

### Physical architecture model (`MyPhysical.slx`) — build third

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

# Allocation (Phases 6–8)

Three distinct allocation steps:

| Phase | What | API |
|---|---|---|
| 6 | Functional → Logical allocation set | `systemcomposer.allocation` |
| 7 | Logical → Physical allocation set | `systemcomposer.allocation` |
| 8 | Requirements → Component Implement links | `slreq.createLink` |

---

## Phase 6: Functional-to-Logical Allocation Set

Maps each logical function to the logical element(s) that realize it.

See [`code/buildAllocationSet.m`](code/buildAllocationSet.m). The allocation set name is
derived automatically by appending `'Set'` to the file base name:

```
buildAllocationSet(allocFile, funcModelName, logicalModelName, archDir)
```

**Reuse the default scenario; do not call `createScenario`.** `createAllocationSet`
auto-creates a default scenario named `"Scenario 1"`. If you call `createScenario`
on top of that, you get a *second* scenario and the Allocation Editor opens to the
empty default — making it look like nothing is allocated. Instead: rename
`allocSet.Scenarios(1)` and populate it.

---

## Phase 7: Logical-to-Physical Allocation Set

Maps each logical element to the physical component(s) that implement it.
Uses the same function — just pass the logical and physical model names:

```
buildAllocationSet(allocFile, logicalModelName, physModelName, archDir)
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

## Phase 8: Architecture → Requirements Implement Links

`Implement` links connect architecture artifacts to the system requirements they
realize ("requirement → implemented by → architectural element"). Per slreq convention
the link source is the **architecture element** and the destination is the **requirement**:

```matlab
lnk      = slreq.createLink(component, req);   % source = component, destination = requirement
lnk.Type = 'Implement';
```

From the requirement's perspective these are `inLinks()`, not outLinks. The cleanup
helper for idempotent rebuilds iterates `req.inLinks()` and filters by source artifact.

**Register the link-store file with the project.** The first time slreq creates a link
into a model, it auto-generates `{modelName}~mdl.slmx` next to the `.slx` to store the
link data. Every allocation script must register this file with the project (alongside
the `.slx`), or project checks will fail and the traceability won't travel with the
project.

This is distinct from the allocation sets (Phases 6–7, `systemcomposer.allocation`) —
Implement links live in the requirements toolbox and are queryable via `slreq`.

`Refine` links remain a valid slreq link type, but are reserved for refining a
requirement into more specific requirements (same artifact kind, more detail). Do **not**
use Refine for requirement → architecture in this workflow.

Three sets of Implement links are created, in order:

**SR → Function (mandatory):** Every SR must trace to at least one function in the
functional architecture. This closes the loop between requirements and the functional
decomposition — if a function has no SRs pointing to it, it is either orphaned or
covering an undocumented need.

**SR → Logical component:** Use when the requirement is non-functional (timing,
performance, safety, security) or is specific to a logical solution role.

**SR → Physical component:** Use when the requirement is hardware-specific
(connector type, EMC rating, operating temperature range, packaging envelope,
installation constraints).

One SR may link to a function *and* a logical *and* a physical component. Each link
type answers a different question: what does the system do (F), what kind of element
owns it (L), what hardware implements it (P).

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

**Default pattern for roll-ups:** write a dedicated analysis function
(`MySystemRollupAnalysis.m`, one file per model, signature
`function fn(instance, varargin)`) matching the MathWorks
`CostAndWeightRollupAnalysis` shape, and drive it with
`iterate(instance, 'PostOrder', @fn)`. Do **not** default to flat-loop
aggregation in MATLAB — the analysis-function approach writes rolled-up
values to every parent in the hierarchy so the Instance Viewer is useful at
every level. Details, non-sum aggregations (min/mean), and when to bypass
the pattern: `references/analysis.md`. Runnable templates:
`code/myRollupAnalysis.m` (analysis function) and `code/runMyAnalysis.m` (driver).
