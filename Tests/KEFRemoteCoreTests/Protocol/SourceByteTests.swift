import Testing
@testable import KEFRemoteCore

// MARK: - Decoding

@Test func testDecodeOpticalPoweredOn60MinStandby() {
    // Byte 0x1B (binary: 0001_1011)
    // Bit 7=0 (on), bit 6=0 (no inverse), bits 5-4=01 (60min), bits 3-0=1011 (optical)
    let source = SourceByte(byte: 0x1B)
    #expect(source.isPoweredOn == true)
    #expect(source.isInversed == false)
    #expect(source.standby == .sixtyMinutes)
    #expect(source.input == .optical)
}

@Test func testDecodePoweredOff() {
    // Byte 0x9B (binary: 1001_1011) — bit 7=1 (off)
    let source = SourceByte(byte: 0x9B)
    #expect(source.isPoweredOn == false)
    #expect(source.input == .optical)
}

@Test func testDecodeInversed() {
    // Byte 0x5B (binary: 0101_1011) — bit 6=1 (inversed)
    let source = SourceByte(byte: 0x5B)
    #expect(source.isInversed == true)
}

@Test func testDecode20MinStandby() {
    // Byte 0x0B (binary: 0000_1011) — bits 5-4=00
    let source = SourceByte(byte: 0x0B)
    #expect(source.standby == .twentyMinutes)
}

@Test func testDecodeNeverStandby() {
    // Byte 0x2B (binary: 0010_1011) — bits 5-4=10
    let source = SourceByte(byte: 0x2B)
    #expect(source.standby == .never)
}

@Test func testDecodeAllInputSources() {
    // Base: 0b0001_0000 (power on, no inverse, 60min standby, input=0)
    let base: UInt8 = 0b0001_0000

    let wifi = SourceByte(byte: base | 0b0010)
    #expect(wifi.input == .wifi)

    let usb = SourceByte(byte: base | 0b1100)
    #expect(usb.input == .usb)

    let btPaired = SourceByte(byte: base | 0b1001)
    #expect(btPaired.input == .bluetoothPaired)

    let btUnpaired = SourceByte(byte: base | 0b1111)
    #expect(btUnpaired.input == .bluetoothUnpaired)

    let aux = SourceByte(byte: base | 0b1010)
    #expect(aux.input == .aux)

    let optical = SourceByte(byte: base | 0b1011)
    #expect(optical.input == .optical)
}

// MARK: - Encoding

@Test func testEncodeOpticalPoweredOn60Min() {
    let source = SourceByte(
        isPoweredOn: true, isInversed: false,
        standby: .sixtyMinutes, input: .optical
    )
    #expect(source.encode() == 0x1B)
}

@Test func testEncodePoweredOff() {
    let source = SourceByte(
        isPoweredOn: false, isInversed: false,
        standby: .sixtyMinutes, input: .optical
    )
    #expect(source.encode() == 0x9B)
}

@Test func testEncodeInversed() {
    let source = SourceByte(
        isPoweredOn: true, isInversed: true,
        standby: .sixtyMinutes, input: .optical
    )
    #expect(source.encode() == 0x5B)
}

// MARK: - Round-trip

@Test func testRoundTripPreservesAllFields() {
    // Create with all non-default values
    let original = SourceByte(
        isPoweredOn: false, isInversed: true,
        standby: .never, input: .usb
    )
    let encoded = original.encode()
    let decoded = SourceByte(byte: encoded)
    #expect(decoded.isPoweredOn == original.isPoweredOn)
    #expect(decoded.isInversed == original.isInversed)
    #expect(decoded.standby == original.standby)
    #expect(decoded.input == original.input)
}

// MARK: - Read-modify-write helpers

@Test func testWithPowerPreservesOtherBits() {
    // Start with 0x1B (on, not inversed, 60min, optical)
    let original = SourceByte(byte: 0x1B)
    let modified = original.with(isPoweredOn: false)
    // Only power should change
    #expect(modified.isPoweredOn == false)
    #expect(modified.isInversed == original.isInversed)
    #expect(modified.standby == original.standby)
    #expect(modified.input == original.input)
}

@Test func testWithInputPreservesOtherBits() {
    // Start with 0x1B (on, not inversed, 60min, optical)
    let original = SourceByte(byte: 0x1B)
    let modified = original.with(input: .wifi)
    // Only input should change
    #expect(modified.input == .wifi)
    #expect(modified.isPoweredOn == original.isPoweredOn)
    #expect(modified.isInversed == original.isInversed)
    #expect(modified.standby == original.standby)
}

@Test func testWithStandbyPreservesOtherBits() {
    // Start with 0x1B (on, not inversed, 60min, optical)
    let original = SourceByte(byte: 0x1B)
    let modified = original.with(standby: .never)
    // Only standby should change
    #expect(modified.standby == .never)
    #expect(modified.isPoweredOn == original.isPoweredOn)
    #expect(modified.isInversed == original.isInversed)
    #expect(modified.input == original.input)
}
