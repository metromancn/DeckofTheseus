import SwiftUI
import CoreText

@main
struct DeckTheseusApp: App {
    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "VT323-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
