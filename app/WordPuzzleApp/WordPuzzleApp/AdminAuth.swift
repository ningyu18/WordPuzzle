import LocalAuthentication

/// Device-auth gate for the admin "reveal all answers" affordance. Uses
/// `.deviceOwnerAuthentication`, which prompts Face ID / Touch ID and falls
/// back to the device passcode automatically. No entitlement required; Face ID
/// only needs the NSFaceIDUsageDescription Info.plist key.
enum AdminAuth {
    /// Prompt the user for Face ID / Touch ID / passcode. Returns true on
    /// success, false if authentication is unavailable or fails.
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        // No passcode set (or otherwise unavailable) → reveal stays locked.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication,
                                        error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Reveal all puzzle answers")) ?? false
    }
}
