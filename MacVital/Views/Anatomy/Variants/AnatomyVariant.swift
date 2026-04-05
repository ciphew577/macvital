// MacVital/Views/Anatomy/Variants/AnatomyVariant.swift

import SwiftUI

enum AnatomyVariant: Int, CaseIterable, Identifiable, Sendable {
    case bentoSchematic = 0
    case explodedView   = 1
    case crossSection   = 2
    case wiringDiagram  = 3
    case ifixitPhoto    = 4

    var id: Int { rawValue }

    static let storageKey = "com.macvital.anatomy.variant"

    var displayName: String {
        switch self {
        case .bentoSchematic: return "Bento Schematic"
        case .explodedView:   return "Exploded View"
        case .crossSection:   return "Cross Section"
        case .wiringDiagram:  return "Wiring Diagram"
        case .ifixitPhoto:    return "iFixit Photo"
        }
    }

    var eyebrow: String {
        switch self {
        case .bentoSchematic: return "V1 BENTO"
        case .explodedView:   return "V2 EXPLODED"
        case .crossSection:   return "V3 CROSS-SECTION"
        case .wiringDiagram:  return "V4 WIRING"
        case .ifixitPhoto:    return "V5 IFIXIT"
        }
    }
}
