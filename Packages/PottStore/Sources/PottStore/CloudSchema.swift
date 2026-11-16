import CoreData

extension Repository {
    /// Creates every record type of the model in the CloudKit development environment, so the schema
    /// can be exported and promoted to production before the first TestFlight build. Debug only;
    /// needs an iCloud account on the device.
    public func initializeCloudSchema() throws {
        try persistence.container.initializeCloudKitSchema(options: [])
    }

    /// The same off the main thread, for test builds on a device; `done` gets the error, if any.
    public func initializeCloudSchemaInBackground(_ done: @escaping @MainActor @Sendable (Bool) -> Void) {
        let container = persistence.container
        DispatchQueue.global(qos: .utility).async {
            let succeeded = (try? container.initializeCloudKitSchema(options: [])) != nil
            Task { @MainActor in done(succeeded) }
        }
    }
}
