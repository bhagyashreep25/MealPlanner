import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Bindable var viewModel: RecipeViewModel
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingImportURL = false
    @State private var showingImportPhoto = false

    private let columns = [
        GridItem(.flexible(), spacing: MPSpacing.lg),
        GridItem(.flexible(), spacing: MPSpacing.lg)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.md)

                // Search
                MPSearchBar(text: $viewModel.searchText)
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.lg)

                // Category filter
                categoryFilter
                    .padding(.top, MPSpacing.md)

                // Content
                if filteredRecipes.isEmpty {
                    Spacer()
                    if recipes.isEmpty {
                        MPEmptyState(
                            icon: "book.closed",
                            title: "No recipes yet",
                            subtitle: "Start building your cookbook by adding your first recipe",
                            buttonTitle: "Add Recipe"
                        ) {
                            viewModel.showingAddRecipe = true
                        }
                    } else {
                        MPEmptyState(
                            icon: "magnifyingglass",
                            title: "No matches",
                            subtitle: "Try different search terms or clear the filter"
                        )
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: MPSpacing.lg) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(value: recipe) {
                                    RecipeCardView(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.lg)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(MPAdaptiveColors.background(for: colorScheme))

            // FAB with menu
            addMenu
                .padding(.trailing, MPSpacing.xl)
                .padding(.bottom, 90)
        }
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAddRecipe) {
            RecipeFormView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.recipeToEdit) { recipe in
            RecipeFormView(viewModel: viewModel, recipe: recipe)
        }
        .sheet(isPresented: $showingImportURL) {
            RecipeImportView(viewModel: viewModel, importMode: .url)
        }
        .sheet(isPresented: $showingImportPhoto) {
            RecipeImportView(viewModel: viewModel, importMode: .photo)
        }
    }

    // MARK: - Add Menu (FAB with options)

    private var addMenu: some View {
        Menu {
            Button {
                viewModel.showingAddRecipe = true
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

    private var filteredRecipes: [Recipe] {
        viewModel.filteredRecipes(recipes)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MPSpacing.xs) {
            Text("My Recipes")
                .font(MPTypography.largeTitle())
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            Text("\(recipes.count) recipe\(recipes.count == 1 ? "" : "s") in your cookbook")
                .font(MPTypography.callout())
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MPSpacing.sm) {
                MPChip(label: "All", isSelected: viewModel.selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedCategory = nil
                    }
                }

                ForEach(activeCategories, id: \.self) { category in
                    MPChip(label: category, isSelected: viewModel.selectedCategory == category) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedCategory = (viewModel.selectedCategory == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, MPSpacing.xl)
        }
    }

    /// Only show categories that are actually in use
    private var activeCategories: [String] {
        let usedTags = Set(recipes.flatMap(\.tags))
        return viewModel.allCategories.filter { usedTags.contains($0) }
    }
}

// MARK: - Recipe Card

struct RecipeCardView: View {
    let recipe: Recipe
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack {
                if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [MPColors.primarySoft, MPColors.primaryMuted.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(MPColors.primary.opacity(0.5))
                    )
                    .frame(height: 120)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: MPSpacing.xs) {
                Text(recipe.name)
                    .font(MPTypography.callout(.semibold))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(2)

                HStack(spacing: MPSpacing.xs) {
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
                        Text("·")
                            .foregroundColor(MPColors.textTertiary)
                        Text(recipe.tags.first ?? "")
                            .font(MPTypography.small(.medium))
                            .foregroundColor(MPColors.primary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(MPSpacing.md)

            Spacer(minLength: 0)
        }
        .frame(height: 200)
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
        .shadow(color: MPColors.shadow, radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        RecipeListView(viewModel: RecipeViewModel())
    }
    .modelContainer(for: [Recipe.self, Ingredient.self], inMemory: true)
}
