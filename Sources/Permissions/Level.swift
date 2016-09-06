//
//  Level.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//


/// Defines the allowance level of a `Permission` on a User, Group or Application.
/// 
/// Levels have the following importance, from most to least important:
/// - Force allow
/// - Deny
/// - Allow
/// - Unknown
///
/// Unknown is the default value.
public enum Level {
    case undefined
    case allow
    case deny
    case forceAllow
    
    /// `true` if the level grants allowance, false otherwise
    public var grantsAllowance: Bool {
        switch self {
        case .allow, .forceAllow: return true
        default: return false
        }
    }
}

extension Level : Comparable {
    private var compareValue: Int {
        switch self {
        case .undefined: return 0
        case .allow: return 10
        case .deny: return 20
        case .forceAllow: return 30
        }
    }
    
    public static func <(lhs: Level, rhs: Level) -> Bool {
        return lhs.compareValue < rhs.compareValue
    }
}
