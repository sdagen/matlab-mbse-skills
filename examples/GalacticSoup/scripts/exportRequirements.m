function exportRequirements()
% EXPORTREQUIREMENTS Export every requirement set in the project to xlsx.
%   For each requirements/*.slreqx file, writes a sibling .xlsx with columns
%   Id, Summary, Description, Rationale, DerivedFrom. DerivedFrom is filled
%   from incoming Derive links (comma-separated parent IDs). Idempotent.

    proj   = currentProject();
    reqDir = fullfile(proj.RootFolder, 'requirements');
    sets   = dir(fullfile(reqDir, '*.slreqx'));

    xlsxFiles = cell(numel(sets), 1);
    for k = 1:numel(sets)
        slreqxFile = fullfile(sets(k).folder, sets(k).name);
        xlsxFile   = strrep(slreqxFile, '.slreqx', '.xlsx');
        lockFile   = fullfile(sets(k).folder, ...
            ['~$' strrep(sets(k).name, '.slreqx', '.xlsx')]);
        if isfile(lockFile)
            error('exportRequirements:locked', ...
                '%s is open in Excel -- close it and retry.', xlsxFile);
        end

        rs = slreq.load(slreqxFile);
        T  = reqSetToTable(rs);
        if isfile(xlsxFile), delete(xlsxFile); end
        writetable(T, xlsxFile);

        fprintf('%-28s -> %d reqs\n', sets(k).name, height(T));
        xlsxFiles{k} = xlsxFile;
    end
    registerWithProject(xlsxFiles);
end

function T = reqSetToTable(rs)
    reqs = find(rs, 'Type', 'Requirement');
    n = numel(reqs);
    [id, summary, desc, rat, derived] = deal(strings(n,1));
    for i = 1:n
        r = reqs(i);
        id(i)      = string(r.Id);
        summary(i) = string(r.Summary);
        desc(i)    = string(r.Description);
        rat(i)     = string(r.Rationale);
        derived(i) = strjoin(deriveParents(r), ', ');
    end
    T = table(id, summary, desc, rat, derived, ...
        'VariableNames', {'Id','Summary','Description','Rationale','DerivedFrom'});
end

function ids = deriveParents(req)
    ids  = strings(0,1);
    lnks = req.inLinks();
    for k = 1:numel(lnks)
        if strcmp(lnks(k).Type, 'Derive')
            ids(end+1,1) = string(strtok(lnks(k).getSourceLabel())); %#ok<AGROW>
        end
    end
end
