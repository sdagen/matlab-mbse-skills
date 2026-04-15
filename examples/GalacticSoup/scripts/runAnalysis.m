function runAnalysis()
% RUNANALYSIS Compute roll-ups, margins, throughput bottleneck, and staffing
% for GalacticSoup. Roll-ups are computed by the GalacticSoupRollupAnalysis
% analysis function iterated over the analysis instance in PostOrder, so every
% parent in the hierarchy gets aggregated values (visible in the Instance
% Viewer). Budget caps are read from SR-GS-011..014 at run time.

    proj        = currentProject();
    reqDir      = fullfile(proj.RootFolder, 'requirements');
    archDir     = fullfile(proj.RootFolder, 'architecture');
    analysisDir = fullfile(proj.RootFolder, 'analysis');
    profileName = 'GalacticSoupProfile';
    modelName   = 'GalacticSoupPhysical';
    prefix      = [profileName, '.ComponentProperties.'];

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

    % Run the analysis function. PostOrder visits children before parents so
    % each parent sees already-aggregated child values.
    iterate(instance, 'PostOrder', @GalacticSoupRollupAnalysis);

    % Roll-ups now live on the top-level architecture instance
    topComps = instance.Components;
    totMass  = sumTop(topComps, [prefix, 'mass']);
    totVol   = sumTop(topComps, [prefix, 'volume']);
    totPower = sumTop(topComps, [prefix, 'power']);
    totCost  = sumTop(topComps, [prefix, 'cost']);

    % Throughput bottleneck and average automation across top-level components
    [thruVals, autoVals] = deal([]);
    for i = 1:numel(topComps)
        c = topComps(i);
        t = c.getValue([prefix, 'throughput']);
        if t > 0, thruVals(end+1) = t; end %#ok<AGROW>
        autoVals(end+1) = c.getValue([prefix, 'automationLevel']); %#ok<AGROW>
    end
    bottleThru = min(thruVals);
    avgAuto    = mean(autoVals);
    crewNeeded = sum(1 - autoVals);

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

    registerWithProject({ ...
        fullfile(analysisDir, 'GalacticSoupAnalysis.mat'), ...
        fullfile(analysisDir, 'GalacticSoupRollupAnalysis.m'), ...   % analysis function lives in analysis/, not scripts/
    });
end

function s = sumTop(comps, prop)
    s = 0;
    for i = 1:numel(comps)
        s = s + comps(i).getValue(prop);
    end
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
