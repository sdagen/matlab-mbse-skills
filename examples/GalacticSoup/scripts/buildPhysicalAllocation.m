function buildPhysicalAllocation()
% BUILDPHYSICALALLOCATION Create SR -> Physical Refine links for GalacticSoup.
%   Idempotent within the physical model scope. Use for hardware-specific,
%   environmental, and structural requirements, plus system-level budget caps
%   (mass/volume/power/cost) that roll up across components.
%
%   NOTE: re-run whenever buildPhysical.m is re-run — SIDs change on rebuild.

    proj    = currentProject();
    reqDir  = fullfile(proj.RootFolder, 'requirements');
    archDir = fullfile(proj.RootFolder, 'architecture');

    slreq.clear();
    srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
    addpath(archDir);
    physModel = systemcomposer.openModel('GalacticSoupPhysical');
    physArch  = physModel.Architecture;

    removeRefineLinksToModel(srSet, 'GalacticSoupPhysical');

    allTop = { 'CryoPantry','AugerDispenser','RoboPrepStation','PrecisionScale', ...
               'CookingStation','QualitySensorSuite','SealingLine','LoaderArm', ...
               'InventoryDB','GravityIMU','KitchenController' };

    allocation = {
        'SR-GS-006', { 'LoaderArm' };                                                      % load time hardware
        'SR-GS-007', { 'QualitySensorSuite' };                                             % contamination sensor
        'SR-GS-008', { 'QualitySensorSuite','CookingStation' };                            % temperature
        'SR-GS-009', { 'SealingLine' };                                                    % 30-day seal rating
        'SR-GS-011', allTop;                                                               % mass budget — rolls up
        'SR-GS-012', allTop;                                                               % power budget — rolls up
        'SR-GS-013', allTop;                                                               % cost budget — rolls up
        'SR-GS-014', allTop;                                                               % volume budget — rolls up
        'SR-GS-015', { 'GravityIMU','PrecisionScale','RoboPrepStation','CookingStation','SealingLine' };  % gravity operation
        'SR-GS-016', allTop;                                                               % structural 12g — every component
    };

    nLinks = 0;
    for i = 1:size(allocation, 1)
        req = srSet.find('Id', allocation{i,1});
        for j = 1:numel(allocation{i,2})
            comp     = physArch.getComponent(allocation{i,2}{j});
            lnk      = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
            nLinks   = nLinks + 1;
        end
    end

    slreq.saveAll();
    fprintf('SR -> Physical Refine links: %d\n', nLinks);
    registerWithProject({fullfile(archDir, 'GalacticSoupPhysical.slx')});
end
