import Testing
@testable import KEFRemoteCore

/// Which inputs the saved speaker has: no USB on an LSX.
struct SpeakerModelTests {
    private func model(name: String? = nil, model: String? = nil) -> SpeakerModel {
        SpeakerModel(AppConfig.SpeakerConfig(name: name, model: model))
    }

    @Test func theLSXsModelNameMakesItAnLSX() {
        #expect(model(name: "Living room", model: "SP3994") == .lsx)
        #expect(model(model: "sp3994") == .lsx)
    }

    /// A config saved before the model was kept: Dileepa's says "LSX".
    @Test func withNoModelTheNameDecides() {
        #expect(model(name: "LSX") == .lsx)
        #expect(model(name: "KEF lsx") == .lsx)
        #expect(model(name: "LS50 Wireless") == .other)
    }

    @Test func aKnownModelThatIsNotAnLSXWinsOverTheName() {
        #expect(model(name: "LSX", model: "LS50W") == .other)
    }

    @Test func anUnknownSpeakerOffersEveryInput() {
        #expect(SpeakerModel(nil) == .other)
        #expect(model() == .other)
    }

    @Test func theLSXHasNoUSB() {
        #expect(!SpeakerModel.lsx.hasUSBInput)
        #expect(SpeakerModel.lsx.inputs == [.optical, .wifi, .bluetoothPaired, .aux])
    }

    @Test func otherSpeakersHaveEveryInput() {
        #expect(SpeakerModel.other.hasUSBInput)
        #expect(SpeakerModel.other.inputs == [.optical, .wifi, .bluetoothPaired, .aux, .usb])
    }

    @Test func inputOnTurnOnLeavesOutUSBOnAnLSX() {
        #expect(SpeakerModel.lsx.powerOnChoices(keeping: .dontChange)
            == [.dontChange, .optical, .wifi, .bluetooth, .aux])
        #expect(SpeakerModel.other.powerOnChoices(keeping: .dontChange) == PowerOnInput.allCases)
    }

    /// The picker must list what it shows.
    @Test func aSavedUSBChoiceStaysListedOnAnLSX() {
        #expect(SpeakerModel.lsx.powerOnChoices(keeping: .usb).contains(.usb))
    }
}
