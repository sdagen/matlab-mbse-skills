function buildAllocationSet(allocFile, funcModelName, physModelName, archDir)
% BUILDALLOCATIONSET Create a System Composer functional-to-physical allocation set.
%   Closes any existing allocation set, deletes the file, then creates a new
%   allocation set with a FunctionalToPhysical scenario (idempotent).
%
%   Inputs:
%     allocFile     - Full path to the allocation file (.mldatx) (string)
%     funcModelName - Name of the functional SC model (string)
%     physModelName - Name of the physical SC model (string)
%     archDir       - Directory containing both models; added to MATLAB path (string)

    systemcomposer.allocation.AllocationSet.closeAll();
    if isfile(allocFile), delete(allocFile); end

    addpath(archDir);
    funcModel = systemcomposer.openModel(funcModelName);
    physModel = systemcomposer.openModel(physModelName);
    funcArch  = funcModel.Architecture;
    physArch  = physModel.Architecture;

    % Allocation set name must differ from the file base name — save() derives
    % a name from the file path and checks uniqueness; a match causes "name must
    % be unique" to fail.
    [~, allocBase] = fileparts(allocFile);
    allocSetName   = [allocBase, 'Set'];
    allocSet = systemcomposer.allocation.createAllocationSet(...
        allocSetName, funcModel, physModel);

    % Reuse the default scenario createAllocationSet auto-creates ("Scenario 1")
    % rather than calling createScenario, which would leave the default empty
    % and the Allocation Editor would open to the empty scenario by default.
    scenario      = allocSet.Scenarios(1);
    scenario.Name = 'FunctionalToPhysical';

    allocate(scenario, funcArch.getComponent('FunctionA'), physArch.getComponent('ComponentX'));
    allocate(scenario, funcArch.getComponent('FunctionB'), physArch.getComponent('ComponentY'));
    % One function can map to multiple physical components:
    allocate(scenario, funcArch.getComponent('FunctionC'), physArch.getComponent('ComponentX'));
    allocate(scenario, funcArch.getComponent('FunctionC'), physArch.getComponent('ComponentZ'));

    save(allocSet, allocFile);
end
