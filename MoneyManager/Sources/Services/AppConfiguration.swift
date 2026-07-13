import Foundation

enum AppConfiguration {
    static let apiBaseURL: URL = {
        guard
            let configuredValue = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            !configuredValue.contains("$("),
            let configuredURL = URL(string: configuredValue)
        else {
            preconditionFailure("APIBaseURL must be configured in the target build settings")
        }
        return configuredURL
    }()
}
