// MacVital/Views/Shared/AccessibilityHelpers.swift
//
// Shared SwiftUI accessibility helpers. Keeping these in one place lets us
// fold the same VoiceOver behaviour into every metric tile, row, and chip
// without scattering accessibilityElement / accessibilityLabel calls across
// the codebase.

import SwiftUI

extension View {

    /// Wraps a metric tile so VoiceOver reads "Label: Value" once instead of
    /// announcing each child Text fragment individually.
    ///
    /// Use on any composite view where the visual hierarchy already conveys
    /// the relationship (label above number, monospaced unit beside it, etc.)
    /// but VoiceOver would otherwise read four or five disjoint fragments.
    func metricA11y(
        label: String,
        value: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint ?? "")
    }
}
