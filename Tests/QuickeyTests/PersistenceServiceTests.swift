import Foundation
import Testing
@testable import Quickey

@Suite("PersistenceService disk loading")
struct PersistenceServiceDiskLoadingTests {
    @Test
    func roundTripsCurrentSchemaThroughDisk() throws {
        let harness = try PersistenceServiceHarness()
        defer { harness.cleanup() }

        let shortcuts = [
            AppShortcut(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["command", "shift"]
            ),
            AppShortcut(
                appName: "IINA",
                bundleIdentifier: "com.colliderli.iina",
                keyEquivalent: "i",
                modifierFlags: ["command", "option"],
                isEnabled: false
            ),
        ]

        let service = harness.makeService()
        service.save(shortcuts)

        let loaded = try service.load()

        #expect(loaded == shortcuts)
        #expect(harness.diagnostics.messages.isEmpty)
    }

    @Test
    func preservesMalformedJSONAndThrows() throws {
        let harness = try PersistenceServiceHarness()
        defer { harness.cleanup() }

        let malformed = Data("{ definitely not json".utf8)
        try malformed.write(to: harness.shortcutsURL)

        let service = harness.makeService(backupID: "malformed")

        #expect(throws: PersistenceService.LoadError.self) {
            try service.load()
        }

        let backupURL = harness.directory.appendingPathComponent("shortcuts.load-failure-malformed.json")
        #expect(try Data(contentsOf: harness.shortcutsURL) == malformed)
        #expect(try Data(contentsOf: backupURL) == malformed)
        #expect(harness.diagnostics.messages.contains {
            $0.contains("path=\(harness.shortcutsURL.path)") && $0.contains("reason=")
        })
    }

    @Test
    func rejectsMissingIsEnabledPayloadWithoutSilentMigration() throws {
        let harness = try PersistenceServiceHarness()
        defer { harness.cleanup() }

        let legacyPayload = Data(
            """
            [
              {
                "id": "12345678-1234-1234-1234-123456789012",
                "appName": "Safari",
                "bundleIdentifier": "com.apple.Safari",
                "keyEquivalent": "s",
                "modifierFlags": ["command"]
              }
            ]
            """.utf8
        )
        try legacyPayload.write(to: harness.shortcutsURL)

        let service = harness.makeService(backupID: "missing-enabled")

        #expect(throws: PersistenceService.LoadError.self) {
            try service.load()
        }

        let backupURL = harness.directory.appendingPathComponent("shortcuts.load-failure-missing-enabled.json")
        #expect(try Data(contentsOf: harness.shortcutsURL) == legacyPayload)
        #expect(try Data(contentsOf: backupURL) == legacyPayload)
        #expect(harness.diagnostics.messages.contains {
            $0.contains("path=\(harness.shortcutsURL.path)") && $0.contains("reason=")
        })
    }

    @Test
    func rejectsUnsupportedSchemaPayload() throws {
        let harness = try PersistenceServiceHarness()
        defer { harness.cleanup() }

        let unsupportedPayload = Data(
            """
            {
              "schemaVersion": 2,
              "shortcuts": []
            }
            """.utf8
        )
        try unsupportedPayload.write(to: harness.shortcutsURL)

        let service = harness.makeService(backupID: "unsupported-schema")

        #expect(throws: PersistenceService.LoadError.self) {
            try service.load()
        }

        let backupURL = harness.directory.appendingPathComponent("shortcuts.load-failure-unsupported-schema.json")
        #expect(try Data(contentsOf: harness.shortcutsURL) == unsupportedPayload)
        #expect(try Data(contentsOf: backupURL) == unsupportedPayload)
    }
}

private struct PersistenceServiceHarness {
    let directory: URL
    let shortcutsURL: URL
    let diagnostics = DiagnosticRecorder()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        shortcutsURL = directory.appendingPathComponent("shortcuts.json")
    }

    func makeService(backupID: String = "fixture") -> PersistenceService {
        PersistenceService(
            storageURLProvider: { shortcutsURL },
            diagnosticClient: .init(log: { message in
                diagnostics.append(message)
            }),
            backupIDProvider: { backupID }
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class DiagnosticRecorder: @unchecked Sendable {
    private(set) var messages: [String] = []

    func append(_ message: String) {
        messages.append(message)
    }
}
