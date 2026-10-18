import Foundation

struct ShopAPI {
    private let endpoint = URL(string: "https://app.mval.qq.com/go/mlol_store/agame/user_store")!

    func fetchStore(for credential: ShopCredential) async throws -> [ShopItem] {
        guard credential.isComplete else { throw ShopError.notLoggedIn }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("mval/2.3.0.10050 Channel/5 Manufacturer/iPhone", forHTTPHeaderField: "User-Agent")
        request.setValue(cookie(for: credential), forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["_t": Int(Date().timeIntervalSince1970)])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ShopError.network("商店接口请求失败")
            }
            return try parse(data)
        } catch let error as ShopError {
            throw error
        } catch {
            throw ShopError.network(error.localizedDescription)
        }
    }

    private func cookie(for credential: ShopCredential) -> String {
        var parts = [
            "clientType=9",
            "accountType=5",
            "userId=\(credential.userId)",
            "tid=\(credential.tid)",
            "access_token=null"
        ]
        if let openID = credential.openID, !openID.isEmpty { parts.append("openid=\(openID)") }
        if let uin = credential.uin, !uin.isEmpty { parts.append("uin=o\(uin)") }
        return parts.joined(separator: "; ")
    }

    private func parse(_ data: Data) throws -> [ShopItem] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShopError.invalidResponse
        }
        if let result = root["result"] as? NSNumber, result.intValue != 0 {
            let message = (root["errMsg"] as? String) ?? (root["msg"] as? String) ?? "商店查询失败"
            if [1001, 1003, 999999].contains(result.intValue) || message.lowercased().contains("expire") {
                throw ShopError.expired
            }
            throw ShopError.server(message)
        }
        guard var dataObject = root["data"] else { throw ShopError.invalidResponse }
        if let array = dataObject as? [[String: Any]] { dataObject = array.first ?? [:] }
        guard let dictionary = dataObject as? [String: Any] else { throw ShopError.invalidResponse }
        let rawItems = dictionary["list"] as? [[String: Any]] ?? []
        return rawItems.enumerated().map { ShopItem(dictionary: $0.element, index: $0.offset) }
    }
}
