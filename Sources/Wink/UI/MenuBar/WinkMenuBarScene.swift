import AppKit
import DeveloperToolsSupport
import SwiftUI

struct WinkMenuBarSceneDescriptor: Equatable {
    let title: String
    let imageName: String
    let usesWindowStyle: Bool
    let isInserted: Bool
}

enum WinkMenuBarTemplateAsset {
    static let name = "MenuBarTemplate"
    static let imageResource = ImageResource(name: name, bundle: .module)

    static var image: NSImage {
        NSImage(resource: imageResource)
    }
}

private enum WinkMenuBarSceneConstants {
    static let title = "Wink"
}

struct WinkMenuBarScene<Content: View>: Scene {
    @Binding private var isInserted: Bool
    @ViewBuilder private let content: () -> Content

    init(
        isInserted: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isInserted = isInserted
        self.content = content
    }

    nonisolated static func descriptor(isInserted: Bool) -> WinkMenuBarSceneDescriptor {
        WinkMenuBarSceneDescriptor(
            title: WinkMenuBarSceneConstants.title,
            imageName: WinkMenuBarTemplateAsset.name,
            usesWindowStyle: true,
            isInserted: isInserted
        )
    }

    var body: some Scene {
        MenuBarExtra(
            WinkMenuBarSceneConstants.title,
            image: WinkMenuBarTemplateAsset.imageResource,
            isInserted: $isInserted
        ) {
            content()
        }
        .menuBarExtraStyle(.window)
    }
}
