function buildAllocation(reqDir, archDir)
% BUILDALLOCATION Create Refine links from system requirements to architecture components.
%   Removes any existing Refine links then recreates them from the allocation
%   table (idempotent). Distinct from the functional-to-physical allocation set
%   (Phase 4) — Refine links live in the requirements toolbox and are queryable
%   via slreq.
%
%   Inputs:
%     reqDir  - Directory containing SystemRequirements.slreqx (string)
%     archDir - Directory containing the physical SC model (string)

    slreq.clear();
    srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    model = systemcomposer.openModel('MySystem');   % open by name — never use '..' in SC paths
    arch  = model.Architecture;

    % Remove existing Refine links (idempotent)
    allReqs = srSet.find('Type', 'Requirement');
    for i = 1:numel(allReqs)
        lnks = allReqs(i).outLinks();   % method on the object — NOT slreq.outLinks(req)
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
end
