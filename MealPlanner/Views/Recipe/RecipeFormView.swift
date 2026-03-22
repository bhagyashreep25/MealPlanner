import SwiftUI
import SwiftData
import PhotosUI

struct RecipeFormView: View {
    @Bindable var viewModel: RecipeViewModel
    var recipe: Recipe? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Form state
    @State private var name: String = ""
    @State private var prepTime: Int = 0
    @State private var cookTime: Int = 0
    @State private var servings: Int = 1
    @State private var ingredients: [IngredientEntry] = [IngredientEntry()]
    @State private var steps: [StepEntry] = [StepEntry()]
    @State private var tags: [String] = []
    @State private var tagInput: String = ""
    @State private var sourceURL: String = ""
    @State private var photoData: Data? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil

    @State private var showingCategoryPicker = false

    var isEditing: Bool { recipe != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MPSpacing.xl) {
                    // Photo picker
                    photoSection

                    // Basic info
                    basicInfoSection

                    // Time & servings
                    timeServingsSection

                    // Tags
                    tagsSection

                    // Ingredients
                    ingredientsSection

                    // Steps
                    stepsSection

                    // Source URL
                    sourceSection
                }
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.lg)
                .padding(.bottom, MPSpacing.xxxl)
            }
            .background(MPAdaptiveColors.background(for: colorScheme))
            .navigationTitle(isEditing ? "Edit Recipe" : "New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MPColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { saveRecipe() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(name.isEmpty ? MPColors.textTertiary : MPColors.primary)
                        .disabled(name.isEmpty)
                }
            }
        }
        .onAppear { loadRecipeData() }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(MPColors.onPrimary)
                                            .shadow(radius: 4)
                                            .padding(MPSpacing.md)
                                    }
                                }
                            )
                    } else {
                        VStack(spacing: MPSpacing.md) {
                            Image(systemName: "camera")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(MPColors.textWarm)
                            Text("Add Photo")
                                .font(MPTypography.callout(.medium))
                                .foregroundColor(MPColors.textWarm)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(MPAdaptiveColors.surface(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: MPRadius.lg)
                                .stroke(MPColors.divider.opacity(0.6), lineWidth: 1)
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
            }

            // Delete photo button
            if photoData != nil {
                Button(action: {
                    withAnimation {
                        photoData = nil
                        selectedPhoto = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .shadow(radius: 3)
                }
                .padding(MPSpacing.sm)
            }
        }
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Recipe Name")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)
            MPTextField(placeholder: "e.g. Chicken Tikka Masala", text: $name)
        }
    }

    // MARK: - Time & Servings

    private var timeServingsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Time & Servings")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: MPSpacing.md) {
                MPNumberField(placeholder: "Prep", value: $prepTime, icon: "clock", suffix: "min")
                MPNumberField(placeholder: "Cook", value: $cookTime, icon: "flame", suffix: "min")
                MPNumberField(placeholder: "Serves", value: $servings, icon: "person.2")
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Categories")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)

            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: MPSpacing.sm) {
                    ForEach(tags, id: \.self) { tag in
                        MPRemovableChip(label: tag) {
                            withAnimation { tags.removeAll { $0 == tag } }
                        }
                    }
                }
            }

            // Add tags — quick select from common categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MPSpacing.sm) {
                    ForEach(availableCategories, id: \.self) { category in
                        Button(action: {
                            withAnimation { tags.append(category) }
                        }) {
                            Text("+ \(category)")
                                .font(MPTypography.caption(.medium))
                                .padding(.horizontal, MPSpacing.md)
                                .padding(.vertical, MPSpacing.xs + 2)
                                .foregroundColor(MPColors.textSecondary)
                                .background(MPColors.surfaceSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Custom tag input
            HStack(spacing: MPSpacing.sm) {
                MPTextField(placeholder: "Add custom tag", text: $tagInput)
                if !tagInput.isEmpty {
                    Button(action: addCustomTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(MPColors.primary)
                    }
                }
            }
        }
    }

    private var availableCategories: [String] {
        viewModel.allCategories.filter { !tags.contains($0) }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Ingredients")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: MPSpacing.sm) {
                    MPTextField(placeholder: "Qty", text: $ingredients[index].quantity)
                        .frame(width: 80)
                    MPTextField(placeholder: "Ingredient name", text: $ingredients[index].name)

                    if ingredients.count > 1 {
                        Button(action: {
                            withAnimation { _ = ingredients.remove(at: index) }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(MPColors.error.opacity(0.7))
                        }
                    }
                }
            }

            Button(action: {
                withAnimation { ingredients.append(IngredientEntry()) }
            }) {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                    Text("Add Ingredient")
                        .font(MPTypography.callout(.medium))
                }
                .foregroundColor(MPColors.primary)
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Steps")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                HStack(alignment: .top, spacing: MPSpacing.sm) {
                    Text("\(index + 1)")
                        .font(MPTypography.caption(.bold))
                        .foregroundColor(MPColors.onPrimary)
                        .frame(width: 24, height: 24)
                        .background(MPColors.primary)
                        .clipShape(Circle())
                        .padding(.top, MPSpacing.md)

                    MPTextField(placeholder: "Describe step \(index + 1)...", text: $steps[index].text)

                    if steps.count > 1 {
                        Button(action: {
                            withAnimation { _ = steps.remove(at: index) }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(MPColors.error.opacity(0.7))
                        }
                        .padding(.top, MPSpacing.md)
                    }
                }
            }

            Button(action: {
                withAnimation { steps.append(StepEntry()) }
            }) {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                    Text("Add Step")
                        .font(MPTypography.callout(.medium))
                }
                .foregroundColor(MPColors.primary)
            }
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text("Source URL (optional)")
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)
            MPTextField(placeholder: "https://...", text: $sourceURL, icon: "link", keyboardType: .URL)
        }
    }

    // MARK: - Actions

    private func addCustomTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation {
                tags.append(trimmed)
                tagInput = ""
            }
        }
    }

    private func saveRecipe() {
        let ingredientData = ingredients
            .filter { !$0.name.isEmpty }
            .map { (name: $0.name, quantity: $0.quantity) }
        let stepTexts = steps.map(\.text).filter { !$0.isEmpty }

        if let recipe = recipe {
            viewModel.updateRecipe(
                recipe,
                name: name,
                photoData: photoData,
                ingredients: ingredientData,
                steps: stepTexts,
                prepTime: prepTime,
                cookTime: cookTime,
                servings: servings,
                tags: tags,
                sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                context: modelContext
            )
        } else {
            viewModel.addRecipe(
                name: name,
                photoData: photoData,
                ingredients: ingredientData,
                steps: stepTexts,
                prepTime: prepTime,
                cookTime: cookTime,
                servings: servings,
                tags: tags,
                sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                context: modelContext
            )
        }

        dismiss()
    }

    private func loadRecipeData() {
        guard let recipe = recipe else { return }
        name = recipe.name
        photoData = recipe.photoData
        prepTime = recipe.prepTime
        cookTime = recipe.cookTime
        servings = recipe.servings
        tags = recipe.tags
        sourceURL = recipe.sourceURL ?? ""
        ingredients = recipe.ingredients.map { IngredientEntry(name: $0.name, quantity: $0.quantity) }
        steps = recipe.steps.map { StepEntry(text: $0) }

        if ingredients.isEmpty { ingredients = [IngredientEntry()] }
        if steps.isEmpty { steps = [StepEntry()] }
    }
}

// MARK: - Helper types

struct IngredientEntry: Identifiable {
    let id = UUID()
    var name: String = ""
    var quantity: String = ""
}

struct StepEntry: Identifiable {
    let id = UUID()
    var text: String = ""
}
