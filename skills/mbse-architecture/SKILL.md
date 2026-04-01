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

Two separate models is the standard MBSE approach and provides explicit,
navigable functional→physical traceability. Architecture Views are display
filters on a single model, not a separate tier.

### Physical architecture model (`MySystem.slx`)

What the system *implements* — hardware/software components, interfaces,
and stereotype properties. Build this first; it owns the interface dictionary.

### Functional architecture model (`MyFunctional.slx`)

What the system *does* — logical functions independent of physical implementation.
Shares the same interface dictionary as the physical model.

```matlab
function buildMyFunctional()
    rootDir   = fileparts(fileparts(mfilename('fullpath')));
    archDir   = fullfile(rootDir, 'architecture');
    modelName = "MyFunctional";               % double-quoted string
    dictFile  = fullfile(archDir, 'MyInterfaces.sldd');

    % Get interfaces from physical model (already in memory)
    addpath(archDir);
    physModel = systemcomposer.openModel('MySystem');
    dict      = physModel.InterfaceDictionary; % correct — not systemcomposer.loadDictionary
    myIface   = dict.getInterface('MyInterface');

    if bdIsLoaded(modelName), close_system(modelName, 0); end
    slxFile = fullfile(archDir, char(modelName) + ".slx");  % double-quoted string required
    if isfile(slxFile), delete(slxFile); end
    model = systemcomposer.createModel(modelName);
    arch  = model.Architecture;
    linkDictionary(model, strrep(dictFile, '\', '/'));

    funcA = addComponent(arch, 'FunctionA');
    addTypedPort(funcA.Architecture, 'OutputA', 'out', myIface);
    % ... more components, ports, connections ...

    Simulink.BlockDiagram.arrangeSystem(modelName);
    save_system(char(modelName), char(fullfile(archDir, modelName)));
end

function addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);
end
```

**Key gotchas:**
- Use `physModel.InterfaceDictionary` — `systemcomposer.loadDictionary` does not exist
- `modelName` must be a double-quoted MATLAB string so `char(modelName) + ".slx"` concatenates; single-quoted char + char does arithmetic
- `addpath(archDir)` before `openModel` — SC resolves models via MATLAB path even with full path

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

```matlab
rootDir   = fileparts(fileparts(mfilename('fullpath')));
archDir   = fullfile(rootDir, 'architecture');
allocFile = fullfile(archDir, 'MyAllocation.mldatx');

systemcomposer.allocation.AllocationSet.closeAll();
if isfile(allocFile), delete(allocFile); end

addpath(archDir);
funcModel = systemcomposer.openModel('MyFunctional');
physModel = systemcomposer.openModel('MySystem');
funcArch  = funcModel.Architecture;
physArch  = physModel.Architecture;

% Use a name that differs from the file base name — save() derives 'MyAllocation'
% from the file path and checks uniqueness; if the in-memory name matches, the set
% conflicts with itself and save fails with "name must be unique".
allocSet = systemcomposer.allocation.createAllocationSet(...
    'MyAllocationSet', funcModel, physModel);

scenario = createScenario(allocSet, 'FunctionalToPhysical');

allocate(scenario, funcArch.getComponent('FunctionA'), physArch.getComponent('ComponentX'));
allocate(scenario, funcArch.getComponent('FunctionB'), physArch.getComponent('ComponentY'));
% One function can map to multiple physical components:
allocate(scenario, funcArch.getComponent('FunctionC'), physArch.getComponent('ComponentX'));
allocate(scenario, funcArch.getComponent('FunctionC'), physArch.getComponent('ComponentZ'));

save(allocSet, allocFile);
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

```matlab
rootDir = fileparts(fileparts(mfilename('fullpath')));
reqDir  = fullfile(rootDir, 'requirements');
archDir = fullfile(rootDir, 'architecture');

slreq.clear();
srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
addpath(archDir);
model = systemcomposer.openModel('MySystem');   % by name — never full path with ..
arch  = model.Architecture;

% Remove existing Refine links (idempotent)
allReqs = srSet.find();
for i = 1:numel(allReqs)
    lnks = slreq.outLinks(allReqs(i));
    for j = 1:numel(lnks)
        if strcmp(lnks(j).Type, 'Refine'), lnks(j).remove(); end
    end
end

% { SR-ID, { component names... } }
allocation = {
    'SR-SYS-001', { 'ComponentA', 'ComponentB' };
    'SR-SYS-002', { 'ComponentA'               };
};

for i = 1:size(allocation, 1)
    req = srSet.find('Id', allocation{i, 1});
    for j = 1:numel(allocation{i, 2})
        comp     = arch.getComponent(allocation{i, 2}{j});
        lnk      = slreq.createLink(req, comp);
        lnk.Type = 'Refine';
    end
end
slreq.saveAll();
```

### Bidirectional navigation

```matlab
% Forward: requirement → components
outL = slreq.outLinks(req);
for i = 1:numel(outL)
    if strcmp(outL(i).Type, 'Refine')
        h = Simulink.ID.getHandle([strrep(outL(i).destination.artifact, '.slx', ''), ...
                                    outL(i).destination.id]);
        fprintf('%s\n', get_param(h, 'Name'));
    end
end

% Reverse: component → requirements
inL = slreq.inLinks(comp);
for i = 1:numel(inL)
    rs  = slreq.open(inL(i).source.artifact);
    all = rs.find();
    for k = 1:numel(all)
        if all(k).SID == str2double(inL(i).source.id)
            fprintf('%s\n', all(k).Id); break;
        end
    end
end
```

### Path rule

Never use `'..'` in paths passed to System Composer. Use `fileparts` twice to
get the project root:

```matlab
rootDir = fileparts(fileparts(mfilename('fullpath')));  % project root
archDir = fullfile(rootDir, 'architecture');
addpath(archDir);
model = systemcomposer.openModel('MySystem');  % open by name
```

---

# Analysis (Phase 6)

Analysis is optional and project-specific. Read `references/analysis.md` in
this skill folder when the user needs to set up quantitative analysis
(roll-up, trade study, sensitivity, margins).
