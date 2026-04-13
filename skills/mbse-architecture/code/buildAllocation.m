function buildAllocation(reqDir, archDir)
% BUILDALLOCATION Create Refine links from system requirements to architecture.
%   Creates two types of Refine links (idempotent):
%     SR -> Function:           mandatory — every SR traces to at least one function
%     SR -> Logical component:  for non-functional requirements (timing, performance,
%                               safety, security) or requirements specific to a logical role
%     SR -> Physical component: for hardware-specific, environmental, EMC, or
%                               packaging/installation requirements
%   Removes all existing Refine links before recreating.
%
%   Inputs:
%     reqDir  - Directory containing SystemRequirements.slreqx (string)
%     archDir - Directory containing the SC models (string)

    slreq.clear();
    srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    funcModel = systemcomposer.openModel('MyFunctional');
    funcArch  = funcModel.Architecture;
    logModel  = systemcomposer.openModel('MyLogical');
    logArch   = logModel.Architecture;
    physModel = systemcomposer.openModel('MySystem');
    physArch  = physModel.Architecture;

    % Remove existing Refine links (idempotent)
    allReqs = srSet.find('Type', 'Requirement');
    for i = 1:numel(allReqs)
        lnks = allReqs(i).outLinks();   % method on the object — NOT slreq.outLinks(req)
        for j = 1:numel(lnks)
            if strcmp(lnks(j).Type, 'Refine'), lnks(j).remove(); end
        end
    end

    % SR -> Function Refine links (mandatory — every SR must trace to at least one function)
    % { SR-ID, { function component names... } }
    funcAllocation = {
        'SR-SYS-001', { 'FunctionA', 'FunctionB' };
        'SR-SYS-002', { 'FunctionA'               };
    };

    for i = 1:size(funcAllocation, 1)
        req = srSet.find('Id', funcAllocation{i, 1});
        for j = 1:numel(funcAllocation{i, 2})
            func     = funcArch.getComponent(funcAllocation{i, 2}{j});
            lnk      = slreq.createLink(req, func);
            lnk.Type = 'Refine';
        end
    end

    % SR -> Logical component Refine links
    % Use for: non-functional requirements (timing, performance, safety, security),
    %          requirements specific to a logical solution role
    % { SR-ID, { logical component names... } }
    logAllocation = {
        'SR-SYS-001', { 'SensingUnit'  };
        'SR-SYS-003', { 'ControlUnit'  };
    };

    for i = 1:size(logAllocation, 1)
        req = srSet.find('Id', logAllocation{i, 1});
        for j = 1:numel(logAllocation{i, 2})
            comp     = logArch.getComponent(logAllocation{i, 2}{j});
            lnk      = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
        end
    end

    % SR -> Physical component Refine links
    % Use for: hardware-specific requirements, environmental constraints,
    %          EMC, packaging, and installation requirements
    % { SR-ID, { physical component names... } }
    physAllocation = {
        'SR-SYS-002', { 'ComponentA', 'ComponentB' };
        'SR-SYS-004', { 'ComponentA'               };
    };

    for i = 1:size(physAllocation, 1)
        req = srSet.find('Id', physAllocation{i, 1});
        for j = 1:numel(physAllocation{i, 2})
            comp     = physArch.getComponent(physAllocation{i, 2}{j});
            lnk      = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
        end
    end

    slreq.saveAll();
end
