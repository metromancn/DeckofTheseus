import SwiftUI

// RevenueCat is only imported when the package is actually linked, so the game builds
// either way. Add the SPM package and the real implementation below compiles itself in —
// no other edits needed. See the note in `purchase(_:)`.
#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Gems
//
// Premium currency, bought with real money. Unlike Gold — which is earned in a run and wiped
// by `startGame()` — the Gem balance belongs to the PLAYER, not the run: it survives death,
// new runs, and app launches.

enum GemWallet {
    private static let key = "gemBalance"

    static var balance: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: key) }
    }

    static func canAfford(_ amount: Int) -> Bool { balance >= amount }

    /// Deducts and reports success — never spends more than the player has.
    @discardableResult
    static func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    static func grant(_ amount: Int) { balance += amount }
}

// MARK: - Purchasing

/// A buyable bundle: one store product, one Gem quantity.
struct GemPack: Identifiable {
    let productId: String
    let gems: Int
    var id: String { productId }
    var title: String { "\(gems) Gems" }
}

/// THE ONLY PLACE THE GAME TALKS TO A STORE. Everything else just asks for a pack and gets
/// back "purchased / cancelled / failed".
enum GemStore {

    /// Gem packs on sale. **Add more here and nothing else changes** — the shop lists
    /// whatever is in this array, and each pack carries its own Gem quantity.
    static let packs: [GemPack] = [
        GemPack(productId: "earn_15_gems", gems: 15),
    ]

    /// RevenueCat SDK API key, passed to `Purchases.configure` at launch.
    /// This is the **Test Store** key (`test_` prefix): purchases are simulated by
    /// RevenueCat and never charge anyone. A real App Store build needs the `appl_` key.
    /// SDK keys are public by design and safe to ship inside the app.
    static let apiKey = "test_JPOPXrPqISIJCLIBevmIxPicNET"

    /// RevenueCat Offering the SDK reads packages from. This is the Offering's
    /// **identifier** — what `offerings.all` is keyed by — not its REST object ID.
    static let offeringId = "default"

    /// The same Offering's REST API / dashboard object ID. Recorded for reference only
    /// (server-side calls, dashboard lookups); the SDK never resolves an Offering by this.
    static let offeringRestId = "ofrng6f28d07311"

    /// What a revive costs. One constant — change it here.
    static let reviveCost = 10

    enum PurchaseResult {
        case purchased(Int)      // gems granted
        case cancelled
        case failed(String)
    }

    #if canImport(RevenueCat)
    /// Configure RevenueCat if nothing has yet. The app does this at launch, but SwiftUI
    /// Previews never run `App.init()` — and `Purchases.shared` **crashes with fatalError**
    /// when unconfigured, which kills the preview process rather than showing an error.
    /// Doing it here makes every entry point safe.
    static func ensureConfigured() {
        guard !Purchases.isConfigured else { return }
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Live implementation — active as soon as the RevenueCat package is linked.
    static func purchase(_ pack: GemPack) async -> PurchaseResult {
        ensureConfigured()
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current ?? offerings.all[offeringId] else {
                return .failed("No \"\(offeringId)\" offering is configured.")
            }
            guard let package = offering.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == pack.productId
            }) else {
                return .failed("The \"\(offeringId)\" offering has no package for \(pack.productId).")
            }
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            GemWallet.grant(pack.gems)
            return .purchased(pack.gems)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
    #else
    /// No SDK linked — nothing to configure.
    static func ensureConfigured() {}

    /// The RevenueCat package isn't in the project yet, so there is no storefront to talk to.
    ///
    /// In DEBUG this grants the Gems anyway so the revive flow is testable; a release build
    /// reports the failure honestly and can never hand out free Gems.
    static func purchase(_ pack: GemPack) async -> PurchaseResult {
        #if DEBUG
        try? await Task.sleep(for: .milliseconds(400))
        GemWallet.grant(pack.gems)
        return .purchased(pack.gems)
        #else
        return .failed("Purchases are unavailable — the RevenueCat SDK is not installed.")
        #endif
    }
    #endif

    /// True once a real storefront is wired up.
    static var isLive: Bool {
        #if canImport(RevenueCat)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Shop UI

/// A plain purchase screen: the current balance, one row per pack, and a close button.
struct GemShopView: View {
    let balance: Int
    let size: CGSize
    let onPurchased: () -> Void
    let onClose: () -> Void

    @State private var busyPackId: String? = nil
    @State private var message: String? = nil

    var body: some View {
        let unit = min(size.width, size.height)
        let font = min(unit * 0.034, 22)

        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: unit * 0.026) {
                HStack {
                    Text("GEMS").font(.pixel(font * 1.3)).foregroundColor(.goldBright)
                    Spacer()
                    HStack(spacing: 6) {
                        GemIcon(size: font)
                        Text("\(balance)").font(.pixel(font)).foregroundColor(.textParchment)
                    }
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: font * 0.9, weight: .bold))
                            .foregroundColor(.textMuted)
                            .padding(.leading, 12)
                    }.buttonStyle(.plain)
                }

                ForEach(GemStore.packs) { pack in
                    Button {
                        busyPackId = pack.id
                        message = nil
                        Task { @MainActor in
                            switch await GemStore.purchase(pack) {
                            case .purchased(let gems):
                                message = "+\(gems) Gems"
                                onPurchased()
                            case .cancelled:
                                message = nil
                            case .failed(let reason):
                                message = reason
                            }
                            busyPackId = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            GemIcon(size: font * 1.2)
                            Text(pack.title).font(.pixel(font))
                            Spacer()
                            Text(busyPackId == pack.id ? "\u{2026}" : "Buy")
                                .font(.pixel(font))
                                .foregroundColor(.goldBright)
                        }
                        .foregroundColor(.textParchment)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(busyPackId != nil)
                }

                if let message {
                    Text(message)
                        .font(.pixel(font * 0.8))
                        .foregroundColor(.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !GemStore.isLive {
                    Text("[ RevenueCat SDK not installed \u{2014} debug builds grant Gems locally ]")
                        .font(.pixel(font * 0.72))
                        .foregroundColor(Color(hex: 0xC09A4A))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(unit * 0.035)
            .frame(width: min(unit * 0.8, 540))
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x18122A)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.goldBorder, lineWidth: 2))
            .shadow(color: .black.opacity(0.6), radius: 24)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The always-present balance pill: gem icon, count, and a "+" that opens the shop.
/// Shown everywhere including the title page, so Gems can be bought without dying first.
struct GemBarView: View {
    let balance: Int
    let size: CGFloat            // base font size
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: size * 0.38) {
            GemIcon(size: size)

            Text("\(balance)")
                .font(.pixel(size))
                .foregroundColor(.textParchment)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: size * 1.1, alignment: .leading)

            Button(action: onBuy) {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [Color(hex: 0x5FCB6C), Color(hex: 0x2C8C3C)],
                                       startPoint: .top, endPoint: .bottom))
                    Circle().stroke(Color(hex: 0x1E5A28), lineWidth: 1.5)
                    Image(systemName: "plus")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: size * 1.15, height: size * 1.15)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, size * 0.5)
        .padding(.trailing, size * 0.2)
        .padding(.vertical, size * 0.2)
        .background(Capsule().fill(Color(hex: 0x140E20).opacity(0.92)))
        .overlay(Capsule().stroke(Color.goldBorder, lineWidth: 1.5))
    }
}

/// Placeholder gem icon (swap for real art later, like the gold coin).
struct GemIcon: View {
    let size: CGFloat
    var body: some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: size))
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: 0x7FE7FF), Color(hex: 0x2F8FD0)],
                               startPoint: .top, endPoint: .bottom)
            )
    }
}
