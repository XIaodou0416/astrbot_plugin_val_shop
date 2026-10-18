import Foundation

struct ShopCredential: Codable, Equatable {
    var userId: String
    var tid: String
    var nickname: String?
    var openID: String?
    var uin: String?

    var isComplete: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ShopItem: Identifiable, Hashable {
    let id: String
    let name: String
    let price: String
    let backgroundURL: URL?
    let imageURL: URL?
    let category: String
    let rarity: String

    init(dictionary: [String: Any], index: Int) {
        let fallbackID = "item-\(index)"
        id = Self.string(dictionary["goods_id"]) ?? Self.string(dictionary["id"]) ?? fallbackID
        name = Self.string(dictionary["goods_name"]) ?? Self.string(dictionary["name"]) ?? "未命名商品"
        price = Self.string(dictionary["rmb_price"]) ?? Self.string(dictionary["price"]) ?? "0"
        backgroundURL = Self.url(dictionary["bg_image"] ?? dictionary["background"])
        imageURL = Self.url(dictionary["goods_pic"] ?? dictionary["icon"] ?? dictionary["image"])
        category = Self.string(dictionary["goods_type"]) ?? Self.string(dictionary["type"]) ?? "武器皮肤"
        rarity = Self.string(dictionary["rarity"]) ?? Self.string(dictionary["quality"]) ?? "每日商店"
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func url(_ value: Any?) -> URL? {
        guard let raw = string(value), !raw.isEmpty else { return nil }
        return URL(string: raw.hasPrefix("http") ? raw : "https://\(raw)")
    }
}

enum ShopError: LocalizedError {
    case notLoggedIn
    case invalidResponse
    case server(String)
    case expired
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "请先绑定无畏契约账号"
        case .invalidResponse: return "商店接口返回格式异常"
        case .server(let message): return message
        case .expired: return "登录凭证已过期，请重新扫码登录"
        case .network(let message): return message
        }
    }
}
