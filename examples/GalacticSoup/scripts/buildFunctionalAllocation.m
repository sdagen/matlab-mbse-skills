function buildFunctionalAllocation()
% BUILDFUNCTIONALALLOCATION Create SR -> Function Refine links for GalacticSoup.
%   Idempotent within the functional model scope. SR links may target either
%   top-level functions or sub-functions inside CookSoup (ExecuteRecipe,
%   ControlHeating, StirContents, ApplyHeat).
%
%   NOTE: re-run whenever buildFunctional.m is re-run — SIDs change on rebuild.

    proj    = currentProject();
    reqDir  = fullfile(proj.RootFolder, 'requirements');
    archDir = fullfile(proj.RootFolder, 'architecture');

    slreq.clear();
    srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    funcModel = systemcomposer.openModel('GalacticSoupFunctional');
    funcArch  = funcModel.Architecture;
    cookArch  = funcArch.getComponent('CookSoup').Architecture;

    removeRefineLinksToModel(srSet, 'GalacticSoupFunctional');

    % Helper: resolve name to a component (top-level or CookSoup sub-function)
    cookSubs = {'ApplyHeat','ControlHeating','StirContents','ExecuteRecipe'};

    allocation = {
        'SR-GS-001', { 'OrchestrateOperations','ExecuteRecipe','ProcessProduce','PortionIngredients' };
        'SR-GS-002', { 'ProcessProduce','PortionIngredients','ExecuteRecipe','PackageSoup','ShipSoup','OrchestrateOperations' };
        'SR-GS-003', { 'OrchestrateOperations' };
        'SR-GS-004', { 'OrchestrateOperations' };
        'SR-GS-005', { 'ShipSoup' };
        'SR-GS-006', { 'ShipSoup','OrchestrateOperations' };
        'SR-GS-007', { 'InspectQuality' };
        'SR-GS-008', { 'InspectQuality','ControlHeating' };
        'SR-GS-009', { 'PackageSoup' };
        'SR-GS-010', { 'TrackInventory','PortionIngredients' };
        'SR-GS-011', { 'OrchestrateOperations' };
        'SR-GS-012', { 'OrchestrateOperations' };
        'SR-GS-013', { 'OrchestrateOperations' };
        'SR-GS-014', { 'OrchestrateOperations' };
        'SR-GS-015', { 'MonitorEnvironment','ProcessProduce','PortionIngredients','StirContents','ControlHeating','PackageSoup' };
        'SR-GS-016', { 'OrchestrateOperations','MonitorEnvironment' };
    };

    nLinks = 0;
    for i = 1:size(allocation, 1)
        req = srSet.find('Id', allocation{i,1});
        for j = 1:numel(allocation{i,2})
            name = allocation{i,2}{j};
            if any(strcmp(name, cookSubs))
                comp = cookArch.getComponent(name);
            else
                comp = funcArch.getComponent(name);
            end
            lnk      = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
            nLinks   = nLinks + 1;
        end
    end

    slreq.saveAll();
    fprintf('SR -> Function Refine links: %d\n', nLinks);
    registerWithProject({fullfile(archDir, 'GalacticSoupFunctional.slx')});
end
