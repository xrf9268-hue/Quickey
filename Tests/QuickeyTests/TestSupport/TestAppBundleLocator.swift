import Foundation
@testable import Quickey

private let defaultResolvedTestBundleIdentifiers: Set<String> = [
    "com.apple.Safari",
    "com.apple.Terminal",
    "com.apple.Mail",
    "com.apple.Finder",
    "com.colliderli.iina",
    "com.mitchellh.ghostty",
]

func makeTestAppBundleLocator(
    resolvedBundleIdentifiers: Set<String> = defaultResolvedTestBundleIdentifiers
) -> AppBundleLocator {
    AppBundleLocator(applicationURLClient: { bundleIdentifier in
        guard resolvedBundleIdentifiers.contains(bundleIdentifier) else {
            return nil
        }

        let appName = bundleIdentifier
            .split(separator: ".")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
            ?? "TestApp"

        return URL(fileURLWithPath: "/Applications/\(appName).app")
    })
}
