import SwiftUI
import SwiftData

@Observable
class ShoppingListViewModel {
    var showingAddItem = false
    var newItemName: String = ""
    var newItemQuantity: String = ""
    var newItemCategory: String = "Other"

    let defaultCategories = [
        "Produce", "Dairy", "Meat & Seafood", "Grains & Bread",
        "Spices & Seasonings", "Canned & Packaged", "Frozen",
        "Beverages", "Snacks", "Ingredients", "Other"
    ]

    func groupedItems(_ items: [ShoppingItem]) -> [(category: String, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
    }

    func addItem(context: ModelContext) {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = ShoppingItem(
            name: trimmed,
            quantity: newItemQuantity.trimmingCharacters(in: .whitespacesAndNewlines),
            category: newItemCategory
        )
        context.insert(item)
        try? context.save()

        newItemName = ""
        newItemQuantity = ""
        newItemCategory = "Other"
        showingAddItem = false
    }

    func toggleItem(_ item: ShoppingItem, context: ModelContext) {
        item.isChecked.toggle()
        try? context.save()
    }

    func deleteItem(_ item: ShoppingItem, context: ModelContext) {
        context.delete(item)
        try? context.save()
    }

    func clearChecked(_ items: [ShoppingItem], context: ModelContext) {
        for item in items where item.isChecked {
            context.delete(item)
        }
        try? context.save()
    }

    func clearAll(_ items: [ShoppingItem], context: ModelContext) {
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    func generateFromMealPlan(mealPlans: [MealPlan], existingItems: [ShoppingItem], context: ModelContext) {
        // Get this week's start and end
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }

        // Filter meal plans for this week
        let thisWeekPlans = mealPlans.filter { plan in
            plan.date >= weekStart && plan.date < weekEnd && plan.recipe != nil
        }

        // Collect all ingredients
        let existingNames = Set(existingItems.map { $0.name.lowercased() })
        var addedNames = Set<String>()

        for plan in thisWeekPlans {
            guard let recipe = plan.recipe else { continue }
            for ingredient in recipe.ingredients {
                let lowered = ingredient.name.lowercased()
                // Skip duplicates
                guard !existingNames.contains(lowered), !addedNames.contains(lowered) else { continue }
                addedNames.insert(lowered)

                let item = ShoppingItem(
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    category: "Ingredients"
                )
                context.insert(item)
            }
        }
        try? context.save()
    }
}
