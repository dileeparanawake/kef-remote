import Testing
import Foundation
@testable import KEFRemoteCore

/// The rule for a volume press as the speaker powers on: a muted read in
/// the window is read again, and nothing else is.
struct PowerOnMuteGuardTests {
    let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
    let muted = VolumeState(level: 45, isMuted: true)
    let unmuted = VolumeState(level: 45, isMuted: false)

    @Test func aMutedReadSoonAfterTheAppTurnsItOnIsReadAgain() {
        var rule = PowerOnMuteGuard()
        rule.notePowerOnWrite(at: .seconds(10))
        #expect(rule.shouldReadAgain(muted, at: .seconds(15)))
    }

    @Test func anUnmutedReadIsNeverReadAgain() {
        var rule = PowerOnMuteGuard()
        rule.notePowerOnWrite(at: .seconds(10))
        #expect(!rule.shouldReadAgain(unmuted, at: .seconds(15)))
    }

    @Test func aMutedReadAfterTheWindowIsTrusted() {
        var rule = PowerOnMuteGuard()
        rule.notePowerOnWrite(at: .seconds(10))
        #expect(!rule.shouldReadAgain(muted, at: .seconds(10) + PowerOnMuteGuard.window))
    }

    @Test func withNoPowerOnSeenAMutedReadIsTrusted() {
        #expect(!PowerOnMuteGuard().shouldReadAgain(muted, at: .seconds(1)))
    }

    @Test func aReadOfOnAfterAReadOfOffStartsTheWindow() {
        var rule = PowerOnMuteGuard()
        rule.noteRead(on.with(isPoweredOn: false), at: .seconds(1))
        rule.noteRead(on, at: .seconds(30))
        #expect(rule.shouldReadAgain(muted, at: .seconds(31)))
        #expect(rule.sincePowerOn(at: .seconds(31)) == .seconds(1))
    }

    /// The first read says nothing about when it came on.
    @Test func aFirstReadOfOnDoesNotStartTheWindow() {
        var rule = PowerOnMuteGuard()
        rule.noteRead(on, at: .seconds(1))
        #expect(!rule.shouldReadAgain(muted, at: .seconds(2)))
    }

    @Test func readsOfOnInARowDoNotRestartTheWindow() {
        var rule = PowerOnMuteGuard()
        rule.noteRead(on.with(isPoweredOn: false), at: .seconds(1))
        rule.noteRead(on, at: .seconds(2))
        rule.noteRead(on, at: .seconds(20))
        #expect(!rule.shouldReadAgain(muted, at: .seconds(2) + PowerOnMuteGuard.window))
    }
}
