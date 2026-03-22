import Testing
import Foundation
import SwiftData
@testable import MealPlanner

// MARK: - Test Helpers

/// Creates an in-memory SwiftData ModelContext for testing
private func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Recipe.self, Ingredient.self, MealPlan.self, ShoppingItem.self,
        configurations: config
    )
    return ModelContext(container)
}

/// Creates a Recipe with ingredients for testing (must be inserted into context for SwiftData)
private func makeRecipe(
    name: String,
    ingredients: [(name: String, quantity: String)] = [],
    steps: [String] = [],
    prepTime: Int = 0,
    cookTime: Int = 0,
    servings: Int = 1,
    tags: [String] = [],
    sourceURL: String? = nil,
    context: ModelContext
) -> Recipe {
    let recipe = Recipe(
        name: name,
        steps: steps,
        prepTime: prepTime,
        cookTime: cookTime,
        servings: servings,
        tags: tags,
        sourceURL: sourceURL
    )
    context.insert(recipe)

    for ing in ingredients {
        let ingredient = Ingredient(name: ing.name, quantity: ing.quantity)
        ingredient.recipe = recipe
        recipe.ingredients.append(ingredient)
    }

    try? context.save()
    return recipe
}

// MARK: - Recipe Model Tests

@Suite("Recipe Model")
struct RecipeModelTests {

    @Test("totalTime sums prep and cook time")
    func totalTime() {
        let recipe = Recipe(name: "Test", prepTime: 15, cookTime: 30)
        #expect(recipe.totalTime == 45)
    }

    @Test("totalTime is zero when both are zero")
    func totalTimeZero() {
        let recipe = Recipe(name: "Test")
        #expect(recipe.totalTime == 0)
    }

    @Test("formattedTotalTime shows minutes under 60")
    func formattedTimeMinutes() {
        let recipe = Recipe(name: "Test", prepTime: 10, cookTime: 20)
        #expect(recipe.formattedTotalTime == "30m")
    }

    @Test("formattedTotalTime shows hours and minutes over 60")
    func formattedTimeHoursAndMinutes() {
        let recipe = Recipe(name: "Test", prepTime: 30, cookTime: 45)
        #expect(recipe.formattedTotalTime == "1h 15m")
    }

    @Test("formattedTotalTime shows hours only when even")
    func formattedTimeExactHours() {
        let recipe = Recipe(name: "Test", prepTime: 60, cookTime: 60)
        #expect(recipe.formattedTotalTime == "2h")
    }

    @Test("formattedTotalTime shows 0m when no time set")
    func formattedTimeZero() {
        let recipe = Recipe(name: "Test")
        #expect(recipe.formattedTotalTime == "0m")
    }

    @Test("default values are set correctly")
    func defaults() {
        let recipe = Recipe(name: "My Recipe")
        #expect(recipe.name == "My Recipe")
        #expect(recipe.prepTime == 0)
        #expect(recipe.cookTime == 0)
        #expect(recipe.servings == 1)
        #expect(recipe.tags.isEmpty)
        #expect(recipe.steps.isEmpty)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.sourceURL == nil)
        #expect(recipe.photoData == nil)
    }
}

// MARK: - MealType Tests

@Suite("MealType")
struct MealTypeTests {

    @Test("raw values are correct")
    func rawValues() {
        #expect(MealType.lunch.rawValue == "Lunch")
        #expect(MealType.dinner.rawValue == "Dinner")
    }

    @Test("all cases returns both types")
    func allCases() {
        #expect(MealType.allCases.count == 2)
    }
}

// MARK: - RecipeViewModel Tests

@Suite("RecipeViewModel")
struct RecipeViewModelTests {

    @Test("allCategories returns expected count")
    func categoriesCount() {
        let vm = RecipeViewModel()
        #expect(vm.allCategories.count == 20)
    }

    @Test("filteredRecipes returns all when no search or category")
    func noFilter() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        let r1 = makeRecipe(name: "Pasta", context: context)
        let r2 = makeRecipe(name: "Salad", context: context)
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.count == 2)
    }

    @Test("filteredRecipes filters by name search")
    func searchByName() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "pasta"
        let r1 = makeRecipe(name: "Creamy Pasta", context: context)
        let r2 = makeRecipe(name: "Green Salad", context: context)
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.name == "Creamy Pasta")
    }

    @Test("filteredRecipes search is case insensitive")
    func searchCaseInsensitive() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "PASTA"
        let r1 = makeRecipe(name: "pasta carbonara", context: context)
        let result = vm.filteredRecipes([r1])
        #expect(result.count == 1)
    }

    @Test("filteredRecipes filters by tag search")
    func searchByTag() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "italian"
        let r1 = makeRecipe(name: "Pasta", tags: ["Italian", "Dinner"], context: context)
        let r2 = makeRecipe(name: "Tacos", tags: ["Mexican"], context: context)
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.name == "Pasta")
    }

    @Test("filteredRecipes filters by ingredient search")
    func searchByIngredient() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "chicken"
        let r1 = makeRecipe(name: "Tikka Masala", ingredients: [("Chicken breast", "500g")], context: context)
        let r2 = makeRecipe(name: "Veggie Bowl", ingredients: [("Tofu", "200g")], context: context)
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.name == "Tikka Masala")
    }

    @Test("filteredRecipes filters by selected category")
    func filterByCategory() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.selectedCategory = "Indian"
        let r1 = makeRecipe(name: "Tikka Masala", tags: ["Indian"], context: context)
        let r2 = makeRecipe(name: "Pasta", tags: ["Italian"], context: context)
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.name == "Tikka Masala")
    }

    @Test("filteredRecipes applies both search and category filter")
    func searchAndCategory() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "chicken"
        vm.selectedCategory = "Indian"
        let r1 = makeRecipe(name: "Chicken Tikka", tags: ["Indian"], ingredients: [("Chicken", "500g")], context: context)
        let r2 = makeRecipe(name: "Chicken Parmesan", tags: ["Italian"], ingredients: [("Chicken", "300g")], context: context)
        let r3 = makeRecipe(name: "Dal Tadka", tags: ["Indian"], ingredients: [("Lentils", "1 cup")], context: context)
        let result = vm.filteredRecipes([r1, r2, r3])
        #expect(result.count == 1)
        #expect(result.first?.name == "Chicken Tikka")
    }

    @Test("filteredRecipes returns empty for no matches")
    func noMatches() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.searchText = "xyz"
        let r1 = makeRecipe(name: "Pasta", context: context)
        let result = vm.filteredRecipes([r1])
        #expect(result.isEmpty)
    }

    @Test("filteredRecipes sorts by updatedAt descending")
    func sortOrder() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        let r1 = makeRecipe(name: "Old Recipe", context: context)
        r1.updatedAt = Date().addingTimeInterval(-3600)
        let r2 = makeRecipe(name: "New Recipe", context: context)
        r2.updatedAt = Date()
        let result = vm.filteredRecipes([r1, r2])
        #expect(result.first?.name == "New Recipe")
    }
}

// MARK: - CalendarViewModel Tests

@Suite("CalendarViewModel")
struct CalendarViewModelTests {

    @Test("currentWeekDates returns 7 dates")
    func weekDatesCount() {
        let vm = CalendarViewModel()
        #expect(vm.currentWeekDates.count == 7)
    }

    @Test("isToday returns true for today")
    func isTodayTrue() {
        let vm = CalendarViewModel()
        #expect(vm.isToday(Date()) == true)
    }

    @Test("isToday returns false for yesterday")
    func isTodayFalse() {
        let vm = CalendarViewModel()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(vm.isToday(yesterday) == false)
    }

    @Test("isSelected matches selected date")
    func isSelected() {
        let vm = CalendarViewModel()
        #expect(vm.isSelected(Date()) == true)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(vm.isSelected(tomorrow) == false)
    }

    @Test("goToNextDay advances by one day")
    func nextDay() {
        let vm = CalendarViewModel()
        let today = Calendar.current.startOfDay(for: vm.selectedDate)
        vm.goToNextDay()
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        #expect(Calendar.current.isDate(vm.selectedDate, inSameDayAs: expected))
    }

    @Test("goToPreviousDay goes back one day")
    func previousDay() {
        let vm = CalendarViewModel()
        let today = Calendar.current.startOfDay(for: vm.selectedDate)
        vm.goToPreviousDay()
        let expected = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        #expect(Calendar.current.isDate(vm.selectedDate, inSameDayAs: expected))
    }

    @Test("goToToday resets to today")
    func goToToday() {
        let vm = CalendarViewModel()
        vm.goToNextDay()
        vm.goToNextDay()
        vm.goToToday()
        #expect(Calendar.current.isDateInToday(vm.selectedDate))
    }

    @Test("selectSlot sets meal slot and shows picker")
    func selectSlot() {
        let vm = CalendarViewModel()
        let date = Date()
        vm.selectSlot(date: date, mealType: .dinner)
        #expect(vm.selectedMealSlot != nil)
        #expect(vm.selectedMealSlot?.mealType == .dinner)
        #expect(vm.showingRecipePicker == true)
    }

    @Test("mealsForDate returns only matching date meals")
    func mealsForDate() throws {
        let context = try makeTestContext()
        let vm = CalendarViewModel()
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let recipe = makeRecipe(name: "Test", context: context)
        let meal1 = MealPlan(date: today, mealType: .lunch, recipe: recipe)
        let meal2 = MealPlan(date: tomorrow, mealType: .dinner, recipe: recipe)
        context.insert(meal1)
        context.insert(meal2)

        let todayMeals = vm.mealsForDate(today, from: [meal1, meal2])
        #expect(todayMeals.count == 1)
        #expect(todayMeals.first?.mealType == .lunch)
    }

    @Test("mealForSlot returns correct meal plan")
    func mealForSlot() throws {
        let context = try makeTestContext()
        let vm = CalendarViewModel()
        let today = Date()
        let recipe = makeRecipe(name: "Test", context: context)
        let lunchPlan = MealPlan(date: today, mealType: .lunch, recipe: recipe)
        let dinnerPlan = MealPlan(date: today, mealType: .dinner, recipe: recipe)
        context.insert(lunchPlan)
        context.insert(dinnerPlan)

        let found = vm.mealForSlot(date: today, mealType: .dinner, from: [lunchPlan, dinnerPlan])
        #expect(found?.mealType == .dinner)
    }

    @Test("mealForSlot returns nil when no match")
    func mealForSlotNil() {
        let vm = CalendarViewModel()
        let result = vm.mealForSlot(date: Date(), mealType: .lunch, from: [])
        #expect(result == nil)
    }

    @Test("dayTitle returns non-empty string")
    func dayTitle() {
        let vm = CalendarViewModel()
        #expect(!vm.dayTitle.isEmpty)
    }

    @Test("dayNumber returns a number string")
    func dayNumber() {
        let vm = CalendarViewModel()
        let num = vm.dayNumber(for: Date())
        #expect(Int(num) != nil)
    }
}

// MARK: - SuggestionsViewModel Tests

@Suite("SuggestionsViewModel")
struct SuggestionsViewModelTests {

    @Test("addIngredient adds trimmed lowercase ingredient")
    func addIngredient() {
        let vm = SuggestionsViewModel()
        vm.ingredientInput = "  Chicken  "
        vm.addIngredient()
        #expect(vm.userIngredients == ["chicken"])
        #expect(vm.ingredientInput.isEmpty)
    }

    @Test("addIngredient rejects empty input")
    func addEmpty() {
        let vm = SuggestionsViewModel()
        vm.ingredientInput = "   "
        vm.addIngredient()
        #expect(vm.userIngredients.isEmpty)
    }

    @Test("addIngredient rejects duplicate")
    func addDuplicate() {
        let vm = SuggestionsViewModel()
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        #expect(vm.userIngredients.count == 1)
    }

    @Test("removeIngredient removes and resets when empty")
    func removeIngredient() {
        let vm = SuggestionsViewModel()
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.hasSearched = true
        vm.removeIngredient("chicken")
        #expect(vm.userIngredients.isEmpty)
        #expect(vm.matches.isEmpty)
        #expect(vm.hasSearched == false)
    }

    @Test("removeIngredient keeps other ingredients")
    func removeOne() {
        let vm = SuggestionsViewModel()
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.ingredientInput = "rice"
        vm.addIngredient()
        vm.removeIngredient("chicken")
        #expect(vm.userIngredients == ["rice"])
    }

    @Test("findMatches returns recipes with matching ingredients")
    func findMatchesFull() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let recipe = makeRecipe(
            name: "Chicken Rice",
            ingredients: [("Chicken", "500g"), ("Rice", "2 cups"), ("Salt", "1 tsp")],
            context: context
        )
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.ingredientInput = "rice"
        vm.addIngredient()
        vm.ingredientInput = "salt"
        vm.addIngredient()

        vm.findMatches(from: [recipe])
        #expect(vm.hasSearched == true)
        #expect(vm.matches.count == 1)
        #expect(vm.matches.first?.coveragePercent == 100)
        #expect(vm.matches.first?.missingIngredients.isEmpty == true)
    }

    @Test("findMatches computes partial coverage")
    func findMatchesPartial() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let recipe = makeRecipe(
            name: "Stir Fry",
            ingredients: [("Chicken", "500g"), ("Broccoli", "1 head"), ("Soy sauce", "2 tbsp"), ("Garlic", "3 cloves")],
            context: context
        )
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.ingredientInput = "garlic"
        vm.addIngredient()

        vm.findMatches(from: [recipe])
        #expect(vm.matches.count == 1)
        #expect(vm.matches.first?.coveragePercent == 50)
        #expect(vm.matches.first?.matchedIngredients.count == 2)
        #expect(vm.matches.first?.missingIngredients.count == 2)
    }

    @Test("findMatches excludes recipes with zero matches")
    func noMatchRecipe() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let recipe = makeRecipe(
            name: "Fish Tacos",
            ingredients: [("Fish", "300g"), ("Tortilla", "4")],
            context: context
        )
        vm.ingredientInput = "chicken"
        vm.addIngredient()

        vm.findMatches(from: [recipe])
        #expect(vm.matches.isEmpty)
    }

    @Test("findMatches sorts by coverage descending")
    func matchesSortOrder() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let r1 = makeRecipe(
            name: "Simple",
            ingredients: [("Chicken", "500g"), ("Rice", "2 cups")],
            context: context
        )
        let r2 = makeRecipe(
            name: "Complex",
            ingredients: [("Chicken", "500g"), ("Rice", "2 cups"), ("Soy", "1 tbsp"), ("Ginger", "1 inch")],
            context: context
        )
        vm.ingredientInput = "chicken"
        vm.addIngredient()
        vm.ingredientInput = "rice"
        vm.addIngredient()

        vm.findMatches(from: [r1, r2])
        #expect(vm.matches.count == 2)
        #expect(vm.matches[0].coveragePercent == 100) // Simple: 2/2
        #expect(vm.matches[1].coveragePercent == 50)  // Complex: 2/4
    }

    @Test("findMatches with empty user ingredients resets state")
    func findMatchesEmpty() {
        let vm = SuggestionsViewModel()
        vm.hasSearched = true
        vm.findMatches(from: [])
        #expect(vm.hasSearched == false)
        #expect(vm.matches.isEmpty)
    }

    @Test("findMatches uses fuzzy matching (contains)")
    func fuzzyMatch() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let recipe = makeRecipe(
            name: "Curry",
            ingredients: [("Chicken breast", "500g"), ("Coconut milk", "1 can")],
            context: context
        )
        vm.ingredientInput = "chicken"
        vm.addIngredient()

        vm.findMatches(from: [recipe])
        #expect(vm.matches.count == 1)
        #expect(vm.matches.first?.matchedIngredients.first == "Chicken breast")
    }

    @Test("findMatches skips recipes with no ingredients")
    func skipEmptyIngredients() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()
        let recipe = makeRecipe(name: "Empty Recipe", context: context)
        vm.ingredientInput = "chicken"
        vm.addIngredient()

        vm.findMatches(from: [recipe])
        #expect(vm.matches.isEmpty)
    }
}

// MARK: - ShoppingListViewModel Tests

@Suite("ShoppingListViewModel")
struct ShoppingListViewModelTests {

    @Test("groupedItems groups by category and sorts")
    func groupedItems() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Milk", category: "Dairy"),
            ShoppingItem(name: "Cheese", category: "Dairy"),
            ShoppingItem(name: "Apples", category: "Produce"),
            ShoppingItem(name: "Bread", category: "Grains & Bread"),
        ]

        let grouped = vm.groupedItems(items)
        #expect(grouped.count == 3)
        #expect(grouped[0].category == "Dairy")
        #expect(grouped[0].items.count == 2)
        #expect(grouped[1].category == "Grains & Bread")
        #expect(grouped[2].category == "Produce")
    }

    @Test("groupedItems sorts items within category alphabetically")
    func groupedItemsSort() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Zucchini", category: "Produce"),
            ShoppingItem(name: "Apples", category: "Produce"),
            ShoppingItem(name: "Carrots", category: "Produce"),
        ]

        let grouped = vm.groupedItems(items)
        #expect(grouped[0].items[0].name == "Apples")
        #expect(grouped[0].items[1].name == "Carrots")
        #expect(grouped[0].items[2].name == "Zucchini")
    }

    @Test("groupedItems returns empty for empty input")
    func groupedEmpty() {
        let vm = ShoppingListViewModel()
        let grouped = vm.groupedItems([])
        #expect(grouped.isEmpty)
    }

    @Test("addItem creates item and resets form state")
    func addItem() throws {
        let context = try makeTestContext()
        let vm = ShoppingListViewModel()
        vm.newItemName = "  Milk  "
        vm.newItemQuantity = "1 gallon"
        vm.newItemCategory = "Dairy"
        vm.showingAddItem = true

        vm.addItem(context: context)

        #expect(vm.newItemName.isEmpty)
        #expect(vm.newItemQuantity.isEmpty)
        #expect(vm.newItemCategory == "Other")
        #expect(vm.showingAddItem == false)
    }

    @Test("addItem rejects empty name")
    func addEmptyItem() throws {
        let context = try makeTestContext()
        let vm = ShoppingListViewModel()
        vm.newItemName = "   "
        vm.addItem(context: context)
        // Form should not be reset if item was rejected
        #expect(vm.showingAddItem == false) // still false (default)
    }

    @Test("toggleItem flips isChecked")
    func toggleItem() throws {
        let context = try makeTestContext()
        let vm = ShoppingListViewModel()
        let item = ShoppingItem(name: "Milk")
        context.insert(item)
        #expect(item.isChecked == false)

        vm.toggleItem(item, context: context)
        #expect(item.isChecked == true)

        vm.toggleItem(item, context: context)
        #expect(item.isChecked == false)
    }

    @Test("defaultCategories contains expected values")
    func defaultCategories() {
        let vm = ShoppingListViewModel()
        #expect(vm.defaultCategories.contains("Produce"))
        #expect(vm.defaultCategories.contains("Dairy"))
        #expect(vm.defaultCategories.contains("Other"))
        #expect(vm.defaultCategories.count == 11)
    }
}

// MARK: - RecipeImportService Tests

@Suite("RecipeImportService")
struct RecipeImportServiceTests {

    // MARK: - Duration Parsing

    @Test("parseDuration with hours and minutes")
    func durationHoursAndMinutes() async {
        let service = RecipeImportService()
        let result = await service.parseDuration("PT1H30M")
        #expect(result == 90)
    }

    @Test("parseDuration with minutes only")
    func durationMinutesOnly() async {
        let service = RecipeImportService()
        let result = await service.parseDuration("PT45M")
        #expect(result == 45)
    }

    @Test("parseDuration with hours only")
    func durationHoursOnly() async {
        let service = RecipeImportService()
        let result = await service.parseDuration("PT2H")
        #expect(result == 120)
    }

    @Test("parseDuration returns 0 for nil")
    func durationNil() async {
        let service = RecipeImportService()
        let result = await service.parseDuration(nil)
        #expect(result == 0)
    }

    @Test("parseDuration returns 0 for non-string")
    func durationNonString() async {
        let service = RecipeImportService()
        let result = await service.parseDuration(42)
        #expect(result == 0)
    }

    // MARK: - Ingredient Splitting

    @Test("splitIngredient separates quantity and name")
    func splitWithQuantity() async {
        let service = RecipeImportService()
        let result = await service.splitIngredient("2 cups flour")
        #expect(result.quantity == "2 cups")
        #expect(result.name == "flour")
    }

    @Test("splitIngredient handles no quantity")
    func splitNoQuantity() async {
        let service = RecipeImportService()
        let result = await service.splitIngredient("salt to taste")
        #expect(result.name == "salt to taste")
        #expect(result.quantity == "")
    }

    @Test("splitIngredient handles fractions")
    func splitFractions() async {
        let service = RecipeImportService()
        let result = await service.splitIngredient("½ tsp cinnamon")
        #expect(result.quantity == "½ tsp")
        #expect(result.name == "cinnamon")
    }

    @Test("splitIngredient strips bullet points")
    func splitBullets() async {
        let service = RecipeImportService()
        let result = await service.splitIngredient("• 3 cloves garlic")
        #expect(result.quantity == "3 cloves")
        #expect(result.name == "garlic")
    }

    @Test("splitIngredient handles tablespoons")
    func splitTablespoons() async {
        let service = RecipeImportService()
        let result = await service.splitIngredient("2 tablespoons olive oil")
        #expect(result.quantity == "2 tablespoons")
        #expect(result.name == "olive oil")
    }

    // MARK: - HTML Decoding

    @Test("decodeHTML handles named entities")
    func decodeNamedEntities() async {
        let service = RecipeImportService()
        let result = await service.decodeHTML("Tom &amp; Jerry &lt;3&gt;")
        #expect(result == "Tom & Jerry <3>")
    }

    @Test("decodeHTML handles numeric entities")
    func decodeNumericEntities() async {
        let service = RecipeImportService()
        let result = await service.decodeHTML("&#189; cup") // ½
        #expect(result == "½ cup")
    }

    @Test("decodeHTML handles hex entities")
    func decodeHexEntities() async {
        let service = RecipeImportService()
        let result = await service.decodeHTML("&#x00BD; cup") // ½
        #expect(result == "½ cup")
    }

    @Test("decodeHTML handles fraction entities")
    func decodeFractionEntities() async {
        let service = RecipeImportService()
        let result = await service.decodeHTML("&frac14; tsp &frac34; cup")
        #expect(result == "¼ tsp ¾ cup")
    }

    @Test("decodeHTML passes through plain text unchanged")
    func decodePlainText() async {
        let service = RecipeImportService()
        let result = await service.decodeHTML("just plain text")
        #expect(result == "just plain text")
    }

    // MARK: - HTML Stripping

    @Test("stripHTML removes tags")
    func stripTags() async {
        let service = RecipeImportService()
        let result = await service.stripHTML("<p>Hello <strong>world</strong></p>")
        #expect(result == "Hello world")
    }

    @Test("stripHTML handles empty string")
    func stripEmpty() async {
        let service = RecipeImportService()
        let result = await service.stripHTML("")
        #expect(result == "")
    }

    // MARK: - Number Extraction

    @Test("extractNumber gets number from string")
    func extractFromString() async {
        let service = RecipeImportService()
        #expect(await service.extractNumber(from: "4 servings") == 4)
        #expect(await service.extractNumber(from: "12") == 12)
        #expect(await service.extractNumber(from: "Makes about 6-8") == 68)
    }

    @Test("extractNumber returns nil for no digits")
    func extractNoDigits() async {
        let service = RecipeImportService()
        #expect(await service.extractNumber(from: "none") == nil)
    }

    // MARK: - OCR Text Parsing

    @Test("parseOCRText extracts recipe name from first line")
    func ocrRecipeName() async {
        let service = RecipeImportService()
        let text = "Chicken Tikka Masala\nIngredients\n2 cups rice\nDirections\n1. Cook the rice"
        let result = await service.parseOCRText(text)
        #expect(result.name == "Chicken Tikka Masala")
    }

    @Test("parseOCRText extracts ingredients after header")
    func ocrIngredients() async {
        let service = RecipeImportService()
        let text = """
        My Recipe
        Ingredients
        2 cups flour
        1 tsp salt
        3 eggs
        Directions
        1. Mix everything together well
        """
        let result = await service.parseOCRText(text)
        #expect(result.ingredients.count == 3)
        #expect(result.ingredients[0].name == "flour")
        #expect(result.ingredients[0].quantity == "2 cups")
        #expect(result.ingredients[1].name == "salt")
        #expect(result.ingredients[2].quantity == "3")
    }

    @Test("parseOCRText extracts steps after directions header")
    func ocrSteps() async {
        let service = RecipeImportService()
        let text = """
        My Recipe
        Ingredients
        2 cups flour
        Directions
        1. Preheat oven to 350 degrees fahrenheit
        2. Mix all ingredients together in a bowl
        3. Bake for thirty minutes until golden
        """
        let result = await service.parseOCRText(text)
        #expect(result.steps.count == 3)
        #expect(result.steps[0].contains("Preheat oven"))
        #expect(result.steps[1].contains("Mix all"))
    }

    @Test("parseOCRText stops at Notes section")
    func ocrStopsAtNotes() async {
        let service = RecipeImportService()
        let text = """
        My Recipe
        Directions
        1. Cook the rice in boiling water for 20 min
        2. Serve with vegetables and sauce
        Notes
        This recipe was my grandmother's
        """
        let result = await service.parseOCRText(text)
        #expect(result.steps.count == 2)
    }

    @Test("parseOCRText handles empty text")
    func ocrEmpty() async {
        let service = RecipeImportService()
        let result = await service.parseOCRText("")
        #expect(result.name.isEmpty)
        #expect(result.ingredients.isEmpty)
        #expect(result.steps.isEmpty)
    }

    @Test("parseOCRText auto-detects ingredients without header")
    func ocrAutoDetectIngredients() async {
        let service = RecipeImportService()
        let text = """
        Simple Pancakes
        2 cups flour
        1 cup milk
        2 large eggs
        """
        let result = await service.parseOCRText(text)
        #expect(result.ingredients.count == 3)
    }

    @Test("parseOCRText handles Instructions header variant")
    func ocrInstructionsHeader() async {
        let service = RecipeImportService()
        let text = """
        My Recipe
        Instructions
        1. Do the first step of cooking this
        2. Do the second step of cooking this
        """
        let result = await service.parseOCRText(text)
        #expect(result.steps.count == 2)
    }

    // MARK: - ImportError

    @Test("ImportError provides localized descriptions")
    func errorDescriptions() {
        #expect(ImportError.invalidURL.errorDescription == "Please enter a valid URL")
        #expect(ImportError.parseError("bad data").errorDescription == "bad data")
        #expect(ImportError.networkError("timeout").errorDescription == "timeout")
    }
}

// MARK: - ParsedRecipe Tests

@Suite("ParsedRecipe")
struct ParsedRecipeTests {

    @Test("default values are sensible")
    func defaults() {
        let parsed = ParsedRecipe()
        #expect(parsed.name.isEmpty)
        #expect(parsed.ingredients.isEmpty)
        #expect(parsed.steps.isEmpty)
        #expect(parsed.prepTime == 0)
        #expect(parsed.cookTime == 0)
        #expect(parsed.servings == 1)
        #expect(parsed.tags.isEmpty)
        #expect(parsed.sourceURL == nil)
        #expect(parsed.imageURL == nil)
    }
}

// MARK: - Integration Tests

@Suite("Integration")
struct IntegrationTests {

    @Test("addRecipe creates recipe with ingredients in SwiftData")
    func addRecipeIntegration() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        vm.addRecipe(
            name: "Test Recipe",
            photoData: nil,
            ingredients: [("Flour", "2 cups"), ("Sugar", "1 cup"), ("", "")],
            steps: ["Mix", "Bake", ""],
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            tags: ["Dessert"],
            sourceURL: "https://example.com",
            context: context
        )

        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try context.fetch(descriptor)
        #expect(recipes.count == 1)

        let recipe = recipes.first!
        #expect(recipe.name == "Test Recipe")
        #expect(recipe.ingredients.count == 2) // empty ingredient filtered out
        #expect(recipe.steps == ["Mix", "Bake"]) // empty step filtered out
        #expect(recipe.prepTime == 15)
        #expect(recipe.cookTime == 30)
        #expect(recipe.servings == 4)
        #expect(recipe.tags == ["Dessert"])
        #expect(recipe.sourceURL == "https://example.com")
    }

    @Test("updateRecipe replaces ingredients")
    func updateRecipeIntegration() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()

        let recipe = makeRecipe(
            name: "Old Name",
            ingredients: [("Flour", "1 cup")],
            context: context
        )

        vm.updateRecipe(
            recipe,
            name: "New Name",
            photoData: nil,
            ingredients: [("Sugar", "2 cups"), ("Butter", "1 stick")],
            steps: ["Cream butter and sugar"],
            prepTime: 10,
            cookTime: 20,
            servings: 8,
            tags: ["Dessert"],
            sourceURL: nil,
            context: context
        )

        #expect(recipe.name == "New Name")
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.ingredients.contains(where: { $0.name == "Sugar" }))
        #expect(recipe.ingredients.contains(where: { $0.name == "Butter" }))
        #expect(!recipe.ingredients.contains(where: { $0.name == "Flour" }))
        #expect(recipe.steps == ["Cream butter and sugar"])
    }

    @Test("deleteRecipe removes from context")
    func deleteRecipeIntegration() throws {
        let context = try makeTestContext()
        let vm = RecipeViewModel()
        let recipe = makeRecipe(name: "To Delete", context: context)

        vm.deleteRecipe(recipe, context: context)

        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try context.fetch(descriptor)
        #expect(recipes.isEmpty)
    }

    @Test("addMissingToShoppingList creates shopping items")
    func addMissingToShoppingList() throws {
        let context = try makeTestContext()
        let vm = SuggestionsViewModel()

        let ing1 = Ingredient(name: "Butter", quantity: "2 tbsp")
        let ing2 = Ingredient(name: "Cream", quantity: "1 cup")
        context.insert(ing1)
        context.insert(ing2)

        vm.addMissingToShoppingList([ing1, ing2], context: context)

        let descriptor = FetchDescriptor<ShoppingItem>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 2)
        #expect(items.contains(where: { $0.name == "Butter" && $0.quantity == "2 tbsp" }))
        #expect(items.contains(where: { $0.name == "Cream" && $0.category == "Ingredients" }))
    }

    @Test("clearChecked only removes checked items")
    func clearChecked() throws {
        let context = try makeTestContext()
        let vm = ShoppingListViewModel()

        let item1 = ShoppingItem(name: "Milk", isChecked: true)
        let item2 = ShoppingItem(name: "Eggs", isChecked: false)
        let item3 = ShoppingItem(name: "Bread", isChecked: true)
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)

        vm.clearChecked([item1, item2, item3], context: context)

        let descriptor = FetchDescriptor<ShoppingItem>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Eggs")
    }

    @Test("clearAll removes all items")
    func clearAll() throws {
        let context = try makeTestContext()
        let vm = ShoppingListViewModel()

        let item1 = ShoppingItem(name: "Milk")
        let item2 = ShoppingItem(name: "Eggs")
        context.insert(item1)
        context.insert(item2)

        vm.clearAll([item1, item2], context: context)

        let descriptor = FetchDescriptor<ShoppingItem>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    @Test("assignRecipe replaces existing meal in same slot")
    func assignRecipeReplace() throws {
        let context = try makeTestContext()
        let vm = CalendarViewModel()
        let today = Date()
        let recipe1 = makeRecipe(name: "Old Meal", context: context)
        let recipe2 = makeRecipe(name: "New Meal", context: context)

        let slot = CalendarViewModel.MealSlot(date: today, mealType: .dinner)

        // Assign first recipe
        vm.assignRecipe(recipe1, to: slot, context: context)

        let descriptor = FetchDescriptor<MealPlan>()
        var plans = try context.fetch(descriptor)
        #expect(plans.count == 1)
        #expect(plans.first?.recipe?.name == "Old Meal")

        // Assign second recipe to same slot — should replace
        vm.assignRecipe(recipe2, to: slot, context: context)

        plans = try context.fetch(descriptor)
        let dinnerPlans = plans.filter { Calendar.current.isDate($0.date, inSameDayAs: today) && $0.mealType == .dinner }
        #expect(dinnerPlans.count == 1)
        #expect(dinnerPlans.first?.recipe?.name == "New Meal")
    }

    @Test("removeMeal deletes meal plan")
    func removeMeal() throws {
        let context = try makeTestContext()
        let vm = CalendarViewModel()
        let recipe = makeRecipe(name: "Test", context: context)
        let meal = MealPlan(date: Date(), mealType: .lunch, recipe: recipe)
        context.insert(meal)
        try context.save()

        vm.removeMeal(meal, context: context)

        let descriptor = FetchDescriptor<MealPlan>()
        let plans = try context.fetch(descriptor)
        #expect(plans.isEmpty)
    }
}
