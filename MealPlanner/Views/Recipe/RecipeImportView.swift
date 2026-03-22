import SwiftUI
import SwiftData
import PhotosUI

struct RecipeImportView: View {
    @Bindable var viewModel: RecipeViewModel
    var importMode: ImportMode

    enum ImportMode {
        case url
        case photo
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var urlInput: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var parsedRecipe: ParsedRecipe? = nil

    // Editable form state (populated from parsed recipe)
    @State private var name: String = ""
    @State private var prepTime: Int = 0
    @State private var cookTime: Int = 0
    @State private var servings: Int = 1
    @State private var ingredients: [IngredientEntry] = []
    @State private var steps: [StepEntry] = []
    @State private var tags: [String] = []
    @State private var sourceURL: String = ""
    @State private var photoData: Data? = nil
    @State private var dishPhoto: PhotosPickerItem? = nil

    private let importService = RecipeImportService()

    var body: some View {
        NavigationStack {
            Group {
                if parsedRecipe == nil {
                    inputPhase
                } else {
                    reviewPhase
                }
            }
            .background(MPAdaptiveColors.background(for: colorScheme))
            .navigationTitle(parsedRecipe == nil ? (importMode == .url ? "Import from URL" : "Import from Photo") : "Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MPColors.textSecondary)
                }
                if parsedRecipe != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { saveRecipe() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(name.isEmpty ? MPColors.textTertiary : MPColors.primary)
                            .disabled(name.isEmpty)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        // Don't set photoData here — the scanned photo is not the recipe image
                        await performOCR(image: image)
                    }
                }
            }
            .onChange(of: dishPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        VStack(spacing: MPSpacing.xl) {
            if importMode == .url {
                urlInputView
            } else {
                photoInputView
            }

            if isLoading {
                VStack(spacing: MPSpacing.md) {
                    ProgressView()
                        .tint(MPColors.primary)
                    Text(importMode == .url ? "Fetching recipe..." : "Scanning text...")
                        .font(MPTypography.callout())
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.top, MPSpacing.xxl)
            }

            if let error = errorMessage {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(MPColors.warning)
                    Text(error)
                        .font(MPTypography.callout())
                        .foregroundColor(MPColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(MPSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MPColors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
            }

            Spacer()
        }
        .padding(.horizontal, MPSpacing.xl)
        .padding(.top, MPSpacing.xl)
    }

    private var urlInputView: some View {
        VStack(alignment: .leading, spacing: MPSpacing.lg) {
            VStack(alignment: .leading, spacing: MPSpacing.sm) {
                Text("Paste a recipe URL")
                    .font(MPTypography.headline())
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                Text("We'll extract the recipe details automatically")
                    .font(MPTypography.callout())
                    .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
            }

            MPTextField(placeholder: "https://example.com/recipe...", text: $urlInput, icon: "link", keyboardType: .URL)

            MPButton(title: "Import Recipe", icon: "arrow.down.circle", isFullWidth: true) {
                Task { await performURLImport() }
            }
            .opacity(urlInput.isEmpty ? 0.5 : 1)
            .disabled(urlInput.isEmpty || isLoading)
        }
    }

    private var photoInputView: some View {
        VStack(alignment: .leading, spacing: MPSpacing.lg) {
            VStack(alignment: .leading, spacing: MPSpacing.sm) {
                Text("Scan a recipe photo")
                    .font(MPTypography.headline())
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                Text("Take a photo or select from your gallery")
                    .font(MPTypography.callout())
                    .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
            }

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .semibold))
                    Text(selectedImage == nil ? "Select Photo" : "Choose Different Photo")
                        .font(MPTypography.callout(.semibold))
                }
                .foregroundColor(MPColors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MPSpacing.md + 2)
                .background(MPColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.xl))
            }
        }
    }

    // MARK: - Review Phase (editable form)

    private var reviewPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MPSpacing.xl) {
                // Success banner
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MPColors.primary)
                    Text("Recipe extracted — review and edit below")
                        .font(MPTypography.callout(.medium))
                        .foregroundColor(MPColors.primary)
                }
                .padding(MPSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MPColors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))

                // Photo section with delete
                photoReviewSection

                // Name
                formSection("RECIPE NAME") {
                    MPTextField(placeholder: "Recipe name", text: $name)
                }

                // Time & servings
                formSection("TIME & SERVINGS") {
                    HStack(spacing: MPSpacing.md) {
                        MPNumberField(placeholder: "Prep", value: $prepTime, icon: "clock", suffix: "min")
                        MPNumberField(placeholder: "Cook", value: $cookTime, icon: "flame", suffix: "min")
                        MPNumberField(placeholder: "Serves", value: $servings, icon: "person.2")
                    }
                }

                // Tags
                if !tags.isEmpty {
                    formSection("CATEGORIES") {
                        FlowLayout(spacing: MPSpacing.sm) {
                            ForEach(tags, id: \.self) { tag in
                                MPRemovableChip(label: tag) {
                                    withAnimation { tags.removeAll { $0 == tag } }
                                }
                            }
                        }
                    }
                }

                // Ingredients
                let validIngredientCount = ingredients.filter { !$0.name.isEmpty }.count
                formSection("INGREDIENTS (\(validIngredientCount))") {
                    VStack(spacing: MPSpacing.sm) {
                        ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, _ in
                            HStack(spacing: MPSpacing.sm) {
                                MPTextField(placeholder: "Qty", text: $ingredients[index].quantity)
                                    .frame(width: 80)
                                MPTextField(placeholder: "Ingredient", text: $ingredients[index].name)
                                Button {
                                    withAnimation { _ = ingredients.remove(at: index) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(MPColors.error.opacity(0.7))
                                }
                            }
                        }
                        Button {
                            withAnimation { ingredients.append(IngredientEntry()) }
                        } label: {
                            HStack(spacing: MPSpacing.sm) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                Text("Add Ingredient")
                                    .font(MPTypography.caption(.medium))
                            }
                            .foregroundColor(MPColors.primary)
                        }
                    }
                }

                // Steps
                let validStepCount = steps.filter { !$0.text.isEmpty }.count
                formSection("STEPS (\(validStepCount))") {
                    VStack(spacing: MPSpacing.sm) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                            HStack(alignment: .top, spacing: MPSpacing.sm) {
                                Text("\(index + 1)")
                                    .font(MPTypography.caption(.bold))
                                    .foregroundColor(MPColors.onPrimary)
                                    .frame(width: 22, height: 22)
                                    .background(MPColors.primary)
                                    .clipShape(Circle())
                                    .padding(.top, MPSpacing.md)

                                MPTextField(placeholder: "Step \(index + 1)...", text: $steps[index].text)

                                Button {
                                    withAnimation { _ = steps.remove(at: index) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(MPColors.error.opacity(0.7))
                                }
                                .padding(.top, MPSpacing.md)
                            }
                        }
                        Button {
                            withAnimation { steps.append(StepEntry()) }
                        } label: {
                            HStack(spacing: MPSpacing.sm) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                Text("Add Step")
                                    .font(MPTypography.caption(.medium))
                            }
                            .foregroundColor(MPColors.primary)
                        }
                    }
                }

                // Source URL (for URL imports)
                if !sourceURL.isEmpty {
                    formSection("SOURCE") {
                        Text(sourceURL)
                            .font(MPTypography.caption())
                            .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(.horizontal, MPSpacing.xl)
            .padding(.top, MPSpacing.lg)
            .padding(.bottom, MPSpacing.xxxl)
        }
    }

    // MARK: - Photo Review Section

    private var photoReviewSection: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $dishPhoto, matching: .images) {
                ZStack {
                    if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
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
                        .frame(height: 180)
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

            if photoData != nil {
                Button(action: {
                    withAnimation {
                        self.photoData = nil
                        self.dishPhoto = nil
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

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            Text(title)
                .font(MPTypography.caption(.semibold))
                .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                .tracking(0.5)
            content()
        }
    }

    // MARK: - Actions

    private func performURLImport() async {
        isLoading = true
        errorMessage = nil

        do {
            let parsed = try await importService.parseFromURL(urlInput)
            await MainActor.run {
                populateForm(from: parsed)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func performOCR(image: UIImage) async {
        isLoading = true
        errorMessage = nil

        do {
            let parsed = try await importService.parseFromImage(image)
            await MainActor.run {
                populateForm(from: parsed)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not extract text from image: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func populateForm(from parsed: ParsedRecipe) {
        parsedRecipe = parsed
        name = parsed.name
        prepTime = parsed.prepTime
        cookTime = parsed.cookTime
        servings = max(parsed.servings, 1)
        tags = parsed.tags
        sourceURL = parsed.sourceURL ?? ""

        ingredients = parsed.ingredients.map {
            IngredientEntry(name: $0.name, quantity: $0.quantity)
        }
        if ingredients.isEmpty { ingredients = [IngredientEntry()] }

        steps = parsed.steps.map { StepEntry(text: $0) }
        if steps.isEmpty { steps = [StepEntry()] }

        // Download recipe image (URL import only — not the scanned photo)
        if let imageURLStr = parsed.imageURL, let imageURL = URL(string: imageURLStr) {
            Task {
                var request = URLRequest(url: imageURL)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let httpResp = response as? HTTPURLResponse,
                   httpResp.statusCode == 200 {
                    await MainActor.run { photoData = data }
                }
            }
        }
    }

    private func saveRecipe() {
        let ingredientData = ingredients
            .filter { !$0.name.isEmpty }
            .map { (name: $0.name, quantity: $0.quantity) }
        let stepTexts = steps.map(\.text).filter { !$0.isEmpty }

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

        dismiss()
    }
}
