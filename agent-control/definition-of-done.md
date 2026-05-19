# Definition Of Done

A task is done only when implementation, review, and validation evidence are complete.

## Done Checklist

- [ ] Acceptance criteria are satisfied.
- [ ] Relevant tests were added or updated where practical.
- [ ] Relevant quality gates passed.
- [ ] Agent log was updated.
- [ ] Task status was updated.
- [ ] Review findings are resolved or accepted.
- [ ] Security findings are resolved or accepted when applicable.
- [ ] Validation report has passing evidence or documented accepted risk.
- [ ] Documentation was updated when behavior/setup changed.
- [ ] No unrelated files were changed.
- [ ] For mobile app work, the relevant platform project exists and validation includes an installable device/simulator build, an APK/IPA/app artifact, or a documented external toolchain blocker.

## Not Done Conditions

- Code works only manually but no validation evidence exists.
- Mobile app code passes unit/widget checks but cannot be built or installed for the target platform, unless that gap is explicitly out of scope or blocked by missing external tooling.
- Critical or major validation/security/review finding is open.
- Implementation changed architecture without a decision record.
- Task ownership was exceeded without a handoff.
