import SwiftUI

@main
struct ValShopApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var shopModel = ShopViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountStore)
                .environmentObject(shopModel)
                .preferredColorScheme(.light)
        }
    }
}
