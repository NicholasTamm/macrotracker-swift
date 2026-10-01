//  MFDataError.swift
//  DataLayer — shared error type for every repository.

import Foundation

public enum MFDataError: Error, Sendable, Equatable {
    case notFound(String)
    case duplicate(String)
    case invalidInput(String)
    case networkUnavailable
    case underlying(String)

    public var userMessage: String {
        switch self {
        case .notFound(let what): return "\(what) could not be found."
        case .duplicate(let what): return "\(what) already exists."
        case .invalidInput(let why): return why
        case .networkUnavailable: return "You're offline. Try again when connected."
        case .underlying(let message): return message
        }
    }
}
