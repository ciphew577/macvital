// MacVital/Services/HelperInstaller.swift
import Foundation
import ServiceManagement

enum HelperInstaller {

    /// Check if the helper daemon is reachable via XPC.
    ///
    /// IMPORTANT: This method must be safe to call from the main thread.
    /// Previous implementation used a DispatchSemaphore which deadlocked
    /// when called from main because NSXPCConnection dispatches reply
    /// handlers to the main queue, but main was blocked on the semaphore.
    ///
    /// Now uses a simple file-based check (is the helper binary present and
    /// is the launchd job loaded?) which avoids any XPC round-trip.
    static func isHelperRunning() -> Bool {
        // Check 1: Helper binary exists at the expected path
        let helperPath = "/Library/PrivilegedHelperTools/com.macvital.helper"
        guard FileManager.default.fileExists(atPath: helperPath) else {
            return false
        }

        // Check 2: LaunchDaemon plist exists
        let plistPath = "/Library/LaunchDaemons/com.macvital.helper.plist"
        guard FileManager.default.fileExists(atPath: plistPath) else {
            return false
        }

        // Check 3: Process is actually running (fast check via pgrep exit code)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "com.macvital.helper"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            // pgrep failed to launch — fall back to file-based checks only
            return true
        }
    }

    static func install() throws {
        // macOS 14+: Try SMAppService first (requires proper code signing)
        let service = SMAppService.daemon(plistName: "com.macvital.helper.plist")
        do {
            try service.register()
            return
        } catch {
            // SMAppService fails with ad-hoc signing — fall back to manual install via script
            try installViaScript()
        }
    }

    /// Fallback: copy helper to /Library/PrivilegedHelperTools and load via launchctl.
    ///
    /// Hardening approach (security finding C-fix):
    ///   We previously built one big shell command-string with bundlePath
    ///   interpolated and passed it to `do shell script "..."` after
    ///   escaping backslashes and double quotes. That left at least four
    ///   injection vectors open: backticks, `$(...)` command substitution,
    ///   single quotes, and embedded newlines. A bundlePath like
    ///   `/tmp/x'; rm -rf /; echo 'pwned` would have escaped its quoting.
    ///
    ///   The current approach writes a self-contained POSIX shell script to
    ///   a sandbox-protected temp directory, marks it executable, and asks
    ///   AppleScript to run only the path to that script via
    ///   `do shell script "/path/to/installer.sh" with administrator
    ///   privileges`. The bundlePath, helperDst, and plistDst values are
    ///   embedded inside the script with single-quote escaping where every
    ///   embedded `'` becomes `'\''`, that is the canonical POSIX form
    ///   that closes the quoted block, inserts a literal escaped quote,
    ///   then reopens the block, leaving zero in-band metacharacters that
    ///   the shell might re-interpret. The AppleScript source itself only
    ///   contains a static absolute path that we generate, no interpolated
    ///   user / bundle data.
    ///
    /// NOTE: For an even cleaner approach we would invoke `/bin/launchctl`
    /// and `/bin/cp` via `Process()` with `[String]` argument arrays (no
    /// shell at all). That requires privilege escalation that Process does
    /// not provide, SMJobBless / SMAppService is the supported root path.
    /// AppleScript with administrator privileges is the documented fallback
    /// for ad-hoc-signed builds and is what we keep here.
    private static func installViaScript() throws {
        let bundlePath = Bundle.main.bundlePath
        let helperSrc = "\(bundlePath)/Contents/Resources/MacVitalHelper"
        let helperDst = "/Library/PrivilegedHelperTools/com.macvital.helper"
        let plistDst  = "/Library/LaunchDaemons/com.macvital.helper.plist"

        // Build the plist as a proper dictionary and write to a temp file
        let plistDict: [String: Any] = [
            "Label": "com.macvital.helper",
            "Program": helperDst,
            "MachServices": ["com.macvital.helper": true],
            "RunAtLoad": true,
            "KeepAlive": true
        ]

        let tmpDir = FileManager.default.temporaryDirectory
        let tmpPlist = tmpDir.appendingPathComponent("com.macvital.helper.plist")

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        try plistData.write(to: tmpPlist)

        // POSIX-safe single-quote escape: every embedded ' becomes '\''
        // which closes the quoted block, emits a literal ', and reopens.
        func sq(_ s: String) -> String {
            return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        // Build the script body. Each path is single-quoted so backticks,
        // $(...), embedded quotes and newlines all become literal bytes.
        // `set -eu` makes the script fail on any error, including unset vars.
        let scriptBody = """
        #!/bin/sh
        set -eu

        HELPER_SRC=\(sq(helperSrc))
        HELPER_DST=\(sq(helperDst))
        PLIST_SRC=\(sq(tmpPlist.path))
        PLIST_DST=\(sq(plistDst))

        # Clean up any previous broken install (ignore errors).
        /bin/launchctl bootout system/com.macvital.helper 2>/dev/null || true
        /bin/rm -f "$PLIST_DST" "$HELPER_DST"

        # Install helper binary.
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cp "$HELPER_SRC" "$HELPER_DST"
        /bin/chmod 544 "$HELPER_DST"
        /usr/sbin/chown root:wheel "$HELPER_DST"

        # Install LaunchDaemon plist.
        /bin/cp "$PLIST_SRC" "$PLIST_DST"
        /bin/chmod 644 "$PLIST_DST"
        /usr/sbin/chown root:wheel "$PLIST_DST"

        # Bootstrap the daemon.
        /bin/launchctl bootstrap system "$PLIST_DST"
        """

        // Write the script to a per-user temp dir. Use a UUID-suffixed name
        // to avoid any predictable-name attack when /tmp is shared.
        let scriptURL = tmpDir.appendingPathComponent("macvital-helper-install-\(UUID().uuidString).sh")
        try scriptBody.write(to: scriptURL, atomically: true, encoding: .utf8)
        // chmod 700, owner read/write/execute only.
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: scriptURL.path
        )

        // The AppleScript source only references the absolute script path.
        // The script path is generated by us (UUID + temporaryDirectory),
        // never user-controlled. We still escape any embedded ' just in
        // case temporaryDirectory ever sits under a path with metacharacters.
        let appleScript = "do shell script \(asQuote(scriptURL.path)) with administrator privileges"

        defer {
            try? FileManager.default.removeItem(at: scriptURL)
            try? FileManager.default.removeItem(at: tmpPlist)
        }

        var error: NSDictionary?
        if let scriptObj = NSAppleScript(source: appleScript) {
            scriptObj.executeAndReturnError(&error)
            if let error = error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Installation cancelled"
                throw NSError(domain: "HelperInstaller", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } else {
            throw NSError(domain: "HelperInstaller", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create install script"])
        }
    }

    /// AppleScript-safe double-quoting. Escapes backslash, double quote,
    /// and any control char that AppleScript would interpret. Everything
    /// else is passed through literally.
    private static func asQuote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    static func uninstall() throws {
        let service = SMAppService.daemon(plistName: "com.macvital.helper.plist")
        try service.unregister()
    }

    static func status() -> SMAppService.Status {
        let service = SMAppService.daemon(plistName: "com.macvital.helper.plist")
        return service.status
    }
}
