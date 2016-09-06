//
//  PermissionsChecker.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

import class HTTP.Request

/// An error type that represents permission failures
public enum PermissionError: Error {
    /// The permission check has failed because the user or application lacks a certain permission
    case denied(need: Permission)
    
    /// The permission check has failed because the request is not authenticated correctly
    case unauthenticated
    
    /// A permission could not be found with its machine identifier
    case unknownPermission
}

public extension Request {
    /// `true` when the permissions for this request have been checked, false otherwise
    public private(set) var isPermissionChecked: Bool {
        get {
            return self.storage["permissionsChecked"] as? Bool == true
        }
        set {
            self.storage["permissionsChecked"] = true
        }
    }
    
    private var user: User? {
        return self.storage["user"] as? User
    }
    
    private var application: Application? {
        return self.storage["application"] as? Application
    }
    
    /// Validates that the user for this request has a given permission
    ///
    /// Checking a permission requires that a `User` has been set for the key `user` in the requests
    /// `storage`, for example, by means of a custom middleware.
    ///
    /// - parameter permission: The permission you require.
    ///
    /// - throws: `PermissionError.denied` when the user lacks the required permission.
    public func require(_ permission: Permission) throws {
        guard let application = self.application else {
            throw PermissionError.unauthenticated
        }
        
        guard let user = self.user else {
            throw PermissionError.unauthenticated
        }
        
        guard level(forPermission: permission, onUser: user, inApplication: application).grantsAllowance else {
            throw PermissionError.denied(need: permission)
        }
        
        self.isPermissionChecked = true
    }
    
    /// Returns `true` if the user has access the given permission, or false otherwise
    public func level(forPermission permission: Permission, onUser user: User, inApplication application: Application) -> Level {
        return user.level(forPermission: permission, inApplication: application)
    }
    
    /// Explicitly mark this request as being safe for anonymous access
    public func allowAnonymous() {
        self.isPermissionChecked = true
    }
}
