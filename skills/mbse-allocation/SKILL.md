---
name: mbse-allocation
description: >
  Use this skill to allocate requirements to System Composer architectural components in
  MATLAB with bidirectional traceability. Trigger when the user wants to link requirements
  to components, create an allocation matrix, check which components implement which
  requirements, or navigate traceability between requirements and architecture. Use this
  skill proactively whenever the user has both a requirement set and a System Composer
  model and wants to connect them.
---

# MBSE Phase 4: Requirements Allocation

Allocation creates `Refine` links from each system requirement to the
component(s) responsible for implementing it. Links are bidirectional:
navigate forward from a requirement to find its components, or backward
from a component to find its requirements.

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
Add its folder to the path before opening:

```matlab
archDir = fullfile(fileparts(mfilename('fullpath')), '..', 'architecture');
addpath(archDir);
model = systemcomposer.openModel('MySystem');
```

---

## Skeleton

```matlab
function buildMyAllocation()
    reqDir  = fullfile(fileparts(mfilename('fullpath')), '..', 'requirements');
    archDir = fullfile(fileparts(mfilename('fullpath')), '..', 'architecture');

    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    model = systemcomposer.openModel('MySystem');
    arch  = model.Architecture;

    % Remove existing Refine links
    for i = 1:numel(srSet.find())
        lnks = slreq.outLinks(srSet.find()); % or iterate individually
        % ... remove as above
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
