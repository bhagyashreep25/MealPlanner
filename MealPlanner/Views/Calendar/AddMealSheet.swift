import SwiftUI
import SwiftData

struct AddMealSheet: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var showingSuggestions = false
    @State private var recipeViewModel = RecipeViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: MPSpacing.md),
        GridItem(.flexible(), spacing: MPSpacing.md)
    ]

    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        let query = searchText.lowercased()
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Search bar
                    MPSearchBar(text: $searchText, placeholder: "Search recipes...", cornerRadius: MPRadius.md)
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.md)

                    if filteredRecipes.isEmpty {
                        Spacer()
                        MPEmptyState(
                            icon: "book.closed",
                            title: recipes.isEmpty ? "No recipes yet" : "No matches",
                            subtitle: recipes.isEmpty
                                ? "Add recipes from the Recipes tab"
                                : "Try a different search term"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: MPSpacing.md) {
                                ForEach(filteredRecipes) { recipe in
                                    recipeCard(recipe)
                                }
                            }
                            .padding(.horizontal, MPSpacing.xl)
                            .padding(.top, MPSpacing.md)
                            .padding(.bottom, 80)
                        }
                    }
                }

                // Suggestions button — fixed at bottom
                suggestionsButton
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, 6)
                    .padding(.bottom, MPSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        Rectangle()
                            .fill(MPAdaptiveColors.background(for: colorScheme))
                            .padding(.bottom, -100)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .background(MPAdaptiveColors.background(for: colorScheme))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Meal")
                        .font(MPTypography.headline())
                        .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MPColors.textWarm)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingSuggestions) {
                SuggestionsView(onSelectRecipe: { recipe in
                    onSelect(recipe)
                })
            }
        }
    }

    // MARK: - Suggestions Button

    private var suggestionsButton: some View {
        Button(action: { showingSuggestions = true }) {
            HStack(spacing: MPSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                Text("Get Suggestions")
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
        .buttonStyle(.plain)
    }

    // MARK: - Recipe Card (image-centric grid)

    private func recipeCard(_ recipe: Recipe) -> some View {
        Button(action: { onSelect(recipe) }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                ZStack {
                    if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(height: 130)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [MPColors.surfaceSecondary, MPColors.divider],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 130)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 24, weight: .ultraLight))
                                .foregroundColor(MPColors.textWarm.opacity(0.4))
                        )
                    }
                }
                .frame(height: 130)

                // Title
                Text(recipe.name)
                    .font(MPTypography.callout(.medium))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, MPSpacing.sm)
                    .padding(.horizontal, MPSpacing.md)

                Spacer(minLength: 0)
            }
            .frame(height: 185)
            .background(MPAdaptiveColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MPRadius.md)
                    .stroke(MPColors.divider.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
