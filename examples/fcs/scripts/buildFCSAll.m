function buildFCSAll()
% buildFCSAll  Rebuild the complete FCS MBSE project from scratch.
%
%   Runs all build scripts in order. Each script is idempotent — safe to
%   re-run at any time.
%
%   Steps:
%     1. buildFCSRequirements  — StakeholderNeeds.slreqx, SystemRequirements.slreqx
%     2. buildFCSModel         — FCSSystem.slx, FCSInterfaces.sldd, FCSBudget.xml
%     3. buildFCSFunctional    — FCSFunctional.slx
%     4. buildFCSAllocationSet — FCSAllocation.mldatx
%     5. buildFCSAllocation    — Refine links (SR -> components)
%     6. rollupAnalysis        — PowerMassRollup.mat
%     7. buildFCSTestCases     — TestCases.slreqx (TC requirements + Verify links)
%
%   Note: Simulink Test (.mldatx) is deferred until a Simulink simulation model
%   exists. TC requirements in TestCases.slreqx provide full traceability now.

    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);

    %% Isolate this build from any other FCS workspaces on the MATLAB path
    % Other directories (e.g. fcs-mbse) may contain same-named models and
    % dictionaries.  System Composer resolves by path, so shadowing causes
    % "dictionary already open" conflicts at createModel/createDictionary time.
    isolatedPaths = isolateBuildPath('fcs-mbse');
    cleanupObj = onCleanup(@() restoreBuildPath(isolatedPaths)); %#ok<NASGU>

    %% Clean MATLAB state before starting
    if bdIsLoaded('FCSSystem'),     close_system('FCSSystem', 0); end
    if bdIsLoaded('FCSFunctional'), close_system('FCSFunctional', 0); end
    Simulink.data.dictionary.closeAll('-discard');
    systemcomposer.profile.Profile.closeAll();
    slreq.clear();

    steps = {
        'buildFCSRequirements',  @buildFCSRequirements;
        'buildFCSModel',         @buildFCSModel;
        'buildFCSFunctional',    @buildFCSFunctional;
        'buildFCSAllocationSet', @buildFCSAllocationSet;
        'buildFCSAllocation',    @buildFCSAllocation;
        'rollupAnalysis',        @rollupAnalysis;
        'buildFCSTestCases',     @buildFCSTestCases;
    };

    fprintf('FCS MBSE — full build\n');
    fprintf('%s\n', repmat('=', 1, 56));
    totalStart = tic;

    for i = 1:size(steps, 1)
        fprintf('\nStep %d — %s\n', i, steps{i, 1});
        fprintf('%s\n', repmat('-', 1, 56));
        t = tic;
        steps{i, 2}();
        fprintf('[%.1f s]\n', toc(t));
    end

    fprintf('\n%s\n', repmat('=', 1, 56));
    fprintf('Build complete in %.1f s\n', toc(totalStart));

    %% Register all scripts with the project
    scriptsDir = fileparts(mfilename('fullpath'));
    fcsDir = fileparts(scriptsDir);
    registerWithProject({fullfile(fcsDir, 'README.md')});

    scriptFiles = { ...
        fullfile(scriptsDir, 'buildFCSAll.m'), ...
        fullfile(scriptsDir, 'buildFCSRequirements.m'), ...
        fullfile(scriptsDir, 'buildFCSModel.m'), ...
        fullfile(scriptsDir, 'buildFCSFunctional.m'), ...
        fullfile(scriptsDir, 'buildFCSAllocationSet.m'), ...
        fullfile(scriptsDir, 'buildFCSAllocation.m'), ...
        fullfile(scriptsDir, 'rollupAnalysis.m'), ...
        fullfile(scriptsDir, 'buildFCSTestCases.m'), ...
        fullfile(scriptsDir, 'registerWithProject.m'), ...
        fullfile(scriptsDir, 'setupFCSProject.m'), ...
    };
    registerWithProject(scriptFiles);

    %% Project health check
    proj = matlab.project.currentProject();
    if ~isempty(proj.Name)
        results = runChecks(proj);
        nFail = 0;
        fprintf('\nProject checks:\n');
        for i = 1:numel(results)
            if results(i).Passed
                fprintf('  [PASS] %s\n', results(i).Description);
            else
                fprintf('  [FAIL] %s\n', results(i).Description);
                for j = 1:numel(results(i).ProblemFiles)
                    fprintf('           %s\n', results(i).ProblemFiles(j));
                end
                nFail = nFail + 1;
            end
        end
        if nFail == 0
            fprintf('All checks passed.\n');
        else
            fprintf('%d check(s) failed — review output above.\n', nFail);
        end
    end

    fprintf('\nArtifacts:\n');
    fprintf('  requirements/  StakeholderNeeds.slreqx (6)\n');
    fprintf('                 SystemRequirements.slreqx (15)\n');
    fprintf('                 TestCases.slreqx (13)\n');
    fprintf('  architecture/  FCSSystem.slx\n');
    fprintf('                 FCSFunctional.slx\n');
    fprintf('                 FCSInterfaces.sldd\n');
    fprintf('                 FCSBudget.xml\n');
    fprintf('                 FCSAllocation.mldatx\n');
    fprintf('                 PowerMassRollup.mat\n');
    fprintf('  verification/  (Simulink Test deferred — no simulation model yet)\n');
    fprintf('\nRun buildFCSAll() at any time to rebuild everything cleanly.\n');
end

% ── Path isolation helpers ────────────────────────────────────────────────────

function removedPaths = isolateBuildPath(filterToken)
% Remove MATLAB path entries that contain filterToken.
% Returns the removed entries so they can be restored later.
    allPaths     = strsplit(path, pathsep);
    toRemove     = allPaths(contains(allPaths, filterToken));
    removedPaths = toRemove;
    if ~isempty(toRemove)
        rmpath(toRemove{:});
        fprintf('Isolated build: temporarily removed %d path(s) matching "%s".\n', ...
            numel(toRemove), filterToken);
    end
end

function restoreBuildPath(removedPaths)
% Re-add previously removed path entries.
    if ~isempty(removedPaths)
        addpath(removedPaths{:});
    end
end
