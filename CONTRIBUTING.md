# Contributing to MacVital

Thanks for considering a contribution. MacVital is a small but
opinionated codebase. This document covers how to get set up, what
the codebase expects, and how to land a change.

## Getting set up

1. macOS 14.0+ (Sonoma) and Xcode 15+.
2. Apple Silicon (M1 / M2 / M3 / M4). Intel is out of scope.
3. Install [xcodegen](https://github.com/yonaskolb/XcodeGen) if you
   plan to regenerate the project file: `brew install xcodegen`.
4. Clone the repo and run `./create-xcode-project.sh` if you need a
   fresh `.xcodeproj`. Otherwise just `open MacVital.xcodeproj`.
5. Cmd+R to build and run. First launch will prompt to install the
   privileged helper.

## Codebase conventions

- **Swift 6 strict concurrency** is the goal. Most of the codebase
  already passes; the helper boundary is the main area still being
  tightened.
- **File size cap ~800 lines.** Split a module when it gets close.
  A few existing files exceed this and are being broken up.
- **IOKit / SMC reads go through the helper.** Never inline an IOKit
  call inside a view. The XPC interface in `Shared/HelperProtocol.swift`
  is the only sanctioned channel.
- **Every metric the helper reads should be visible in the UI.** The
  app deliberately avoids hidden aggregate scores with no methodology.
  If you add a reader, surface its raw value somewhere.
- **No external Swift package dependencies.** Charts, PDFKit, IOKit,
  XPC are all first-party. New dependencies need a strong reason.
- **Animate compositor-friendly properties.** Transform, opacity, and
  clip-path only. Avoid animating layout-bound properties like width,
  height, or padding.

## Visual / design conventions

- Avoid generic dashboard tropes (uniform card grids, gradient blobs,
  glowing donuts). Each tab gets its own deliberate layout.
- Use `MVPalette` tokens for color. Hardcoded hex is fine for one-off
  illustrative state but should be lifted to the palette when it
  becomes a recurring color.
- Charts should never animate while the underlying data is paused or
  the value is `nil`. Add a `Calibrating` state for the first 0 to 2
  seconds after launch instead of zeros or blank.

## Pull requests

1. Branch from `main`. Keep PRs scoped to one concern.
2. The PR template asks you to describe the change, list any visible
   UI effects, and call out anything that touches the privileged
   helper or the XPC protocol.
3. Add or update tests if you touch the helper protocol or any reader.
4. Run a Release build locally before opening the PR.

## Reporting bugs

Use the Bug Report template under
`.github/ISSUE_TEMPLATE/bug_report.md`. Include the Mac model,
macOS version, and the relevant tab. If the issue involves the
privileged helper, the output of `launchctl print system/com.macvital.helper`
is gold.

## Suggesting features

Use the Feature Request template. Concrete examples and a description
of the metric or behavior the new feature exposes are more useful than
a general suggestion.
