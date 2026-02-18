import Foundation

enum Config {
    enum OAuthKey: String, CaseIterable {
        case googleClientID = "GOOGLE_CLIENT_ID"
        case googleClientSecret = "GOOGLE_CLIENT_SECRET"
        case outlookClientID = "OUTLOOK_CLIENT_ID"
        case outlookTenantID = "OUTLOOK_TENANT_ID"
    }

    private static let infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]

    private static func value(for key: OAuthKey) -> String? {
        guard let value = infoDictionary[key.rawValue] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var missingOAuthKeys: [String] {
        OAuthKey.allCases.compactMap { key in
            value(for: key) == nil ? key.rawValue : nil
        }
    }

    static var hasRequiredOAuthConfig: Bool {
        missingOAuthKeys.isEmpty
    }

    static let googleClientID: String = value(for: .googleClientID) ?? ""

    static let googleClientSecret: String = value(for: .googleClientSecret) ?? ""

    static let outlookClientID: String = value(for: .outlookClientID) ?? ""

    static let outlookTenantID: String = value(for: .outlookTenantID) ?? ""
}
