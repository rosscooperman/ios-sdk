import Foundation

import Nimble
import Quick
import OHHTTPStubs
#if !COCOAPODS
import OHHTTPStubsSwift
#endif
@testable import Statsig

extension Dictionary {
    subscript(d key: Key) -> [String: Any]? {
        get {
            return self[key] as? [String: Any]
        }
    }

    subscript(a key: Key) -> [Any]? {
        get {
            return self[key] as? [Any]
        }
    }
}

extension Array {
    subscript(d key: Index) -> [String: Any]? {
        get {
            return self[key] as? [String: Any]
        }
    }

    subscript(a key: Index) -> [Any]? {
        get {
            return self[key] as? [Any]
        }
    }
}

class LayerExposureSpec: QuickSpec {

    override func spec() {
        describe("Layer Exposure Logging") {
            it("logs layers without an allocated experiment correctly") {
                TestUtils.startWithResponseAndWait([
                    "layer_configs": [
                        "layer".sha256(): [
                            "value": ["an_int": 99],
                            "rule_id": "default",
                            "secondary_exposures": [["gate": "secondary_exp"]],
                            "undelegated_secondary_exposures": [["gate": "undelegated_secondary_exp"]],
                            "allocated_experiment_name": "",
                            "explicit_parameters": []
                        ]
                    ]
                ])

                let layer = Statsig.getLayer("layer")
                _ = layer.getValue(forKey: "an_int", defaultValue: 0)

                var logs: [String: Any]!
                TestUtils.captureLogs { captured in
                    logs = captured
                }
                Statsig.shutdown()

                expect(logs).toEventuallyNot(beNil())

                expect(logs[a: "events"]?.count).toEventually(equal(1))
                let event = logs[a: "events"]?[d: 0]
                expect(event?[a: "secondaryExposures"] as? [[String: String]])
                    .to(equal([["gate": "undelegated_secondary_exp"]]))
                expect(event?[d: "metadata"] as? [String: String])
                    .to(equal([
                        "config": "layer",
                        "ruleID": "default",
                        "allocatedExperiment": "",
                        "parameterName": "an_int",
                        "isExplicitParameter": "false"
                    ]))
            }

            it("logs explicit and implicit parameters correctly") {
                TestUtils.startWithResponseAndWait([
                    "layer_configs": [
                        "layer".sha256(): [
                            "value": ["an_int": 99, "a_string": "value"],
                            "rule_id": "default",
                            "secondary_exposures": [["gate": "secondary_exp"]],
                            "undelegated_secondary_exposures": [["gate": "undelegated_secondary_exp"]],
                            "allocated_experiment_name": "the_allocated_experiment",
                            "explicit_parameters": ["an_int"]
                        ]
                    ]
                ])

                let layer = Statsig.getLayer("layer")
                _ = layer.getValue(forKey: "an_int", defaultValue: 0)
                _ = layer.getValue(forKey: "a_string", defaultValue: "")

                var logs: [String: Any]!
                TestUtils.captureLogs { captured in
                    logs = captured
                }
                Statsig.shutdown()

                expect(logs).toEventuallyNot(beNil())


                let events = logs[a: "events"]
                expect(events?.count).to(equal(2))

                let explicitEvent = events?[d: 0]
                expect(explicitEvent?[a: "secondaryExposures"] as? [[String: String]])
                    .to(equal([["gate": "secondary_exp"]]))
                expect(explicitEvent?[d: "metadata"] as? [String: String])
                    .to(equal([
                        "config": "layer",
                        "ruleID": "default",
                        "allocatedExperiment": "the_allocated_experiment",
                        "parameterName": "an_int",
                        "isExplicitParameter": "true"
                    ]))

                let implicitEvent = events?[d: 1]
                expect(implicitEvent?[a: "secondaryExposures"] as? [[String: String]])
                    .to(equal([["gate": "undelegated_secondary_exp"]]))
                expect(implicitEvent?[d: "metadata"] as? [String: String])
                    .to(equal([
                        "config": "layer",
                        "ruleID": "default",
                        "allocatedExperiment": "",
                        "parameterName": "a_string",
                        "isExplicitParameter": "false"
                    ]))
            }

            it("logs different object types correctly") {
                TestUtils.startWithResponseAndWait([
                    "layer_configs": [
                        "layer".sha256(): [
                            "value": [
                                "a_bool": true,
                                "an_int": 99,
                                "a_double": 1.23,
                                "a_long": UInt64(1),
                                "a_string": "value",
                                "an_array": ["a", "b"],
                                "an_object": ["key": "value"]
                            ],
                        ]
                    ]
                ])

                let layer = Statsig.getLayer("layer")
                _ = layer.getValue(forKey: "a_bool", defaultValue: false)
                _ = layer.getValue(forKey: "an_int", defaultValue: 0)
                _ = layer.getValue(forKey: "a_double", defaultValue: 0.0)
                _ = layer.getValue(forKey: "a_long", defaultValue: 0)
                _ = layer.getValue(forKey: "a_string", defaultValue: "")
                _ = layer.getValue(forKey: "an_array", defaultValue: [])
                _ = layer.getValue(forKey: "an_object", defaultValue: [:])

                var logs: [String: Any]!
                TestUtils.captureLogs { captured in
                    logs = captured
                }
                Statsig.shutdown()

                expect(logs).toEventuallyNot(beNil())

                let events = logs[a: "events"]
                expect(events?.count).to(equal(7))
            }

            it("does not log when shutdown") {
                TestUtils.startWithResponseAndWait([
                    "layer_configs": [
                        "layer".sha256(): [
                            "value": [
                                "a_bool": true,
                            ],
                        ]
                    ]
                ])

                let layer = Statsig.getLayer("layer")
                var logs: [String: Any]!
                TestUtils.captureLogs { captured in
                    logs = captured
                }
                Statsig.shutdown()

                _ = layer.getValue(forKey: "a_bool", defaultValue: false)

                expect(logs).to(beNil())
            }

            it("logs the correct name and user values") {
                TestUtils.startWithResponseAndWait([
                    "layer_configs": [
                        "layer".sha256(): [
                            "value": ["an_int": 99],
                        ]
                    ]
                ], "client-sdk-key", StatsigUser(userID: "dloomb", email: "dan@loomb.co.nz"))

                let layer = Statsig.getLayer("layer")
                _ = layer.getValue(forKey: "an_int", defaultValue: 0)

                var logs: [String: Any]!
                TestUtils.captureLogs { captured in
                    logs = captured
                }
                Statsig.shutdown()

                expect(logs).toEventuallyNot(beNil())

                expect(logs[a: "events"]?.count).toEventually(equal(1))
                let event = logs[a: "events"]?[d: 0]
                expect(event?["eventName"] as? String)
                    .to(equal("statsig::layer_exposure"))

                expect(event?["user"] as? [String: AnyHashable])
                    .to(equal([
                        "userID": "dloomb",
                        "email": "dan@loomb.co.nz",
                        "statsigEnvironment": [String: String]()
                    ]))
            }
        }
    }
}
