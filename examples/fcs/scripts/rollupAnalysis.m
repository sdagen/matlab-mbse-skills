function rollupAnalysis()
% rollupAnalysis  Roll-up power and mass budget analysis for the FCS.
%
%   Creates a System Composer analysis instance from the FCSBudget profile,
%   reads PowerBudget_W, PowerEstimate_W, and Mass_kg from each component,
%   computes system-level totals, and writes per-component power margins back
%   to the instance.  Saves the instance as a MAT-file for the Analysis Viewer.
%
%   System-level budget caps are read from requirements:
%     SR-FCS-014  (total power budget, W)
%     SR-FCS-015  (total mass budget, kg)
%
%   Prerequisite: run buildFCSModel() before this script.

    fcsDir      = fileparts(fileparts(mfilename('fullpath')));
    reqDir      = fullfile(fcsDir, 'requirements');
    archDir     = fullfile(fcsDir, 'architecture');
    analysisDir = fullfile(fcsDir, 'analysis');
    profileName = 'FCSBudget';
    modelName   = 'FCSSystem';

    %% Read system-level budget limits from requirements
    % addpath(reqDir) before slreq.clear() keeps .slmx paths relative
    addpath(reqDir);
    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    sysPowerBudget_W = parseBudgetValue(srSet, 'SR-FCS-014', 'W');
    sysMassBudget_kg = parseBudgetValue(srSet, 'SR-FCS-015', 'kg');
    fprintf('Budget limits from requirements:  Power %.0f W  |  Mass %.0f kg\n\n', ...
        sysPowerBudget_W, sysMassBudget_kg);

    %% Create analysis instance
    addpath(archDir);
    model    = systemcomposer.openModel(modelName);
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'PowerMassRollup');

    %% Collect values from all component instances
    prefix = [profileName, '.BudgetProperties.'];
    nComp  = numel(instance.Components);

    names           = cell(nComp, 1);
    powerBudget_W   = zeros(nComp, 1);
    powerEstimate_W = zeros(nComp, 1);
    mass_kg         = zeros(nComp, 1);

    for i = 1:nComp
        ci = instance.Components(i);
        names{i}           = ci.Name;
        powerBudget_W(i)   = getValue(ci, [prefix, 'PowerBudget_W']);
        powerEstimate_W(i) = getValue(ci, [prefix, 'PowerEstimate_W']);
        mass_kg(i)         = getValue(ci, [prefix, 'Mass_kg']);
    end

    %% Write per-component power margin back to instance
    for i = 1:nComp
        ci = instance.Components(i);
        setValue(ci, [prefix, 'PowerMargin_W'], powerBudget_W(i) - powerEstimate_W(i));
    end

    %% Power budget report
    fprintf('Power Budget Analysis\n');
    fprintf('%s\n', repmat('-', 1, 72));
    fprintf('%-20s  %12s  %12s  %10s  %6s\n', ...
        'Component', 'Budget (W)', 'Estimate (W)', 'Margin (W)', 'Status');
    fprintf('%s\n', repmat('-', 1, 72));

    for i = 1:nComp
        margin = powerBudget_W(i) - powerEstimate_W(i);
        if margin >= 0
            status = 'OK';
        else
            status = 'OVER';
        end
        fprintf('%-20s  %12.1f  %12.1f  %10.1f  %6s\n', ...
            names{i}, powerBudget_W(i), powerEstimate_W(i), margin, status);
    end

    fprintf('%s\n', repmat('-', 1, 72));
    totalPower  = sum(powerEstimate_W);
    powerMargin = sysPowerBudget_W - totalPower;
    fprintf('%-20s  %12.1f  %12.1f  %10.1f  %6s\n', ...
        'SYSTEM TOTAL', sysPowerBudget_W, totalPower, powerMargin, ...
        statusLabel(powerMargin));
    fprintf('  System power utilisation: %.1f%%\n\n', ...
        100 * totalPower / sysPowerBudget_W);

    %% Mass roll-up report
    fprintf('Mass Roll-Up Analysis\n');
    fprintf('%s\n', repmat('-', 1, 50));
    fprintf('%-20s  %12s\n', 'Component', 'Mass (kg)');
    fprintf('%s\n', repmat('-', 1, 50));

    for i = 1:nComp
        fprintf('%-20s  %12.2f\n', names{i}, mass_kg(i));
    end

    fprintf('%s\n', repmat('-', 1, 50));
    totalMass  = sum(mass_kg);
    massMargin = sysMassBudget_kg - totalMass;
    fprintf('%-20s  %12.2f\n', 'SYSTEM TOTAL', totalMass);
    fprintf('%-20s  %12.2f\n', 'BUDGET', sysMassBudget_kg);
    fprintf('%-20s  %12.2f  %s\n', 'MARGIN', massMargin, statusLabel(massMargin));
    fprintf('  System mass utilisation: %.1f%%\n\n', ...
        100 * totalMass / sysMassBudget_kg);

    %% Save instance for Analysis Viewer
    instanceFile = fullfile(analysisDir, 'PowerMassRollup.mat');
    save(instance, instanceFile);
    fprintf('Analysis instance saved: %s\n', instanceFile);
    fprintf('Open viewer: systemcomposer.analysis.openViewer(''%s'')\n', 'PowerMassRollup');

    %% Register with project
    registerWithProject({instanceFile});
end

% ── Helpers ──────────────────────────────────────────────────────────────────

function s = statusLabel(margin)
    if margin >= 0
        s = 'OK';
    else
        s = 'OVER BUDGET';
    end
end

function value = parseBudgetValue(srSet, reqId, unit)
% parseBudgetValue  Extract a numeric limit from a requirement description.
%
%   Looks for the pattern "not exceed <number> <unit>" in the requirement
%   Description field.  Errors if the requirement is not found or the
%   pattern does not match.
    req = srSet.find('Id', reqId);
    if isempty(req)
        error('rollupAnalysis:reqNotFound', 'Requirement %s not found in set.', reqId);
    end
    pattern = ['not exceed\s+([\d.]+)\s+', unit];
    tok = regexp(req.Description, pattern, 'tokens', 'once');
    if isempty(tok)
        error('rollupAnalysis:parseError', ...
            'Could not parse "%s" budget from %s description:\n  %s', ...
            unit, reqId, req.Description);
    end
    value = str2double(tok{1});
end
