/// Factory for creating loggers scoped to a concern.
///
/// Concerns receive a factory or a pre-made logger - never construct their own.
public protocol KefLogFactory: Sendable {
    func makeLogger(category: String) -> KefLog
}
