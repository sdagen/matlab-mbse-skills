function removeImplementLinksToModel(srSet, modelBasename)
% REMOVEIMPLEMENTLINKSTOMODEL Remove Implement links from a given model into requirements in srSet.
%   Implement links go: architecture element (source) -> requirement (destination).
%   So from a requirement's perspective these are inLinks. This helper iterates
%   all requirements in srSet and removes any inLink of type 'Implement' whose
%   SOURCE artifact (from lnk.source()) lives in the named model. Used by each
%   per-phase allocation script so they can be re-run in any order without
%   wiping each other out.
%
%   Inputs:
%     srSet         - slreq.ReqSet handle (System Requirements set)
%     modelBasename - model file basename, e.g. "GalacticSoupFunctional" (string)

    reqs = srSet.find('Type', 'Requirement');
    for i = 1:numel(reqs)
        lnks = reqs(i).inLinks();
        for j = 1:numel(lnks)
            if ~strcmp(lnks(j).Type, 'Implement'), continue; end
            src = lnks(j).source();
            [~, srcBase, ~] = fileparts(src.artifact);
            if strcmp(srcBase, char(modelBasename))
                lnks(j).remove();
            end
        end
    end
end
