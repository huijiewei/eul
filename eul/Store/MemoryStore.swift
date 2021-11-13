//
//  MemoryStore.swift
//  eul
//
//  Created by Gao Sun on 2020/6/29.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import Foundation
import SharedLibrary
import SystemKit

class MemoryStore: ObservableObject, Refreshable {
    @Published var free: Double = 0
    @Published var active: Double = 0
    @Published var inactive: Double = 0
    @Published var wired: Double = 0
    @Published var compressed: Double = 0
    @Published var appMemory: Double = 0
    @Published var cachedFiles: Double = 0
    @Published var temp: Double?
    @Published var usageHistory: [Double] = []

    var used: Double {
        appMemory + wired + compressed
    }

    var usedPercentage: Double {
        used / total * 100
    }

    var usedPercentageString: String {
        (used / total).percentageString
    }

    var total: Double {
        free + inactive + active + wired + compressed
    }

    var allFree: Double {
        total - used
    }

    var allFreePercentage: Double {
        allFree / total * 100
    }

    var freeString: String {
        (total - used).memoryString
    }

    var usedString: String {
        used.memoryString
    }

    @objc func refresh() {
        (free, active, inactive, wired, compressed, appMemory, cachedFiles) = System.memoryUsage()
        temp = SmcControl.shared.memoryProximityTemperature
        usageHistory = (usageHistory + [usedPercentage]).suffix(LineChart.defaultMaxPointCount)
    }

    init() {
        initObserver(for: .StoreShouldRefresh)
    }
}
