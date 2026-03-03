import CoreWLAN
import Foundation
import os

/// Monitors Wi-Fi network changes and publishes active/dormant state.
///
/// When the current SSID matches the configured home SSID, the monitor
/// reports ``NetworkState/active`` and the app should function normally.
/// When on a different network or disconnected, it reports
/// ``NetworkState/dormant`` and the app should disable hotkeys and skip
/// lifecycle hooks.
///
/// If ``homeSSID`` is `nil` (not configured yet), the monitor defaults
/// to ``NetworkState/active`` — the assumption is that the user hasn't
/// configured network awareness yet, so we allow the app to work
/// everywhere.
///
/// Usage:
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.homeSSID = "MyHomeNetwork"
/// monitor.onStateChange = { state in
///     print("Network state: \(state)")
/// }
/// try monitor.start()
/// ```
///
/// The actual integration with hotkeys and lifecycle hooks is NOT wired
/// here — that happens in the integration task (Task 22). This class
/// only provides the monitoring infrastructure and state publishing.
final class NetworkMonitor: NSObject {

    // MARK: - Types

    /// Whether the app should be active or dormant based on the current
    /// Wi-Fi network.
    enum NetworkState: Equatable, CustomStringConvertible {
        /// On the home network (or homeSSID not configured).
        case active
        /// On a different network or disconnected from Wi-Fi.
        case dormant

        var description: String {
            switch self {
            case .active: "active"
            case .dormant: "dormant"
            }
        }
    }

    // MARK: - Properties

    private let logger = Logger(
        subsystem: "com.kef-remote",
        category: "NetworkMonitor"
    )

    /// Current network state.
    ///
    /// Updated when the SSID changes. Always accessed and mutated on
    /// the main thread.
    private(set) var state: NetworkState = .dormant

    /// Called when the network state changes.
    ///
    /// Invoked on the main thread. Only called when the state actually
    /// changes (not on every SSID check).
    var onStateChange: ((NetworkState) -> Void)?

    /// The home SSID to compare against.
    ///
    /// If `nil`, the monitor treats all networks as home (defaults to
    /// ``NetworkState/active``). When set, the monitor compares the
    /// current Wi-Fi SSID against this value (case-sensitive match).
    var homeSSID: String? {
        didSet {
            // Re-evaluate state when homeSSID changes.
            checkCurrentNetwork()
        }
    }

    /// The CoreWLAN client used for Wi-Fi monitoring.
    private let wifiClient: CWWiFiClient

    /// Whether the monitor is currently subscribed to SSID change events.
    private var isMonitoring = false

    // MARK: - Initialization

    /// Create a network monitor.
    ///
    /// - Parameter wifiClient: The CoreWLAN client to use. Defaults to
    ///   the shared instance. Exposed for testing if needed.
    init(wifiClient: CWWiFiClient = .shared()) {
        self.wifiClient = wifiClient
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Start monitoring Wi-Fi network changes.
    ///
    /// Reads the current SSID, evaluates initial state, and subscribes
    /// to SSID change notifications via CoreWLAN's event delegate.
    ///
    /// - Throws: If CoreWLAN fails to start monitoring events.
    func start() throws {
        guard !isMonitoring else {
            logger.debug("Network monitor already running")
            return
        }

        // Set ourselves as the delegate to receive SSID change events.
        wifiClient.delegate = self

        // Subscribe to SSID change notifications.
        try wifiClient.startMonitoringEvent(with: .ssidDidChange)
        isMonitoring = true

        logger.info("Network monitor started")

        // Evaluate the initial state based on the current SSID.
        checkCurrentNetwork()
    }

    /// Stop monitoring Wi-Fi network changes.
    ///
    /// Unsubscribes from all CoreWLAN events. Calling `stop()` when
    /// not started is a no-op.
    func stop() {
        guard isMonitoring else { return }

        do {
            try wifiClient.stopMonitoringAllEvents()
        } catch {
            logger.warning("Failed to stop monitoring events: \(error.localizedDescription)")
        }

        wifiClient.delegate = nil
        isMonitoring = false

        logger.info("Network monitor stopped")
    }

    // MARK: - Network evaluation

    /// Read the current SSID and update state accordingly.
    ///
    /// This is called automatically on start and when the SSID changes.
    /// It can also be called manually to force a re-evaluation (e.g.,
    /// after the user changes the homeSSID in settings).
    func checkCurrentNetwork() {
        let currentSSID = wifiClient.interface()?.ssid()
        let newState = evaluateState(currentSSID: currentSSID)

        logger.info("Network check: SSID=\(currentSSID ?? "<none>", privacy: .public), homeSSID=\(self.homeSSID ?? "<not set>", privacy: .public), state=\(newState.description, privacy: .public)")

        updateState(newState)
    }

    /// Determine what the network state should be given the current SSID.
    ///
    /// - Parameter currentSSID: The SSID from CoreWLAN, or `nil` if
    ///   disconnected.
    /// - Returns: The evaluated network state.
    private func evaluateState(currentSSID: String?) -> NetworkState {
        // If no home SSID is configured, default to active (don't
        // restrict functionality until the user sets up network awareness).
        guard let homeSSID = homeSSID else {
            return .active
        }

        // If we can't read the SSID (disconnected from Wi-Fi), go dormant.
        guard let currentSSID = currentSSID else {
            return .dormant
        }

        // Case-sensitive comparison against the home SSID.
        return currentSSID == homeSSID ? .active : .dormant
    }

    /// Update the stored state and notify the callback if it changed.
    ///
    /// Ensures the state update and callback happen on the main thread,
    /// since CWEventDelegate methods are called on arbitrary threads.
    private func updateState(_ newState: NetworkState) {
        let notify = { [weak self] in
            guard let self = self else { return }
            let oldState = self.state
            self.state = newState
            if oldState != newState {
                self.logger.info(
                    "Network state changed: \(oldState.description) -> \(newState.description)"
                )
                self.onStateChange?(newState)
            }
        }

        if Thread.isMainThread {
            notify()
        } else {
            DispatchQueue.main.async(execute: notify)
        }
    }
}

// MARK: - CWEventDelegate

extension NetworkMonitor: CWEventDelegate {
    /// Called by CoreWLAN when the Wi-Fi SSID changes.
    ///
    /// This method is called on an arbitrary thread. We dispatch the
    /// state evaluation to the main thread via ``updateState(_:)``.
    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        logger.debug("SSID change detected on interface: \(interfaceName, privacy: .public)")
        checkCurrentNetwork()
    }
}
