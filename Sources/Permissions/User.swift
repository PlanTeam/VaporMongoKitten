//
//  User.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

/// A single human being with certain permissions
///
/// A certain `User` can have permissions that are set on his or her own user instance, but can also
/// belong to one or more groups. When the permissions conflict, they are compared as defined in
/// the `Level` enum.
public protocol User {
    /// Returns the permissions set for this single user instance
    var permissions: PermissionSet { get }
    
    /// Returns all groups this user belongs to
    var groups: [Group] { get }
}

extension User {
    public func level(forPermission permission: Permission, inApplication application: Application) -> Level {
        // Get all the declarations:
        let groupLevels = self.groups.flatMap{ group in
            group.permissions.permissions.first(where: {$0.permission == permission})?.level
        }
        
        // Sort them by importance and get the topmost result:
        let groupLevel = groupLevels.sorted(by: >).first ?? Level.undefined
        
        // Get the user level declaration:
        let userLevel = self.permissions.permissions.first { $0.permission == permission}?.level ?? Level.undefined
        
        // Get the application level declaration:
        let applicationLevel = application.permissions.first { $0.0 == permission}?.1 ?? Level.undefined
        
        // Return the most important one:
        let finalUserLevel = groupLevel > userLevel ? groupLevel : userLevel
        
        return applicationLevel > finalUserLevel ? applicationLevel : finalUserLevel
    }
}
