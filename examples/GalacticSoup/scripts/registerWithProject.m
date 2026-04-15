function registerWithProject(files, folders)
% REGISTERWITHPROJECT Add files and folders to the MATLAB project if one is open.
%   Safe to call repeatedly — addFile and addPath are idempotent. Silently does
%   nothing if no project is currently open.
%
%   Inputs:
%     files   - Cell array of absolute file paths; non-existent files are skipped
%     folders - Cell array of folder paths; each is tracked and added to project path

    if nargin < 2, folders = {}; end
    proj = matlab.project.currentProject();
    if isempty(proj.Name), return; end
    for i = 1:numel(files)
        if isfile(files{i}), addFile(proj, files{i}); end
    end
    for i = 1:numel(folders)
        if isfolder(folders{i})
            addFolderIncludingChildFiles(proj, folders{i});
            addPath(proj, folders{i});
        end
    end
end
