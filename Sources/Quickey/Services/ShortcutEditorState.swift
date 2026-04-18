import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ShortcutEditorState {
    enum RecipeFeedback: Equatable {
        case success(String)
        case error(String)

        var message: String {
            switch self {
            case let .success(message), let .error(message):
                message
            }
        }

        var isError: Bool {
            if case .error = self {
                return true
            }
            return false
        }
    }

    struct RecipeTransferClient {
        let importData: @MainActor () throws -> Data?
        let exportData: @MainActor (_ suggestedFilename: String, _ data: Data) throws -> URL?

        static let live = RecipeTransferClient(
            importData: {
                let panel = NSOpenPanel()
                let recipeType = UTType(filenameExtension: "quickeyrecipe") ?? .json
                panel.allowedContentTypes = [recipeType, .json]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true

                guard panel.runModal() == .OK,
                      let url = panel.url else {
                    return nil
                }

                return try Data(contentsOf: url)
            },
            exportData: { suggestedFilename, data in
                let panel = NSSavePanel()
                let recipeType = UTType(filenameExtension: "quickeyrecipe") ?? .json
                panel.allowedContentTypes = [recipeType, .json]
                panel.canCreateDirectories = true
                panel.directoryURL = StoragePaths.appSupportDirectory()
                panel.nameFieldStringValue = suggestedFilename

                guard panel.runModal() == .OK,
                      let selectedURL = panel.url else {
                    return nil
                }

                let finalURL: URL
                if selectedURL.pathExtension.isEmpty {
                    finalURL = selectedURL.appendingPathExtension("quickeyrecipe")
                } else {
                    finalURL = selectedURL
                }

                try data.write(to: finalURL, options: .atomic)
                return finalURL
            }
        )
    }

    var shortcuts: [AppShortcut] = []
    var selectedAppName: String = ""
    var selectedBundleIdentifier: String = ""
    var recordedShortcut: RecordedShortcut?
    var isRecordingShortcut: Bool = false
    var conflictMessage: String?
    var recipeFeedback: RecipeFeedback?
    var pendingRecipeImport: QuickeyRecipeImportPlanner.ImportPlan?
    var usageCounts: [UUID: Int] = [:]

    private let shortcutStore: ShortcutStore
    private let shortcutManager: ShortcutManager
    private let usageTracker: UsageTracker?
    private let onShortcutConfigurationChange: @MainActor () -> Void
    private let shortcutValidator = ShortcutValidator()
    private let recipeCodec: QuickeyRecipeCodec
    private let recipeImportPlanner: QuickeyRecipeImportPlanner
    private let recipeTransferClient: RecipeTransferClient
    private let appBundleLocator: AppBundleLocator

    init(
        shortcutStore: ShortcutStore,
        shortcutManager: ShortcutManager,
        usageTracker: UsageTracker? = nil,
        recipeCodec: QuickeyRecipeCodec = QuickeyRecipeCodec(),
        recipeImportPlanner: QuickeyRecipeImportPlanner = QuickeyRecipeImportPlanner(),
        recipeTransferClient: RecipeTransferClient = .live,
        appBundleLocator: AppBundleLocator = AppBundleLocator(),
        onShortcutConfigurationChange: @escaping @MainActor () -> Void = {}
    ) {
        self.shortcutStore = shortcutStore
        self.shortcutManager = shortcutManager
        self.usageTracker = usageTracker
        self.recipeCodec = recipeCodec
        self.recipeImportPlanner = recipeImportPlanner
        self.recipeTransferClient = recipeTransferClient
        self.appBundleLocator = appBundleLocator
        self.onShortcutConfigurationChange = onShortcutConfigurationChange
        self.shortcuts = shortcutStore.shortcuts
        Task { await refreshUsageCounts() }
    }

    func addShortcut() {
        guard !selectedAppName.isEmpty,
              !selectedBundleIdentifier.isEmpty,
              let recordedShortcut else {
            return
        }

        let candidate = AppShortcut(
            appName: selectedAppName,
            bundleIdentifier: selectedBundleIdentifier,
            keyEquivalent: recordedShortcut.keyEquivalent,
            modifierFlags: recordedShortcut.modifierFlags
        )

        if let conflict = shortcutValidator.conflict(for: candidate, in: shortcuts) {
            conflictMessage = "Conflict: \(conflict.existingShortcut.appName) already uses \(conflict.existingShortcut.modifierFlags.joined(separator: "+"))+\(conflict.existingShortcut.keyEquivalent.uppercased())"
            return
        }

        var updated = shortcuts
        updated.append(candidate)
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
        onShortcutConfigurationChange()
        conflictMessage = nil
        resetDraft()
        Task { await refreshUsageCounts() }
    }

    func removeShortcut(id: UUID) {
        let updated = shortcuts.filter { $0.id != id }
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
        onShortcutConfigurationChange()
        if let usageTracker {
            Task {
                await usageTracker.deleteUsage(shortcutId: id)
                await refreshUsageCounts()
            }
        }
    }

    var allEnabled: Bool {
        !shortcuts.isEmpty && shortcuts.allSatisfy(\.isEnabled)
    }

    func toggleShortcutEnabled(id: UUID) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        shortcuts[index].isEnabled.toggle()
        shortcutManager.save(shortcuts: shortcuts)
        onShortcutConfigurationChange()
    }

    func setAllEnabled(_ enabled: Bool) {
        for index in shortcuts.indices {
            shortcuts[index].isEnabled = enabled
        }
        shortcutManager.save(shortcuts: shortcuts)
        onShortcutConfigurationChange()
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }

        selectedAppName = url.deletingPathExtension().lastPathComponent
        selectedBundleIdentifier = bundleIdentifier
    }

    func clearRecordedShortcut() {
        recordedShortcut = nil
        isRecordingShortcut = false
    }

    func exportRecipeData() throws -> Data {
        try recipeCodec.encode(shortcuts: shortcuts)
    }

    func exportRecipes() {
        do {
            let data = try exportRecipeData()
            guard let url = try recipeTransferClient.exportData(
                "Quickey.quickeyrecipe",
                data
            ) else {
                return
            }

            recipeFeedback = .success(
                "Exported \(shortcuts.count) shortcuts to \(url.lastPathComponent)"
            )
        } catch {
            recipeFeedback = .error(
                "Failed to export recipe: \(error.localizedDescription)"
            )
        }
    }

    func importRecipes(using appListProvider: AppListProvider) async {
        do {
            await appListProvider.refreshAndWaitIfNeeded()
            guard let data = try recipeTransferClient.importData() else {
                return
            }
            try beginImport(from: data, installedApps: appListProvider.allApps)
        } catch {
            pendingRecipeImport = nil
            recipeFeedback = .error(
                "Failed to import recipe: \(error.localizedDescription)"
            )
        }
    }

    func beginImport(from data: Data, installedApps: [AppEntry]) throws {
        let recipe = try recipeCodec.decode(data)
        let importCatalog = importCatalog(for: recipe, installedApps: installedApps)
        let plan = recipeImportPlanner.planImport(
            recipe: recipe,
            existingShortcuts: shortcuts,
            installedApps: importCatalog
        )
        conflictMessage = nil
        pendingRecipeImport = plan
        recipeFeedback = .success(
            "Import preview ready: \(plan.readyEntries.count) ready, \(plan.conflictEntries.count) conflicts, \(plan.unresolvedEntries.count) unresolved"
        )
    }

    func applyPendingImport(
        strategy: QuickeyRecipeImportPlanner.ConflictResolutionStrategy
    ) {
        guard let pendingRecipeImport else {
            return
        }

        let updatedShortcuts = recipeImportPlanner.applying(
            plan: pendingRecipeImport,
            to: shortcuts,
            strategy: strategy
        )

        shortcuts = updatedShortcuts
        shortcutManager.save(shortcuts: updatedShortcuts)
        onShortcutConfigurationChange()
        conflictMessage = nil
        self.pendingRecipeImport = nil
        recipeFeedback = .success(
            "Imported \(pendingRecipeImport.importedEntryCount(for: strategy)) shortcuts"
        )
        Task { await refreshUsageCounts() }
    }

    func discardPendingRecipeImport() {
        pendingRecipeImport = nil
    }

    func refreshUsageCounts() async {
        guard let usageTracker else { return }
        usageCounts = await usageTracker.usageCounts(days: 7)
    }

    private func resetDraft() {
        selectedAppName = ""
        selectedBundleIdentifier = ""
        recordedShortcut = nil
        isRecordingShortcut = false
    }

    private func importCatalog(
        for recipe: QuickeyRecipe,
        installedApps: [AppEntry]
    ) -> [AppEntry] {
        var appsByBundleIdentifier = Dictionary(
            uniqueKeysWithValues: installedApps.map { ($0.bundleIdentifier, $0) }
        )

        for recipeShortcut in recipe.shortcuts {
            guard appsByBundleIdentifier[recipeShortcut.bundleIdentifier] == nil,
                  let applicationURL = appBundleLocator.applicationURL(
                      for: recipeShortcut.bundleIdentifier
                  ) else {
                continue
            }

            let bundle = Bundle(url: applicationURL)
            let appName = (bundle?.infoDictionary?["CFBundleName"] as? String)
                ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? applicationURL.deletingPathExtension().lastPathComponent

            appsByBundleIdentifier[recipeShortcut.bundleIdentifier] = AppEntry(
                id: recipeShortcut.bundleIdentifier,
                name: appName,
                url: applicationURL
            )
        }

        return Array(appsByBundleIdentifier.values)
    }
}
