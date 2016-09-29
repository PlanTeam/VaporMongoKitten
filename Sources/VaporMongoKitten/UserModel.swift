import Permissions
import BCrypt

public protocol UserModel: Model, User {
    var username: String { get }
    var password: String { get }
}

extension UserModel {
    public func setPermission(_ permission: Permission, atLevel level: Level) {
        var permissions = self.permissions
        
        permissions[permission] = level
        
        self["permissions"] = ~permissions.makeDocument()
    }
    
    /// The permissions that are bound to this specific `User` exlucding `Group`s
    public var permissions: PermissionSet {
        return PermissionSet.make(from: self["permissions"].document)
    }
    
    /// Hashes the password
    public static func hash(password: String) throws -> String {
        let derivedKey = BCrypt.hash(password: password)
        
        return derivedKey
    }
    
    public func validate(against inputPassword: String) throws -> Bool {
        return try BCrypt.verify(password: inputPassword, matchesHash: password)
    }
}
