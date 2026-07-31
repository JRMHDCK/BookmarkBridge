//
//  ApplicationScreen.swift
//  BookmarkBridge
//

/// Stable top-level destinations for the application shell.
nonisolated enum ApplicationScreen: String, CaseIterable, Hashable, Identifiable, Sendable {
    case dashboard
    case synchronization
    case bookmarkAccess
    case settings
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Accueil"
        case .synchronization: "Synchronisation"
        case .bookmarkAccess: "Accès aux favoris"
        case .settings: "Réglages"
        case .about: "À propos"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house"
        case .synchronization: "arrow.triangle.2.circlepath"
        case .bookmarkAccess: "lock.doc"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
