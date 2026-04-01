---
name: mbse-architecture
description: >
  Use this skill for the architecture phase of an MBSE workflow in MATLAB — decomposing
  requirements into physical components, building a System Composer model, and setting up
  budget profiles/stereotypes. Trigger when the user wants to translate requirements into
  a System Composer architecture, define component budgets, or connect the architecture
  step to the wider MBSE process. Works alongside the system-composer skill, which covers
  the detailed System Composer port/connection API.
---

# MBSE Phase 3: Architecture Model

See the `system-composer` skill for the full System Composer API reference
(interfaces, ports, connections, auto-layout, update diagram verification).
This skill covers the MBSE-specific decisions and patterns layered on top.

---

## Functional vs Physical Decomposition

Before writing any code, decide whether you need one or two SC models:

- **Single model (simple systems)** — physical components only; annotate functions
  in comments or use Architecture Views as display filters
- **Two models (recommended for ARP4754A compliance)** — separate functional and
  physical models linked by a System Composer allocation set

Two separate models is the standard MBSE approach and provides explicit,
navigable functional→physical traceability. Architecture Views are display
filters on a single model, not a separate tier.

### Physical architecture model (`MySystem.slx`)

What the system *implements* — hardware/software components, interfaces,
and budget properties. Build this first; it owns the interface dictionary.

### Functional architecture model (`MyFunctional.slx`)

What the system *does* — logical functions that are independent of physical
implementation. Shares the same interface dictionary as the physical model.

```matlab
function buildMyFunctional()
    fcsDir    = fileparts(fileparts(mfilename('fullpath')));
    archDir   = fullfile(fcsDir, 'architecture');
    modelName = "MyFunctional";               % double-quoted string
    dictFile  = fullfile(archDir, 'MyInterfaces.sldd');

    % Get interfaces from physical model (already in memory)
    addpath(archDir);
    physModel = systemcomposer.openModel('MySystem');
    dict      = physModel.InterfaceDictionary; % correct property — not loadDictionary
    myIface   = dict.getInterface('MyInterface');

    % Create functional model (clean slate)
    if bdIsLoaded(modelName), close_system(modelName, 0); end
    slxFile = fullfile(archDir, char(modelName) + ".slx");  % + with double-quoted string
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
- Use `physModel.InterfaceDictionary` to get the shared dict — `systemcomposer.loadDictionary` does not exist
- `modelName` must be a MATLAB `string` (double-quoted) so that `char(modelName) + ".slx"` concatenates correctly; single-quoted char + single-quoted char does arithmetic
- `addpath(archDir)` before `openModel` — SC resolves models via the MATLAB path even when given a full path

---

## Component Naming and Domains

Group components by domain in the source — it makes the architecture readable
and directly informs what interfaces they exchange:

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

## Profile and Budget Stereotype — Set Up in the Architecture Script

Define and apply the budget profile at the **end of `buildMySystemModel()`**,
not in a separate script. This keeps estimates co-located with the model and
ensures they survive every rebuild.

```matlab
%% Profile: budget properties
profileName = 'MySystemBudget';
profileXml  = fullfile(fileparts(mfilename('fullpath')), [profileName, '.xml']);

systemcomposer.profile.Profile.closeAll();
if isfile(profileXml), delete(profileXml); end

profile = systemcomposer.profile.Profile.createProfile(profileName);
st = addStereotype(profile, 'BudgetProperties', AppliesTo="Component");
addProperty(st, 'PowerBudget_W',   Type="double", Units="W",  DefaultValue="0");
addProperty(st, 'PowerEstimate_W', Type="double", Units="W",  DefaultValue="0");
addProperty(st, 'Mass_kg',         Type="double", Units="kg", DefaultValue="0");
profile.save(profileXml);          % ← must be a char path, NOT a string type

applyProfile(model, profileName);
prefix = [profileName, '.BudgetProperties.'];   % ← char concat, not string +

%         Component        Budget_W  Estimate_W  Mass_kg
budgets = {
    'FlightComputer',   150,  120,  3.5;
    'SensorSuite',       50,   45,  4.0;
    % ...
};

for i = 1:size(budgets, 1)
    comp = arch.getComponent(budgets{i, 1});
    applyStereotype(comp, [profileName, '.BudgetProperties']);
    setProperty(comp, [prefix, 'PowerBudget_W'],   num2str(budgets{i, 2}));
    setProperty(comp, [prefix, 'PowerEstimate_W'], num2str(budgets{i, 3}));
    setProperty(comp, [prefix, 'Mass_kg'],         num2str(budgets{i, 4}));
end
```

### Profile path gotcha

`profile.save()` requires a **char array** path. String type (`"..."`) causes
a cryptic "Value must be a scalar" error:

```matlab
profile.save([profileName, '.xml'])   % OK  — char concat
profile.save(profileName + ".xml")    % FAILS — numeric addition on char array
profile.save("FCSBudget.xml")         % FAILS — string type not accepted
```

---

## Verification

After building, run the standard connectivity check from the `system-composer`
skill, then rebuild allocation if the model was rebuilt:

```matlab
% All ports connected?
for i = 1:numel(arch.Components)
    for j = 1:numel(arch.Components(i).Ports)
        if isempty(arch.Components(i).Ports(j).Connectors)
            fprintf('Unconnected: %s.%s\n', ...
                arch.Components(i).Name, arch.Components(i).Ports(j).Name);
        end
    end
end
```

Rebuilding the model invalidates allocation links — always re-run
`buildMyAllocation()` after `buildMySystemModel()`.
