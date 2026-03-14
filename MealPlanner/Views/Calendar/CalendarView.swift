import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @Query private var mealPlans: [MealPlan]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader
            viewModeToggle
                .padding(.horizontal, MPSpacing.xl)
                .padding(.top, MPSpacing.md)

            Group {
                switch viewModel.viewMode {
                case .day:
                    dayView
                case .week:
                    weekView
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.viewMode)

            Spacer(minLength: 0)
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .sheet(isPresented: $viewModel.showingRecipePicker) {
            RecipePickerView(
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

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: MPSpacing.sm) {
            Text("Meal Calendar")
                .font(MPTypography.largeTitle())
                .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))

            HStack {
                Text(viewModel.viewMode == .day ? viewModel.dayTitle : viewModel.weekTitle)
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
                        Button(action: {
                            if viewModel.viewMode == .day { viewModel.goToPreviousDay() }
                            else { viewModel.goToPreviousWeek() }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MPColors.primary)
                        }
                        Button(action: {
                            if viewModel.viewMode == .day { viewModel.goToNextDay() }
                            else { viewModel.goToNextWeek() }
                        }) {
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

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewModel.CalendarViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.viewMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(MPTypography.callout(viewModel.viewMode == mode ? .semibold : .regular))
                        .foregroundColor(viewModel.viewMode == mode ? .white : MPColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MPSpacing.sm)
                        .background(viewModel.viewMode == mode ? MPColors.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: MPRadius.sm))
                }
            }
        }
        .padding(3)
        .background(MPColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
    }

    // =========================================================================
    // MARK: - DAY VIEW — focused view of today's two meals
    // =========================================================================

    private var dayView: some View {
        ScrollView {
            VStack(spacing: MPSpacing.xl) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    dayMealCard(mealType: mealType)
                }
            }
            .padding(.horizontal, MPSpacing.xl)
            .padding(.top, MPSpacing.xl)
            .padding(.bottom, 100)
        }
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
                // Filled — rich recipe card
                dayFilledContent(recipe: recipe)
            } else {
                // Empty — add button
                dayEmptyContent(mealType: mealType)
            }
        }
        .background(MPAdaptiveColors.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
        .shadow(color: MPColors.shadow, radius: 8, x: 0, y: 2)
    }

    private func dayFilledContent(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: MPSpacing.md) {
            // Photo
            if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
                    .padding(.horizontal, MPSpacing.lg)
            }

            // Recipe info
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

                // Tags
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

                // Quick ingredient summary
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

    // =========================================================================
    // MARK: - WEEK VIEW — Google Calendar-inspired grid
    // =========================================================================

    private var weekView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Column headers (days)
                weekDayHeaders
                    .padding(.top, MPSpacing.lg)

                // Grid body — two rows (Lunch, Dinner)
                VStack(spacing: 0) {
                    weekMealRow(mealType: .lunch)
                    Divider().foregroundColor(MPColors.divider.opacity(0.5))
                    weekMealRow(mealType: .dinner)
                }
                .padding(.top, MPSpacing.sm)
            }
            .padding(.horizontal, MPSpacing.md)
            .padding(.bottom, 100)
        }
    }

    private var weekDayHeaders: some View {
        HStack(spacing: 0) {
            // Row label spacer
            Color.clear.frame(width: 52)

            ForEach(viewModel.currentWeekDates, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(viewModel.dayName(for: date))
                        .font(MPTypography.small(.medium))
                        .foregroundColor(
                            viewModel.isToday(date) ? MPColors.primary :
                            MPAdaptiveColors.textSecondary(for: colorScheme)
                        )
                    Text(viewModel.dayNumber(for: date))
                        .font(MPTypography.callout(viewModel.isToday(date) ? .bold : .medium))
                        .foregroundColor(viewModel.isToday(date) ? .white : MPAdaptiveColors.textPrimary(for: colorScheme))
                        .frame(width: 28, height: 28)
                        .background(viewModel.isToday(date) ? MPColors.primary : Color.clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekMealRow(mealType: MealType) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Row label
            Text(mealType == .lunch ? "L" : "D")
                .font(MPTypography.caption(.bold))
                .foregroundColor(mealType == .lunch ? MPColors.primaryLight : MPColors.primary)
                .frame(width: 52)
                .padding(.top, MPSpacing.lg)

            // Cells
            ForEach(viewModel.currentWeekDates, id: \.self) { date in
                weekCell(date: date, mealType: mealType)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, MPSpacing.xs)
    }

    private func weekCell(date: Date, mealType: MealType) -> some View {
        let meal = viewModel.mealForSlot(date: date, mealType: mealType, from: mealPlans)

        return Group {
            if let meal = meal, let recipe = meal.recipe {
                weekFilledCell(recipe: recipe, mealPlan: meal, date: date, mealType: mealType)
            } else {
                weekEmptyCell(date: date, mealType: mealType)
            }
        }
    }

    private func weekFilledCell(recipe: Recipe, mealPlan: MealPlan, date: Date, mealType: MealType) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Recipe thumbnail
            if let photoData = recipe.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 28)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Recipe name — always visible
            Text(recipe.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(mealType == .lunch ?
                    Color(hex: "1B5E20") : .white
                )
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 3)

            // Cook time
            if recipe.totalTime > 0 {
                Text(recipe.formattedTotalTime)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(mealType == .lunch ?
                        Color(hex: "1B5E20").opacity(0.7) :
                        Color.white.opacity(0.8)
                    )
                    .padding(.horizontal, 4)
                    .padding(.bottom, 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(mealType == .lunch ?
                    MPColors.primarySoft :
                    MPColors.primary.opacity(0.85)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            Button {
                viewModel.selectSlot(date: date, mealType: mealType)
            } label: {
                Label("Change Recipe", systemImage: "arrow.triangle.swap")
            }
            Button(role: .destructive) {
                viewModel.removeMeal(mealPlan, context: modelContext)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func weekEmptyCell(date: Date, mealType: MealType) -> some View {
        Button(action: {
            viewModel.selectSlot(date: date, mealType: mealType)
        }) {
            VStack {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MPColors.textTertiary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(MPColors.surfaceSecondary.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    .foregroundColor(MPColors.divider.opacity(0.5))
            )
        }
    }
}
