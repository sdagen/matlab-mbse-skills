function buildFCSAllocation()
% buildFCSAllocation  Allocate FCS system requirements to architectural
%                     components with bidirectional traceability links.
%
%   Creates "Refine" links from each system requirement (SR-FCS-xxx) to the
%   architectural component(s) responsible for implementing it.  Any existing
%   Refine links are removed and rebuilt from scratch on every run.
%
%   Link direction:  SR (source) --> Component (destination), Type = "Refine"
%
%   Bidirectional navigation after running this script:
%     Forward  (req -> components): slreq.outLinks(req)   filter Type=="Refine"
%     Reverse  (comp -> reqs):      slreq.inLinks(comp)   all are Refine links

    fcsDir  = fileparts(fileparts(mfilename('fullpath')));
    reqDir  = fullfile(fcsDir, 'requirements');
    archDir = fullfile(fcsDir, 'architecture');
    srFile  = fullfile(reqDir, 'SystemRequirements.slreqx');

    %% Open requirements and model
    % addpath(reqDir) before slreq.clear() keeps .slmx paths relative
    addpath(reqDir);
    slreq.clear();
    srSet = slreq.open(srFile);
    addpath(archDir);
    model = systemcomposer.openModel('FCSSystem');
    arch  = model.Architecture;

    %% Remove any existing Refine links (idempotent rebuild)
    allSRs = srSet.find();
    for i = 1:numel(allSRs)
        lnks = slreq.outLinks(allSRs(i));
        for j = 1:numel(lnks)
            if strcmp(lnks(j).Type, 'Refine')
                lnks(j).remove();
            end
        end
    end

    %% Allocation table: { 'SR-ID', { component names } }
    allocation = {
        'SR-FCS-001', { 'PilotInterface', 'FlightComputer'                              };
        'SR-FCS-002', { 'PilotInterface', 'FlightComputer'                              };
        'SR-FCS-003', { 'PilotInterface', 'FlightComputer'                              };
        'SR-FCS-004', { 'FlightComputer', 'SensorSuite',   'ActuatorSystem'             };
        'SR-FCS-005', { 'FlightComputer', 'SensorSuite',   'ActuatorSystem'             };
        'SR-FCS-006', { 'FlightComputer'                                                };
        'SR-FCS-007', { 'FlightComputer'                                                };
        'SR-FCS-008', { 'FlightComputer', 'SensorSuite',   'ActuatorSystem', 'DataBus' };
        'SR-FCS-009', { 'FlightComputer'                                                };
        'SR-FCS-010', { 'FlightComputer', 'DataBus'                                     };
        'SR-FCS-011', { 'PowerSystem'                                                   };
        'SR-FCS-012', { 'FlightComputer', 'DataBus'                                     };
        'SR-FCS-013', { 'DataBus'                                                       };
    };

    %% Create links
    linkCount = 0;
    for i = 1:size(allocation, 1)
        srId    = allocation{i, 1};
        compNames = allocation{i, 2};
        req = srSet.find('Id', srId);
        for j = 1:numel(compNames)
            comp = arch.getComponent(compNames{j});
            lnk  = slreq.createLink(req, comp);
            lnk.Type = 'Refine';
            linkCount = linkCount + 1;
        end
    end

    slreq.saveAll();
    fprintf('Allocation links created: %d (SR -> component, Type=Refine)\n\n', linkCount);

    %% Report: Requirements -> Components (forward traceability)
    fprintf('%-16s  %-40s  Components\n', 'ID', 'Summary');
    fprintf('%s\n', repmat('-', 1, 90));
    for i = 1:size(allocation, 1)
        req  = srSet.find('Id', allocation{i, 1});
        outL = slreq.outLinks(req);
        compNames = {};
        for j = 1:numel(outL)
            if strcmp(outL(j).Type, 'Refine')
                dst  = outL(j).destination;
                mn   = strrep(dst.artifact, '.slx', '');
                h    = Simulink.ID.getHandle([mn, dst.id]);
                compNames{end+1} = get_param(h, 'Name'); %#ok<AGROW>
            end
        end
        fprintf('%-16s  %-40s  %s\n', req.Id, req.Summary, strjoin(compNames, ', '));
    end

    %% Report: Components -> Requirements (reverse traceability)
    fprintf('\n%-20s  Allocated requirements\n', 'Component');
    fprintf('%s\n', repmat('-', 1, 90));
    compList = { 'FlightComputer', 'PilotInterface', 'SensorSuite', ...
                 'ActuatorSystem', 'PowerSystem',    'DataBus' };
    for i = 1:numel(compList)
        comp = arch.getComponent(compList{i});
        inL  = slreq.inLinks(comp);
        reqIds = {};
        for j = 1:numel(inL)
            rs2  = slreq.open(inL(j).source.artifact);
            reqs = rs2.find();
            for k = 1:numel(reqs)
                if reqs(k).SID == str2double(inL(j).source.id)
                    reqIds{end+1} = reqs(k).Id; %#ok<AGROW>
                    break;
                end
            end
        end
        fprintf('%-20s  %s\n', compList{i}, strjoin(reqIds, ', '));
    end
end
