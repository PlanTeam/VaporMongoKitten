public protocol DocumentRepresentable {
    var document: Document { get }
}

extension Document: DocumentRepresentable {
    public var document: Document {
        return self
    }
}

extension Array where Element: DocumentRepresentable {
    public var arrayDocument: Document {
        return Document(array: self.map {
            ~$0.document
        })
    }
} 
