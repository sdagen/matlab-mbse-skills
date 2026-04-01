---
name: mbse-allocation
description: >
  Use this skill for either type of MBSE allocation in MATLAB: (1) functional-to-physical
  allocation sets linking logical functions to physical components using
  systemcomposer.allocation.createAllocationSet, or (2) requirements-to-component Refine
  links using slreq.createLink. Trigger when the user wants to link requirements to
  components, map functions to hardware, create an allocation matrix, check traceability
  between requirements and architecture, or build a System Composer allocation set. Use
  this skill proactively whenever the user has both a functional model and a physical model,
  or both a requirement set and a System Composer model, and wants to connect them.
---

# MBSE Phases 4–5: Allocation

There are **two distinct allocation steps** in the MBSE workflow:

| Step | What | API |
|---|---|---|
| Phase 4 | Functional → Physical allocation set | `systemcomposer.allocation` |
| Phase 5 | Requirements → Component `Refine` links | `slreq.createLink` |

Both are needed for full ARP4754A traceability. Phase 4 links logical
functions to physical components. Phase 5 links shall-statements to
components. They use different APIs and produce different artifact types.

---

## Phase 4: Functional-to-Physical Allocation Set

An SC allocation set (`*.mldatx`) maps each logical function in the
functional architecture model to the physical component(s) that implement it.

### Create and save

```matlab
fcsDir    = fileparts(fileparts(mfilename('fullpath')));
archDir   = fullfile(fcsDir, 'architecture');
allocFile = fullfile(archDir, 'MyAllocation.mldatx');

systemcomposer.allocation.AllocationSet.closeAll();
if isfile(allocFile), delete(allocFile); end

addpath(archDir);
funcModel = systemcomposer.openModel('MyFunctional');
physModel = systemcomposer.openModel('MySystem');
funcArch  = funcModel.Architecture;
physArch  = physModel.Architecture;

% IMPORTANT: use a name that differs from the file base name.
% save(allocSet, filePath) derives a name from the file ('MyAllocation') and
% checks uniqueness against all in-memory sets.  If the in-memory name is
% also 'MyAllocation' the set conflicts with itself and save fails with
% "name must be unique".
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

### Open the Allocation Editor

```matlab
systemcomposer.allocation.editor('path/to/MyAllocation.mldatx')
```

### Query allocations

```matlab
allocatedTo = getAllocatedTo(scenario, funcArch.getComponent('FunctionA'));
for i = 1:numel(allocatedTo)
    fprintf('%s\n', allocatedTo(i).Name);
end
```

---

## Phase 5: Requirements Allocation (`Refine` links)

`Refine` links are created with `slreq.createLink` — separate from the SC
allocation set above.

---

## Link Type

Use `"Refine"` for requirement → component allocation:

```matlab
lnk = slreq.createLink(req, comp);   % req=source, comp=destination
lnk.Type = 'Refine';
```

---

## Idempotent Rebuild

Always remove existing `Refine` links before recreating them. This makes the
script safe to re-run without accumulating duplicates:

```matlab
allReqs = srSet.find();
for i = 1:numel(allReqs)
    lnks = slreq.outLinks(allReqs(i));
    for j = 1:numel(lnks)
        if strcmp(lnks(j).Type, 'Refine')
            lnks(j).remove();
        end
    end
end
```

---

## Allocation Table Pattern

Define the mapping as a cell array — one row per requirement, second column
is a cell array of component names:

```matlab
allocation = {
    'SR-SYS-001', { 'ComponentA', 'ComponentB' };
    'SR-SYS-002', { 'ComponentA'               };
};

for i = 1:size(allocation, 1)
    req = srSet.find('Id', allocation{i, 1});
    for j = 1:numel(allocation{i, 2})
        comp = arch.getComponent(allocation{i, 2}{j});
        lnk  = slreq.createLink(req, comp);
        lnk.Type = 'Refine';
    end
end
slreq.saveAll();
```

---

## Bidirectional Navigation

### Forward: requirement → components it is allocated to

```matlab
outL = slreq.outLinks(req);
for i = 1:numel(outL)
    if strcmp(outL(i).Type, 'Refine')
        dst      = outL(i).destination;
        modelName = strrep(dst.artifact, '.slx', '');
        h        = Simulink.ID.getHandle([modelName, dst.id]);
        fprintf('%s\n', get_param(h, 'Name'));
    end
end
```

### Reverse: component → requirements allocated to it

```matlab
inL = slreq.inLinks(comp);
for i = 1:numel(inL)
    rs  = slreq.open(inL(i).source.artifact);
    all = rs.find();
    for k = 1:numel(all)
        if all(k).SID == str2double(inL(i).source.id)
            fprintf('%s\n', all(k).Id);
            break;
        end
    end
end
```

### Link struct fields

`outLinks` destination: `artifact` (`.slx` path), `id` (Simulink SID as `':N'`)
`inLinks` source: `artifact` (`.slreqx` path), `id` (requirement SID as `'N'`)

Full Simulink SID = `[strrep(artifact, '.slx', ''), id]` e.g. `'FCSSystem:1'`

---

## Opening the Architecture Model

The architecture `.slx` is in a different folder from the allocation script.
Use `fileparts` twice to get the project root, then build absolute paths — do
not use `'..'` in paths passed to System Composer, as unresolved `..` segments
cause `openModel` to fail:

```matlab
fcsDir  = fileparts(fileparts(mfilename('fullpath')));  % project root
archDir = fullfile(fcsDir, 'architecture');
addpath(archDir);
model = systemcomposer.openModel('MySystem');            % open by name, not path
```

---

## Skeleton

```matlab
function buildMyAllocation()
    fcsDir  = fileparts(fileparts(mfilename('fullpath')));
    reqDir  = fullfile(fcsDir, 'requirements');
    archDir = fullfile(fcsDir, 'architecture');

    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    model = systemcomposer.openModel('MySystem');   % by name, not full path
    arch  = model.Architecture;

    % Remove existing Refine links
    allReqs = srSet.find();
    for i = 1:numel(allReqs)
        lnks = slreq.outLinks(allReqs(i));
        for j = 1:numel(lnks)
            if strcmp(lnks(j).Type, 'Refine'), lnks(j).remove(); end
        end
    end

    allocation = {
        'SR-SYS-001', { 'ComponentA', 'ComponentB' };
        % ...
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
end
```
