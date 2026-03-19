import SwiftUI
import SwiftData

struct AddMealSheet: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var showingSuggestions = false
    @State private var showingAddManually = false
    @State private var showingImportURL = false
    @State private var showingImportPhoto = false
    @State private var recipeViewModel = RecipeViewModel()

    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        let query = searchText.lowercased()
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Search bar + AI suggestions icon
                    HStack(spacing: MPSpacing.sm) {
                        MPSearchBar(text: $searchText, placeholder: "Search recipes...")

                        Button(action: { showingSuggestions = true }) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(MPColors.primary)
                                .frame(width: 44, height: 44)
                                .background(MPColors.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
                        }
                    }
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.md)

                    if filteredRecipes.isEmpty {
                        Spacer()
                        MPEmptyState(
                            icon: "book.closed",
                            title: recipes.isEmpty ? "No recipes yet" : "No matches",
                            subtitle: recipes.isEmpty
                                ? "Tap + to add your first recipe"
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
                            .padding(.bottom, MPSpacing.xxxl + 60)
                        }
                    }
                }

                // FAB for adding new recipes
                addMenu
                    .padding(.trailing, MPSpacing.xl)
                    .padding(.bottom, MPSpacing.xl)
            }
            .background(MPAdaptiveColors.background(for: colorScheme))
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MPColors.textSecondary)
                }
            }
            .navigationDestination(isPresented: $showingSuggestions) {
                SuggestionsView(onSelectRecipe: { recipe in
                    onSelect(recipe)
                })
            }
            .sheet(isPresented: $showingAddManually) {
                RecipeFormView(viewModel: recipeViewModel)
            }
            .sheet(isPresented: $showingImportURL) {
                RecipeImportView(viewModel: recipeViewModel, importMode: .url)
            }
            .sheet(isPresented: $showingImportPhoto) {
                RecipeImportView(viewModel: recipeViewModel, importMode: .photo)
            }
        }
    }

    // MARK: - Add Menu (FAB)

    private var addMenu: some View {
        Menu {
            Button {
                showingAddManually = true
            } label: {
                Label("Add Manually", systemImage: "square.and.pencil")
            }

            Button {
                showingImportURL = true
            } label: {
                Label("Import from URL", systemImage: "link")
            }

            Button {
                showingImportPhoto = true
            } label: {
                Label("Scan from Photo", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(MPColors.primary)
                .clipShape(Circle())
                .shadow(color: MPColors.primary.opacity(0.35), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - Recipe Row

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
