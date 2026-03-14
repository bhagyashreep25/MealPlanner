import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID
    var name: String
    var photoData: Data?
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]
    var steps: [String]
    var prepTime: Int // minutes
    var cookTime: Int // minutes
    var servings: Int
    var tags: [String]
    var sourceURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        photoData: Data? = nil,
        ingredients: [Ingredient] = [],
        steps: [String] = [],
        prepTime: Int = 0,
        cookTime: Int = 0,
        servings: Int = 1,
        tags: [String] = [],
        sourceURL: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.photoData = photoData
        self.ingredients = ingredients
        self.steps = steps
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.tags = tags
        self.sourceURL = sourceURL
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalTime: Int {
        prepTime + cookTime
    }

    var formattedTotalTime: String {
        let total = totalTime
        if total >= 60 {
            let hours = total / 60
            let mins = total % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(total)m"
    }
}
