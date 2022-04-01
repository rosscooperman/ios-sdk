import Foundation

typealias StringRecord = [String: String]

public struct Layer: ConfigProtocol {
    public let name: String
    public let ruleID: String
    public let isUserInExperiment: Bool
    public let isExperimentActive: Bool
    public let hashedName: String
    public let allocatedExperimentName: String

    weak internal var client: StatsigClient?
    internal let secondaryExposures: [[String: String]]
    internal let undelegatedSecondaryExposures: [[String: String]]
    internal let explicitParameters: Set<String>
    internal var isDeviceBased: Bool = false
    internal var rawValue: [String: Any] = [:]

    private let value: [String: Any]

    internal init(client: StatsigClient?, name: String, configObj: [String: Any] = [:]) {
        self.client = client
        self.name = name
        self.ruleID = configObj["rule_id"] as? String ?? ""
        self.value = configObj["value"] as? [String: Any] ?? [:]
        self.secondaryExposures = configObj["secondary_exposures"] as? [[String: String]] ?? []
        self.undelegatedSecondaryExposures = configObj["undelegated_secondary_exposures"] as? [[String: String]] ?? []
        self.hashedName = configObj["name"] as? String ?? ""

        self.isDeviceBased = configObj["is_device_based"] as? Bool ?? false
        self.isUserInExperiment = configObj["is_user_in_experiment"] as? Bool ?? false
        self.isExperimentActive = configObj["is_experiment_active"] as? Bool ?? false
        self.allocatedExperimentName = configObj["allocated_experiment_name"] as? String ?? ""
        self.explicitParameters = Set(configObj["explicit_parameters"] as? [String] ?? [])
        self.rawValue = configObj
    }

    internal init(client: StatsigClient?, name: String, value: [String: Any], ruleID: String) {
        self.client = client
        self.name = name
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
        self.undelegatedSecondaryExposures = []
        self.explicitParameters = Set()
        self.hashedName = ""

        self.isExperimentActive = false
        self.isUserInExperiment = false
        self.allocatedExperimentName = ""
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            print("[Statsig]: \(forKey) does not exist in this Layer. Returning the defaultValue.")
        } else {
            client?.logLayerParameterExposure(layer: self, parameterName: forKey)
        }
        return serverValue ?? defaultValue
    }
}
