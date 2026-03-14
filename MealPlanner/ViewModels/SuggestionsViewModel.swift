import SwiftUI
import SwiftData

struct RecipeMatch: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let matchedIngredients: [String]
    let missingIngredients: [Ingredient]
    let coveragePercent: Int
}

@Observable
class SuggestionsViewModel {
    var ingredientInput: String = ""
    var userIngredients: [String] = []
    var matches: [RecipeMatch] = []
    var hasSearched: Bool = false

    func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !userIngredients.contains(trimmed) else { return }
        userIngredients.append(trimmed)
        ingredientInput = ""
    }

    func removeIngredient(_ ingredient: String) {
        userIngredients.removeAll { $0 == ingredient }
        if userIngredients.isEmpty {
            matches = []
            hasSearched = false
        }
    }

    func findMatches(from recipes: [Recipe]) {
        guard !userIngredients.isEmpty else {
            matches = []
            hasSearched = false
            return
        }

        hasSearched = true

        matches = recipes.compactMap { recipe in
            let recipeIngredientNames = recipe.ingredients.map { $0.name.lowercased() }
            guard !recipeIngredientNames.isEmpty else { return nil }

            var matched: [String] = []
            var missing: [Ingredient] = []

            for ingredient in recipe.ingredients {
                let name = ingredient.name.lowercased()
                let isMatched = userIngredients.contains { userIng in
                    name.contains(userIng) || userIng.contains(name)
                }
                if isMatched {
                    matched.append(ingredient.name)
                } else {
                    missing.append(ingredient)
                }
            }

            guard !matched.isEmpty else { return nil }

            let coverage = Int((Double(matched.count) / Double(recipe.ingredients.count)) * 100)

            return RecipeMatch(
                recipe: recipe,
                matchedIngredients: matched,
                missingIngredients: missing,
                coveragePercent: coverage
            )
        }
        .sorted { $0.coveragePercent > $1.coveragePercent }
    }

    func addMissingToShoppingList(_ missingIngredients: [Ingredient], context: ModelContext) {
        for ingredient in missingIngredients {
            let item = ShoppingItem(
                name: ingredient.name,
                quantity: ingredient.quantity,
                category: "Ingredients"
            )
            context.insert(item)
        }
        try? context.save()
    }
}
