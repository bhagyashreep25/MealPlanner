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
}
