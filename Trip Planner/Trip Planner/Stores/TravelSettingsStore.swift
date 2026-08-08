import Foundation
import SwiftData

@MainActor
enum TravelSettingsStore {
    static func settings(in context: ModelContext) throws -> TravelSettings {
        var descriptor = FetchDescriptor<TravelSettings>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let settings = try context.fetch(descriptor).first {
            return settings
        }

        let settings = TravelSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
}
