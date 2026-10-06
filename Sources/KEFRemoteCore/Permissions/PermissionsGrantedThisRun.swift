/// Which permissions he switched on while this copy of the app runs.
///
/// A permission allowed mid-run may not reach everything that needed it
/// (the volume key tap, a discovery that already failed), so setup
/// offers a restart once both are allowed (``PermissionsStepContinue``).
///
/// ```
/// notGranted ──> granted      counts: he allowed it during this run
/// notCheckedYet ──> granted   doesn't: Local Network was allowed before
///                             this run (the speaker answered first time)
/// ```
public struct PermissionsGrantedThisRun: Equatable, Sendable {
    public private(set) var permissions: Set<Permission> = []

    public init() {}

    /// Note a change of one permission.
    /// - Returns: True when it counts for the first time, so the caller
    ///   logs it once.
    public mutating func note(_ permission: Permission, from old: PermissionStatus, to new: PermissionStatus) -> Bool {
        guard old == .notGranted, new == .granted else { return false }
        return permissions.insert(permission).inserted
    }
}
