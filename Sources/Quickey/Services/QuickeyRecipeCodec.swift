import Foundation

struct QuickeyRecipeCodec: Sendable {
    enum Error: Swift.Error, LocalizedError, Sendable {
        case unsupportedSchemaVersion(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchemaVersion(version):
                return "Unsupported recipe schema version: \(version)"
            }
        }
    }

    func decode(_ data: Data) throws -> QuickeyRecipe {
        let recipe = try JSONDecoder().decode(QuickeyRecipe.self, from: data)
        guard recipe.schemaVersion == QuickeyRecipe.currentSchemaVersion else {
            throw Error.unsupportedSchemaVersion(recipe.schemaVersion)
        }
        return recipe
    }

    func encode(_ recipe: QuickeyRecipe) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(recipe)
    }

    func encode(shortcuts: [AppShortcut]) throws -> Data {
        try encode(QuickeyRecipe(shortcuts: shortcuts))
    }
}
