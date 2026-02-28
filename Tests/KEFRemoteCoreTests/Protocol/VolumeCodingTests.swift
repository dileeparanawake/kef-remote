import Testing
@testable import KEFRemoteCore

// MARK: - Decoding: byte → VolumeState

@Test func testDecodeUnmutedVolume() {
    let state = VolumeCoding.decode(70)
    #expect(state.level == 70)
    #expect(!state.isMuted)
}

@Test func testDecodeZeroVolume() {
    let state = VolumeCoding.decode(0)
    #expect(state.level == 0)
    #expect(!state.isMuted)
}

@Test func testDecodeMaxVolume() {
    let state = VolumeCoding.decode(100)
    #expect(state.level == 100)
    #expect(!state.isMuted)
}

@Test func testDecodeMutedVolume() {
    // 198 = 128 + 70
    let state = VolumeCoding.decode(198)
    #expect(state.level == 70)
    #expect(state.isMuted)
}

@Test func testDecodeMutedAtZero() {
    // Edge case: muted at volume 0 (byte = 128)
    // The Perl reference gets this wrong — uses > 128 instead of >= 128
    let state = VolumeCoding.decode(128)
    #expect(state.level == 0)
    #expect(state.isMuted)
}

@Test func testDecodeMutedAtMax() {
    // 228 = 128 + 100
    let state = VolumeCoding.decode(228)
    #expect(state.level == 100)
    #expect(state.isMuted)
}

// MARK: - Encoding: VolumeState → byte

@Test func testEncodeUnmutedVolume() {
    let byte = VolumeCoding.encode(level: 70, isMuted: false)
    #expect(byte == 70)
}

@Test func testEncodeMutedVolume() {
    let byte = VolumeCoding.encode(level: 70, isMuted: true)
    #expect(byte == 198)
}

@Test func testEncodeMutedAtZero() {
    let byte = VolumeCoding.encode(level: 0, isMuted: true)
    #expect(byte == 128)
}

// MARK: - Clamping

@Test func testEncodeClampsBelowZero() {
    let byte = VolumeCoding.encode(level: -5, isMuted: false)
    #expect(byte == 0)
}

@Test func testEncodeClampsAbove100() {
    let byte = VolumeCoding.encode(level: 150, isMuted: false)
    #expect(byte == 100)
}

// MARK: - Round-trip

@Test func testRoundTripUnmuted() {
    let byte = VolumeCoding.encode(level: 55, isMuted: false)
    let state = VolumeCoding.decode(byte)
    #expect(state.level == 55)
    #expect(!state.isMuted)
}

@Test func testRoundTripMuted() {
    let byte = VolumeCoding.encode(level: 55, isMuted: true)
    let state = VolumeCoding.decode(byte)
    #expect(state.level == 55)
    #expect(state.isMuted)
}
