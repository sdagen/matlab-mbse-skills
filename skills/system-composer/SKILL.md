---
name: system-composer
description: >
  Use this skill whenever the user wants to create, edit, or extend a MATLAB System Composer
  architecture model programmatically — including building models, defining interface dictionaries,
  wiring component connections, creating profiles with stereotypes, or applying property values.
  Trigger on any mention of System Composer, architecture models (.slx), interface dictionaries
  (.sldd), stereotypes, profiles, or programmatic component/port/connection creation in MATLAB.
  Also trigger when the user is debugging System Composer scripts that aren't working as expected
  (e.g., connections not appearing, interfaces not resolving, profile errors).
---

# MATLAB System Composer — Programmatic Authoring Guide

System Composer lets you model multi-domain architectures in MATLAB. This skill captures the
correct API patterns, common gotchas, and a proven script structure for building models reliably.

---

## Recommended Script Structure

Split work across two scripts — keep them composable so the profile script always starts clean:

```
buildMySystemModel.m    ← Phase 1+2: architecture + interface dictionary
buildMySystemProfile.m  ← Phase 3: profile, stereotypes, property values
                          (calls buildMySystemModel at the top)
```

Each script is idempotent: it deletes and recreates its artifacts on every run.

---

## Phase 1+2: Architecture Model + Interface Dictionary

### Skeleton

```matlab
function buildMySystemModel()
    modelName = "MySystem";
    dictFile  = "MySystemInterfaces.sldd";

    %% Interface Dictionary
    if isfile(dictFile)
        Simulink.data.dictionary.closeAll("-discard");
        delete(dictFile);
    end
    dict = systemcomposer.createDictionary(dictFile);

    % Interfaces — use Type="double" for all elements; document units in comments.
    % Do NOT use addValueType to create named types for physical quantities like
    % Temperature or Voltage — addValueType creates Simulink.ValueType objects that
    % the bus compiler cannot resolve, causing "update diagram" to fail.
    thermalIface = addInterface(dict, "ThermalFluid");
    addElement(thermalIface, "Temperature", Type="double");   % K
    addElement(thermalIface, "MassFlowRate", Type="double");  % kg/s
    % ... more interfaces ...

    % CRITICAL: save dictionary before creating model, then re-fetch interfaces
    dict.save();
    thermalIface = dict.getInterface("ThermalFluid");         % ← re-fetch after save
    % ... re-fetch all interfaces ...

    %% Architecture Model
    if bdIsLoaded(modelName), close_system(modelName, 0); end
    model = systemcomposer.createModel(modelName);                 % ← name only, no 2nd arg
    arch  = model.Architecture;
    linkDictionary(model, dictFile);

    %% Components
    compA = addComponent(arch, "ComponentA");
    compB = addComponent(arch, "ComponentB");

    %% Ports
    addTypedPort(compA.Architecture, "OutPort1", "out", thermalIface);
    addTypedPort(compB.Architecture, "InPort1",  "in",  thermalIface);

    %% Connections — CRITICAL: use connect(srcPort, dstPort), NO architecture argument
    connect(compA.getPort("OutPort1"), compB.getPort("InPort1"));

    %% Layout, Save, and Open
    Simulink.BlockDiagram.arrangeSystem(modelName);
    save_system(char(modelName), char(fullfile(archDir, modelName)));
    open_system(char(modelName));   % ← required: createModel alone does not show the SC editor
    fprintf("Model created: %s\n", modelName);
end

% ── Helpers ──────────────────────────────────────────────────────────────────

function addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);    % ← setInterface(), NOT port.Interface = iface (read-only)
end
```

---

## Phase 3: Profile & Stereotypes

```matlab
function buildMySystemProfile()
    profileName = "MySystemProfile";
    modelName   = "MySystem";

    % Always rebuild model first — avoids stale stereotype errors on re-runs
    buildMySystemModel();

    %% Create Profile
    systemcomposer.profile.Profile.closeAll();   % ← no arguments
    profile = systemcomposer.profile.Profile.createProfile(profileName);  % ← name only

    %% Stereotypes
    st = addStereotype(profile, "MyComponent", AppliesTo="Component", Description="...");
    addProperty(st, "NominalPower_W", Type="double", Units="W",  DefaultValue="0");
    addProperty(st, "SafetyClass",    Type="string",             DefaultValue='"standard"');
    %                                                                        ^^^^^^^^^^^
    %   String DefaultValue must be a quoted MATLAB expression — wrap in extra quotes

    profile.save();          % ← no-arg form saves to <profileName>.xml in current folder
    % profile.save([profileName, '.xml'])  ← char path OK if you need a specific location
    % profile.save(profileName + ".xml")   ← FAILS: string type causes "must be scalar" error

    %% Apply to Model
    model = systemcomposer.openModel(modelName);
    applyProfile(model, profileName);
    arch  = model.Architecture;

    applyStereotype(arch.getComponent("ComponentA"), profileName + ".MyComponent");

    %% Set Property Values
    setProperty(arch.getComponent("ComponentA"), ...   % ← setProperty(), NOT setPropertyValue()
        profileName + ".MyComponent.SafetyClass", '"safety-critical"');
    %                                              ^^^^^^^^^^^^^^^^^^^
    %   String values also need inner quotes when passed to setProperty

    save(model);
    fprintf("Profile applied: %s\n", profileName);
end
```

---

## Critical API Gotchas

These will silently fail or throw cryptic errors without warning:

| What you want | Correct API | Wrong / common mistake |
|---|---|---|
| Connect two component ports | `connect(srcPort, dstPort)` | `connect(arch, srcPort, dstPort)` — silently fails; dispatches to Control System Toolbox |
| Assign interface to port | `port.setInterface(iface)` | `port.Interface = iface` — read-only property error |
| Add interface element | `addElement(iface, "Name", Type="double")` | `Type="MyValueTypeName"` — value type names resolve to `Simulink.ValueType` objects which the bus compiler cannot use; always use a Simulink base type directly |
| Create model | `systemcomposer.createModel(name)` | `systemcomposer.createModel(name, true)` — invalid 2nd arg |
| Set string stereotype property | `setProperty(comp, path, '"value"')` | `setProperty(comp, path, 'value')` — evaluates as MATLAB variable |
| Set string default in addProperty | `DefaultValue='"standard"'` | `DefaultValue="standard"` — evaluates, throws error |
| Apply stereotype property | `setProperty(comp, ...)` | `setPropertyValue(comp, ...)` — wrong function name |
| Close all profiles | `systemcomposer.profile.Profile.closeAll()` | `...closeAll("-discard")` — too many arguments |
| Create profile | `createProfile(name)` | `createProfile(name, "file.xml")` — invalid 2nd arg |

---

## Why `connect(srcPort, dstPort)` Must Have No Architecture Argument

`connect` is shadowed by Control System Toolbox's `connect.m`. When you write
`connect(arch, srcPort, dstPort)`, MATLAB dispatches to the CST version (which connects
LTI models) instead of System Composer — it returns an empty 0×0 Connector silently.

The two-argument form `connect(srcPort, dstPort)` dispatches correctly via the port object's
class method. Always use this form for explicit port-to-port connections.

For component-to-component auto-wiring by matching port names, the form
`connect(arch, [srcComp,...], [dstComp,...])` is also safe since `arch` dispatches correctly.

---

## Why dict.save() + Re-fetch Is Required

`systemcomposer.createDictionary()` creates the file but interface objects in memory aren't
fully resolved until after `dict.save()`. If you call `port.setInterface(iface)` before saving,
the model links the port to an unresolvable interface name — connections will silently fail and
reopening the model shows "Unable to resolve interface" errors.

Pattern to always follow:
```matlab
% 1. Add all value types and interfaces
thermalIface = addInterface(dict, "ThermalFluid");
addElement(thermalIface, "Temperature", Type="Temperature");

% 2. Save
dict.save();

% 3. Re-fetch — now safe to pass to setInterface
thermalIface = dict.getInterface("ThermalFluid");
```

---

## Auto-layout

Always call `Simulink.BlockDiagram.arrangeSystem` before `save(model)` — programmatically
added components all start at position (0,0) and stack on top of each other without it.

**For hierarchical models, arrange every decomposed sub-architecture as well as the top level.**
Use the Simulink subsystem path `modelName + "/ComponentName"` for each level:

```matlab
%% Layout and Save
Simulink.BlockDiagram.arrangeSystem(modelName + "/Powertrain");   % sub-levels first
Simulink.BlockDiagram.arrangeSystem(modelName + "/Drivetrain");
Simulink.BlockDiagram.arrangeSystem(modelName);                   % top level last
save(model);
```

Arrange sub-levels before the top level so the top-level layout has accurate size information
for each component block. A sub-architecture that was never arranged remains a collapsed pile,
and the top-level arrange won't fix it.

---

## Re-run Safety for Profile Scripts

Calling `applyProfile` on a model that already has the profile throws a "uniqueness constraint"
error. The cleanest solution is to rebuild the model from scratch at the top of the profile
script — this guarantees a clean slate and makes both scripts independently idempotent:

```matlab
function buildMySystemProfile()
    buildMySystemModel();   % always start fresh
    ...
end
```

---

## Multi-Domain Interface Patterns

Use `Type="double"` for all elements and document physical units in comments.
Do not use `addValueType` for physical quantities — it creates `Simulink.ValueType`
objects the bus compiler cannot resolve (breaks "update diagram").

**Thermal**
```matlab
thermalFluidIface = addInterface(dict, "ThermalFluid");
addElement(thermalFluidIface, "Temperature",  Type="double");   % K
addElement(thermalFluidIface, "MassFlowRate", Type="double");   % kg/s

heatFlowIface = addInterface(dict, "HeatFlow");
addElement(heatFlowIface, "HeatFlowRate", Type="double");       % W

tempSignalIface = addInterface(dict, "TemperatureSignal");
addElement(tempSignalIface, "Value", Type="double");            % K
```

**Electrical**
```matlab
elecPowerIface = addInterface(dict, "ElectricalPower");
addElement(elecPowerIface, "Voltage", Type="double");           % V
addElement(elecPowerIface, "Current", Type="double");           % A

controlSignalIface = addInterface(dict, "ControlSignal");
addElement(controlSignalIface, "Value", Type="double");         % boolean 0/1
```

**Mechanical (rotational)**
```matlab
rotMechIface = addInterface(dict, "RotationalMechanical");
addElement(rotMechIface, "Torque",          Type="double");     % Nm
addElement(rotMechIface, "AngularVelocity", Type="double");     % rad/s
```

**User Interface / Control signals**
```matlab
userCommandIface = addInterface(dict, "UserCommand");
addElement(userCommandIface, "CommandID", Type="double");       % enumerated code
```

---

## Verifying Your Model

Run these checks after every build. They catch real problems that the build step itself
won't flag.

### 1. Check for unconnected ports

Ports that were added but never wired are silently valid at build time but represent
incomplete or inconsistent architecture. This loop surfaces them immediately:

```matlab
model = systemcomposer.openModel("MySystem");
arch  = model.Architecture;

anyUnconnected = false;
for i = 1:numel(arch.Components)
    ports = arch.Components(i).Ports;
    for j = 1:numel(ports)
        if isempty(ports(j).Connectors)
            fprintf("Unconnected: %s.%s\n", arch.Components(i).Name, ports(j).Name);
            anyUnconnected = true;
        end
    end
end
if ~anyUnconnected
    fprintf("All ports connected (%d connectors).\n", numel(arch.Connectors));
end
```

### 2. Update diagram

`set_param` update catches any remaining type resolution issues (e.g. a bad interface
element type that slipped through):

```matlab
set_param("MySystem", "SimulationCommand", "update");
```

**Expected warning for pure architecture models:** `Architecture model contains no
components or all components are virtual.` This is normal — architecture components
have no simulation behaviour. It does not indicate a problem with your model.

If you see a type resolution error instead (e.g. `DataType 'X' did not resolve`), the
cause is almost always an `addElement` call using a value type name instead of a
Simulink base type — see the gotchas table above.

### 3. Check stereotype properties (if using profiles)

```matlab
comp  = arch.getComponent("ComponentA");
props = comp.getStereotypeProperties();
for i = 1:numel(props)
    fprintf("  %s = %s\n", props(i), comp.getPropertyValue(props(i)));
end
```
