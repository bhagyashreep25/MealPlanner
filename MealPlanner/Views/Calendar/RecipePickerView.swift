import SwiftUI

struct RecipePickerView: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        let query = searchText.lowercased()
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MPSearchBar(text: $searchText, placeholder: "Search recipes...")
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.md)

                if filteredRecipes.isEmpty {
                    Spacer()
                    MPEmptyState(
                        icon: "book.closed",
                        title: recipes.isEmpty ? "No recipes" : "No matches",
                        subtitle: recipes.isEmpty
                            ? "Add some recipes first, then come back to plan meals"
                            : "Try a different search term"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: MPSpacing.sm) {
                            ForEach(filteredRecipes) { recipe in
                                Button(action: { onSelect(recipe) }) {
                                    recipeRow(recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.md)
                        .padding(.bottom, MPSpacing.xxxl)
                    }
                }
            }
            .background(MPAdaptiveColors.background(for: colorScheme))
            .navigationTitle("Choose Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MPColors.textSecondary)
                }
            }
        }
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: MPSpacing.md) {
            // Thumbnail
            ZStack {
                if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
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
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(MPColors.primary.opacity(0.5))
                    )
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))

            // Info
            VStack(alignment: .leading, spacing: MPSpacing.xs) {
                Text(recipe.name)
                    .font(MPTypography.body(.medium))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: MPSpacing.sm) {
                    if recipe.totalTime > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(recipe.formattedTotalTime)
                                .font(MPTypography.small())
                        }
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if !recipe.tags.isEmpty {
                        Text(recipe.tags.prefix(2).joined(separator: ", "))
                            .font(MPTypography.small())
                            .foregroundColor(MPColors.primary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(MPColors.textTertiary)
        }
        .padding(MPSpacing.md)
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
        .shadow(color: MPColors.shadow, radius: 4, x: 0, y: 1)
    }
}
