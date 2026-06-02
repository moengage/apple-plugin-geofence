// Type 1 — Fire and forget
// Use when: native API returns Void, no nativeToHybrid contract file.
// Example: startGeofenceMonitoring, stopGeofenceMonitoring
// RULE: always pass identifier to the native API — label varies (forAppID:, for:, workspaceId:)

@objc public func <methodName>(_ payload: [String: Any]) {
    let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    #if os(tvOS)
    MoEngageLogger.logDefault(message: "<MethodName> is unavailable for tvOS 🛑")
    #else
    // Use the label from the native signature — forAppID:, for:, or workspaceId:
    MoEngageSDKGeofence.sharedInstance.<nativeMethod>(forAppID: identifier)
    #endif
}

// Real example — startGeofenceMonitoring
@objc public func startGeofenceMonitoring(_ payload: [String: Any]) {
    let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    MoEngageSDKGeofence.sharedInstance.startGeofenceMonitoring(forAppID: identifier)
}

// Real example — stopGeofenceMonitoring
@objc public func stopGeofenceMonitoring(_ payload: [String: Any]) {
    let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    MoEngageSDKGeofence.sharedInstance.stopGeofenceMonitoring(forAppID: identifier)
}
