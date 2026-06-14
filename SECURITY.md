# Security Policy

MacVital ships a privileged XPC helper (`com.macvital.helper`) that runs
as root via `SMAppService`. That trust boundary is the single most
important surface in the codebase to keep correct, and the area I want
to know about first if something goes wrong.

## Supported versions

The `main` branch is the supported version. Tagged releases get
security fixes backported only when there is no breaking change
required to ship them.

## Reporting a vulnerability

For anything that could allow:

- local privilege escalation through the XPC interface
- helper installation or update spoofing
- SMC / IOKit reads being used to exfiltrate or alter data outside the
  declared protocol surface
- denial-of-service that requires more than killing the app to recover

please open a private security advisory on this repository
(`Security` tab -> `Report a vulnerability`) rather than a public issue.

For lower-severity issues (e.g. logging hygiene, UI states that leak
process names you would not expect, missing input validation that does
not cross a privilege boundary), a regular issue is fine. Tag it with
`security`.

## What is in scope

- Helper installation, update, and removal flow
- The XPC protocol defined in `Shared/HelperProtocol.swift`
- Anything that reads from IOKit, SMC, sysctl, or NVMe SMART under root
- Report export (PDF / HTML) and the data it serializes
- Network reader paths that touch raw socket info or per-process
  metadata

## What is out of scope

- Third-party macOS bugs that only show up because of how MacVital
  uses standard APIs (please report those to Apple)
- The (currently disabled) cap-window resume design discussed in
  issues; it is unreachable in the shipped code

## Response

I read advisories within a couple of days. A fix or detailed response
follows within two weeks for confirmed in-scope issues.
