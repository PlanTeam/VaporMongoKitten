//
//  Application.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

import Foundation

/// An Application is used to determine the permissions certain API keys have.
///
/// Example: A backend could have an API key for the Web, iOS and Android client.
public protocol Application {
    /// The permissions for this application
    var permissions: [(Permission, Level)] { get }
}
