//  MFDates.swift
//  DataLayer — day bucketing. Log days use the DEVICE calendar (what the
//  user sees as "today"); the coaching engine's UTC helpers are used only
//  inside engine computations, never for day grouping.

import Foundation

public enum MFDates {
    /// Start of the log day containing `date`, in the device calendar.
    public static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Weekday 1…7 (1 = Sunday) in the device calendar.
    public static func weekday(of date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date)
    }
}
