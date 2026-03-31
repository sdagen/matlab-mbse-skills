---
name: mbse-requirements
description: >
  Use this skill when creating or editing MATLAB Requirements Toolbox requirement sets
  programmatically — stakeholder needs, system requirements, or test cases. Trigger on:
  creating .slreqx files, writing shall-statements, setting up requirement ID schemes,
  creating derivation or verification links between requirement levels, or any programmatic
  requirements management with the slreq API. Use this skill proactively whenever the user
  is starting the requirements phase of an MBSE workflow.
---

# MBSE Phase 1–2: Requirements

---

## Two-Level Structure

| Level | ID scheme | Character |
|---|---|---|
| Stakeholder Needs | `SN-SYS-001` | Operational, informal — what the user/operator needs |
| System Requirements | `SR-SYS-001` | Formal, testable — what the system shall do |

Each SR traces back to one or more SNs via a `Derive` link.

---

## Well-Formed Shall-Statements

- One obligation per requirement ("shall", not "should" or "will")
- Measurable and testable — include numeric criteria where possible
- Avoid `<` and `>` characters in Description fields; the Requirements Editor
  treats them as HTML. Use "not exceeding", "at least", "greater than", etc.

**Good:** `The FCS shall respond to pilot inputs with an end-to-end latency not exceeding 100 ms.`
**Avoid:** `The FCS shall respond to pilot inputs with latency < 100 ms.`

---

## slreq API Patterns

### Create and populate a requirement set

```matlab
slreq.clear();
if isfile('MyReqs.slreqx'), delete('MyReqs.slreqx'); end
rs = slreq.new('MyReqs.slreqx');        % NOT slreq.createReqSet (does not exist)

req = rs.add();                          % no Type argument — always returns slreq.Requirement
req.Id          = 'SR-SYS-001';
req.Summary     = 'Short title';
req.Description = 'The system shall ...';
req.Rationale   = 'Why this requirement exists.';

rs.save();
fprintf('%d requirements\n', numel(rs.find()));
```

### Find a requirement by ID

```matlab
req = rs.find('Id', 'SR-SYS-001');     % returns slreq.Requirement
```

### Valid link types

| Type | Meaning | Typical direction |
|---|---|---|
| `"Derive"` | Child requirement derived from parent | SR (source) --> SN (destination) |
| `"Refine"` | Architecture element implements requirement | SR (source) --> Component (destination) |
| `"Verify"` | Test case verifies requirement | TC (source) --> SR (destination) |
| `"Relate"` | Generic association | either direction |

### Create a derivation link

```matlab
lnk = slreq.createLink(childReq, parentReq);
lnk.Type = 'Derive';
```

### Save everything (including cross-set links)

```matlab
slreq.saveAll();
```

---

## Skeleton

```matlab
function buildMyRequirements()
    reqDir = fileparts(mfilename('fullpath'));
    snFile = fullfile(reqDir, 'StakeholderNeeds.slreqx');
    srFile = fullfile(reqDir, 'SystemRequirements.slreqx');

    slreq.clear();
    if isfile(snFile), delete(snFile); end
    if isfile(srFile), delete(srFile); end

    %% Stakeholder Needs
    snSet = slreq.new(snFile);
    sn1 = addReq(snSet, 'SN-SYS-001', 'Short title', ...
        "The operator shall be able to ...", ...
        "Rationale for this need.");
    snSet.save();

    %% System Requirements
    srSet = slreq.new(srFile);
    sr1 = addReq(srSet, 'SR-SYS-001', 'Short title', ...
        "The system shall ... [measurable criterion].", ...
        "Derived from SN-SYS-001.");
    srSet.save();

    %% Derivation links
    derive(sr1, sn1);

    slreq.saveAll();
end

function req = addReq(rs, id, summary, description, rationale)
    req             = rs.add();
    req.Id          = id;
    req.Summary     = summary;
    req.Description = description;
    req.Rationale   = rationale;
end

function lnk = derive(child, parent)
    lnk      = slreq.createLink(child, parent);
    lnk.Type = 'Derive';
end
```
