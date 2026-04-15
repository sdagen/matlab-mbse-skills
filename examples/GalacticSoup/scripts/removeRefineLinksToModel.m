function removeRefineLinksToModel(srSet, modelBasename)
% REMOVEREFINELINKSTOMODEL Remove SR Refine links whose destination lies in a given model.
%   Iterates all requirements in srSet and removes only Refine links whose
%   destination artifact (from getReferenceInfo) matches modelBasename. Used by
%   each per-phase allocation script so they can be re-run in any order without
%   wiping each other out.
%
%   Inputs:
%     srSet         - slreq.ReqSet handle (System Requirements set)
%     modelBasename - model file basename, e.g. "GalacticSoupFunctional" (string)

    reqs = srSet.find('Type', 'Requirement');
    for i = 1:numel(reqs)
        lnks = reqs(i).outLinks();
        for j = 1:numel(lnks)
            if ~strcmp(lnks(j).Type, 'Refine'), continue; end
            info = lnks(j).getReferenceInfo();
            [~, destBase, ~] = fileparts(info.artifact);
            if strcmp(destBase, char(modelBasename))
                lnks(j).remove();
            end
        end
    end
end
