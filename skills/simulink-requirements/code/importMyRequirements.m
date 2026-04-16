function reqSet = importMyRequirements(xlsxFile, setName, opts)
% IMPORTMYREQUIREMENTS Import an Excel file into an editable requirement set.
%   Wrapper over slreq.import that (1) skips the header row, (2) maps the
%   standard columns Id/Summary/Description/Rationale, (3) saves the result
%   to disk — slreq.import leaves the set Dirty in memory by default.
%
%   Inputs:
%     xlsxFile - Full path to the source .xlsx file
%     setName  - Name (and filename stem) for the new requirement set
%     opts     - Optional struct with fields:
%                .destDir         (default: folder containing xlsxFile)
%                .rows            (default: [2 lastRow] — skip header)
%                .idColumn        (default: 1)
%                .summaryColumn   (default: 2)
%                .descriptionColumn (default: 3)
%                .rationaleColumn (default: 4)
%                .attributeColumn (default: [] — e.g. 5 to map DerivedFrom)
%                .attributes      (default: {} — e.g. {'DerivedFrom'})
%
%   Output:
%     reqSet - slreq.ReqSet (saved to disk)

    arguments
        xlsxFile (1,1) string
        setName  (1,1) string
        opts.destDir           string = ""
        opts.rows              double = []
        opts.idColumn          (1,1) double = 1
        opts.summaryColumn     (1,1) double = 2
        opts.descriptionColumn (1,1) double = 3
        opts.rationaleColumn   (1,1) double = 4
        opts.attributeColumn   double = []
        opts.attributes        cell   = {}
    end

    if strlength(opts.destDir) == 0
        opts.destDir = fileparts(xlsxFile);
    end
    if isempty(opts.rows)
        t = readtable(xlsxFile, 'VariableNamingRule','preserve');
        opts.rows = [2, height(t) + 1];   % +1 because readtable skips header row
    end

    % slreq.import writes the new .slreqx into the current folder — cd first.
    oldCd = cd(opts.destDir);
    c = onCleanup(@() cd(oldCd));

    args = {xlsxFile, ...
        'ReqSet',            char(setName), ...
        'AsReference',       false, ...
        'rows',              opts.rows, ...
        'idColumn',          opts.idColumn, ...
        'summaryColumn',     opts.summaryColumn, ...
        'descriptionColumn', opts.descriptionColumn, ...
        'rationaleColumn',   opts.rationaleColumn};
    if ~isempty(opts.attributeColumn)
        args = [args, {'attributeColumn', opts.attributeColumn, 'attributes', opts.attributes}];
    end

    [n, ~, reqSet] = slreq.import(args{:});
    reqSet.save();   % slreq.import does NOT save to disk on its own

    fprintf('Imported %d requirements -> %s\n', n, reqSet.Filename);
end
