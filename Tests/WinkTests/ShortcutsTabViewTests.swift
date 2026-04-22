import Testing
@testable import Wink

@Suite("Shortcuts tab")
struct ShortcutsTabViewTests {
    @Test
    func pausedCaptureMapsToInfoBanner() {
        let status = ShortcutCaptureStatus(
            accessibilityGranted: true,
            inputMonitoringGranted: true,
            carbonHotKeysRegistered: false,
            eventTapActive: false,
            standardShortcutsReady: false,
            hyperShortcutsReady: false,
            shortcutsPaused: true
        )

        #expect(
            ShortcutBannerPresentation(status: status)
                == .info(title: "Shortcuts paused", message: "All shortcuts are paused.")
        )
    }
}
