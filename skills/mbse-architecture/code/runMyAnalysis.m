function runMyAnalysis()
% Driver template for a System Composer roll-up analysis.
%
%   1. Read system-level caps from requirements (not hard-coded)
%   2. Instantiate the architecture against the profile
%   3. Run the analysis function via iterate(..., 'PostOrder', @fn) so every
%      parent in the hierarchy gets aggregated values (visible in the Viewer)
%   4. Read rolled-up totals off the top-level instance
%   5. Report margins and save for the Analysis Viewer

    proj        = currentProject();
    reqDir      = fullfile(proj.RootFolder, 'requirements');
    archDir     = fullfile(proj.RootFolder, 'architecture');
    analysisDir = fullfile(proj.RootFolder, 'analysis');
    profileName = 'MyProfile';
    modelName   = 'MySystem';
    prefix      = [profileName, '.Stereotype.'];

    % --- Read caps from requirements ---------------------------------------
    slreq.clear();
    srSet     = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    capMass   = parseBudgetValue(srSet, 'SR-SYS-010', 'kg');
    capPower  = parseBudgetValue(srSet, 'SR-SYS-011', 'W');

    % --- Instantiate and iterate -------------------------------------------
    addpath(archDir);
    model    = systemcomposer.openModel(modelName);
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'MyAnalysis');

    iterate(instance, 'PostOrder', @myRollupAnalysis);

    % --- Read top-level aggregated values ----------------------------------
    totMass  = sumTop(instance.Components, [prefix, 'mass']);
    totPower = sumTop(instance.Components, [prefix, 'power']);

    % --- Report -------------------------------------------------------------
    report = { ...
        'Mass (kg)',  totMass,  capMass,  capMass  - totMass,  totMass  <= capMass; ...
        'Power (W)',  totPower, capPower, capPower - totPower, totPower <= capPower; ...
    };
    fprintf('\n%-20s %12s %12s %12s %8s\n', 'Metric','Value','Cap','Margin','OK');
    fprintf('%s\n', repmat('-', 1, 70));
    for i = 1:size(report,1)
        fprintf('%-20s %12.2f %12.2f %12.2f %8s\n', report{i,1:4}, ...
            ternary(report{i,5}, 'PASS', 'FAIL'));
    end

    % --- Save for the Analysis Viewer --------------------------------------
    save(instance, fullfile(analysisDir, 'MyAnalysis.mat'));
    fprintf('\nSaved: analysis/MyAnalysis.mat\n');
    fprintf('Open: systemcomposer.analysis.openViewer(''MyAnalysis'')\n');
end

function s = sumTop(comps, prop)
    s = 0;
    for i = 1:numel(comps)
        s = s + comps(i).getValue(prop);
    end
end

function value = parseBudgetValue(srSet, reqId, unit)
% Extract numeric cap from "shall not exceed X <unit>" in a requirement description.
    req = srSet.find('Id', reqId);
    tok = regexp(req.Description, ['not exceed\s+([\d.]+)\s+', unit], 'tokens', 'once');
    if isempty(tok)
        error('parseBudgetValue:noMatch', 'Cannot parse %s from %s.', unit, reqId);
    end
    value = str2double(tok{1});
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
