function xlsxFile = exportRequirementsToExcel(slreqxFile, xlsxFile)
% EXPORTREQUIREMENTSTOEXCEL Export a .slreqx to .xlsx.
%   Columns: Id, Summary, Description, Rationale, DerivedFrom.
%   DerivedFrom is filled from incoming Derive links (comma-separated parent
%   IDs). There is no public slreq Excel-export API — slreq.export emits
%   ReqIF only, and the Requirements Editor's xlsx export is GUI-only. This
%   function builds the table manually with writetable.
%
%   Inputs:
%     slreqxFile - Full path to the .slreqx file
%     xlsxFile   - (optional) Output xlsx path; defaults to sibling of slreqx
%
%   Output:
%     xlsxFile - Full path to the written xlsx file

    if nargin < 2 || isempty(xlsxFile)
        xlsxFile = strrep(slreqxFile, '.slreqx', '.xlsx');
    end

    [xlsxDir, xlsxName, xlsxExt] = fileparts(xlsxFile);
    lockFile = fullfile(xlsxDir, ['~$' xlsxName xlsxExt]);
    if isfile(lockFile)
        error('exportRequirementsToExcel:locked', ...
            '%s is open in Excel -- close it and retry.', xlsxFile);
    end

    rs = slreq.load(slreqxFile);
    T  = reqSetToTable(rs);

    if isfile(xlsxFile), delete(xlsxFile); end
    writetable(T, xlsxFile);
    fprintf('%s -> %s (%d reqs)\n', rs.Name, xlsxFile, height(T));
end

function T = reqSetToTable(rs)
    reqs = find(rs, 'Type', 'Requirement');
    n = numel(reqs);
    [id, summary, desc, rat, derived] = deal(strings(n,1));
    for i = 1:n
        r = reqs(i);
        id(i)      = string(r.Id);
        summary(i) = string(r.Summary);
        desc(i)    = string(r.getDescriptionAsText());
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
            % getSourceLabel() returns "ID Summary"; strtok pulls just the ID
            ids(end+1,1) = string(strtok(lnks(k).getSourceLabel())); %#ok<AGROW>
        end
    end
end
