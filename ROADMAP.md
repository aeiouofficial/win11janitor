# win11janitor Roadmap
Updated 2026-09-27. Authoritative execution plan: [2026-09-27 modular update](docs/superpowers/plans/2026-09-27-modular-update.md).

## Delivery status
| Phase | Deliverable | State | Gate |
| --- | --- | --- | --- |
| P0 | Evidence, baseline, module policy, no-C workspace and branch isolation | Implemented | Local non-mutating regression tests |
| P1 | Opt-in privacy modules 18–23, edition/build/Edge checks and secure snapshot preflight | Code complete; elevated validation pending | Disposable Windows VM Apply/Audit/Restore/compare |
| P2 | Read-only hardware, startup and PCI interrupt inventory | Implemented | Windows 11 local read-only integration and privacy review |
| P3 | Bounded PresentMon CSV analysis, comparison and checksum-pinned capture adapter | CSV validated; real capture unverified | Comparable real A/B captures on target hardware |
| P4 | Temporary game profiles with watchdog recovery, EcoQoS and P/E-core-aware CPU sets | Not started | Offline replay + anti-cheat-aware VM testing |
| P5 | Per-app GPU profile and experimental MSI/IRQ adapters | Not started | Vendor/driver compatibility + hardware test matrix |
| P6 | GUI, per-setting search, profiles, diagnostics and restore history | Not started | Accessible Windows usability tests |

## Non-negotiable quality criteria
- 100% of mutating operations are allowlisted, backed up and auditable; unsupported systems must refuse explicit mutation.
- 0 writes to project files outside D:\win11janitor; no unattended downloads and no disabling security software.
- Read-only probes report unavailable data explicitly; unknown GPU, interrupt and power capabilities are never guessed.
- Each module documents minimum build, OS edition, functional trade-offs, source and rollback expectations.
## Work planned after the current PR
1. Windows VM matrix: Windows 11 Home, Pro and Enterprise, account switching through UAC, systems with and without Edge, older and newer builds.
2. Exercise elevated Apply, repeat Apply, interrupted Apply and both v1/v2 Restore; compare all registry types, tasks, services and user profiles.
3. Verify a PresentMon 2.x CLI binary by published hash, collect repeated comparable 30–120 second workload samples; test capture exit/ETW contention.
4. Session daemon design: choose least-privilege helper; only apply CPU/priority modifications to allowlisted per-process identities; restore on exit, timeout, crash and boot.
5. P/E-core topology via Windows CPU Sets API, with physical/hybrid validation and no unverified affinity pinning on non-hybrid CPUs.
6. GPU per-app profile export/restore and interrupt-policy experiments only when exact device/driver support can be verified.
7. Usability layer and signed distribution with trusted installation directory and integrity-verified updates.

## What does not ship automatically
Blanket Nagle, ETW, MMCSS, HPET/timer, pagefile, SysMain, service suppression, HVCI/VBS, Windows Update or Defender changes. A source project's benchmark is not evidence for all hardware. Revisit each only after controlled testing and documented functional impact.
