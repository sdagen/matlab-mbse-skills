---
name: simulink-test
description: >
  Use this skill when the user wants to create or work with Simulink Test files
  (.mldatx) — test suites, test cases, system-under-test configuration, and linking
  test cases to TC requirements via slreq. Trigger when the user asks about
  sltest.testmanager, creating test suites, running Simulink tests, or the Tier 2
  (executable simulation) layer of MBSE verification. Do NOT trigger for TC requirement
  creation in slreqx files — use the simulink-requirements skill for that.
---

# Simulink Test (sltest.testmanager)

This skill covers creating executable Simulink Test files (`.mldatx`) and linking
them to TC requirements. For TC requirement creation in `.slreqx` files (Tier 1),
see the `simulink-requirements` skill.

---

## Two Tiers of Verification

**Tier 1 — TC requirements** (`TestCases.slreqx`, built in the requirements phase):
testable shall-statements with `Verify` links to SRs. Valid standalone; provide full
traceability with no simulation model required.

**Tier 2 — Simulink Test file** (`.mldatx`, this skill): links test cases to a
Simulink model under test with inputs and pass/fail assessments.

**Only generate a Simulink Test file when an actual Simulink simulation model exists.**
Without a model under test, `createTestCase` produces empty stubs that cannot run
and add no value over the TC requirements already in Tier 1.

For each test case to be runnable it needs:
- `SystemUnderTest` set to the `.slx` model path
- Inputs defined (test sequence, signal editor, or external data)
- Pass/fail assessments (verify statements or baseline comparison)

---

## Script Skeleton

```matlab
function buildMySimulinkTests()
    rootDir = fileparts(fileparts(mfilename('fullpath')));
    reqDir  = fullfile(rootDir, 'requirements');
    verDir  = fullfile(rootDir, 'verification');
    tcFile  = fullfile(reqDir,  'TestCases.slreqx');
    mldatx  = fullfile(verDir,  'MyTests.mldatx');
    mldatxLinks = fullfile(verDir, 'MyTests~mldatx.slmx');

    addpath(reqDir);   % required: without this, slreq.createLink stores an absolute path
                       % in the .slmx link file instead of a relative one, breaking portability
    slreq.clear();
    tcSet = slreq.open(tcFile);
    sltest.testmanager.clear();
    if isfile(mldatx),      delete(mldatx);      end
    if isfile(mldatxLinks), delete(mldatxLinks); end

    tf = sltest.testmanager.TestFile(mldatx);
    tf.Description = 'System-level verification tests.';

    % Remove the auto-created default suite
    for s = tf.getTestSuites(), remove(s); end

    % { SuiteName, Tag, { TC-IDs... } }
    suites = {
        'Functional Tests', 'functional', { 'TC-SYS-001', 'TC-SYS-002' };
    };

    for s = 1:size(suites, 1)
        suite = createTestSuite(tf, suites{s, 1});
        suite.Tags = suites{s, 2};
        for t = 1:numel(suites{s, 3})
            tcId  = suites{s, 3}{t};
            tcReq = tcSet.find('Id', tcId);
            if isempty(tcReq), warning('TC %s not found — skipped.', tcId); continue; end
            stc                  = createTestCase(suite, 'simulation', tcId);
            stc.Description      = tcReq.Description;
            stc.Tags             = suites{s, 2};
            stc.SystemUnderTest  = 'MySimulinkModel';   % must be set; no-op without this
            lnk      = slreq.createLink(stc, tcReq);
            lnk.Type = 'Verify';
        end
    end

    saveToFile(tf);
    slreq.saveAll();
end
```

---

## Key API Notes

- `sltest.testmanager.clear()` — unloads all test files from memory before rebuilding
- `sltest.testmanager.TestFile(path)` — creates a new test file on disk
- `createTestSuite(tf, name)` — adds a suite to the test file
- `createTestCase(suite, 'simulation', name)` — adds a simulation test case to a suite
- `saveToFile(tf)` — saves the test file to disk
- `slreq.createLink(stc, tcReq)` — links the Simulink Test case to the TC requirement
- `addpath(reqDir)` before `slreq.createLink` — ensures relative paths in the `.slmx`
  link file instead of absolute paths (portability)
- `slreq.open()` is correct here (not `slreq.load()`) when you need the Requirements
  Editor to be open so that `slreq.createLink` can resolve the TC requirement objects
