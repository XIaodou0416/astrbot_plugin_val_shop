import Foundation

struct QRLoginPayload {
    let imageData: Data
    let token: Int
    let loginURL: URL
    let cookies: [HTTPCookie]
}

struct LoginResult {
    let openID: String
    let accessToken: String
    let userID: String
    let tid: String
    let uin: String?
}

/// QQ 扫码登录的纯 HTTP 客户端，流程对应插件中的 xlogin → ptqrshow → ptqrlogin。
final class QRLoginService {
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage
    private let loginURL = URL(string: "https://xui.ptlogin2.qq.com/cgi-bin/xlogin?pt_enable_pwd=1&appid=716027609&pt_3rd_aid=102061775&daid=381&pt_skey_valid=0&style=35&force_qr=1&autorefresh=1&s_url=http%3A%2F%2Fconnect.qq.com&refer_cgi=m_authorize&ucheck=1&fall_to_wv=1&redirect_uri=auth%3A%2F%2Ftauth.qq.com%2F&client_id=102061775&pf=openmobile_android&response_type=token&scope=all&sdkp=a&sdkv=3.5.17.lite&status_machine=MjMxMTdSSzY2Qw%3D%3D&switch=1&show_download_ui=true&loginty=6")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        cookieStorage = HTTPCookieStorage()
        configuration.httpCookieStorage = cookieStorage
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        session = URLSession(configuration: configuration)
    }

    func makeQRCode() async throws -> QRLoginPayload {
        var request = URLRequest(url: loginURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (pageData, pageResponse) = try await session.data(for: request)
        let page = String(decoding: pageData, as: UTF8.self)
        let loginSig = match(#"g_login_sig=encodeURIComponent\(\"([^\"]+)\"\)"#, in: page) ?? cookie("pt_login_sig") ?? ""
        let jsver = match(#"jsver\s*=\s*['\"]([^'\"]+)['\"]"#, in: page) ?? "28d22679"
        let qrURL = URL(string: "https://xui.ptlogin2.qq.com/ssl/ptqrshow?s=8&e=0&appid=716027609&type=0&t=\(Double.random(in: 0..<1))&u1=http%3A%2F%2Fconnect.qq.com&daid=381&pt_3rd_aid=102061775")!
        var qrRequest = URLRequest(url: qrURL)
        qrRequest.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
        qrRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (imageData, qrResponse) = try await session.data(for: qrRequest)
        guard !imageData.isEmpty else { throw LoginError.qrUnavailable }
        let qrsig = cookie("qrsig") ?? responseCookie("qrsig", from: qrResponse) ?? responseCookie("qrsig", from: pageResponse)
        guard let qrsig, !qrsig.isEmpty else { throw LoginError.qrUnavailable }
        let token = calcToken(qrsig)
        _ = loginSig
        _ = jsver
        return QRLoginPayload(imageData: imageData, token: token, loginURL: loginURL, cookies: session.configuration.httpCookieStorage?.cookies ?? [])
    }

    func waitForScan(_ payload: QRLoginPayload, timeout: TimeInterval = 90) async throws -> LoginResult {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(2))
            var components = URLComponents(string: "https://xui.ptlogin2.qq.com/ssl/ptqrlogin")!
            components.queryItems = [
                URLQueryItem(name: "u1", value: "http://connect.qq.com"),
                URLQueryItem(name: "from_ui", value: "1"),
                URLQueryItem(name: "type", value: "1"),
                URLQueryItem(name: "ptqrtoken", value: String(payload.token)),
                URLQueryItem(name: "daid", value: "381"),
                URLQueryItem(name: "aid", value: "716027609"),
                URLQueryItem(name: "pt_3rd_aid", value: "102061775"),
                URLQueryItem(name: "pt_uistyle", value: "35"),
                URLQueryItem(name: "jsver", value: "28d22679"),
                URLQueryItem(name: "r", value: String.randomToken())
            ]
            var request = URLRequest(url: components.url!)
            request.setValue(payload.loginURL.absoluteString, forHTTPHeaderField: "Referer")
            let (data, _) = try await session.data(for: request)
            let text = String(decoding: data, as: UTF8.self)
            guard let callback = parseCallback(text) else { continue }
            if callback.code == "65" { throw LoginError.qrExpired }
            if callback.code == "0", let redirect = callback.redirectURL,
               let values = URLComponents(string: redirect)?.queryItems {
                let map = Dictionary(uniqueKeysWithValues: values.map { ($0.name, $0.value ?? "") })
                guard let openID = map["openid"], let accessToken = map["access_token"] else { throw LoginError.missingToken }
                let final = try await exchange(openID: openID, accessToken: accessToken)
                return final
            }
        }
        throw LoginError.timeout
    }

    private func exchange(openID: String, accessToken: String) async throws -> LoginResult {
        let url = URL(string: "https://app.mval.qq.com/go/auth/login_by_qq?source_game_zone=agame&game_zone=agame")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("clientType=9; openid=null; access_token=null;", forHTTPHeaderField: "Cookie")
        let body: [String: Any] = [
            "clienttype": 9,
            "config_params": ["client_dev_name": "iPhone", "lang_type": 0],
            "login_info": ["appid": 102061775, "openid": openID, "qq_info_type": 5, "sig": accessToken, "uin": 0],
            "mappid": 10200,
            "mcode": "132f0a77d34402abc8463d60100011d19b0e",
            "source_game_zone": "agame",
            "game_zone": "agame"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = (root["data"] as? [String: Any])?["login_info"] as? [String: Any],
              let userID = info["user_id"] as? String,
              let tid = info["wt"] as? String else { throw LoginError.exchangeFailed }
        return LoginResult(openID: openID, accessToken: accessToken, userID: userID, tid: tid, uin: (info["uin"] as? NSNumber)?.stringValue)
    }

    private func cookie(_ name: String) -> String? {
        cookieStorage.cookies?.first(where: { $0.name == name })?.value
    }

    private func responseCookie(_ name: String, from response: URLResponse) -> String? {
        guard let http = response as? HTTPURLResponse else { return nil }
        for (rawKey, rawValue) in http.allHeaderFields {
            guard String(describing: rawKey).lowercased() == "set-cookie" else { continue }
            let header = String(describing: rawValue)
            for part in header.split(separator: ";") {
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces) == name { return pair[1] }
            }
        }
        return nil
    }

    private func calcToken(_ qrsig: String) -> Int {
        var token = 0
        for byte in qrsig.utf8 { token += (token << 5) + Int(byte) }
        return token & 0x7fffffff
    }

    private func match(_ pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = expression.firstMatch(in: text, range: range), result.numberOfRanges > 1,
              let valueRange = Range(result.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    private func parseCallback(_ text: String) -> (code: String, redirectURL: String?)? {
        let expression: NSRegularExpression
        do {
            expression = try NSRegularExpression(
                pattern: "ptuiCB\\('([^']*)','([^']*)','([^']*)','([^']*)','([^']*)'",
                options: []
            )
        } catch {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = expression.firstMatch(in: text, range: range), result.numberOfRanges >= 6 else { return nil }
        func value(_ index: Int) -> String { guard let r = Range(result.range(at: index), in: text) else { return "" }; return String(text[r]) }
        return (value(1), value(3).replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "\\x26", with: "&").removingPercentEncoding)
    }
}

enum LoginError: LocalizedError {
    case qrUnavailable, qrExpired, missingToken, exchangeFailed, timeout
    var errorDescription: String? {
        switch self {
        case .qrUnavailable: return "二维码生成失败，请稍后重试"
        case .qrExpired: return "二维码已过期，请重新生成"
        case .missingToken: return "登录回调缺少授权信息"
        case .exchangeFailed: return "登录凭证换取失败"
        case .timeout: return "扫码等待超时"
        }
    }
}

private extension String {
    static func randomToken() -> String { String(format: "%.12f", Double.random(in: 0..<1)) }
}
