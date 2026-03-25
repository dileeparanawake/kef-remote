import Foundation
import KEFRemoteCore

@main
struct App {
    static func main() {
        let factory = AppKefLogFactory()
        let log = factory.makeLogger(category: "App")

        log.info("KEF Remote starting")
        log.debug("Debug logging active")
        log.warning("Test warning message")
        log.error("Test error message")

        RunLoop.current.run()
    }
}
