import SwiftUI
import SwiftData

struct SuggestionsView: View {
    var onSelectRecipe: ((Recipe) -> Void)? = nil

    @State private var viewModel = SuggestionsViewModel()
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var addedToShoppingRecipeIds: Set<UUID> = []
    @State private var plannedRecipeIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.md)

            // Ingredient input
            ingredientInputSection
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.lg)

            // Entered ingredients
            if !viewModel.userIngredients.isEmpty {
                enteredIngredients
                    .padding(.top, MPSpacing.md)

                // Search button
                MPButton(
                    title: "Find Recipes",
                    icon: "magnifyingglass",
                    isFullWidth: true
                ) {
                    viewModel.findMatches(from: recipes)
                }
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.md)
            }

            // Results
            if viewModel.hasSearched {
                resultsSection
            } else if viewModel.userIngredients.isEmpty {
                Spacer()
                MPEmptyState(
                    icon: "lightbulb",
                    title: "What's in your kitchen?",
                    subtitle: "Enter ingredients you have on hand and we'll suggest recipes you can make"
                )
                Spacer()
            } else {
                Spacer()
            }
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: MPSpacing.xs) {
            Text("Suggestions")
                .font(MPTypography.largeTitle())
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            Text("Find recipes based on what you have")
                .font(MPTypography.callout())
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ingredient Input

    private var ingredientInputSection: some View {
        HStack(spacing: MPSpacing.sm) {
            MPTextField(
                placeholder: "e.g. chicken, rice, tomato...",
                text: $viewModel.ingredientInput,
                icon: "leaf"
            )

            Button(action: { viewModel.addIngredient() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        viewModel.ingredientInput.isEmpty ? MPColors.textTertiary : MPColors.primary
                    )
            }
            .disabled(viewModel.ingredientInput.isEmpty)
        }
    }

    // MARK: - Entered Ingredients

    private var enteredIngredients: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MPSpacing.sm) {
                ForEach(viewModel.userIngredients, id: \.self) { ingredient in
                    MPRemovableChip(label: ingredient) {
                        withAnimation {
                            viewModel.removeIngredient(ingredient)
                            // Re-search when removing
                            if !viewModel.userIngredients.isEmpty {
                                viewModel.findMatches(from: recipes)
                            }
                        }
                    }
                }

                if viewModel.userIngredients.count > 1 {
                    Button(action: {
                        withAnimation {
                            viewModel.userIngredients.removeAll()
                            viewModel.matches = []
                            viewModel.hasSearched = false
                            addedToShoppingRecipeIds.removeAll()
                        }
                    }) {
                        Text("Clear all")
                            .font(MPTypography.caption(.medium))
                            .foregroundColor(MPColors.error.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, MPSpacing.xl)
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        Group {
            if viewModel.matches.isEmpty {
                VStack {
                    Spacer()
                    MPEmptyState(
                        icon: "tray",
                        title: "No matches found",
                        subtitle: "Try adding more ingredients or add new recipes to your cookbook"
                    )
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(viewModel.matches.count) recipe\(viewModel.matches.count == 1 ? "" : "s") found")
                                .font(MPTypography.caption(.medium))
                                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.lg)

                        LazyVStack(spacing: MPSpacing.md) {
                            ForEach(viewModel.matches) { match in
                                matchCard(match)
                            }
                        }
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }

    // MARK: - Match Card

    private func matchCard(_ match: RecipeMatch) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: recipe info + coverage badge
            HStack(alignment: .top, spacing: MPSpacing.md) {
                // Thumbnail
                ZStack {
                    if let photoData = match.recipe.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [MPColors.primarySoft, MPColors.primaryMuted.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(MPColors.primary.opacity(0.5))
                        )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))

                VStack(alignment: .leading, spacing: MPSpacing.xs) {
                    Text(match.recipe.name)
                        .font(MPTypography.headline())
                        .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    if match.recipe.totalTime > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(match.recipe.formattedTotalTime)
                                .font(MPTypography.small())
                        }
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                // Coverage percentage
                coverageBadge(match.coveragePercent)
            }
            .padding(MPSpacing.lg)

            Divider().foregroundColor(MPColors.divider)

            // Ingredient breakdown
            VStack(alignment: .leading, spacing: MPSpacing.md) {
                // What you have
                if !match.matchedIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: MPSpacing.xs) {
                        HStack(spacing: MPSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(MPColors.primary)
                            Text("You have (\(match.matchedIngredients.count))")
                                .font(MPTypography.caption(.semibold))
                                .foregroundColor(MPColors.primary)
                        }
                        Text(match.matchedIngredients.joined(separator: ", "))
                            .font(MPTypography.caption())
                            .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                // What you need
                if !match.missingIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: MPSpacing.xs) {
                        HStack(spacing: MPSpacing.xs) {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 12))
                                .foregroundColor(MPColors.warning)
                            Text("You need (\(match.missingIngredients.count))")
                                .font(MPTypography.caption(.semibold))
                                .foregroundColor(MPColors.warning)
                        }

                        FlowLayout(spacing: MPSpacing.xs) {
                            ForEach(match.missingIngredients) { ingredient in
                                HStack(spacing: 3) {
                                    if !ingredient.quantity.isEmpty {
                                        Text(ingredient.quantity)
                                            .font(MPTypography.small(.semibold))
                                    }
                                    Text(ingredient.name)
                                        .font(MPTypography.small())
                                }
                                .padding(.horizontal, MPSpacing.sm)
                                .padding(.vertical, 3)
                                .background(MPColors.warning.opacity(0.1))
                                .clipShape(Capsule())
                                .foregroundColor(MPColors.warning)
                            }
                        }
                    }

                    // Add to shopping list button
                    let alreadyAdded = addedToShoppingRecipeIds.contains(match.recipe.id)
                    Button(action: {
                        viewModel.addMissingToShoppingList(match.missingIngredients, context: modelContext)
                        withAnimation {
                            addedToShoppingRecipeIds.insert(match.recipe.id)
                        }
                    }) {
                        HStack(spacing: MPSpacing.sm) {
                            Image(systemName: alreadyAdded ? "checkmark" : "cart.badge.plus")
                                .font(.system(size: 13, weight: .medium))
                            Text(alreadyAdded ? "Added to shopping list" : "Add missing to shopping list")
                                .font(MPTypography.caption(.semibold))
                        }
                        .foregroundColor(alreadyAdded ? MPColors.primary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MPSpacing.sm)
                        .background(alreadyAdded ? MPColors.primarySoft : MPColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))
                    }
                    .disabled(alreadyAdded)
                }

                // Plan this meal button (only when accessed from AddMealSheet)
                if let onSelectRecipe = onSelectRecipe {
                    let alreadyPlanned = plannedRecipeIds.contains(match.recipe.id)
                    Button(action: {
                        // Add missing ingredients to shopping list automatically
                        if !match.missingIngredients.isEmpty && !addedToShoppingRecipeIds.contains(match.recipe.id) {
                            viewModel.addMissingToShoppingList(match.missingIngredients, context: modelContext)
                            addedToShoppingRecipeIds.insert(match.recipe.id)
                        }
                        withAnimation {
                            plannedRecipeIds.insert(match.recipe.id)
                        }
                        onSelectRecipe(match.recipe)
                    }) {
                        HStack(spacing: MPSpacing.sm) {
                            Image(systemName: alreadyPlanned ? "checkmark.circle.fill" : "calendar.badge.plus")
                                .font(.system(size: 13, weight: .medium))
                            Text(alreadyPlanned ? "Added to plan" : "Plan this meal")
                                .font(MPTypography.caption(.semibold))
                        }
                        .foregroundColor(alreadyPlanned ? MPColors.primary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MPSpacing.sm)
                        .background(alreadyPlanned ? MPColors.primarySoft : MPColors.primaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))
                    }
                    .disabled(alreadyPlanned)
                }
            }
            .padding(MPSpacing.lg)
        }
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
        .shadow(color: MPColors.shadow, radius: 6, x: 0, y: 2)
    }

    // MARK: - Coverage Badge

    private func coverageBadge(_ percent: Int) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(MPColors.divider, lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(
                        percent >= 80 ? MPColors.primary :
                        percent >= 50 ? MPColors.primaryLight :
                        MPColors.warning,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(percent)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            }

            Text("match")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}
