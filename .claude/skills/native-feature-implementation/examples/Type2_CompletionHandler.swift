// Type 2 — Completion handler
// Use when: nativeToHybrid contract exists AND native API has a completion closure.
// The bridge method takes a completionHandler param — hybrid caller gets result directly.
// Response dict keys must exactly match the nativeToHybrid contract file.
// RULE: identifier is non-optional — fetch directly, no guard let needed.

@objc public func <methodName>(
    _ payload: [String: Any],
    completionHandler: @escaping ([String: Any]) -> Void
) {
    let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    #if os(tvOS)
    MoEngageLogger.logDefault(message: "<MethodName> is unavailable for tvOS 🛑")
    #else
    MoEngageSDKGeofence.sharedInstance.<nativeMethod>(forAppID: identifier) { result in
        // Build response matching the nativeToHybrid contract keys
        let response: [String: Any] = [
            MoEngagePluginConstants.General.accountMeta:
                MoEngagePluginUtils.createAccountPayload(identifier: identifier),
            MoEngagePluginConstants.General.data: [
                "<contractResponseKey>": result.<responseField> as Any
            ]
        ]
        completionHandler(response)
    }
    #endif
}
