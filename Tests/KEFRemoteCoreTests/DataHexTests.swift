import Testing
import Foundation
@testable import KEFRemoteCore

@Suite("Data+Hex")
struct DataHexTests {

    @Test("formats bytes as space-separated uppercase hex pairs")
    func hexFormatting() {
        let data = Data([0x47, 0x25, 0x80])
        #expect(data.hexString == "47 25 80")
    }

    @Test("empty data produces empty string")
    func emptyData() {
        let data = Data()
        #expect(data.hexString == "")
    }

    @Test("single byte has no separator")
    func singleByte() {
        let data = Data([0xFF])
        #expect(data.hexString == "FF")
    }
}
