# win11janitor: modular, evidence-gated expansion (2026-09-27)
Status: implementation in progress on `feat/modular-hardware-privacy-foundation`.
Workspace: `D:\win11janitor`; every project-created temporary file, log, cache, baseline and snapshot must stay under `D:\win11janitor\.workspace`. OS-owned registry/system writes cannot be redirected.
Objective: improve actionable privacy, hardware discovery and measurable performance without reinstalling Windows, deleting user data or disabling security.
Constraints: preserve the professional README visual structure and existing 01-17 launchers; audit and dry-run must never change Windows settings; no elevated Apply/Restore on the development laptop.
Evidence standard: an upstream README is an implementation lead, NOT proof of an FPS, DPC or power benefit. Every new mutation needs a documented policy/API, edition/build guard, actual-state snapshot, preflight, postcondition and rollback. Unsupported or unverifiable targets must refuse mutation.

## Baseline and architecture
Baseline: main commit `9ef08c4` (2026-09-26), 17 modules, 17 passing non-mutating tests, no open PR when checked.
Keep native Windows PowerShell 5.1 engine as the primary implementation; retain .bat wrappers and existing JSON CLI. Add separately loadable `Capabilities.ps1` and `Diagnostics.ps1` instead of an unrelated runtime.
Module schema: stable ID, mode (Safe/Optional/AuditOnly), operations, documented provenance, support predicate (Windows client, build, edition or Edge presence), impact and restart notice.
CLI outcomes: PLAN/AUDIT show SUPPORTED/UNSUPPORTED without masking failure; explicit unsupported Apply must fail before mutation; support checks cannot be bypassed by profile selection.
Snapshots: allowlisted targets only, save before mutation, compare current values before Restore, lock operations, journal traceId, report rollback failures. Existing schema-v1 snapshots must remain readable and require explicit conflict handling when current values diverge.
## Delivery gates
P0: capture branch/baseline, write plan and evidence, document deferred modules, test original state without live OS changes.
P1: capability detection and guarded modules 18-23: Search highlights, cloud search, Widgets, Edge background, Edge startup boost and cross-device clipboard. All are opt-in; policies unsupported on Home are never advertised as applied.
P2: hardware/software diagnostics (Windows build/edition, CPU/GPU/RAM, physical disks, security feature status, startup inventory, network overview, interrupt-policy audit). Inventory must not change system state or expose serial numbers/user files in normal output.
P3: safe benchmarking interface: versioned local JSON baseline and comparison, deterministic counters and exports; optional PresentMon adapter requires a verified binary and explicit capture permission. No FPS claims without comparable A/B measurements.
P4: process/session optimization: per-process reversible EcoQoS and CPU-set experiments; enforce process identity/start-time match, foreground consent, anti-cheat non-interference, and automatic exit/crash recovery before enabling any background service.
P5: deeper adapters: NVIDIA per-app profile export/restore; GPU interrupt/MSI diagnostics and experimental tuning after vendor driver and rollback tests; workload-specific network, storage and power diagnostics.
P6: usability: discoverable module picker, support reasons, search, preview, target accounts, A/B charts, per-module restore, update-safe templates and accessible CLI fallback.
P4-P6 are roadmap items, not shipped behavior unless their gates are actually implemented and tested; no placeholder implementations are allowed.

## Security model and failure modes
- No shell code execution from repository catalogs, remote URLs or benchmark CSV. All target writes use a compile-time allowlist and approved typed operations.
- Disallow generic unvalidated registry paths, arbitrary command arguments, untrusted binary downloads, security-component disable and broad service kills.
- Detect account mismatch for HKCU if running elevated under a different interactive account; deliberate cross-account changes require a separate future documented workflow.
- Snapshots saved atomically under D:; reject unallowlisted targets and unexpected snapshot schema. Preflight current target state before Restore to avoid overwriting external policy/driver changes.
- Hardware probes return explicit `UNAVAILABLE` on access restrictions; never infer chipset topology or policy applicability from marketing names.
- Power-loss mid-Apply: persisted pre-state survives. Apply failures roll back only touched targets and record partial recovery; recovery must not pretend an inaccessible target was restored.
- Do not copy GPL/AGPL code into MIT project; use independent implementations or compatible MIT code with copyright and notice preservation after review.
- No CI on GitHub Actions is required; Windows local tests are authoritative until independent isolated VM elevated acceptance is performed.
## Primary evidence (read and checked 2026-09-27)
- Windows Search CSP, policy/edition/build mappings: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search
- Widgets policy: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests
- Clipboard policy: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy
- Edge background policy (May 2026): https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled
- Edge startup policy: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
- Windows CPU sets: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemcpusetinformation
- EcoQoS process API: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setprocessinformation
- Intel PresentMon: https://github.com/GameTechDev/PresentMon (license/release/API review needed before bundling)
- CapFrameX: https://github.com/CXWorld/CapFrameX (MIT; benchmark inspiration, no code copied)
- GameShift: https://github.com/lhceist41/GameShift (MIT; claims not treated as validation, no code copied)
- Interrupt affinity tool: https://github.com/vadyaravadim/interrupt-affinity-utility (MIT; explicit default-vs-forced affinity distinction)
- MSI-mode measurements: https://github.com/vadyaravadim/msi-mode-utility/bench/results/README.md (single machine and uncontrolled confounders)
- NVIDIA Profile Inspector: https://github.com/Orbmu2k/nvidiaProfileInspector (MIT; future adapter)
- Sophia Script: https://github.com/farag2/Sophia-Script-for-Windows (MIT; source of comparison, no code copied)
- simplewall GPL-3.0 and privacy.sexy AGPL-3.0 are research references only, not vendored.
## Acceptance and release checklist
- Baseline green. New tests: policy metadata and edition matrix; plan/audit/WhatIf non-mutation; unsupported Apply no snapshot; exact pre-state restoration; new diagnostic JSON schema and no writes; existing 17 wrappers unchanged.
- Verify PowerShell 5.1 syntax and PowerShell 7 behavior, Windows 11 client-only gate, no write outside D workspace by project code, and no C-backed temporary files.
- Run local non-mutating `python -m unittest discover -s tests -v` with TEMP, TMP, TMPDIR, PYTHONPYCACHEPREFIX or PYTHONDONTWRITEBYTECODE redirected to D workspace.
- Elevated Apply -> Audit -> Restore -> compare is intentionally restricted to disposable VM acceptance after review. Do not call that tested on the developer laptop.
- Create feature-branch commits, push to origin, and open an inspectable PR; keep `main` unchanged until validation.
- Update CHANGELOG and README by adding sections while preserving the original banner, badges, module table layout and professional presentation.
