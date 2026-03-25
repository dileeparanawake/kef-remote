import KEFRemoteCore

/// Factory that creates AppLogger instances with a shared subsystem and LogWriter.
struct AppKefLogFactory: KefLogFactory {

    private let subsystem: String
    private let writer: LogWriter

    init(subsystem: String = "com.kef-remote", writer: LogWriter = LogWriter()) {
        self.subsystem = subsystem
        self.writer = writer
    }

    func makeLogger(category: String) -> KefLog {
        AppLogger(subsystem: subsystem, category: category, writer: writer)
    }
}
