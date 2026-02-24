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
        guard !trimmed.isEmpty else { return nil }
        // In release builds a missing build setting can survive as "$(KEY)".
        // Treat unresolved placeholders as missing to avoid hanging auth flows.
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") {
            return nil
        }
        return trimmed
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

    static func missingOAuthKeys(for serviceName: String) -> [String] {
        func missing(_ keys: [OAuthKey]) -> [String] {
            keys.compactMap { key in
                value(for: key) == nil ? key.rawValue : nil
            }
        }

        switch serviceName {
        case "Google Calendar":
            return missing([.googleClientID, .googleClientSecret])
        case "Outlook Calendar":
            return missing([.outlookClientID, .outlookTenantID])
        default:
            return missingOAuthKeys
        }
    }
}
