//
//  Application.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

import Foundation

public protocol Application {
    /// The permissions for this application
    var permissions: [(Permission, Level)] { get }
}
