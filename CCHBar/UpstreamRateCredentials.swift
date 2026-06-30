import Foundation
import Security

struct UpstreamRateCredential: Identifiable, Codable, Equatable {
    var id: String { host }
    var host: String
    var sourceType: UpstreamRateSourceType
    var baseURL: String
    var userAgent: String
    var sub2AuthToken: String
    var sub2RefreshToken: String
    var sub2TokenExpiresAt: Date?
    var sub2CookieHeader: String
    var newAPIUserId: String
    var newAPIAccessToken: String
    var newAPICookieHeader: String

    enum CodingKeys: String, CodingKey {
        case host
        case sourceType
        case baseURL
        case userAgent
        case sub2AuthToken
        case sub2RefreshToken
        case sub2TokenExpiresAt
        case sub2CookieHeader
        case newAPIUserId
        case newAPIAccessToken
        case newAPICookieHeader
    }

    static func empty(host: String, sourceType: UpstreamRateSourceType) -> UpstreamRateCredential {
        UpstreamRateCredential(
            host: host,
            sourceType: sourceType == .unknown ? .newAPI : sourceType,
            baseURL: "https://\(host)",
            userAgent: "",
            sub2AuthToken: "",
            sub2RefreshToken: "",
            sub2TokenExpiresAt: nil,
            sub2CookieHeader: "",
            newAPIUserId: "",
            newAPIAccessToken: "",
            newAPICookieHeader: ""
        )
    }

    init(
        host: String,
        sourceType: UpstreamRateSourceType,
        baseURL: String,
        userAgent: String = "",
        sub2AuthToken: String,
        sub2RefreshToken: String,
        sub2TokenExpiresAt: Date?,
        sub2CookieHeader: String = "",
        newAPIUserId: String,
        newAPIAccessToken: String,
        newAPICookieHeader: String = ""
    ) {
        self.host = host
        self.sourceType = sourceType
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.sub2AuthToken = sub2AuthToken
        self.sub2RefreshToken = sub2RefreshToken
        self.sub2TokenExpiresAt = sub2TokenExpiresAt
        self.sub2CookieHeader = sub2CookieHeader
        self.newAPIUserId = newAPIUserId
        self.newAPIAccessToken = newAPIAccessToken
        self.newAPICookieHeader = newAPICookieHeader
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        sourceType = try container.decode(UpstreamRateSourceType.self, forKey: .sourceType)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent) ?? ""
        sub2AuthToken = try container.decode(String.self, forKey: .sub2AuthToken)
        sub2RefreshToken = try container.decode(String.self, forKey: .sub2RefreshToken)
        sub2TokenExpiresAt = try container.decodeIfPresent(Date.self, forKey: .sub2TokenExpiresAt)
        sub2CookieHeader = try container.decodeIfPresent(String.self, forKey: .sub2CookieHeader) ?? ""
        newAPIUserId = try container.decode(String.self, forKey: .newAPIUserId)
        newAPIAccessToken = try container.decode(String.self, forKey: .newAPIAccessToken)
        newAPICookieHeader = try container.decodeIfPresent(String.self, forKey: .newAPICookieHeader) ?? ""
    }
}

struct UpstreamRateCredentialStore {
    private let service = "app.cchbar.CCHBar.upstreamRates"
    private let account = "siteCredentials"

    func load() -> [UpstreamRateCredential] {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return [] }
        return (try? JSONDecoder().decode([UpstreamRateCredential].self, from: data)) ?? []
    }

    func save(_ credentials: [UpstreamRateCredential]) throws {
        guard let data = try? JSONEncoder().encode(credentials.sorted { $0.host < $1.host }) else { return }
        var query = baseQuery
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                let retryStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
                guard retryStatus == errSecSuccess else { throw UpstreamRateCredentialStoreError.writeFailed(retryStatus) }
            } else if addStatus != errSecSuccess {
                throw UpstreamRateCredentialStoreError.writeFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw UpstreamRateCredentialStoreError.writeFailed(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum UpstreamRateCredentialStoreError: LocalizedError {
    case writeFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "上游登录态写入钥匙串失败：\(status)"
        }
    }
}
