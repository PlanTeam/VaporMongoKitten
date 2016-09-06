//
//  FailsafeMiddleware.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 10-08-16.
//
//

import class HTTP.Response
import class HTTP.Request
import protocol HTTP.Responder
import protocol Vapor.Middleware

/// A middleware that will execute a closure when a request is handled without a proper permissions
/// check
///
/// Throw or crash in the closure to stop sending data to the client
public class FailsafeMiddleware: Middleware {
    public typealias FailsafeHandler = (Request, Response) throws -> ()
    
    let handler: FailsafeHandler
    
    public init(failsafeHandler handler: @escaping FailsafeHandler) {
        self.handler = handler
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let response = try next.respond(to: request)
        
        let statusCode = response.status.statusCode
        
        if !request.isPermissionChecked && statusCode >= 200 && statusCode < 300 {
            try self.handler(request, response)
        }
        
        return response
    }
}
