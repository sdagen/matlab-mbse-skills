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

Keep profile creation in the same script as the architecture — add it at the end,
after the model and connections are built:

```
buildMySystemModel.m    ← architecture + interface dictionary + profile/stereotypes
```

This keeps both artifacts in sync on every rebuild, and avoids the "profile already
applied" uniqueness error that occurs when a separate profile script re-applies a
profile to an already-profiled model.

The script is idempotent: it deletes and recreates all artifacts on every run.

---

## Phase 1+2: Architecture Model + Interface Dictionary

### Skeleton

See [`code/buildMySystemModel.m`](code/buildMySystemModel.m) for the full parameterized function:

```
buildMySystemModel(modelName, dictFile, archDir)
```

---

## Phase 3: Profile & Stereotypes

See [`code/buildMySystemProfile.m`](code/buildMySystemProfile.m) for the full parameterized function:

```
buildMySystemProfile(profileName, modelName, archDir)
```

---

## Critical API Gotchas

These will silently fail or throw cryptic errors without warning:

| What you want | Correct API | Wrong / common mistake |
|---|---|---|
| Connect two component ports | `connect(srcPort, dstPort)` | `connect(arch, srcPort, dstPort)` — silently fails; dispatches to Control System Toolbox |
| Wire a composite boundary port to a sub-component port | Use the `ArchitecturePort` ref returned by `addPort(comp.Architecture, ...)` | Using `comp.Ports[PortName]` — throws "incompatible directions" |
| Assign interface to port | `port.setInterface(iface)` | `port.Interface = iface` — read-only property error |
| Add interface element | `addElement(iface, "Name", Type="double")` | `Type="MyValueTypeName"` — value type names resolve to `Simulink.ValueType` objects which the bus compiler cannot use; always use a Simulink base type directly |
| Create model | `systemcomposer.createModel(name)` | `systemcomposer.createModel(name, true)` — invalid 2nd arg |
| Set string stereotype property | `setProperty(comp, path, '"value"')` | `setProperty(comp, path, 'value')` — evaluates as MATLAB variable |
| Set string default in addProperty | `DefaultValue='"standard"'` | `DefaultValue="standard"` — evaluates, throws error |
| Apply stereotype property | `setProperty(comp, ...)` | `setPropertyValue(comp, ...)` — wrong function name |
| Close all profiles | `systemcomposer.profile.Profile.closeAll()` | `...closeAll("-discard")` — too many arguments |
| Create profile | `createProfile(name)` | `createProfile(name, "file.xml")` — invalid 2nd arg |
| Look up a component by path | Keep component vars when adding, or use `resolveComponent(arch, 'Parent/Child')` helper | `arch.lookup('Path', ...)` — does not exist |
| Create allocation set | `createAllocationSet(name, srcModelName, dstModelName)` — model **names** | `createAllocationSet(name, srcModelObj, dstModelObj)` — model objects fail on R2025b with unhelpful AllocationAppCatalog signature error |

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

## Port Multiplicity: Fan-Out Works, Fan-In Needs Separate Ports

A single **output port** can be connected to any number of input ports — just call
`connect(out, in1); connect(out, in2); ...`. This is clean 1→N fan-out; use it for
broadcast buses (e.g. `Supervisory.Schedule` feeding every production unit).

A single **input port** cannot receive connections from multiple sources. SC is a
structural modelling tool with no merge semantics — attempting to hook two
outputs into one input either errors or silently fails. Give the destination
component **separate named input ports** for each source (e.g.
`Status_Cook`, `Status_Pack`, `Status_Load`) and wire 1:1. This pattern is
verbose but unambiguous and matches how an MBSE diagram will render for review.

---

## Composite Components: Keep ArchitecturePort Refs for Internal Wiring

When a component has sub-components (a composite), boundary ports have two views:

| View | Accessed via | Used for |
|---|---|---|
| External `ComponentPort` | `comp.Ports` | Connections in the **parent** arch |
| Internal `ArchitecturePort` | return value of `addPort(comp.Architecture, ...)` | Connections **inside** the composite, to sub-component ports |

Using the external `ComponentPort` for an internal connection throws:

```
Unable to connect ports because they have incompatible directions.
```

The error appears because, from inside the composite, a boundary "in" port acts as a *source* for data entering the sub-architecture — but the external `ComponentPort` still reports direction `in`, so the `connect()` call sees two "in" ports and refuses.

**Pattern:** make `addTypedPort` return the port, and save references to each composite boundary port at creation time. Use those saved refs for all internal wiring.

```matlab
function port = addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);
end

% Composite creation — keep boundary refs
conv = addComponent(arch, "ConveyorSystem");
convPowerIn   = addTypedPort(conv.Architecture, "PowerIn",  "in",  ifPower);
convDiagOut   = addTypedPort(conv.Architecture, "DiagOut",  "out", ifDiag);

% Sub-components
motor    = addComponent(conv.Architecture, "Motor");
motorPow = addTypedPort(motor.Architecture, "PowerIn", "in", ifPower);

% Internal connection — use the stored ArchitecturePort ref, NOT conv.Ports
connect(convPowerIn, motorPow);                 % ✓ correct
% connect(getPort(conv, "PowerIn"), motorPow);  % ✗ incompatible directions
```

External connections from the parent arch continue to use `conv.Ports` (via a `getPort(comp, name)` helper) as normal.

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
script — this guarantees a clean slate and makes both scripts independently idempotent.
`buildMySystemProfile` already does this: its first call is always `buildMySystemModel(...)`.

---

## Multi-Domain Interface Patterns

Use `Type="double"` for all elements and document physical units in comments.
Do not use `addValueType` for physical quantities — it creates `Simulink.ValueType`
objects the bus compiler cannot resolve (breaks "update diagram").

See [`code/addCommonInterfaces.m`](code/addCommonInterfaces.m) for an illustrative starting
point covering Thermal, Electrical, Mechanical, and UserCommand interfaces:

```
ifaces = addCommonInterfaces(dict)
```

Returns a struct (`ifaces.ThermalFluid`, `ifaces.ElectricalPower`, etc.). Remember to call
`dict.save()` and re-fetch interfaces before passing them to `setInterface()` — see the
re-fetch pattern above.

---

## Verifying Your Model

Run these checks after every build. They catch real problems that the build step itself
won't flag.

### 1. Check for unconnected ports

Ports that were added but never wired are silently valid at build time but represent
incomplete or inconsistent architecture. See [`code/checkUnconnectedPorts.m`](code/checkUnconnectedPorts.m):

```
checkUnconnectedPorts(modelName)
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
