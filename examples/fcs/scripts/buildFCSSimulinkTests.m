function buildFCSSimulinkTests()
% buildFCSSimulinkTests  Create a Simulink Test file for the FCS and link
%                        each test case to its requirement in TestCases.slreqx.
%
%   Generates:
%     FCSTests.mldatx  — Simulink Test file with one test case per TC requirement,
%                        grouped into suites by functional area.
%
%   Each sltest test case carries:
%     - Name        = TC identifier (e.g. TC-FCS-001)
%     - Description = test procedure from the TC requirement
%     - Tags        = functional area tag
%     - Requirement link (Verify) back to the corresponding slreq.Requirement
%
%   Prerequisite: run buildFCSTestCases() before this script.

    scriptDir = fileparts(mfilename('fullpath'));
    reqDir    = fullfile(scriptDir, '..', 'requirements');
    verDir    = fullfile(scriptDir, '..', 'verification');
    tcFile  = fullfile(reqDir, 'TestCases.slreqx');
    mldatx  = fullfile(verDir, 'FCSTests.mldatx');

    %% Open TC requirement set
    addpath(reqDir);
    slreq.clear();
    tcSet = slreq.open(tcFile);

    %% Create test file (rebuild from scratch each run)
    sltest.testmanager.clear();
    if isfile(mldatx), delete(mldatx); end
    tf = sltest.testmanager.TestFile(mldatx);
    tf.Description = 'FCS system-level verification tests. One test case per TC requirement.';

    % TestFile auto-creates a default "New Test Suite 1" — remove it
    defaultSuites = tf.getTestSuites();
    for i = 1:numel(defaultSuites)
        remove(defaultSuites(i));
    end

    %% Suite definitions — grouped by functional area / stakeholder need
    %   { SuiteName, Tag, { TC-IDs... } }
    suites = {
        'Command Interface',  'command',     { 'TC-FCS-001', 'TC-FCS-002', 'TC-FCS-003' };
        'Stability',          'stability',   { 'TC-FCS-004', 'TC-FCS-005', 'TC-FCS-006' };
        'Handling Qualities', 'handling',    { 'TC-FCS-007', 'TC-FCS-008'               };
        'Failure Safety',     'safety',      { 'TC-FCS-009', 'TC-FCS-010', 'TC-FCS-011' };
        'Maintainability',    'maintain',    { 'TC-FCS-012', 'TC-FCS-013'               };
    };

    totalCreated = 0;

    for s = 1:size(suites, 1)
        suiteName = suites{s, 1};
        tag       = suites{s, 2};
        tcIds     = suites{s, 3};

        suite = createTestSuite(tf, suiteName);
        suite.Tags = tag;

        for t = 1:numel(tcIds)
            tcId  = tcIds{t};
            tcReq = tcSet.find('Id', tcId);

            if isempty(tcReq)
                warning('buildFCSSimulinkTests:notFound', ...
                    'TC requirement %s not found in %s — skipped.', tcId, tcFile);
                continue;
            end

            % Create the sltest test case
            stc             = createTestCase(suite, 'simulation', tcId);
            stc.Description = tcReq.Description;
            stc.Tags        = tag;

            % Link: sltest TC (source) -> slreq TC requirement (destination)
            lnk      = slreq.createLink(stc, tcReq);
            lnk.Type = 'Verify';

            totalCreated = totalCreated + 1;
        end
    end

    %% Save
    saveToFile(tf);
    slreq.saveAll();

    fprintf('Simulink Test file created: %s\n', mldatx);
    fprintf('Test cases created:         %d\n', totalCreated);
    fprintf('Suites:                     %d\n', size(suites, 1));
    fprintf('\nOpen in Test Manager: sltest.testmanager.view()\n');
    fprintf('Load file:            sltest.testmanager.load(''%s'')\n', mldatx);
end
