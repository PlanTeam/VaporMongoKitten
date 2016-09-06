//
//  Group.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

/// A group of human beings with certain permissions
public protocol Group {
    /// The permissions for all members of this group
    var permissions: PermissionSet { get }
}
