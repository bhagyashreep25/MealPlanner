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
            // Fixed top: lightbulb + text + input
            fixedHeader
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.md)

            // Entered ingredients chips
            if !viewModel.userIngredients.isEmpty {
                enteredIngredients
                    .padding(.top, MPSpacing.md)

                // Find button — retro dashed style
                findButton
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.md)
            }

            // Results
            if viewModel.hasSearched {
                resultsSection
            } else {
                Spacer()
            }
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Suggestions")
                    .font(MPTypography.headline())
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Fixed Header (input)

    private var fixedHeader: some View {
        VStack(spacing: MPSpacing.lg) {
            ingredientInputSection
        }
    }

    // MARK: - Ingredient Input

    private var ingredientInputSection: some View {
        HStack(spacing: MPSpacing.sm) {
            MPTextField(
                placeholder: "e.g. chicken, rice, tomato...",
                text: $viewModel.ingredientInput
            )

            Button(action: { viewModel.addIngredient() }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(
                        viewModel.ingredientInput.isEmpty ? MPColors.textTertiary : MPColors.onPrimary
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        viewModel.ingredientInput.isEmpty
                            ? AnyShapeStyle(MPColors.surfaceSecondary)
                            : AnyShapeStyle(MPColors.primary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
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

    // MARK: - Find Button (retro dashed)

    private var findButton: some View {
        Button(action: { viewModel.findMatches(from: recipes) }) {
            HStack(spacing: MPSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                Text("Find Recipes")
                    .font(MPTypography.callout(.semibold))
            }
            .foregroundColor(MPColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MPSpacing.md + 2)
            .background(MPAdaptiveColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MPRadius.md)
                    .stroke(MPColors.primary, lineWidth: 1.5)
            )
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
                            colors: [MPColors.surfaceSecondary, MPColors.primarySoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(MPColors.primaryMuted.opacity(0.5))
                        )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))

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

                coverageBadge(match.coveragePercent)
            }
            .padding(MPSpacing.lg)

            Divider().foregroundColor(MPColors.divider)

            // Ingredient breakdown
            VStack(alignment: .leading, spacing: MPSpacing.lg) {
                if !match.missingIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: MPSpacing.sm) {
                        HStack(spacing: MPSpacing.xs) {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 12))
                                .foregroundColor(MPColors.textSecondary)
                            Text("You need (\(match.missingIngredients.count))")
                                .font(MPTypography.caption(.semibold))
                                .foregroundColor(MPColors.textSecondary)
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
                                .background(MPColors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))
                                .foregroundColor(MPColors.textSecondary)
                            }
                        }
                    }
                }

                // Action buttons side by side
                let alreadyAdded = addedToShoppingRecipeIds.contains(match.recipe.id)
                HStack(spacing: MPSpacing.sm) {
                    // Secondary: Add to list (outline)
                    Button(action: {
                        viewModel.addMissingToShoppingList(match.missingIngredients, context: modelContext)
                        withAnimation {
                            addedToShoppingRecipeIds.insert(match.recipe.id)
                        }
                    }) {
                        Text(alreadyAdded ? "Added" : "Add to List")
                            .font(MPTypography.caption(.semibold))
                            .foregroundColor(alreadyAdded ? MPColors.textTertiary : MPColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MPSpacing.sm)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: MPRadius.md)
                                    .stroke(alreadyAdded ? MPColors.divider : MPColors.primary, lineWidth: 1.5)
                            )
                    }
                    .disabled(alreadyAdded)

                    // Primary: Plan this meal (solid)
                    if let onSelectRecipe = onSelectRecipe {
                        let alreadyPlanned = plannedRecipeIds.contains(match.recipe.id)
                        Button(action: {
                            if !match.missingIngredients.isEmpty && !addedToShoppingRecipeIds.contains(match.recipe.id) {
                                viewModel.addMissingToShoppingList(match.missingIngredients, context: modelContext)
                                addedToShoppingRecipeIds.insert(match.recipe.id)
                            }
                            withAnimation {
                                plannedRecipeIds.insert(match.recipe.id)
                            }
                            onSelectRecipe(match.recipe)
                        }) {
                            Text(alreadyPlanned ? "Planned" : "Plan Meal")
                                .font(MPTypography.caption(.semibold))
                                .foregroundColor(alreadyPlanned ? MPColors.textTertiary : MPColors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, MPSpacing.sm)
                                .background(alreadyPlanned ? MPColors.primarySoft : MPColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
                        }
                        .disabled(alreadyPlanned)
                    }
                }
            }
            .padding(MPSpacing.lg)
        }
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MPRadius.md)
                .stroke(MPColors.divider.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            }

            Text("match")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}
