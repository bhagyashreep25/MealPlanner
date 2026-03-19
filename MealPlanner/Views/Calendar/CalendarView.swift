import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @Query private var mealPlans: [MealPlan]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var drawerExpanded = false
    @State private var showingRecipeList = false
    @State private var showingShoppingList = false
    @State private var recipeViewModel = RecipeViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                calendarHeader
                dateStrip
                dayView
                Spacer(minLength: 0)
            }

            drawerView
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showingRecipePicker) {
            AddMealSheet(
                recipes: recipes,
                onSelect: { recipe in
                    if let slot = viewModel.selectedMealSlot {
                        viewModel.assignRecipe(recipe, to: slot, context: modelContext)
                    }
                    viewModel.showingRecipePicker = false
                }
            )
        }
        .navigationDestination(isPresented: $showingRecipeList) {
            RecipeListView(viewModel: recipeViewModel)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingRecipeList = false }
                            .foregroundColor(MPColors.primary)
                    }
                }
                .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(isPresented: $showingShoppingList) {
            ShoppingListView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingShoppingList = false }
                            .foregroundColor(MPColors.primary)
                    }
                }
                .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: MPSpacing.sm) {
            Text("Meals")
                .font(MPTypography.largeTitle())
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))

            HStack {
                Text(viewModel.dayTitle)
                    .font(MPTypography.headline())
                    .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))

                Spacer()

                HStack(spacing: MPSpacing.lg) {
                    Button(action: { viewModel.goToToday() }) {
                        Text("Today")
                            .font(MPTypography.caption(.semibold))
                            .foregroundColor(MPColors.primary)
                            .padding(.horizontal, MPSpacing.md)
                            .padding(.vertical, MPSpacing.xs + 2)
                            .background(MPColors.primarySoft)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: MPSpacing.sm) {
                        Button(action: { viewModel.goToPreviousDay() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MPColors.primary)
                        }
                        Button(action: { viewModel.goToNextDay() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MPColors.primary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MPSpacing.xl)
        .padding(.top, MPSpacing.md)
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MPSpacing.md) {
                    ForEach(viewModel.currentWeekDates, id: \.self) { date in
                        dateStripItem(date)
                            .id(date)
                            .onTapGesture {
                                viewModel.selectDate(date)
                            }
                    }
                }
                .padding(.horizontal, MPSpacing.xl)
            }
            .onChange(of: viewModel.selectedDate) { _, newDate in
                withAnimation { proxy.scrollTo(newDate, anchor: .center) }
            }
        }
        .padding(.top, MPSpacing.lg)
        .padding(.bottom, MPSpacing.sm)
    }

    private func dateStripItem(_ date: Date) -> some View {
        let selected = viewModel.isSelected(date)
        let today = viewModel.isToday(date)

        return VStack(spacing: MPSpacing.xs) {
            Text(viewModel.dayName(for: date))
                .font(MPTypography.small(.medium))
                .foregroundColor(
                    selected ? MPColors.primary :
                    today ? MPColors.primary :
                    MPAdaptiveColors.textSecondary(for: colorScheme)
                )

            Text(viewModel.dayNumber(for: date))
                .font(MPTypography.callout(selected ? .bold : .medium))
                .foregroundColor(selected ? .white : today ? MPColors.primary : MPAdaptiveColors.textPrimary(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(selected ? MPColors.primary : Color.clear)
                .clipShape(Circle())
        }
        .frame(width: 44)
    }

    // MARK: - Day View

    private var dayView: some View {
        ScrollView {
            VStack(spacing: MPSpacing.xl) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    dayMealCard(mealType: mealType)
                }
            }
            .padding(.horizontal, MPSpacing.xl)
            .padding(.top, MPSpacing.xl)
            .padding(.bottom, 80)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > vertical else { return }
                    if value.translation.width < -50 { viewModel.goToNextDay() }
                    else if value.translation.width > 50 { viewModel.goToPreviousDay() }
                }
        )
    }

    private func dayMealCard(mealType: MealType) -> some View {
        let meal = viewModel.mealForSlot(
            date: viewModel.selectedDate,
            mealType: mealType,
            from: mealPlans
        )

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                HStack(spacing: MPSpacing.sm) {
                    Circle()
                        .fill(mealType == .lunch ? MPColors.primaryLight : MPColors.primary)
                        .frame(width: 10, height: 10)
                    Text(mealType.rawValue)
                        .font(MPTypography.headline())
                        .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                }
                Spacer()
                if meal != nil {
                    Menu {
                        Button {
                            viewModel.selectSlot(date: viewModel.selectedDate, mealType: mealType)
                        } label: {
                            Label("Change Recipe", systemImage: "arrow.triangle.swap")
                        }
                        Button(role: .destructive) {
                            if let meal = meal {
                                viewModel.removeMeal(meal, context: modelContext)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MPColors.textTertiary)
                            .padding(MPSpacing.sm)
                    }
                }
            }
            .padding(.horizontal, MPSpacing.lg)
            .padding(.top, MPSpacing.lg)
            .padding(.bottom, MPSpacing.md)

            if let meal = meal, let recipe = meal.recipe {
                dayFilledContent(recipe: recipe)
            } else {
                dayEmptyContent(mealType: mealType)
            }
        }
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
        .shadow(color: MPColors.shadow, radius: 8, x: 0, y: 2)
    }

    private func dayFilledContent(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
                    .padding(.horizontal, MPSpacing.lg)
            }

            VStack(alignment: .leading, spacing: MPSpacing.sm) {
                Text(recipe.name)
                    .font(MPTypography.title2(.semibold))
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))

                HStack(spacing: MPSpacing.lg) {
                    if recipe.prepTime > 0 {
                        Label("\(recipe.prepTime)m prep", systemImage: "clock")
                            .font(MPTypography.caption())
                            .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }
                    if recipe.cookTime > 0 {
                        Label("\(recipe.cookTime)m cook", systemImage: "flame")
                            .font(MPTypography.caption())
                            .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }
                    if recipe.servings > 0 {
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                            .font(MPTypography.caption())
                            .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                if !recipe.tags.isEmpty {
                    HStack(spacing: MPSpacing.sm) {
                        ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(MPTypography.small(.medium))
                                .foregroundColor(MPColors.primary)
                                .padding(.horizontal, MPSpacing.sm)
                                .padding(.vertical, 2)
                                .background(MPColors.primarySoft)
                                .clipShape(Capsule())
                        }
                    }
                }

                if !recipe.ingredients.isEmpty {
                    let preview = recipe.ingredients.prefix(4).map(\.name).joined(separator: ", ")
                    let more = recipe.ingredients.count > 4 ? " +\(recipe.ingredients.count - 4) more" : ""
                    Text(preview + more)
                        .font(MPTypography.caption())
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, MPSpacing.lg)
            .padding(.bottom, MPSpacing.lg)
        }
    }

    private func dayEmptyContent(mealType: MealType) -> some View {
        Button(action: {
            viewModel.selectSlot(date: viewModel.selectedDate, mealType: mealType)
        }) {
            VStack(spacing: MPSpacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(MPColors.primaryMuted)
                Text("Plan your \(mealType.rawValue.lowercased())")
                    .font(MPTypography.callout())
                    .foregroundColor(MPColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MPSpacing.xxxl)
        }
    }

    // MARK: - Drawer

    private var drawerView: some View {
        VStack(spacing: 0) {
            // Handle
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    drawerExpanded.toggle()
                }
            }) {
                VStack(spacing: MPSpacing.xs) {
                    Capsule()
                        .fill(MPColors.divider)
                        .frame(width: 36, height: 4)
                    Image(systemName: drawerExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MPColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, MPSpacing.md)
                .padding(.bottom, MPSpacing.sm)
            }

            // Expanded content
            if drawerExpanded {
                HStack(spacing: MPSpacing.lg) {
                    drawerCard(
                        icon: "book.fill",
                        title: "Recipes",
                        subtitle: "Browse cookbook"
                    ) {
                        showingRecipeList = true
                    }

                    drawerCard(
                        icon: "cart.fill",
                        title: "Shopping",
                        subtitle: "View list"
                    ) {
                        showingShoppingList = true
                    }
                }
                .padding(.horizontal, MPSpacing.xl)
                .padding(.bottom, MPSpacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: MPRadius.lg)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func drawerCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MPSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(MPColors.primary)
                    .frame(width: 40, height: 40)
                    .background(MPColors.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MPTypography.callout(.semibold))
                        .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                    Text(subtitle)
                        .font(MPTypography.small())
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
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
        .buttonStyle(.plain)
    }
}
