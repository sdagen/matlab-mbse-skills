function buildTestCases()
% BUILDTESTCASES Create Tier 1 test-case requirements linked to System Requirements.
%   One TC per SR with a testable stimulus/measurement/pass-criterion, linked via
%   'Verify'. Budget-cap SRs (SR-GS-011..014) are intentionally skipped — those
%   are verified by runAnalysis.m and will show NOT COVERED in the coverage report.

    proj   = currentProject();
    reqDir = fullfile(proj.RootFolder, 'requirements');
    srFile = fullfile(reqDir, 'SystemRequirements.slreqx');
    tcFile = fullfile(reqDir, 'TestCases.slreqx');
    tcLink = strrep(tcFile, '.slreqx', '~slreqx.slmx');

    slreq.clear();
    if isfile(tcFile), delete(tcFile); end
    if isfile(tcLink), delete(tcLink); end
    srSet = slreq.load(srFile);
    % If SR's link file references TC, load may auto-load a stale TC set;
    % close it before creating the new one.
    existingTc = slreq.find('Type', 'ReqSet', 'Name', 'TestCases');
    if ~isempty(existingTc), existingTc.close(); end
    tcSet = slreq.new(tcFile);

    % Description is rendered as HTML by the Requirements Editor — literal
    % <, >, <=, >= get parsed as tags and truncate the display. Use words.
    tcs = {
      'TC-GS-001','Recipe count verification', ...
        'Load 8 distinct recipe selections via the HMI; confirm each produces a batch. Pass: all 8 produce nominal output.', ...
        'SR-GS-001';
      'TC-GS-002','Throughput test', ...
        'Run kitchen at full demand for 1 hour with representative recipe mix. Measure bowls completed. Pass: at least 200 bowls.', ...
        'SR-GS-002';
      'TC-GS-003','Automation level audit', ...
        'Record time spent in manual mode per component over a 24 h representative shift. Compute automationLevel per component. Pass: mean at least 0.80.', ...
        'SR-GS-003';
      'TC-GS-004','Concurrent operator count', ...
        'Observe crew present on the kitchen floor at peak demand. Pass: at most 5 simultaneous operators required.', ...
        'SR-GS-004';
      'TC-GS-005','Shipping manifest generation', ...
        'Complete one batch; inspect the generated manifest record. Pass: manifest exists with batchId, destination, timestamp, carrier.', ...
        'SR-GS-005';
      'TC-GS-006','Transport loading time', ...
        'Time from end-of-packaging to loaded-on-transport for 20 consecutive batches. Pass: all at most 10 min.', ...
        'SR-GS-006';
      'TC-GS-007','Contamination detection sensitivity', ...
        'Inject 100 spiked batches with known contaminant and 100 clean. Measure true-positive rate. Pass: at least 99%.', ...
        'SR-GS-007';
      'TC-GS-008','Serving temperature', ...
        'Measure soup temperature immediately before sealing, across 50 batches. Pass: all samples in 70-95 deg C.', ...
        'SR-GS-008';
      'TC-GS-009','Container seal-life', ...
        'Seal 30 containers; store under simulated 30-day interstellar transit. Inspect for leaks and spoilage. Pass: 0 leaks, acceptable shelf-life.', ...
        'SR-GS-009';
      'TC-GS-010','Inventory accuracy', ...
        'Physically count stored stock; compare against InventoryState. Pass: abs(actual - recorded) / recorded at most 1%.', ...
        'SR-GS-010';
      'TC-GS-015','Gravity operating range', ...
        'Run full functional test cycle at 0.1, 1, 6, and 12 g on centrifuge-simulator rig. Pass: all functions nominal at each setting.', ...
        'SR-GS-015';
      'TC-GS-016','Structural 12 g tolerance', ...
        'Subject structure to sustained 12 g loading on shake table or via FEA. Inspect for permanent deformation. Pass: FoS at least 1.5, no yield.', ...
        'SR-GS-016';
    };

    nLinks = 0;
    for i = 1:size(tcs,1)
        tc             = tcSet.add();
        tc.Id          = tcs{i,1};
        tc.Summary     = tcs{i,2};
        tc.Description = tcs{i,3};
        tc.Rationale   = ['Verifies ', tcs{i,4}];
        sr             = srSet.find('Id', tcs{i,4});
        lnk            = slreq.createLink(tc, sr);
        lnk.Type       = 'Verify';
        nLinks         = nLinks + 1;
    end
    slreq.saveAll();

    % Coverage: which SRs are covered by TCs and which fall to analysis
    allSrs = srSet.find('Type','Requirement');
    coveredIds = string({tcs{:,4}});
    fprintf('\nTC count       : %d\nVerify links   : %d\n\nCoverage:\n', size(tcs,1), nLinks);
    for i = 1:numel(allSrs)
        srId = string(allSrs(i).Id);
        if any(coveredIds == srId)
            fprintf('  [COVERED    ] %s  %s\n', srId, allSrs(i).Summary);
        else
            fprintf('  [NOT COVERED] %s  %s  (verified by runAnalysis)\n', srId, allSrs(i).Summary);
        end
    end

    registerWithProject({tcFile});
end
