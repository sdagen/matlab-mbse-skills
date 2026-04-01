function setupFCSProject()
% setupFCSProject  Create the MATLAB project for the FCS MBSE example.
%
%   Run once, then open the project with openProject before running buildFCSAll.
%   The build scripts are idempotent and work with or without a project open,
%   but an open project enables file tracking, path management, and health checks.
%
%   Project layout:
%     requirements/   stakeholder needs, system requirements, test cases
%     architecture/   System Composer models, interface dictionary, profile, analysis
%     verification/   (reserved — Simulink Test deferred until a simulation model exists)
%     scripts/        build scripts (on MATLAB path via project)
%     derived/        Simulink cache and codegen outputs (not tracked in project)

    fcsDir      = fileparts(mfilename('fullpath'));
    fcsDir      = fileparts(fcsDir);   % scripts/ -> fcs/
    projectName = 'FCSSystem';

    %% Create project (run once — errors if project already exists in this folder)
    proj    = matlab.project.createProject(Name=projectName, Folder=fcsDir);
    rootDir = proj.RootFolder;

    %% Derived folders for Simulink cache and code generation — not tracked
    % CRITICAL: use absolute paths — these properties resolve relative to the
    % current working directory, not the project root, so relative paths fail
    mkdir(fullfile(rootDir, 'derived', 'cache'));
    mkdir(fullfile(rootDir, 'derived', 'codegen'));
    proj.SimulinkCacheFolder   = fullfile(rootDir, 'derived', 'cache');
    proj.SimulinkCodeGenFolder = fullfile(rootDir, 'derived', 'codegen');

    %% Track MBSE folders and register them on the MATLAB path
    % architecture/ and requirements/ must be on the project path so System
    % Composer resolves models by name and slreq stores relative paths in .slmx
    % files.  runChecks will fail with Project:Checks:ProjectPath otherwise.
    for sub = {'requirements', 'architecture', 'verification', 'scripts'}
        addFolderIncludingChildFiles(proj, fullfile(rootDir, sub{1}));
    end
    addPath(proj, fullfile(rootDir, 'scripts'));
    addPath(proj, fullfile(rootDir, 'architecture'));
    addPath(proj, fullfile(rootDir, 'requirements'));

    %% Shortcuts — added progressively as key files are created by build scripts
    % After running buildFCSAll, uncomment these:
    % addShortcut(proj, fullfile(rootDir, 'scripts', 'buildFCSAll.m'));
    % addShortcut(proj, fullfile(rootDir, 'architecture', 'FCSSystem.slx'));
    % addShortcut(proj, fullfile(rootDir, 'requirements', 'SystemRequirements.slreqx'));

    close(proj);
    fprintf('Project created: %s\n', rootDir);
    fprintf('Open with: openProject(''%s'')\n', rootDir);
    fprintf('Then run: buildFCSAll()\n');
end
