// MacVital/Views/Shared/AppIconResolver.swift
//
// Thread-safe app-icon resolver with NSCache backing.
// All work runs on MainActor because NSWorkspace requires it.

import AppKit

// MARK: - AppIconResolver

@MainActor
final class AppIconResolver {

    // MARK: Shared instance

    static let shared = AppIconResolver()
    private init() {}

    // MARK: Private state

    /// countLimit = 256 entries. NSCache evicts automatically under memory pressure.
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 256
        return c
    }()

    // MARK: Public API

    /// Returns the app icon for a bundle identifier (cached).
    /// Falls back to a generic SF Symbol image when the app is not installed.
    func icon(
        forBundleID bundleID: String,
        size: CGSize = CGSize(width: 32, height: 32)
    ) -> NSImage {
        let key = cacheKey(bundleID: bundleID, size: size) as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let resolved = resolve(bundleID: bundleID, size: size)
        cache.setObject(resolved, forKey: key)
        return resolved
    }

    /// Async pre-warm for a list of bundle IDs at the default 32x32 size.
    func preload(bundleIDs: [String]) {
        let defaultSize = CGSize(width: 32, height: 32)
        for id in bundleIDs {
            _ = icon(forBundleID: id, size: defaultSize)
        }
    }

    /// Clear cache (e.g. on app uninstall notification).
    func clear() {
        cache.removeAllObjects()
    }

    // MARK: Private helpers

    private func resolve(bundleID: String, size: CGSize) -> NSImage {
        guard
            let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
            )
        else {
            return fallbackImage(size: size)
        }

        let raw = NSWorkspace.shared.icon(forFile: appURL.path)
        return resized(raw, to: size)
    }

    /// Redraws `image` into a new NSImage of `targetSize` to avoid memory bloat
    /// from holding the original full-resolution icon in cache.
    private func resized(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        let result = NSImage(size: targetSize)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }

    /// SF Symbol "app.fill" rendered at `size`, tinted with MV.text3.
    private func fallbackImage(size: CGSize) -> NSImage {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size.width * 0.75, weight: .regular)
        let symbol = NSImage(
            systemSymbolName: "app.fill",
            accessibilityDescription: "Application"
        )?.withSymbolConfiguration(symbolConfig) ?? NSImage()

        // Tint: MV.text3 maps to rgba(232, 230, 227, 0.38) on the default Sage palette.
        // We bake the tint at render time so the fallback matches the current palette.
        let tint = NSColor(
            srgbRed: 232.0 / 255.0,
            green:   230.0 / 255.0,
            blue:    227.0 / 255.0,
            alpha:   0.38
        )

        let result = NSImage(size: size)
        result.lockFocus()
        tint.set()
        let drawRect = NSRect(origin: .zero, size: size)
        symbol.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: symbol.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        // Tint overlay using destinationIn compositing
        drawRect.fill(using: .sourceAtop)
        result.unlockFocus()
        return result
    }

    // MARK: Cache key

    /// Format: "com.apple.Safari:32.0x32.0"
    private func cacheKey(bundleID: String, size: CGSize) -> String {
        "\(bundleID):\(size.width)x\(size.height)"
    }
}
