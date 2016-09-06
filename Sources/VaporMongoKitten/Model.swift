@_exported import MongoKitten


public enum ORMError : Error {
    case unfindableObject(collection: MongoKitten.Collection, id: BSON.ObjectId?)
    case unfetcheableEmbeddedModel(entity: Model.Type)
    case impossibleInitialization
    case invalidModel
    case undeletableObject(id: BSON.ObjectId?)
    case undeletableChildren(forObject: BSON.ObjectId?)
}

public protocol Model : class, CustomStringConvertible {
    var data: Document { get set }
    
    static var collection: MongoKitten.Collection { get }
    static var modelName: String { get }
    
    var deletable: Bool { get }
    
    func deleteChildren() throws
    func delete() throws
    
    init(data: Document) throws
    
    /// Types that store data in custom properties should implement this method to update the `data`. This is called when `update()` is called.
    func serializeCustomProperties() throws
    
    /// Types that store data in custom properties should implement this method to update the custom data with the data currently in `data`. This is called when the model is reprojected.
    func deserializeCustomProperties() throws
}

extension Model {
    public init(data: Document, validating: Bool) throws {
        try self.init(data: data)
    }
    
    public func serializeCustomProperties() {}
    public func deserializeCustomProperties() {}
}

extension Model {
    public subscript(key: String) -> BSON.Value {
        get {
            return data[key]
        }
        set {
            data[key] = newValue
        }
    }
    
    var id: ObjectId {
        get {
            guard case Value.objectId(let myId) = self["_id"] else {
                let myId = ObjectId()
                self["_id"] = ~myId
                
                return myId
            }
            
            return myId
        }
    }
}

extension Model {
    static func transform(cursor: Cursor<Document>) -> Cursor<Self> {
        return Cursor(base: cursor) { input in
            return try? Self(data: input)
        }
    }
    
    public static func find(matching query: MongoKitten.QueryProtocol? = nil, sortedBy sort: Document? = nil, projecting projection: BSON.Document? = nil) throws -> Cursor<Self> {
        
        let documentCursor: Cursor<Document>
        
        if let query = query {
            documentCursor = try collection.find(matching: query, sortedBy: sort, projecting: projection)
        } else {
            documentCursor = try collection.find(sortedBy: sort, projecting: projection)
        }
        
        return Self.transform(cursor: documentCursor)
    }
    
    public static func findOne(matching query: MongoKitten.QueryProtocol? = nil, sortedBy sort: Document? = nil, projecting projection: BSON.Document? = nil) throws -> Self? {
        return try self.find(matching: query, sortedBy: sort, projecting: projection).makeIterator().next()
    }
    
    public static func aggregate(_ pipeline: Document) throws -> Cursor<Self>{
        let cursor = try collection.aggregate(pipeline: pipeline)
        
        return Cursor(base: cursor) { input in
            return try? Self(data: input)
        }
    }
    
    public func store() throws {
        self["_id"] = try Self.collection.insert(self.data)["_id"]
    }
    
    /// - parameter unset: If true (default is false), keys in the `fields` array that don't exist in the model will be unset.
    public func update(fieldset fields: [String], unset: Bool = false) throws {
        try self.serializeCustomProperties()
        
        var setQuery: Document = [:]
        var unsetQuery: Document = [:]
        for field in fields {
            let value = self[field]
            if value != .nothing {
                setQuery[field] = value
            } else if unset {
                unsetQuery[field] = ""
            }
        }
        
        var totalQuery: Document = ["$set": ~setQuery]
        if unset && unsetQuery.count > 0 {
            totalQuery["$unset"] = ~unsetQuery
        }
        try Self.collection.update(matching: "_id" == self["_id"], to: totalQuery)
    }
    
    public func update(fields: String..., unset: Bool = false) throws {
        try update(fieldset: fields)
    }
    
    /// Change the fields in self with the fields from the database in projection
    ///
    /// - parameter combine: Defaults to true. Combines this projection with the previous.
    public func reproject(_ projection: BSON.Document, combine: Bool = true) throws {
        guard let data = try Self.collection.findOne(matching: "_id" == self["_id"], projecting: projection) else {
            throw ORMError.unfindableObject(collection: Self.collection, id: self["_id"].objectIdValue)
        }
        
        if combine {
            for (k, v) in data {
                self.data[k] = v
            }
        } else {
            self.data = data
        }
        
        try self.deserializeCustomProperties()
    }
    
    /// WARNING: Dangerous with incomplete data. If model has no _id, the id will be generated.
    public func completeUpsert() throws {
        try self.serializeCustomProperties()
        
        let id: ObjectId
        if let cid = self["_id"].objectIdValue {
            id = cid
        } else {
            id = ObjectId()
            self["_id"] = ~id
        }
        
        try Self.collection.update(matching: "_id" == id, to: self.data, upserting: true)
    }
    
    public func remove() throws {
        try Self.collection.remove(matching: "_id" == self["_id"])
    }
}

extension Model {
    /// Creates a model, fills it with the right data, checks it and then inserts it
    ///
    /// - throws: ValidationError
    public static func create(from document: Document) throws -> Self {
        let me = try Self(data: document)
        try me.store()
        
        return me
    }
}

extension Model {
    public var description: String {
        return "\(Self.modelName)(\(self["_id"].string))"
    }
    
    public func delete() throws {
        guard deletable else {
            throw ORMError.undeletableObject(id: self["_id"].objectIdValue)
        }
        
        try deleteChildren()
        try self.remove()
    }
    
    func deleteChildren() throws {}
}

extension Array where Element : Model {
    public var deletable: Bool {
        for model in self {
            guard model.deletable else {
                return false
            }
        }
        
        return true
    }
    
    public func makeArrayDocument() -> Document {
        return Document(array: self.map {
            ~$0.data
        })
    }
}
