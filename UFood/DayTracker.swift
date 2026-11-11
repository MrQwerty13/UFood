//
//  DayTracker.swift
//  UFood
//

import Foundation
import Observation

@MainActor
@Observable
final class DayTracker {
    private(set) var dayStart: Date

    init(now: Date = Date(), calendar: Calendar = .current) {
        dayStart = calendar.startOfDay(for: now)
    }

    @discardableResult
    func refreshIfNeeded(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let newDayStart = calendar.startOfDay(for: now)
        guard newDayStart != dayStart else { return false }
        dayStart = newDayStart
        return true
    }
}
