import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe
    @Bindable var viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image
                heroImage

                // Content
                VStack(alignment: .leading, spacing: MPSpacing.xl) {
                    // Title & meta
                    titleSection

                    // Tags
                    if !recipe.tags.isEmpty {
                        tagsSection
                    }

                    Divider()
                        .foregroundColor(MPColors.divider)

                    // Time & servings info bar
                    infoBar

                    Divider()
                        .foregroundColor(MPColors.divider)

                    // Ingredients
                    ingredientsSection

                    Divider()
                        .foregroundColor(MPColors.divider)

                    // Steps
                    stepsSection
                }
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.xl)
                .padding(.bottom, 120)
            }
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { viewModel.recipeToEdit = recipe }) {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(MPColors.primary)
                }
            }
        }
        .alert("Delete Recipe", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteRecipe(recipe, context: modelContext)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(recipe.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Sections

    private var heroImage: some View {
        ZStack(alignment: .bottomLeading) {
            if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 280)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [MPColors.primarySoft, MPColors.primaryMuted.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 280)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundColor(MPColors.primary.opacity(0.3))
                )
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.3)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .frame(height: 280)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.sm) {
            Text(recipe.name)
                .font(MPTypography.title(.bold))
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))

            if let sourceURL = recipe.sourceURL, !sourceURL.isEmpty {
                HStack(spacing: MPSpacing.xs) {
                    Image(systemName: "link")
                        .font(.system(size: 12))
                    Text("Source available")
                        .font(MPTypography.caption())
                }
                .foregroundColor(MPColors.primary)
            }
        }
    }

    private var tagsSection: some View {
        FlowLayout(spacing: MPSpacing.sm) {
            ForEach(recipe.tags, id: \.self) { tag in
                MPChip(label: tag)
            }
        }
    }

    private var infoBar: some View {
        HStack(spacing: 0) {
            infoItem(icon: "clock", label: "Prep", value: "\(recipe.prepTime)m")
            Spacer()
            Rectangle()
                .fill(MPColors.divider)
                .frame(width: 1, height: 32)
            Spacer()
            infoItem(icon: "flame", label: "Cook", value: "\(recipe.cookTime)m")
            Spacer()
            Rectangle()
                .fill(MPColors.divider)
                .frame(width: 1, height: 32)
            Spacer()
            infoItem(icon: "person.2", label: "Servings", value: "\(recipe.servings)")
        }
        .padding(.vertical, MPSpacing.sm)
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: MPSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(MPColors.primary)
            Text(value)
                .font(MPTypography.headline())
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
            Text(label)
                .font(MPTypography.small())
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.lg) {
            MPSectionHeader(title: "Ingredients")

            VStack(spacing: MPSpacing.sm) {
                ForEach(recipe.ingredients) { ingredient in
                    HStack(spacing: MPSpacing.md) {
                        Circle()
                            .fill(MPColors.primarySoft)
                            .frame(width: 8, height: 8)

                        if !ingredient.quantity.isEmpty {
                            Text(ingredient.quantity)
                                .font(MPTypography.body(.semibold))
                                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                        }

                        Text(ingredient.name)
                            .font(MPTypography.body())
                            .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))

                        Spacer()
                    }
                    .padding(.vertical, MPSpacing.xs)
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.lg) {
            MPSectionHeader(title: "Steps")

            VStack(alignment: .leading, spacing: MPSpacing.lg) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: MPSpacing.md) {
                        // Step number
                        Text("\(index + 1)")
                            .font(MPTypography.caption(.bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(MPColors.primary)
                            .clipShape(Circle())

                        Text(step)
                            .font(MPTypography.body())
                            .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += maxRowHeight + spacing
                maxRowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxRowHeight = max(maxRowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + maxRowHeight))
    }
}
