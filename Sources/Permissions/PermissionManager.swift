//
//  PermissionManager.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

public enum PermissionManager {
    
    /// The permissions database, used for looking them up by machine identifier
    private static var permissions = [String : Permission]()
    
    /// Register the given permissions in the Manager
    public static func register(_ permissionType: Permission.Type) {
        for permission in permissionType.allValues {
            PermissionManager.permissions[permission.machineIdentifier] = permission
        }
    }
    
    /// Get the permission for the given identifier
    ///
    /// - throws: PermissionError.unknownPermission
    public static func find(_ permissionIdentifier: String) throws -> Permission {
        guard let permission = permissions[permissionIdentifier] else {
            throw PermissionError.unknownPermission
        }
        
        return permission
    }
    
    public static var fullAllowance: [(Permission, Level)] {
        return permissions.map { _, permission in return (permission, .allow) }
    }
    
}
