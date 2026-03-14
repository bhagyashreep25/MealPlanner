import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case lunch = "Lunch"
    case dinner = "Dinner"
}

@Model
final class MealPlan {
    var id: UUID
    var date: Date
    var mealType: MealType
    var recipe: Recipe?

    init(date: Date, mealType: MealType, recipe: Recipe? = nil) {
        self.id = UUID()
        self.date = date
        self.mealType = mealType
        self.recipe = recipe
    }
}
