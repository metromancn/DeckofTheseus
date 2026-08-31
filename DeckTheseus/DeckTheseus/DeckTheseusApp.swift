import SwiftUI
import CoreText

@main
struct DeckTheseusApp: App {
    init() {
        Self.registerFonts()
        Self.configurePurchases()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Hand RevenueCat its API key at launch. `GemStore.ensureConfigured()` is the single
    /// implementation, so previews (which never run this initialiser) configure themselves
    /// on first use instead of crashing.
    private static func configurePurchases() {
        GemStore.ensureConfigured()
    }

    private static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "VT323-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
