import AppKit
import ApplicationServices
import CoreGraphics
import KEFRemoteCore
import os

/// Intercepts media key events when a modifier key is held.
///
/// Uses a `CGEvent` tap to monitor system-defined events. When the
/// configured modifier (default: Control) is held and a media key
/// (volume up, volume down, mute, play/pause, next, previous) is
/// pressed, the event is consumed and the appropriate callback is
/// triggered instead of the system handling it. Without the modifier
/// every key stays the Mac's, so play/pause still controls the Mac's own
/// player. Which key a key code is lives in core (``MediaKey``).
///
/// **Accessibility permission** is required for the event tap to work.
/// Call ``checkAccessibility(prompt:)`` at launch to verify permission
/// and optionally show the system dialog.
///
/// Usage:
/// ```swift
/// let interceptor = MediaKeyInterceptor()
/// interceptor.onMediaKey = { key in
///     switch key {
///     case .volume(let command):   print("Volume \(command)")
///     case .playback(let command): print("Playback \(command)")
///     }
/// }
/// interceptor.start()
/// ```
///
/// This class only intercepts keys and fires callbacks. `AppDelegate`
/// turns the callbacks into speaker commands.
final class MediaKeyInterceptor {

    // MARK: - Event constants

    /// NSEvent subtype for media/special key events.
    private static let mediaKeySubtype: Int16 = 8

    /// The raw value of `NX_SYSDEFINED` / system-defined event type.
    /// CGEventType does not expose a `.systemDefined` case in Swift,
    /// so we compare against the raw value (14) directly.
    private static let systemDefinedEventType: UInt32 = 14

    // MARK: - Properties

    fileprivate let logger = AppLogger(
        subsystem: "com.kef-remote",
        category: "MediaKeyInterceptor"
    )

    /// Called when a media key is intercepted while the modifier is held.
    ///
    /// This callback is invoked on the main thread (the run loop
    /// thread where the event tap is installed).
    var onMediaKey: ((MediaKey) -> Void)?

    /// The modifier key that must be held to intercept media keys.
    ///
    /// Defaults to Control. When this modifier is held and a media key
    /// is pressed, the event is consumed (not passed to the system)
    /// and ``onMediaKey`` is called.
    var modifier: CGEventFlags = MediaKeyModifier.defaultChoice.eventFlags

    /// The Mach port for the CGEvent tap.
    fileprivate var eventTap: CFMachPort?

    /// The run loop source that drives the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Whether the tap is on: ``start()`` makes it only if macOS allows.
    var isRunning: Bool { eventTap != nil }

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    /// Start intercepting media key events.
    ///
    /// Creates a CGEvent tap for system-defined events and installs
    /// it on the main run loop. If the tap cannot be created (usually
    /// because Accessibility permission has not been granted), this
    /// method logs a warning and returns without starting.
    ///
    /// Calling `start()` when already started is a no-op.
    func start() {
        guard eventTap == nil else {
            logger.debug("Media key interceptor already running")
            return
        }

        // Create an unretained pointer to self for the C callback.
        // We use Unmanaged.passUnretained because the interceptor
        // owns the tap (and therefore outlives it). The tap is
        // destroyed in stop() or deinit before self is deallocated.
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let eventMask = CGEventMask(1 << Self.systemDefinedEventType)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: mediaKeyCallback,
            userInfo: refcon
        ) else {
            logger.warning(
                "Failed to create event tap — check Accessibility permission in System Settings"
            )
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, tap, 0
        ) else {
            logger.error("Failed to create run loop source for event tap")
            CFMachPortInvalidate(tap)
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        logger.info("Media key interceptor started")
    }

    /// Stop intercepting media key events.
    ///
    /// Disables and removes the CGEvent tap from the run loop.
    /// Calling `stop()` when not started is a no-op.
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        logger.info("Media key interceptor stopped")
    }

    // MARK: - Accessibility permission

    /// Check whether Accessibility permission has been granted.
    ///
    /// - Parameter prompt: If `true`, shows the system dialog asking
    ///   the user to grant Accessibility permission in System Settings.
    ///   Defaults to `false`.
    /// - Returns: `true` if the process is trusted for Accessibility.
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Event handling (called from C callback)

    /// Process a system-defined CGEvent and determine whether to
    /// intercept it.
    ///
    /// - Parameter event: The CGEvent from the tap callback.
    /// - Returns: The event to pass through, or `nil` to consume it.
    fileprivate func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Only process system-defined events (raw value 14).
        guard event.type.rawValue == Self.systemDefinedEventType else {
            return Unmanaged.passUnretained(event)
        }

        // Convert to NSEvent to access data1 and subtype.
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        // Subtype 8 indicates a media/special key event.
        guard nsEvent.subtype.rawValue == Self.mediaKeySubtype else {
            return Unmanaged.passUnretained(event)
        }

        // Parse the key code and key state from data1.
        //
        // data1 layout (from IOKit):
        //   bits 31-16: key code (NX_KEYTYPE_*)
        //   bits 15-8:  key state: NX_KEYDOWN (10) or NX_KEYUP (11)
        //   bits 7-0:   repeat flag
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyState = (data1 & 0x0000FF00) >> 8
        // Bit 0 tells NX_KEYUP (11) from NX_KEYDOWN (10).
        let isKeyUp = (keyState & 0x01) != 0

        // Check if this is a media key we care about.
        guard let key = MediaKey(keyCode: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        // Check if the modifier is held.
        let modifiers = event.flags
        guard modifiers.contains(modifier) else {
            // Modifier not held — pass the event through to the system.
            return Unmanaged.passUnretained(event)
        }

        // Modifier is held. We consume both key-down and key-up events
        // to prevent the system from processing either half of the
        // key press.

        if isKeyUp {
            // Dispatch once per press, on key-up, so a held key (which
            // repeats its key-down) sends one command. The code is logged
            // so a hand test shows which key a keyboard sends.
            logger.info("key: \(key) (code \(keyCode))")
            onMediaKey?(key)
        }

        // Return nil to consume the event (both key-down and key-up).
        return nil
    }
}

// MARK: - C callback function

/// The CGEvent tap callback. This is a C function pointer and cannot
/// capture any context — it receives the interceptor instance through
/// the `refcon` parameter.
///
/// This function also handles tap-disabled events by re-enabling the
/// tap. macOS disables event taps that take too long to process events
/// (the timeout is about 500ms). If that happens, we re-enable it
/// immediately.
private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap was disabled by the system (timeout or user input),
    // re-enable it and pass the event through.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            // The refcon points to the MediaKeyInterceptor instance.
            // Re-enable the tap through the interceptor's stored reference.
            let interceptor = Unmanaged<MediaKeyInterceptor>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            if let tap = interceptor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                interceptor.logger.info(
                    "Event tap was disabled by system — re-enabled"
                )
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Delegate to the interceptor instance for actual event handling.
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let interceptor = Unmanaged<MediaKeyInterceptor>
        .fromOpaque(refcon)
        .takeUnretainedValue()

    return interceptor.handleEvent(event)
}
