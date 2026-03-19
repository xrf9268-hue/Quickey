# Roadmap

## Phase 0 — Completed scaffold
Status: **done**

Delivered:
- repo initialized and pushed
- menu bar app baseline
- settings window
- persistent shortcut storage
- recorder-style shortcut input
- global event tap baseline
- accessibility permission flow
- conflict detection
- initial Thor-like toggle behavior
- packaging scaffold and validation docs

## Phase 1 — macOS validation
Status: **next critical milestone**

Goal:
Compile and run on a real macOS machine.

Tasks:
- build with `swift build`
- run `swift test`
- package the `.app`
- validate LSUIElement behavior
- validate accessibility prompt and permission persistence
- validate one or more real shortcuts end to end
- fix compile/runtime gaps discovered on macOS

Exit criteria:
- app compiles on macOS
- app launches successfully as a menu bar utility
- at least one app shortcut works end to end

## Phase 2 — recorder and settings polish
Status: **planned**

Goal:
Make shortcut entry and settings interaction feel reliable and pleasant.

Tasks:
- improve recorder control visuals and unsupported-key handling
- add clearer validation and inline help
- improve shortcut display formatting
- improve settings window ergonomics
- optionally add search/filter for mappings

Exit criteria:
- recorder flow is smooth enough for repeated daily use
- common user mistakes are clearly explained

## Phase 3 — Thor/HotApp parity improvements
Status: **planned**

Goal:
Close the behavioral gap with Thor and the visible HotApp design.

Tasks:
- improve previous-app restoration heuristics
- introduce per-shortcut history tracking
- improve minimized/full-screen/multi-window handling
- better Hyper-style combination support
- add stale-app detection and running-app indicators
- optionally explore a private low-latency activation path behind an explicit feature flag

Exit criteria:
- toggle behavior feels dependable in normal daily workflows
- edge cases are substantially reduced

## Phase 4 — packaging and release hardening
Status: **planned**

Goal:
Make the app easier to package, share, and maintain.

Tasks:
- add app icon and polished bundle metadata
- automate release packaging end to end
- document signing and notarization workflow
- define versioning and changelog baseline
- consider macOS CI for builds/tests

Exit criteria:
- reproducible release packaging flow exists
- signing/notarization path is documented or implemented

## Phase 5 — quality and maintenance
Status: **planned**

Goal:
Improve confidence and handoff quality.

Tasks:
- add tests for key mapping
- add tests for conflict logic
- add tests for toggle behavior logic
- add screenshots / demo material
- keep docs aligned with implementation

Exit criteria:
- key logic has meaningful test coverage
- repo is easy for another contributor or agent to continue
