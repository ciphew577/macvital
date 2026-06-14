---
name: Bug report
about: Something is broken or behaving unexpectedly in MacVital
title: "[bug] "
labels: bug
---

## What happened

A clear description of the bug.

## What you expected to happen

What did you think would happen instead.

## Repro steps

1.
2.
3.

## Environment

- Mac model (e.g. MacBook Pro 14, M2 Pro):
- macOS version (e.g. 14.6.1):
- MacVital version / commit:
- Which tab is affected:

## Helper diagnostics (if relevant)

If the bug involves the privileged helper, missing sensor data, or SMC reads:

```
launchctl print system/com.macvital.helper | head -40
```

## Console output

If the bug shows a runtime warning or crash, paste the relevant console.app
entries (filter by process: MacVital or MacVitalHelper).

## Screenshots

If applicable.
