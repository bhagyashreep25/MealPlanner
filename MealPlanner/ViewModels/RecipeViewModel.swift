import SwiftUI
import SwiftData

@Observable
class RecipeViewModel {
    var searchText: String = ""
    var selectedCategory: String? = nil
    var showingAddRecipe: Bool = false
    var recipeToEdit: Recipe? = nil

    var allCategories: [String] {
        [
            "Breakfast", "Lunch", "Dinner", "Snack",
            "Indian", "Italian", "Mexican", "Chinese", "Japanese",
            "Thai", "Mediterranean", "American",
            "Vegetarian", "Vegan", "Gluten-Free",
            "Quick", "Dessert", "Soup", "Salad", "Appetizer"
        ]
    }

    func filteredRecipes(_ recipes: [Recipe]) -> [Recipe] {
        var result = recipes

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { recipe in
                recipe.name.lowercased().contains(query) ||
                recipe.tags.contains(where: { $0.lowercased().contains(query) }) ||
                recipe.ingredients.contains(where: { $0.name.lowercased().contains(query) })
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.tags.contains(category) }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    func addRecipe(
        name: String,
        photoData: Data?,
        ingredients: [(name: String, quantity: String)],
        steps: [String],
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        tags: [String],
        sourceURL: String?,
        context: ModelContext
    ) {
        let recipe = Recipe(
            name: name,
            photoData: photoData,
            steps: steps.filter { !$0.isEmpty },
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            tags: tags,
            sourceURL: sourceURL
        )
        context.insert(recipe)

        for ingredientData in ingredients where !ingredientData.name.isEmpty {
            let ingredient = Ingredient(name: ingredientData.name, quantity: ingredientData.quantity)
            ingredient.recipe = recipe
            recipe.ingredients.append(ingredient)
        }

        try? context.save()
    }

    func updateRecipe(
        _ recipe: Recipe,
        name: String,
        photoData: Data?,
        ingredients: [(name: String, quantity: String)],
        steps: [String],
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        tags: [String],
        sourceURL: String?,
        context: ModelContext
    ) {
        recipe.name = name
        recipe.photoData = photoData
        recipe.steps = steps.filter { !$0.isEmpty }
        recipe.prepTime = prepTime
        recipe.cookTime = cookTime
        recipe.servings = servings
        recipe.tags = tags
        recipe.sourceURL = sourceURL
        recipe.updatedAt = Date()

        // Remove old ingredients
        for ingredient in recipe.ingredients {
            context.delete(ingredient)
        }
        recipe.ingredients.removeAll()

        // Add new ingredients
        for ingredientData in ingredients where !ingredientData.name.isEmpty {
            let ingredient = Ingredient(name: ingredientData.name, quantity: ingredientData.quantity)
            ingredient.recipe = recipe
            recipe.ingredients.append(ingredient)
        }

        try? context.save()
    }

    func deleteRecipe(_ recipe: Recipe, context: ModelContext) {
        context.delete(recipe)
        try? context.save()
    }
}
