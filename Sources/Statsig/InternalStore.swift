import Foundation

import CommonCrypto

class InternalStore {
    private static let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    private let loggedOutUserID = "com.Statsig.InternalStore.loggedOutUserID"
    private let maxUserCacheCount = 5
    private var cache: [String: UserValues]

    init() {
        cache = [String: UserValues]()
        if let localCache = UserDefaults.standard.dictionary(forKey: InternalStore.localStorageKey) {
            for (userID, rawData) in localCache {
                if let rawData = rawData as? [String: Any] {
                    cache[userID] = UserValues(data: rawData)
                }
            }
        }
    }

    func checkGate(_ forUser: StatsigUser, gateName: String) -> FeatureGate? {
        let userValues = get(forUser: forUser)
        return userValues?.checkGate(forName: gateName)
    }

    func getConfig(_ forUser: StatsigUser, configName: String) -> DynamicConfig? {
        let userValues = get(forUser: forUser)
        return userValues?.getConfig(forName: configName)
    }

    func set(forUser: StatsigUser, values: UserValues) {
        cache[forUser.userID ?? loggedOutUserID] = values
        while cache.count > maxUserCacheCount {
            removeOldest()
        }
        
        saveToLocalCache()
    }
    
    func get(forUser: StatsigUser) -> UserValues? {
        if let userID = forUser.userID {
            return cache[userID] ?? nil
        }
        return cache[loggedOutUserID]
    }

    static func deleteLocalStorage() {
        UserDefaults.standard.removeObject(forKey: InternalStore.localStorageKey)
    }
    
    private func removeOldest() {
        var oldestTime: Double = -1;
        var oldestUserKey: String?;
        for (key, values) in cache {
            if oldestTime < 0 || oldestTime > values.creationTime {
                oldestTime = values.creationTime
                oldestUserKey = key
            }
        }
        if oldestUserKey != nil {
            cache.removeValue(forKey: oldestUserKey ?? "")
        }
    }
    
    private func saveToLocalCache() {
        var rawCache = [String: [String: Any]]()
        for (userID, values) in cache {
            rawCache[userID] = values.rawData
        }
        UserDefaults.standard.setValue(rawCache, forKey: InternalStore.localStorageKey)
    }
}

struct UserValues {
    var rawData: [String: Any] // raw data fetched directly from Statsig server
    var gates: [String: FeatureGate]
    var configs: [String: DynamicConfig]
    var creationTime: Double
    
    init(data: [String: Any]) {
        self.rawData = data
        self.creationTime = NSDate().timeIntervalSince1970

        var gates = [String: FeatureGate]()
        var configs = [String: DynamicConfig]()
        if let gatesJSON = data["feature_gates"] as? [String: [String: Any]] {
            for (name, gateObj) in gatesJSON {
                gates[name] = FeatureGate(name: name, gateObj: gateObj)
            }
        }
        self.gates = gates;
        
        if let configsJSON = data["dynamic_configs"] as? [String: [String: Any]] {
            for (name, configObj) in configsJSON {
                configs[name] = DynamicConfig(configName: name, configObj: configObj)
            }
        }
        self.configs = configs;
    }
    
    func checkGate(forName: String) -> FeatureGate? {
        if let nameHash = forName.sha256() {
            return gates[nameHash] ?? gates[forName] ?? nil
        }
        return nil
    }
    
    func getConfig(forName: String) -> DynamicConfig? {
        if let nameHash = forName.sha256() {
            return configs[nameHash] ?? configs[forName]
        }
        return nil
    }
}

extension String {
    func sha256() -> String? {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}
