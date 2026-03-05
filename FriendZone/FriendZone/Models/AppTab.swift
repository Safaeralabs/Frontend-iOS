import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case ambitions
    case hangouts
    case maps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ambitions: return "Ambitions"
        case .hangouts: return "Hangouts"
        case .maps: return "Maps"
        }
    }

    var sfSymbol: String {
        switch self {
        case .ambitions: return "bolt.fill"
        case .hangouts: return "person.3.fill"
        case .maps: return "map.fill"
        }
    }

    var path: String {
        switch self {
        case .ambitions: return "/ambitions"
        case .hangouts: return "/"
        case .maps: return "/maps"
        }
    }
}
