import SwiftUI

struct WinkMenuBarSceneDescriptor: Equatable {
    let title: String
    let systemImage: String
    let usesWindowStyle: Bool
    let isInserted: Bool
}

private enum WinkMenuBarSceneConstants {
    static let title = "Wink"
    static let systemImage = "bolt.square.fill"
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
            systemImage: WinkMenuBarSceneConstants.systemImage,
            usesWindowStyle: true,
            isInserted: isInserted
        )
    }

    var body: some Scene {
        MenuBarExtra(
            WinkMenuBarSceneConstants.title,
            systemImage: WinkMenuBarSceneConstants.systemImage,
            isInserted: $isInserted
        ) {
            content()
        }
        .menuBarExtraStyle(.window)
    }
}
