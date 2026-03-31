function buildFCSAll()
% buildFCSAll  Build the complete FCS MBSE artifact set in one command.
%
%   Calls all seven build scripts in the correct phase order:
%
%     1. buildFCSRequirements  — stakeholder needs + system requirements
%     2. buildFCSModel         — System Composer architecture model
%     3. buildFCSProfile       — budget profile + per-component estimates
%                                (calls buildFCSModel internally — final stable model)
%     4. buildFCSAllocation    — requirement-to-component Refine links
%                                (must run after Profile so links target the final model)
%     5. rollupAnalysis        — power + mass roll-up analysis
%     6. buildFCSTestCases     — TC requirements + Verify links to SRs
%     7. buildFCSSimulinkTests — Simulink Test file linked to TC requirements
%
%   All scripts are idempotent; re-running this rebuilds all artifacts cleanly.

    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);

    %% Isolate this build from any other FCS workspaces on the MATLAB path
    % fcs-mbse and similar directories may contain same-named models and
    % data dictionaries.  System Composer resolves model names via the path,
    % so shadowing files cause "dictionary already open" conflicts at
    % createModel / createDictionary time.  Remove them for the duration of
    % the build and restore on exit.
    isolatedPaths = isolateBuildPath('fcs-mbse');
    cleanupObj = onCleanup(@() restoreBuildPath(isolatedPaths));

    %% Clean MATLAB state before starting
    % Ensures no stale models, dictionaries, profiles, or requirement sets
    % from previous sessions interfere with the build.
    if bdIsLoaded('FCSSystem'), close_system('FCSSystem', 0); end
    Simulink.data.dictionary.closeAll('-discard');
    systemcomposer.profile.Profile.closeAll();
    slreq.clear();
    sltest.testmanager.clear();

    steps = {
        @buildFCSRequirements,  'Requirements (SN + SR sets, Derive links)';
        @buildFCSModel,         'Architecture model + interface dictionary';
        @buildFCSProfile,       'Budget profile + per-component estimates';
        @buildFCSAllocation,    'Requirements allocation (Refine links)';
        @rollupAnalysis,        'Power + mass roll-up analysis';
        @buildFCSTestCases,     'Test case requirements (Verify links to SRs)';
        @buildFCSSimulinkTests, 'Simulink Test file (linked to TC requirements)';
    };

    nSteps = size(steps, 1);
    tTotal = tic;

    fprintf('FCS MBSE Build\n');
    fprintf('%s\n', repmat('=', 1, 56));

    for i = 1:nSteps
        fn    = steps{i, 1};
        label = steps{i, 2};
        fprintf('\n[%d/%d]  %s\n', i, nSteps, label);
        fprintf('%s\n', repmat('-', 1, 56));
        t = tic;
        fn();
        fprintf('  Completed in %.1f s\n', toc(t));
    end

    fprintf('\n%s\n', repmat('=', 1, 56));
    fprintf('Build complete.  Total time: %.1f s\n', toc(tTotal));
end

% ── Path isolation helpers ────────────────────────────────────────────────────

function removedPaths = isolateBuildPath(filterToken)
% isolateBuildPath  Remove MATLAB path entries that contain filterToken.
%   Returns the removed entries so they can be restored later.
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
% restoreBuildPath  Re-add previously removed path entries.
    if ~isempty(removedPaths)
        addpath(removedPaths{:});
    end
end
