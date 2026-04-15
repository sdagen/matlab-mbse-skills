function buildLogicalAllocation()
% BUILDLOGICALALLOCATION Create SR -> Logical Refine links for GalacticSoup.
%   Idempotent within the logical model scope. Use for non-functional reqs
%   (timing, performance, safety) or requirements specific to a logical role.
%   May target sub-roles inside CookingUnit (HeatingController, StirringMechanism,
%   HeatingElement, RecipeExecutor).
%
%   NOTE: re-run whenever buildLogical.m is re-run — SIDs change on rebuild.

    proj    = currentProject();
    reqDir  = fullfile(proj.RootFolder, 'requirements');
    archDir = fullfile(proj.RootFolder, 'architecture');

    slreq.clear();
    srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    logModel = systemcomposer.openModel('GalacticSoupLogical');
    logArch  = logModel.Architecture;
    cookArch = logArch.getComponent('CookingUnit').Architecture;

    removeRefineLinksToModel(srSet, 'GalacticSoupLogical');

    cookSubs = {'HeatingElement','HeatingController','StirringMechanism','RecipeExecutor'};

    allocation = {
        'SR-GS-002', { 'ControlUnit','PrepProcessor','PortioningUnit','RecipeExecutor','PackagingUnit','ShippingUnit' };
        'SR-GS-003', { 'ControlUnit' };
        'SR-GS-004', { 'ControlUnit' };
        'SR-GS-006', { 'ShippingUnit','ControlUnit' };
        'SR-GS-007', { 'QualitySensingUnit' };
        'SR-GS-008', { 'QualitySensingUnit','HeatingController' };
        'SR-GS-010', { 'InventoryTracker','PortioningUnit' };
        'SR-GS-015', { 'EnvironmentSensor','PrepProcessor','PortioningUnit','StirringMechanism','HeatingController','PackagingUnit' };
    };

    nLinks = 0;
    for i = 1:size(allocation, 1)
        req = srSet.find('Id', allocation{i,1});
        for j = 1:numel(allocation{i,2})
            name = allocation{i,2}{j};
            if any(strcmp(name, cookSubs))
                comp = cookArch.getComponent(name);
            else
                comp = logArch.getComponent(name);
            end
            lnk      = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
            nLinks   = nLinks + 1;
        end
    end

    slreq.saveAll();
    fprintf('SR -> Logical Refine links: %d\n', nLinks);
    registerWithProject({fullfile(archDir, 'GalacticSoupLogical.slx')});
end
