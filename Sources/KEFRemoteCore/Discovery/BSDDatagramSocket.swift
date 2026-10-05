import Foundation

/// A failed socket call, with the errno text, for the log.
public struct SocketError: Error, CustomStringConvertible {
    public let call: String
    public let code: Int32

    init(_ call: String, code: Int32 = errno) {
        self.call = call
        self.code = code
    }

    public var description: String { "\(call) failed: \(String(cString: strerror(code))) (errno \(code))" }
}

/// A plain BSD UDP socket for SSDP.
///
/// Why not Network.framework: an `NWConnection` to the multicast address
/// acts as a connected socket, so it drops the replies, which come back
/// unicast from each device's own address and port. This socket binds to
/// any free port and never calls `connect()`, so every reply gets in.
///
/// Multicast TTL is 2, as UPnP asks. No entitlement is needed on macOS.
/// Not unit-tested: check it with `make discover` against a real speaker.
public final class BSDDatagramSocket: DatagramSocket, @unchecked Sendable {
    private let descriptor: Int32
    private let lock = NSLock()
    private var isOpen = true

    public init() throws {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw SocketError("socket") }

        var ttl: UInt8 = 2
        guard setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size)) == 0 else {
            let error = SocketError("setsockopt(IP_MULTICAST_TTL)")
            Darwin.close(fd)
            throw error
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0                       // any free port
        address.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let error = SocketError("bind")
            Darwin.close(fd)
            throw error
        }

        descriptor = fd
    }

    deinit { close() }

    public func send(_ data: Data, toHost host: String, port: UInt16) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw SocketError("inet_pton(\(host))", code: EINVAL)
        }

        let sent = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(descriptor, bytes.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw SocketError("sendto") }
    }

    public func receive(until deadline: ContinuousClock.Instant) async throws -> Datagram? {
        let fd = descriptor
        // poll() blocks, so wait on a GCD thread, not the async pool.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try Self.waitForDatagram(on: fd, until: deadline) })
            }
        }
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        guard isOpen else { return }
        isOpen = false
        Darwin.close(descriptor)
    }

    private static func waitForDatagram(on fd: Int32, until deadline: ContinuousClock.Instant) throws -> Datagram? {
        while true {
            let remaining = ContinuousClock.now.duration(to: deadline)
            guard remaining > .zero else { return nil }
            let milliseconds = Int32(remaining.components.seconds * 1000
                                     + remaining.components.attoseconds / 1_000_000_000_000_000)

            var request = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&request, 1, max(milliseconds, 1))
            if ready < 0 {
                if errno == EINTR { continue }
                throw SocketError("poll")
            }
            if ready == 0 { return nil }

            var buffer = [UInt8](repeating: 0, count: 4096)
            var sender = sockaddr_in()
            var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &senderLength)
                }
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw SocketError("recvfrom")
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &sender.sin_addr, &hostBuffer, socklen_t(INET_ADDRSTRLEN))
            return Datagram(data: Data(buffer[0..<count]), fromHost: String(cString: hostBuffer))
        }
    }
}
