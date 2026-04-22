import AppKit
import Testing
@testable import Wink

@Suite("App icon template")
struct AppIconTemplateTests {
    @Test
    func menuBarTemplateAssetLoadsAsTemplateSizedForStatusBar() {
        let image = WinkMenuBarTemplateAsset.image

        #expect(image.isTemplate == true)
        #expect(abs(image.size.width - 16) < 0.01)
        #expect(abs(image.size.height - 16) < 0.01)
        #expect(image.representations.isEmpty == false)
    }
}
