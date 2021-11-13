//
//  Info.swift
//  eul
//
//  Created by Gao Sun on 2020/6/27.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import Foundation
import IOKit.ps
import SharedLibrary
import SystemKit

public enum BatteryCondition: String, Codable {
    case good
    case fair
    case poor
}

public enum PowerSourceState: String, Codable {
    case battery
    case acPower
    case unknown
}

extension BatteryCondition {
    var description: String {
        "battery.condition.\(rawValue)".localized()
    }
}

extension PowerSourceState {
    var description: String {
        "battery.power_source.\(rawValue)".localized()
    }
}

enum Info {
    static var isBigSur: Bool {
        if #available(OSX 11, *) {
            return true
        }
        return false
    }

    struct Battery {
        var currentCapacity = 0
        var maxCapacity = 0
        var currentCharge: Double {
            Double(currentCapacity) / Double(maxCapacity)
        }

        var condition: BatteryCondition = .good
        var powerSource: PowerSourceState = .unknown
        var timeToFullCharge = 0
        var timeToEmpty = 0
        var isCharged = false
        var isCharging = false

        init() {
            guard
                let blob = IOPSCopyPowerSourcesInfo(),
                let list = IOPSCopyPowerSourcesList(blob.takeRetainedValue()),
                let array = list.takeRetainedValue() as? [Any],
                array.count > 0,
                let dict = array[0] as? NSDictionary
            else {
                return
            }

            currentCapacity = dict[kIOPSCurrentCapacityKey] as? Int ?? 0
            maxCapacity = dict[kIOPSMaxCapacityKey] as? Int ?? 0
            timeToFullCharge = dict[kIOPSTimeToFullChargeKey] as? Int ?? 0
            timeToEmpty = dict[kIOPSTimeToEmptyKey] as? Int ?? 0
            isCharged = dict[kIOPSIsChargedKey] as? Bool ?? false
            isCharging = dict[kIOPSIsChargingKey] as? Bool ?? false

            if let value = dict[kIOPSBatteryHealthConditionKey] as? String {
                switch value {
                case kIOPSPoorValue:
                    condition = .poor
                case kIOPSFairValue:
                    condition = .fair
                default:
                    condition = .good
                }
            }

            if let value = dict[kIOPSPowerSourceStateKey] as? String {
                switch value {
                case kIOPSACPowerValue:
                    powerSource = .acPower
                case kIOPSBatteryPowerValue:
                    powerSource = .battery
                default:
                    powerSource = .unknown
                }
            }

            Print(
                "🔋 battery info",
                currentCapacity,
                maxCapacity,
                timeToFullCharge,
                timeToEmpty,
                isCharged,
                isCharging,
                condition,
                powerSource
            )
        }
    }

    struct NetworkUsage {
        var inBytes: UInt64
        var outBytes: UInt64
    }

    struct NetworkPort: Identifiable {
        var port: String?
        var device: String

        var id: String {
            device
        }

        var description: String {
            guard let port = port else {
                return device
            }
            return "\(port) (\(device))"
        }
    }

    struct InterfaceStatus {
        var name: String
        var status: String?
    }

    static func findPort(_ string: String) -> NetworkPort? {
        guard string.hasPrefix("("), string.hasSuffix(")") else {
            return nil
        }

        let trimmed = String(string.dropFirst().dropLast())

        guard let matched = trimmed.firstMatch("Device: ([^,]+)")?.range(at: 1), let deviceRange = Range(matched, in: trimmed) else {
            return nil
        }

        var port: String?
        let device = String(trimmed[deviceRange])
        if let matched = trimmed.firstMatch("Port: ([^,]+)")?.range(at: 1), let portRange = Range(matched, in: trimmed) {
            port = String(trimmed[portRange])
        }

        return NetworkPort(port: port, device: device)
    }

    static func getActiveInterfaces() -> [String] {
        shell("ifconfig")?.split(separator: "\n").map { String($0) }.reduce([InterfaceStatus]()) {
            // new interface
            if !$1.hasPrefix("\t") {
                guard let colonIndex = $1.firstIndex(of: ":") else {
                    return $0
                }
                return $0.appending(InterfaceStatus(name: String($1[..<colonIndex])))
            }

            let splitted = $1.split(separator: ":").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t")) }

            guard splitted.count == 2, splitted[0] == "status", let lastInterface = $0.last else {
                return $0
            }

            return $0.dropLast().appending(InterfaceStatus(name: lastInterface.name, status: splitted[1]))
        }.compactMap {
            $0.status == "active" ? $0.name : nil
        } ?? []
    }

    static func getNetworkUsage(forDevice: String?, _ onData: @escaping (NetworkUsage, [NetworkPort], NetworkPort?) -> Void) {
        // TO-DO: use Combine
        shellAsync("networksetup -listnetworkserviceorder") {
            let services = $0?.split(separator: "\n").map(String.init).compactMap(Info.findPort) ?? []
            let activeInterfaces = Info.getActiveInterfaces()
            let currentActivePort = services.first(where: { activeInterfaces.contains($0.device) })

            Print("network services order", services)
            Print("network active interfaces", activeInterfaces)
            Print("network current active interfaces", currentActivePort ?? "N/A")

            var inBytes: UInt64?
            var outBytes: UInt64?

            let device = forDevice ?? currentActivePort?.device ?? "en0"

            if
                let rows = shell("netstat -bI \(device)")?.split(separator: "\n").map({ String($0) }),
                rows.count > 1
            {
                let headers = rows[0].splittedByWhitespace
                let values = rows[1].splittedByWhitespace

                if let raw = String.getValue(of: "ibytes", in: values, of: headers), let bytes = UInt64(raw) {
                    inBytes = bytes
                }

                if let raw = String.getValue(of: "obytes", in: values, of: headers), let bytes = UInt64(raw) {
                    outBytes = bytes
                }
            }

            DispatchQueue.main.async {
                onData(NetworkUsage(inBytes: inBytes ?? 0, outBytes: outBytes ?? 0), services, currentActivePort)
            }
        }
    }

    static var system = System()

    static func getProcessCommand(pid: Int) -> String? {
        shell("ps -p \(pid) -o comm=")?.trimmingCharacters(in: .newlines)
    }
}
