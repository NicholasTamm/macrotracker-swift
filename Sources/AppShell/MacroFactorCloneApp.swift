import SwiftUI
import DesignSystem

// MARK: - MacroFactorCloneApp

/// Application entry point.
///
/// The thin `@main` struct lives in AppShell; the heavy lifting (data,
/// features) lives in the feature modules. Global theme wiring comes from
/// `.mfThemed()` (see ``MFTheme``) — color scheme follows the system unless
/// the user overrides it in More → Appearance.
@main
public struct MacroFactorCloneApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
