import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @Query private var mealPlans: [MealPlan]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var recipeViewModel = RecipeViewModel()
    @State private var longPressedMeal: MealPlan? = nil
    @State private var longPressedMealType: MealType? = nil
    @State private var showingMealActions = false
    @State private var selectedTab: BottomTab = .plan

    private enum BottomTab: Int, CaseIterable {
        case plan = 0
        case recipes = 1
        case shopping = 2

        var label: String {
            switch self {
            case .plan: return "Plan"
            case .recipes: return "Recipes"
            case .shopping: return "List"
            }
        }

        var activeIcon: String {
            switch self {
            case .plan: return "nav-plan-active"
            case .recipes: return "nav-recipes-active"
            case .shopping: return "nav-list-active"
            }
        }

        var inactiveIcon: String {
            switch self {
            case .plan: return "nav-plan-inactive"
            case .recipes: return "nav-recipes-inactive"
            case .shopping: return "nav-list-inactive"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .plan:
                    planContent
                case .recipes:
                    RecipeListView(viewModel: recipeViewModel)
                        .navigationBarBackButtonHidden(true)
                case .shopping:
                    ShoppingListView()
                        .navigationBarBackButtonHidden(true)
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 60)
                    .onEnded { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        guard horizontal > vertical * 1.5 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if value.translation.width < -60 {
                                if let next = BottomTab(rawValue: selectedTab.rawValue + 1) {
                                    selectedTab = next
                                }
                            } else if value.translation.width > 60 {
                                if let prev = BottomTab(rawValue: selectedTab.rawValue - 1) {
                                    selectedTab = prev
                                }
                            }
                        }
                    }
            )

            bottomNavBar
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .navigationBarHidden(true)
        .confirmationDialog("", isPresented: $showingMealActions, titleVisibility: .hidden) {
            Button {
                if let mealType = longPressedMealType {
                    viewModel.selectSlot(date: viewModel.selectedDate, mealType: mealType)
                }
            } label: {
                Label("Change Recipe", systemImage: "arrow.triangle.swap")
            }
            Button(role: .destructive) {
                if let meal = longPressedMeal {
                    viewModel.removeMeal(meal, context: modelContext)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button("Cancel", role: .cancel) {}
        }
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
    }

    // MARK: - Plan Content

    private var planContent: some View {
        VStack(spacing: 0) {
            calendarHeader
            dayView
            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(spacing: MPSpacing.sm) {
            // Navigation row: left arrow, date block, right arrow
            HStack {
                Button(action: { viewModel.goToPreviousDay() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MPColors.textTertiary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                dateBlock

                Spacer()

                Button(action: { viewModel.goToNextDay() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MPColors.textTertiary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, MPSpacing.xl)
        }
        .padding(.top, MPSpacing.lg)
        .padding(.bottom, MPSpacing.md)
    }

    // MARK: - Date Block (130×130 square, diagonal gradient)

    private var dateBlock: some View {
        VStack(spacing: 0) {
            Text(viewModel.shortDayOfWeek)
                .font(MPTypography.body(.medium))
                .foregroundColor(Color(hex: "E8E8E8"))
                .tracking(2)
                .textCase(.uppercase)
                .padding(.top, MPSpacing.lg)

            Text(viewModel.dayNumber(for: viewModel.selectedDate))
                .font(MPTypography.gloock(48))
                .foregroundColor(MPColors.onPrimary)
                .padding(.vertical, -2)

            Text(viewModel.shortMonth)
                .font(MPTypography.body(.medium))
                .foregroundColor(Color(hex: "E8E8E8"))
                .tracking(2)
                .textCase(.uppercase)
                .padding(.bottom, MPSpacing.lg)
        }
        .frame(width: 130, height: 130)
        .background(
            LinearGradient(
                colors: [Color(hex: "C96032"), Color(hex: "73351A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
        .shadow(color: Color(hex: "73351A").opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Day View

    private var dayView: some View {
        ScrollView {
            VStack(spacing: MPSpacing.xl) {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, mealType in
                    dayMealCard(mealType: mealType, labelOnRight: index % 2 != 0)
                }
            }
            .padding(.top, MPSpacing.xl)
            .padding(.bottom, MPSpacing.xl)
        }
    }

    private func dayMealCard(mealType: MealType, labelOnRight: Bool) -> some View {
        let meal = viewModel.mealForSlot(
            date: viewModel.selectedDate,
            mealType: mealType,
            from: mealPlans
        )
        let hasMeal = meal?.recipe != nil

        return Button(action: {
                if meal == nil {
                    viewModel.selectSlot(date: viewModel.selectedDate, mealType: mealType)
                }
            }) {
                VStack(alignment: .leading, spacing: 0) {
                    if let meal = meal, let recipe = meal.recipe {
                        filledCardContent(recipe: recipe, alignRight: !labelOnRight)
                    } else {
                        emptyCardContent()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 230)
                .background(MPAdaptiveColors.surface(for: colorScheme))
                .overlay {
                    GeometryReader { geo in
                        verticalMealLabel(mealType.rawValue, onRight: labelOnRight)
                            .position(
                                x: labelOnRight ? geo.size.width - 20 : 20,
                                y: geo.size.height / 2
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: MPRadius.lg)
                        .stroke(MPColors.divider.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        if hasMeal {
                            longPressedMeal = meal
                            longPressedMealType = mealType
                            withAnimation(.easeOut(duration: 0.2)) {
                                showingMealActions = true
                            }
                        }
                    }
            )

        .padding(.horizontal, 30)
    }

    // MARK: - Vertical Meal Label

    private func verticalMealLabel(_ text: String, onRight: Bool) -> some View {
        Text(text.uppercased())
            .font(MPTypography.display())
            .foregroundColor(Color(hex: "BE6E4B"))
            .fixedSize()
            .rotationEffect(.degrees(onRight ? 90 : -90))
    }

    // MARK: - Card Content

    // alignRight: true = lunch (label overlaps left, content right-aligned in card)
    // alignRight: false = dinner (label overlaps right, content left-aligned in card)
    private func filledCardContent(recipe: Recipe, alignRight: Bool) -> some View {
        VStack(alignment: alignRight ? .trailing : .leading, spacing: MPSpacing.sm) {
            if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
            }

            Text(recipe.name)
                .font(MPTypography.gloock(20))
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(alignRight ? .trailing : .leading)
        }
        .padding(20)
        .padding(.leading, alignRight ? 40 : 0)
        .padding(.trailing, alignRight ? 0 : 40)
        .frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
    }

    private func emptyCardContent() -> some View {
        Text("Tap to add")
            .font(MPTypography.callout())
            .foregroundColor(MPColors.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Nav

    private var bottomNavBar: some View {
        HStack(spacing: 0) {
            ForEach(BottomTab.allCases, id: \.self) { tab in
                let isActive = selectedTab == tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 3) {
                        Image(isActive ? tab.activeIcon : tab.inactiveIcon)
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                        Text(tab.label)
                            .font(MPTypography.caption(isActive ? .medium : .regular))
                            .foregroundColor(isActive ? Color(hex: "73351A") : Color(hex: "999999"))
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MPSpacing.sm)
        .background(
            Rectangle()
                .fill(Color(hex: "E0D8CB"))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(hex: "454545").opacity(0.08))
                        .frame(height: 0.5)
                }
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
