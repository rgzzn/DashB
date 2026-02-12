import Foundation

enum Config {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()

    static let googleClientID: String = {
        guard let string = infoDictionary["GOOGLE_CLIENT_ID"] as? String else {
            fatalError("GOOGLE_CLIENT_ID not set in plist")
        }
        return string
    }()

    static let googleClientSecret: String = {
        guard let string = infoDictionary["GOOGLE_CLIENT_SECRET"] as? String else {
            fatalError("GOOGLE_CLIENT_SECRET not set in plist")
        }
        return string
    }()

    static let outlookClientID: String = {
        guard let string = infoDictionary["OUTLOOK_CLIENT_ID"] as? String else {
            fatalError("OUTLOOK_CLIENT_ID not set in plist")
        }
        return string
    }()

    static let outlookClientSecret: String = {
        guard let string = infoDictionary["OUTLOOK_CLIENT_SECRET"] as? String else {
            fatalError("OUTLOOK_CLIENT_SECRET not set in plist")
        }
        return string
    }()

    static let outlookTenantID: String = {
        guard let string = infoDictionary["OUTLOOK_TENANT_ID"] as? String else {
            fatalError("OUTLOOK_TENANT_ID not set in plist")
        }
        return string
    }()
}
