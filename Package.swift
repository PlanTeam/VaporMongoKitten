import PackageDescription

let package = Package(
    name: "VaporMongoKitten",
    targets: [
        // Framework
        Target(name: "VaporMongoKittenExample", dependencies: ["VaporMongoKitten"]),
        Target(name: "VaporMongoKitten", dependencies: ["Permissions"]),
        Target(name: "Permissions"),
        ],
    dependencies: [
        .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 0, minor: 17),
        .Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 1, minor: 5),
        .Package(url: "https://github.com/OpenKitten/LogKitten.git", majorVersion: 0, minor: 2),
    ]
)
