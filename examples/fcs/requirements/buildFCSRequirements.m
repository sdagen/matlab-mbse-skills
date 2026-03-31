function buildFCSRequirements()
% buildFCSRequirements  Create stakeholder needs and system requirements
%                       for the Flight Control System (FCS).
%
%   Generates two requirement sets:
%     StakeholderNeeds.slreqx    — operational-level needs (SN-FCS-xxx)
%     SystemRequirements.slreqx  — derived system requirements (SR-FCS-xxx)
%
%   Derivation links (type "Derive") trace each SR back to its parent SN.
%   Link direction: SR (child/source) -> SN (parent/destination).

    reqDir = fileparts(mfilename('fullpath'));
    snFile = fullfile(reqDir, 'StakeholderNeeds.slreqx');
    srFile = fullfile(reqDir, 'SystemRequirements.slreqx');

    %% Clean slate
    slreq.clear();
    if isfile(snFile), delete(snFile); end
    if isfile(srFile), delete(srFile); end

    %% Stakeholder Needs

    snSet = slreq.new(snFile);

    sn1 = addReq(snSet, 'SN-FCS-001', 'Pilot attitude command', ...
        "The pilot shall be able to command aircraft attitude in roll, pitch, and yaw using the control inceptors.", ...
        "Primary control function of the FCS; enables the pilot to maneuver the aircraft.");

    sn2 = addReq(snSet, 'SN-FCS-002', 'Aircraft stability', ...
        "The FCS shall maintain aircraft stability across the normal flight envelope without continuous pilot intervention.", ...
        "Reduces pilot workload and prevents departures from controlled flight.");

    sn3 = addReq(snSet, 'SN-FCS-003', 'Handling qualities', ...
        "The FCS shall provide handling qualities meeting Level 1 criteria as defined in MIL-STD-1797.", ...
        "Level 1 handling qualities are required for operational effectiveness and pilot acceptance.");

    sn4 = addReq(snSet, 'SN-FCS-004', 'Failure safety', ...
        "No single hardware or software failure shall result in loss of controlled flight.", ...
        "Mandatory safety requirement for airworthiness certification.");

    sn5 = addReq(snSet, 'SN-FCS-005', 'Maintainability', ...
        "The FCS shall be maintainable in the field using standard ground support equipment.", ...
        "Reduces life-cycle cost and aircraft downtime.");

    sn6 = addReq(snSet, 'SN-FCS-006', 'Platform SWaP constraints', ...
        "The FCS shall fit within the aircraft platform allocations for electrical power and equipment mass.", ...
        "The host aircraft imposes fixed power bus capacity and structural mass limits on installed avionics.");

    snSet.save();
    fprintf('Stakeholder needs:    %s  (%d items)\n', snFile, numel(snSet.find()));

    %% System Requirements

    srSet = slreq.new(srFile);

    % Derived from SN-FCS-001: command interface
    sr001 = addReq(srSet, 'SR-FCS-001', 'Roll rate command range', ...
        "The FCS shall accept roll rate commands in the range -180 to +180 deg/s from the pilot inceptors.", ...
        "Covers the full aerobatic roll envelope.");

    sr002 = addReq(srSet, 'SR-FCS-002', 'Pitch rate command range', ...
        "The FCS shall accept pitch rate commands in the range -30 to +30 deg/s from the pilot inceptors.", ...
        "Covers normal and emergency pitch maneuvers.");

    sr003 = addReq(srSet, 'SR-FCS-003', 'Yaw rate command range', ...
        "The FCS shall accept yaw rate commands in the range -30 to +30 deg/s from the pilot inceptors.", ...
        "Covers coordinated turns and crosswind operations.");

    % Derived from SN-FCS-002: stability
    sr004 = addReq(srSet, 'SR-FCS-004', 'Pitch attitude hold accuracy', ...
        "The FCS shall maintain pitch attitude within 0.5 deg of the commanded value in steady-state at all airspeeds within the normal flight envelope.", ...
        "Minimum accuracy for instrument flight procedures.");

    sr005 = addReq(srSet, 'SR-FCS-005', 'Roll attitude hold accuracy', ...
        "The FCS shall maintain roll attitude within 1.0 deg of the commanded value in steady-state at all airspeeds within the normal flight envelope.", ...
        "Minimum accuracy for instrument flight procedures.");

    sr006 = addReq(srSet, 'SR-FCS-006', 'Control loop stability margins', ...
        "The FCS shall provide a minimum phase margin of 45 deg and gain margin of 6 dB at all control loop crossover frequencies.", ...
        "Standard robustness margins for flight control; complies with MIL-HDBK-1797.");

    % Derived from SN-FCS-003: handling qualities / responsiveness
    sr007 = addReq(srSet, 'SR-FCS-007', 'Control loop execution rate', ...
        "The FCS control laws shall execute at a minimum rate of 100 Hz.", ...
        "Required to achieve Level 1 bandwidth per MIL-STD-1797.");

    sr008 = addReq(srSet, 'SR-FCS-008', 'End-to-end command latency', ...
        "The FCS shall respond to pilot inceptor inputs with an end-to-end latency not exceeding 100 ms, measured from inceptor deflection to control surface position change.", ...
        "Required for Level 1 handling qualities; excessive latency degrades pilot-vehicle coupling.");

    % Derived from SN-FCS-004: failure safety
    sr009 = addReq(srSet, 'SR-FCS-009', 'Redundant computation', ...
        "The FCS shall implement dual-redundant flight computers with automatic failover upon detection of a failure in the active channel.", ...
        "Ensures continued flight control following a single computer failure.");

    sr010 = addReq(srSet, 'SR-FCS-010', 'Failure detection latency', ...
        "The FCS shall detect and isolate a single hardware failure within 50 ms of occurrence.", ...
        "Limits crew exposure time after a failure; aligns with DO-178C objectives.");

    sr011 = addReq(srSet, 'SR-FCS-011', 'Power supply redundancy', ...
        "The FCS shall operate from a minimum of two electrically independent power supply paths, with automatic switchover upon loss of the primary path.", ...
        "Power loss must not result in loss of flight control capability.");

    % Derived from SN-FCS-005: maintainability
    sr012 = addReq(srSet, 'SR-FCS-012', 'Built-in test coverage', ...
        "The FCS built-in test equipment (BITE) shall achieve a fault detection coverage of no less than 95% of all detectable faults during power-on and continuous monitoring.", ...
        "Reduces reliance on external test equipment and shortens fault isolation time.");

    sr013 = addReq(srSet, 'SR-FCS-013', 'Maintenance data bus', ...
        "The FCS shall provide a maintenance data bus interface compliant with ARINC 604 for interrogation by standard ground support equipment.", ...
        "Enables use of common GSE across the fleet; reduces training burden.");

    % Derived from SN-FCS-006: SWaP
    sr014 = addReq(srSet, 'SR-FCS-014', 'Total power budget', ...
        "The total electrical power consumed by all FCS equipment shall not exceed 450 W.", ...
        "Platform power bus allocation for avionics; margin held by aircraft integrator.");

    sr015 = addReq(srSet, 'SR-FCS-015', 'Total mass budget', ...
        "The total mass of all FCS equipment shall not exceed 35 kg.", ...
        "Structural mass allocation from the aircraft weight and balance budget.");

    srSet.save();
    fprintf('System requirements:  %s  (%d items)\n', srFile, numel(srSet.find()));

    %% Derivation Links: SR (child) -> SN (parent), type = "Derive"

    % SN-FCS-001: command interface
    derive(sr001, sn1);
    derive(sr002, sn1);
    derive(sr003, sn1);

    % SN-FCS-002: stability
    derive(sr004, sn2);
    derive(sr005, sn2);
    derive(sr006, sn2);

    % SN-FCS-003: handling qualities
    derive(sr007, sn3);
    derive(sr008, sn3);

    % SN-FCS-004: failure safety
    derive(sr009, sn4);
    derive(sr010, sn4);
    derive(sr011, sn4);

    % SN-FCS-005: maintainability
    derive(sr012, sn5);
    derive(sr013, sn5);

    % SN-FCS-006: SWaP
    derive(sr014, sn6);
    derive(sr015, sn6);

    slreq.saveAll();
    fprintf('Derivation links:     15 (SR -> SN)\n');
    fprintf('Done.\n');
end

% ── Helpers ──────────────────────────────────────────────────────────────────

function req = addReq(reqSet, id, summary, description, rationale)
% addReq  Add a requirement with standard fields to a requirement set.
    req             = reqSet.add();
    req.Id          = id;
    req.Summary     = summary;
    req.Description = description;
    req.Rationale   = rationale;
end

function lnk = derive(child, parent)
% derive  Create a Derive link from a child requirement to its parent.
    lnk      = slreq.createLink(child, parent);
    lnk.Type = 'Derive';
end
