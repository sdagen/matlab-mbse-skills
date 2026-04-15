function runAnalysis()
% RUNANALYSIS Compute roll-ups, margins, throughput bottleneck, and staffing
% for GalacticSoup. Budget caps are read from SR-GS-011..014 at run time —
% nothing is hard-coded.

    proj        = currentProject();
    reqDir      = fullfile(proj.RootFolder, 'requirements');
    archDir     = fullfile(proj.RootFolder, 'architecture');
    analysisDir = fullfile(proj.RootFolder, 'analysis');
    profileName = 'GalacticSoupProfile';
    modelName   = 'GalacticSoupPhysical';

    slreq.clear();
    srSet = slreq.open(fullfile(reqDir, 'SystemRequirements.slreqx'));
    capMass   = parseBudgetValue(srSet, 'SR-GS-011', 'kg');
    capPower  = parseBudgetValue(srSet, 'SR-GS-012', 'kW');
    capCost   = parseBudgetValue(srSet, 'SR-GS-013', 'credits');
    capVolume = parseBudgetValue(srSet, 'SR-GS-014', 'm\^3');
    capThru   = 200;     % from SR-GS-002 pass criterion
    capAuto   = 0.80;    % from SR-GS-003 pass criterion
    capCrew   = 5;       % from SR-GS-004 pass criterion

    addpath(archDir);
    model    = systemcomposer.openModel(modelName);
    arch     = model.Architecture;
    instance = instantiate(arch, profileName, 'GalacticSoupAnalysis');

    prefix = [profileName, '.ComponentProperties.'];
    n      = numel(instance.Components);
    names  = strings(n,1);
    mass   = zeros(n,1);
    volume = zeros(n,1);
    power  = zeros(n,1);
    cost   = zeros(n,1);
    thru   = zeros(n,1);
    auto   = zeros(n,1);

    for i = 1:n
        ci        = instance.Components(i);
        names(i)  = ci.Name;
        mass(i)   = getValue(ci, [prefix, 'mass']);
        volume(i) = getValue(ci, [prefix, 'volume']);
        power(i)  = getValue(ci, [prefix, 'power']);
        cost(i)   = getValue(ci, [prefix, 'cost']);
        thru(i)   = getValue(ci, [prefix, 'throughput']);
        auto(i)   = getValue(ci, [prefix, 'automationLevel']);
    end

    totMass = sum(mass); totVol = sum(volume); totPower = sum(power); totCost = sum(cost);
    avgAuto = mean(auto);
    % Throughput bottleneck = min across producing stages (zero-throughput
    % components like controllers/sensors are excluded)
    bottleThru = min(thru(thru > 0));
    % Staffing proxy: crew-equivalents needed if all top-level components ran
    % simultaneously at full manual load. sum(1 - automationLevel).
    crewNeeded = sum(1 - auto);

    report = { ...
        'Mass (kg)',    totMass,  capMass,  capMass  - totMass,  totMass  <= capMass; ...
        'Volume (m^3)', totVol,   capVolume,capVolume- totVol,   totVol   <= capVolume; ...
        'Power (kW)',   totPower, capPower, capPower - totPower, totPower <= capPower; ...
        'Cost (cr)',    totCost,  capCost,  capCost  - totCost,  totCost  <= capCost; ...
        'Throughput (bowls/h, min stage)', bottleThru, capThru, bottleThru - capThru, bottleThru >= capThru; ...
        'Automation (avg)', avgAuto, capAuto, avgAuto - capAuto, avgAuto >= capAuto; ...
        'Crew-equiv (sum(1-auto))', crewNeeded, capCrew, capCrew - crewNeeded, crewNeeded <= capCrew; ...
    };

    fprintf('\n%-35s %12s %12s %12s %8s\n', 'Metric','Value','Cap','Margin','OK');
    fprintf('%s\n', repmat('-',1,85));
    for i = 1:size(report,1)
        ok = report{i,5};
        fprintf('%-35s %12.2f %12.2f %12.2f %8s\n', ...
            report{i,1}, report{i,2}, report{i,3}, report{i,4}, ternary(ok,'PASS','FAIL'));
    end

    save(instance, fullfile(analysisDir, 'GalacticSoupAnalysis.mat'));
    fprintf('\nSaved: analysis/GalacticSoupAnalysis.mat\n');
    fprintf('Open in viewer: systemcomposer.analysis.openViewer(''GalacticSoupAnalysis'')\n');

    registerWithProject({fullfile(analysisDir, 'GalacticSoupAnalysis.mat')});
end

function v = parseBudgetValue(srSet, reqId, unit)
    req = srSet.find('Id', reqId);
    tok = regexp(req.Description, ['not exceed\s+([\d]+)\s+', unit], 'tokens', 'once');
    if isempty(tok)
        error('parseBudgetValue:noMatch', 'Cannot parse %s from %s.', unit, reqId);
    end
    v = str2double(tok{1});
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
