function buildFCSTestCases()
% buildFCSTestCases  Create formal test cases and link them to FCS system
%                   requirements with bidirectional verification traceability.
%
%   Generates:
%     TestCases.slreqx  — one test case per system requirement (TC-FCS-xxx)
%
%   Verification links (type "Verify") trace each TC to the SR it verifies.
%   Link direction: TC (source) --> SR (destination), Type = "Verify"
%
%   Bidirectional navigation:
%     Forward  (TC -> SR):  slreq.outLinks(tc)  filter Type=="Verify"
%     Reverse  (SR -> TCs): slreq.inLinks(sr)   all are Verify links
%
%   Run buildFCSRequirements() before this script.

    reqDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'requirements');
    srFile = fullfile(reqDir, 'SystemRequirements.slreqx');
    tcFile = fullfile(reqDir, 'TestCases.slreqx');

    %% Open SR set; rebuild TC set from scratch
    % Also delete the TC link file — stale Verify links could trigger
    % auto-loading of the architecture model and its data dictionary.
    % addpath(reqDir) before slreq.clear() keeps .slmx paths relative.
    addpath(reqDir);
    slreq.clear();
    tcLinkFile = fullfile(reqDir, 'TestCases~slreqx.slmx');
    if isfile(tcFile),     delete(tcFile);     end
    if isfile(tcLinkFile), delete(tcLinkFile); end
    srSet = slreq.open(srFile);
    tcSet = slreq.new(tcFile);

    %% Test cases
    %   Each row: { TC-ID, Summary, Description (method + pass criteria), SR-ID }
    testCases = {
        'TC-FCS-001', 'Roll rate command acceptance', ...
            ['Apply roll rate commands at -180, 0, and +180 deg/s via the pilot inceptor ' ...
             'interface. Verify that the FCS accepts and processes all commands without ' ...
             'saturation or rejection.'], ...
            'SR-FCS-001';

        'TC-FCS-002', 'Pitch rate command acceptance', ...
            ['Apply pitch rate commands at -30, 0, and +30 deg/s via the pilot inceptor ' ...
             'interface. Verify that the FCS accepts and processes all commands without ' ...
             'saturation or rejection.'], ...
            'SR-FCS-002';

        'TC-FCS-003', 'Yaw rate command acceptance', ...
            ['Apply yaw rate commands at -30, 0, and +30 deg/s via the pilot inceptor ' ...
             'interface. Verify that the FCS accepts and processes all commands without ' ...
             'saturation or rejection.'], ...
            'SR-FCS-003';

        'TC-FCS-004', 'Pitch attitude hold accuracy', ...
            ['Command a series of pitch attitudes across the flight envelope. After ' ...
             'transient settling, record steady-state pitch error. Pass criterion: ' ...
             'error not exceeding 0.5 deg at all test points.'], ...
            'SR-FCS-004';

        'TC-FCS-005', 'Roll attitude hold accuracy', ...
            ['Command a series of roll attitudes across the flight envelope. After ' ...
             'transient settling, record steady-state roll error. Pass criterion: ' ...
             'error not exceeding 1.0 deg at all test points.'], ...
            'SR-FCS-005';

        'TC-FCS-006', 'Control loop stability margins', ...
            ['Inject frequency sweeps at each control loop breakout point. Compute ' ...
             'open-loop frequency response. Pass criterion: phase margin of at least 45 deg ' ...
             'and gain margin of at least 6 dB at all crossover frequencies.'], ...
            'SR-FCS-006';

        'TC-FCS-007', 'Control loop execution rate', ...
            ['Instrument the flight computer control law task. Record execution ' ...
             'timestamps over 10 seconds of operation. Pass criterion: measured rate ' ...
             'of at least 100 Hz with jitter not exceeding 1 ms.'], ...
            'SR-FCS-007';

        'TC-FCS-008', 'End-to-end command latency', ...
            ['Apply a step input at the pilot inceptor and record control surface ' ...
             'position response using high-speed data acquisition. Pass criterion: ' ...
             'time from inceptor deflection to first surface movement not exceeding 100 ms.'], ...
            'SR-FCS-008';

        'TC-FCS-009', 'Automatic failover on computer failure', ...
            ['With the system operational, inject a simulated primary flight computer ' ...
             'failure. Verify that the standby channel assumes control. Pass criterion: ' ...
             'flight control maintained with no pilot intervention; failover logged.'], ...
            'SR-FCS-009';

        'TC-FCS-010', 'Failure detection latency', ...
            ['Inject a single hardware fault at a known test point. Measure time from ' ...
             'fault injection to BITE fault flag assertion. Pass criterion: ' ...
             'detection and isolation not exceeding 50 ms.'], ...
            'SR-FCS-010';

        'TC-FCS-011', 'Power supply redundancy and switchover', ...
            ['With the system operational, remove primary power. Verify that secondary ' ...
             'power path activates and flight control is maintained. Pass criterion: ' ...
             'no loss of control; switchover time not exceeding 20 ms.'], ...
            'SR-FCS-011';

        'TC-FCS-012', 'BITE fault detection coverage', ...
            ['Execute the BITE test sequence against the fault catalogue. Record ' ...
             'detected vs total detectable faults. Pass criterion: ' ...
             'detection coverage of at least 95%.'], ...
            'SR-FCS-012';

        'TC-FCS-013', 'Maintenance data bus compliance', ...
            ['Connect standard ARINC 604-compliant GSE to the maintenance bus port. ' ...
             'Execute the standard interrogation sequence. Pass criterion: all mandatory ' ...
             'ARINC 604 labels transmitted and received within timing tolerances.'], ...
            'SR-FCS-013';
    };

    %% Create test case requirements and verification links
    for i = 1:size(testCases, 1)
        tcId   = testCases{i, 1};
        tcSum  = testCases{i, 2};
        tcDesc = testCases{i, 3};
        srId   = testCases{i, 4};

        tc          = tcSet.add();
        tc.Id          = tcId;
        tc.Summary     = tcSum;
        tc.Description = tcDesc;
        tc.Rationale   = ['Verifies ', srId];

        sr  = srSet.find('Id', srId);
        lnk = slreq.createLink(tc, sr);
        lnk.Type = 'Verify';
    end

    slreq.saveAll();
    fprintf('Test cases created: %d  (%s)\n', numel(tcSet.find()), tcFile);

    %% Verification coverage report
    allSRs = srSet.find();
    covered   = 0;
    uncovered = 0;

    fprintf('\nVerification Coverage Report\n');
    fprintf('%s\n', repmat('─', 1, 80));
    fprintf('%-16s  %-40s  %s\n', 'SR ID', 'Summary', 'Test Cases');
    fprintf('%s\n', repmat('─', 1, 80));

    for i = 1:numel(allSRs)
        sr   = allSRs(i);
        inL  = slreq.inLinks(sr);

        tcIds = {};
        for j = 1:numel(inL)
            if strcmp(inL(j).Type, 'Verify')
                % Resolve TC requirement from source link struct
                tcSetObj = slreq.open(inL(j).source.artifact);
                allTCs   = tcSetObj.find();
                for k = 1:numel(allTCs)
                    if allTCs(k).SID == str2double(inL(j).source.id)
                        tcIds{end+1} = allTCs(k).Id; %#ok<AGROW>
                        break;
                    end
                end
            end
        end

        if isempty(tcIds)
            status = '*** NOT COVERED ***';
            uncovered = uncovered + 1;
        else
            status = strjoin(tcIds, ', ');
            covered = covered + 1;
        end
        fprintf('%-16s  %-40s  %s\n', sr.Id, sr.Summary, status);
    end

    fprintf('%s\n', repmat('─', 1, 80));
    fprintf('Coverage: %d / %d requirements verified  (%.0f%%)\n', ...
        covered, numel(allSRs), 100 * covered / numel(allSRs));
    fprintf('Note: SR-FCS-014 and SR-FCS-015 (budget caps) are verified by\n');
    fprintf('      rollupAnalysis — expected NOT COVERED in this report.\n');

    %% Register with project
    registerWithProject({tcFile});
end
