function buildAll()
% BUILDALL Rebuild every GalacticSoup artifact from scratch and run project checks.

    t0 = tic;

    step('Requirements',            @buildRequirements);
    step('Functional',              @buildFunctional);
    step('Functional allocation',   @buildFunctionalAllocation);
    step('Logical',                 @buildLogical);
    step('Logical allocation',      @buildLogicalAllocation);
    step('Physical + profile',      @buildPhysical);
    step('Physical allocation',     @buildPhysicalAllocation);
    step('F->L allocation set',     @buildFunctionalToLogical);
    step('L->P allocation set',     @buildLogicalToPhysical);
    step('Analysis',                @runAnalysis);
    step('Test cases',              @buildTestCases);

    %% Register all scripts with the project
    scriptsDir  = fileparts(mfilename('fullpath'));
    scriptFiles = { ...
        fullfile(scriptsDir, 'buildAll.m'), ...
        fullfile(scriptsDir, 'buildRequirements.m'), ...
        fullfile(scriptsDir, 'buildFunctional.m'), ...
        fullfile(scriptsDir, 'buildFunctionalAllocation.m'), ...
        fullfile(scriptsDir, 'buildLogical.m'), ...
        fullfile(scriptsDir, 'buildLogicalAllocation.m'), ...
        fullfile(scriptsDir, 'buildPhysical.m'), ...
        fullfile(scriptsDir, 'buildPhysicalAllocation.m'), ...
        fullfile(scriptsDir, 'buildFunctionalToLogical.m'), ...
        fullfile(scriptsDir, 'buildLogicalToPhysical.m'), ...
        fullfile(scriptsDir, 'runAnalysis.m'), ...
        fullfile(scriptsDir, 'GalacticSoupRollupAnalysis.m'), ...
        fullfile(scriptsDir, 'buildTestCases.m'), ...
        fullfile(scriptsDir, 'removeImplementLinksToModel.m'), ...
        fullfile(scriptsDir, 'registerWithProject.m'), ...
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
            fprintf('%d check(s) failed -- review output above.\n', nFail);
        end
    end

    fprintf('\nbuildAll complete in %.1f s\n', toc(t0));
end

function step(label, fn)
    fprintf('\n==== %s ====\n', label);
    t = tic;
    fn();
    fprintf('  (%.1f s)\n', toc(t));
end
