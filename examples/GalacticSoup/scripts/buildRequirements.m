function buildRequirements()
% BUILDREQUIREMENTS Create GalacticSoup stakeholder needs and system requirements.
%   Idempotent: deletes and recreates both .slreqx sets and their .slmx link
%   files on every run.

    proj    = currentProject();
    reqDir  = fullfile(proj.RootFolder, 'requirements');
    snFile  = fullfile(reqDir, 'StakeholderNeeds.slreqx');
    srFile  = fullfile(reqDir, 'SystemRequirements.slreqx');

    slreq.clear();
    for f = {snFile, srFile, ...
             strrep(snFile, '.slreqx', '~slreqx.slmx'), ...
             strrep(srFile, '.slreqx', '~slreqx.slmx')}
        if isfile(f{1}), delete(f{1}); end
    end

    %% Stakeholder Needs
    snSet = slreq.new(snFile);
    sn = containers.Map('KeyType','char','ValueType','any');
    sn('001') = addReq(snSet, 'SN-GS-001', 'Soup menu', ...
        "Kitchen shall produce a menu of distinct soup varieties selectable by operators.", ...
        "Customers expect variety across the menu.");
    sn('002') = addReq(snSet, 'SN-GS-002', 'Small crew', ...
        "Kitchen shall be operable by the small crew of beings on site.", ...
        "Only 5 beings staff the facility.");
    sn('003') = addReq(snSet, 'SN-GS-003', 'Galactic shipping', ...
        "Kitchen shall dispatch finished soup to customers across the galaxy.", ...
        "Customers are distributed across many worlds.");
    sn('004') = addReq(snSet, 'SN-GS-004', 'Food safety', ...
        "Kitchen shall deliver safe, uncontaminated soup at correct serving temperature.", ...
        "Safety and quality are non-negotiable.");
    sn('005') = addReq(snSet, 'SN-GS-005', 'Transit-durable packaging', ...
        "Packaging shall keep soup intact during long-distance interstellar transit.", ...
        "Shipments take weeks to reach far customers.");
    sn('006') = addReq(snSet, 'SN-GS-006', 'Inventory tracking', ...
        "Kitchen shall track ingredient stock so the crew knows what to reorder.", ...
        "Stock-outs halt production; crew needs visibility.");
    sn('007') = addReq(snSet, 'SN-GS-007', 'Facility budgets', ...
        "Kitchen shall fit within facility mass, volume, power, and cost budgets.", ...
        "Deployment site imposes hard resource limits.");
    sn('008') = addReq(snSet, 'SN-GS-008', 'Gravity range', ...
        "Kitchen shall operate across the range of gravitational environments where customer worlds are located.", ...
        "Facility may be deployed on any of a diverse set of worlds.");
    snSet.save();

    %% System Requirements
    srSet = slreq.new(srFile);
    % Description is stored as HTML by slreq — literal <, >, <=, >= get
    % parsed as (mal-formed) tags and the Requirements Editor silently
    % drops everything from the first < through the next >. Use words
    % ("at least", "at most", "not exceeding") instead.
    srSpec = {
      % id,              summary,                  parent, description,                                                                                                                           rationale
      'SR-GS-001','Recipe count',                 '001', "System shall cook at least 8 distinct recipes selectable at runtime.",                                                                 "Eight recipes gives menu variety while staying within ingredient storage and recipe-validation budgets."
      'SR-GS-002','Throughput',                   '001', "System shall sustain total throughput of at least 200 bowls/hour.",                                                                    "200 bowls/hour matches expected peak order rate aggregated across customer worlds."
      'SR-GS-003','Automation level',             '002', "System shall achieve average automation level of at least 0.8 across components.",                                                     "0.8 automation lets the 5-operator crew cover a 24/7 facility with rotation and breaks."
      'SR-GS-004','Operator count',               '002', "System shall require at most 5 concurrent operators at peak load.",                                                                    "Facility berthing and life support are sized for a 5-person crew."
      'SR-GS-005','Shipping manifest',            '003', "System shall generate a shipping manifest per batch including destination.",                                                           "Manifest is required for customs, transport routing, and recipient confirmation on delivery."
      'SR-GS-006','Transport loading time',       '003', "System shall load packaged soup onto transport within 10 minutes of packaging.",                                                       "10-minute window keeps loading pipeline aligned with the 200 bowls/hour production rate."
      'SR-GS-007','Contamination detection',      '004', "System shall detect contamination before sealing with at least 99% sensitivity.",                                                      "99% sensitivity balances false-positive rework cost against the downstream cost of a contaminated shipment."
      'SR-GS-008','Serving temperature',          '004', "System shall verify soup temperature in 70-95 C before QC sign-off.",                                                                  "70-95 C is the safe serving range: above pathogen-kill threshold and below scald risk."
      'SR-GS-009','Container seal life',          '005', "System shall seal containers rated for 30-day interstellar transit.",                                                                  "30 days covers typical transit time to the farthest customer worlds with margin."
      'SR-GS-010','Inventory accuracy',           '006', "System shall track ingredient inventory with at most 1% stock error.",                                                                 "1% stock error keeps reorder decisions accurate enough to avoid production-halting stock-outs."
      'SR-GS-011','Mass budget',                  '007', "Total system mass shall not exceed 15000 kg.",                                                                                         "Allocated from the facility deployment mass budget."
      'SR-GS-012','Power budget',                 '007', "Total system power draw shall not exceed 500 kW.",                                                                                     "Allocated from the facility power budget."
      'SR-GS-013','Cost budget',                  '007', "Total system cost shall not exceed 2000000 credits.",                                                                                  "Allocated from the facility capital cost budget."
      'SR-GS-014','Volume budget',                '007', "Total system volume shall not exceed 400 m^3.",                                                                                        "Allocated from the facility floor-space and volume budget."
      'SR-GS-015','Gravity operating range',      '008', "System shall perform all cooking, packaging, and shipping functions nominally across ambient gravity 0.1 g to 12 g.",                  "0.1-12 g spans the full ambient gravity range across candidate customer worlds."
      'SR-GS-016','Structural 12 g tolerance',    '008', "System structure and mounts shall withstand sustained 12 g loading without permanent deformation.",                                    "12 g is the worst-case sustained ambient gravity among customer worlds."
    };

    nLinks = 0;
    for i = 1:size(srSpec,1)
        sr = addReq(srSet, srSpec{i,1}, srSpec{i,2}, srSpec{i,4}, srSpec{i,5});
        % Derive link: SN (source, parent) -> SR (destination, derived child).
        lnk = slreq.createLink(sn(srSpec{i,3}), sr);
        lnk.Type = 'Derive';
        nLinks = nLinks + 1;
    end
    srSet.save();
    slreq.saveAll();

    nSN = numel(find(snSet, 'Type', 'Requirement'));
    nSR = numel(find(srSet, 'Type', 'Requirement'));
    fprintf('Stakeholder Needs  : %d\n', nSN);
    fprintf('System Requirements: %d\n', nSR);
    fprintf('Derive links       : %d\n', nLinks);

    % StakeholderNeeds~slreqx.slmx is the link store created by slreq when
    % Derive links are added with SN as the source. Lives next to the .slreqx.
    registerWithProject({ ...
        snFile, ...
        srFile, ...
        fullfile(reqDir, 'StakeholderNeeds~slreqx.slmx'), ...
    });
end

function req = addReq(rs, id, summary, description, rationale)
    req             = rs.add();
    req.Id          = id;
    req.Summary     = summary;
    req.Description = description;
    req.Rationale   = rationale;
end
