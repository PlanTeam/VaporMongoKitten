import Vapor

/// The `Permission` protocol is to be implemented on enums.
/// 
/// Implementations provide a human-readable group description
/// trough the `groupDescription` static property. For example,
/// on a `enum EventPermission : Permission` this may be
/// something like "Event permissions".
///
/// The metadata property should return a machine identifier and
/// a human identifier. Both must be unique. The machine
/// identifier is mainly used for permission persistence. The
/// human identifier can be used in the interface of an
/// application.
public protocol Permission {
    
    /// A human-readable description for this permission set in general, like "Event permissions"
    static var groupDescription: String { get }
    
    /// Returns the machine and human identifier. See the documentation on `Permission` for more information.
    var metadata: (machineIdentifier: String, humanIdentifier: String) { get }
    
    /// Return all the possible values for this permission
    static var allValues: [Permission] { get }
}

/// A `Permission`-`Level` pair used as the storage mechanism for `User`, `Group` and `Application` permissions
public struct PermissionPair {
    public var pair: (Permission, Level) {
        get {
            return (permission, level)
        }
        set {
            self.permission = newValue.0
            self.level = newValue.1
        }
    }

    public private(set) var permission: Permission
    public private(set) var level: Level
    
    public init(permission: Permission, level: Level) {
        self.permission = permission
        self.level = level
    }
    
    public init(pair: (Permission, Level)) {
        self.permission = pair.0
        self.level = pair.1
    }
}

public struct PermissionSet: ExpressibleByDictionaryLiteral {
    public subscript(key: Permission) -> Level? {
        get {
            guard let index = self.permissions.index(where: { pair in
                return pair.pair.0 == key
            }) else {
                return nil
            }
            
            return self.permissions[index].pair.1
        }
        set {
            let index = self.permissions.index(where: { pair in
                return pair.pair.0 == key
            })
            
            if let value = newValue {
                if let index = index {
                    self.permissions.remove(at: index)
                }
                let pair = PermissionPair(permission: key, level: value)
                self.permissions.append(pair)
                
            } else if let index = index {
                self.permissions.remove(at: index)
            }
        }
    }
    
    public private(set) var permissions: [PermissionPair]
    
    public init(dictionaryLiteral elements: (Permission, Level)...) {
        self.permissions = elements.map { PermissionPair(pair: $0) }
    }
    
    public init(array elements: [(Permission, Level)]) {
        self.permissions = elements.map { PermissionPair(pair: $0) }
    }

    public typealias Key = Permission
    public typealias Value = Level
    
}

public extension Permission {
    
    /// Extracts the `machineIdentifier` from the `metadata`.
    var machineIdentifier: String {
        return self.metadata.machineIdentifier
    }
    
    /// Extracts the `humanIdentifier` from the `metadata`.
    var humanIdentifier: String {
        return self.metadata.humanIdentifier
    }
}

public func ==(lhs: Permission, rhs: Permission) -> Bool {
    return lhs.machineIdentifier == rhs.machineIdentifier
}
