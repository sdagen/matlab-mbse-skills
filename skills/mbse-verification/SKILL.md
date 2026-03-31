---
name: mbse-verification
description: >
  Use this skill to create formal test cases and link them to requirements in MATLAB
  Requirements Toolbox. Trigger when the user wants to create test cases, set up
  verification links between test cases and requirements, check requirement verification
  coverage, or build a verification traceability matrix. Use this skill proactively
  whenever the user has a set of system requirements and wants to define how each will
  be verified.
---

# MBSE Phase 6: Test Cases & Verification

---

## Structure

Test cases live in their own requirement set (`TestCases.slreqx`), separate
from system requirements. Each test case is an `slreq.Requirement` with:

| Field | Content |
|---|---|
| `Id` | `TC-SYS-001` |
| `Summary` | Short test name |
| `Description` | Method + pass criteria (what you do, what constitutes pass) |
| `Rationale` | Which SR this verifies — e.g. `"Verifies SR-SYS-001"` |

---

## Link Type

Use `"Verify"` for test case → requirement:

```matlab
lnk = slreq.createLink(tc, sr);   % tc=source, sr=destination
lnk.Type = 'Verify';
```

---

## Description Content

A good test case description answers three questions:
1. **Setup** — initial conditions and configuration
2. **Action** — what stimulus or procedure is applied
3. **Pass criterion** — the measurable result that constitutes success

Avoid `<` and `>` in description text — the Requirements Editor treats them as
HTML tags and will warn. Use "not exceeding", "at least", "greater than", etc.

---

## Coverage Report

Check which SRs have at least one TC linked to them:

```matlab
allSRs    = srSet.find();
covered   = 0;

for i = 1:numel(allSRs)
    inL   = slreq.inLinks(allSRs(i));
    tcIds = {};
    for j = 1:numel(inL)
        if strcmp(inL(j).Type, 'Verify')
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
        fprintf('NOT COVERED: %s - %s\n', allSRs(i).Id, allSRs(i).Summary);
    else
        covered = covered + 1;
    end
end
fprintf('Coverage: %d / %d  (%.0f%%)\n', covered, numel(allSRs), ...
    100 * covered / numel(allSRs));
```

---

## Skeleton

```matlab
function buildMyTestCases()
    reqDir = fullfile(fileparts(mfilename('fullpath')), '..', 'requirements');
    srFile = fullfile(reqDir, 'SystemRequirements.slreqx');
    tcFile = fullfile(reqDir, 'TestCases.slreqx');

    slreq.clear();
    srSet = slreq.open(srFile);
    if isfile(tcFile), delete(tcFile); end
    tcSet = slreq.new(tcFile);

    % { TC-ID, Summary, Description, SR-ID }
    testCases = {
        'TC-SYS-001', 'Acceptance test for SR-001', ...
            ['Apply stimulus X. Verify that output Y meets criterion Z.'], ...
            'SR-SYS-001';
        % ...
    };

    for i = 1:size(testCases, 1)
        tc             = tcSet.add();
        tc.Id          = testCases{i, 1};
        tc.Summary     = testCases{i, 2};
        tc.Description = testCases{i, 3};
        tc.Rationale   = ['Verifies ', testCases{i, 4}];

        sr      = srSet.find('Id', testCases{i, 4});
        lnk     = slreq.createLink(tc, sr);
        lnk.Type = 'Verify';
    end

    slreq.saveAll();
    fprintf('%d test cases created.\n', numel(tcSet.find()));
end
```
