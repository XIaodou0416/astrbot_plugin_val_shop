import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var credential: ShopCredential?

    private let key = "valshop.credential"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let value = try? JSONDecoder().decode(ShopCredential.self, from: data) {
            credential = value
        }
    }

    func save(_ value: ShopCredential) {
        credential = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() {
        credential = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class WatchlistStore: ObservableObject {
    @Published private(set) var names: [String]
    private let key = "valshop.watchlist"

    init() {
        names = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func toggle(_ name: String) {
        if let index = names.firstIndex(of: name) {
            names.remove(at: index)
        } else {
            names.append(name)
        }
        names.sort()
        UserDefaults.standard.set(names, forKey: key)
    }

    func contains(_ name: String) -> Bool { names.contains(name) }
}
