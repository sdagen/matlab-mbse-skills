function setupMBSEProject(projectName, projectFolder)
% SETUPMBSEPROJECT Create a new MBSE MATLAB project with standard folder structure.
%   Creates the project, standard subfolders, configures Simulink cache and
%   code generation paths, and registers all tracked folders on the project path.
%
%   Run this inline before any build scripts exist. After it completes, all
%   subsequent build scripts can be generated into scripts/ and run from there.
%
%   Inputs:
%     projectName   - Name for the MATLAB project (string)
%     projectFolder - Full path to the folder where the project will be created (string)

    proj    = matlab.project.createProject(Name=projectName, Folder=projectFolder);
    rootDir = proj.RootFolder;

    % Standard MBSE folder structure
    for sub = {'requirements', 'architecture', 'analysis', 'verification', 'scripts'}
        mkdir(fullfile(rootDir, sub{1}));
    end

    % Derived folders for Simulink cache and code generation — not tracked in the
    % project (they are build outputs), but must exist before setting the properties
    mkdir(fullfile(rootDir, 'derived', 'cache'));
    mkdir(fullfile(rootDir, 'derived', 'codegen'));

    % CRITICAL: use absolute paths — these properties resolve relative to the
    % current working directory, not the project root, so relative paths will be wrong
    proj.SimulinkCacheFolder   = fullfile(rootDir, 'derived', 'cache');
    proj.SimulinkCodeGenFolder = fullfile(rootDir, 'derived', 'codegen');

    % Track all MBSE folders and add each to the MATLAB path. Do NOT track
    % derived/ — it contains generated build outputs.
    % IMPORTANT: all tracked folders must also be on the project path or
    % runChecks will fail with Project:Checks:ProjectPath.
    for sub = {'requirements', 'architecture', 'analysis', 'verification', 'scripts'}
        addFolderIncludingChildFiles(proj, fullfile(rootDir, sub{1}));
        addPath(proj, fullfile(rootDir, sub{1}));
    end

    % Shortcuts point to specific tracked files — add them as files are created.
    % E.g. after Phase 9: addShortcut(proj, fullfile(rootDir, 'scripts', 'buildAll.m'))

    close(proj);
    fprintf("Project created: %s\n", rootDir);
    fprintf("Open with: openProject('%s')\n", rootDir);
end
