import Foundation

@MainActor
final class ShopViewModel: ObservableObject {
    @Published private(set) var items: [ShopItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private let api = ShopAPI()

    func reload(using credential: ShopCredential?) async {
        guard let credential else {
            errorMessage = ShopError.notLoggedIn.localizedDescription
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await api.fetchStore(for: credential)
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
