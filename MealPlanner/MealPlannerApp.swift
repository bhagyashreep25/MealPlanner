import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CalendarView()
            }
        }
        .modelContainer(for: [
            Recipe.self,
            Ingredient.self,
            MealPlan.self,
            ShoppingItem.self
        ])
    }
}
