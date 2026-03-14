import SwiftUI
import SwiftData

@Observable
class CalendarViewModel {
    var selectedDate: Date = Date()
    var viewMode: CalendarViewMode = .day
    var showingRecipePicker = false
    var selectedMealSlot: MealSlot? = nil

    enum CalendarViewMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
    }

    struct MealSlot: Equatable {
        let date: Date
        let mealType: MealType
    }

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    var currentWeekDates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    var weekTitle: String {
        let dates = currentWeekDates
        guard let first = dates.first, let last = dates.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        if calendar.component(.month, from: first) == calendar.component(.month, from: last) {
            endFormatter.dateFormat = "d, yyyy"
        } else {
            endFormatter.dateFormat = "MMM d, yyyy"
        }
        return "\(formatter.string(from: first)) – \(endFormatter.string(from: last))"
    }

    func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    // MARK: - Navigation

    func goToPreviousDay() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    func goToNextDay() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
    }

    func goToPreviousWeek() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    func goToNextWeek() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        }
    }

    func goToToday() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = Date()
        }
    }

    // MARK: - Meal Plan Operations

    func mealsForDate(_ date: Date, from mealPlans: [MealPlan]) -> [MealPlan] {
        mealPlans.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func mealForSlot(date: Date, mealType: MealType, from mealPlans: [MealPlan]) -> MealPlan? {
        mealPlans.first { plan in
            Calendar.current.isDate(plan.date, inSameDayAs: date) && plan.mealType == mealType
        }
    }

    func selectSlot(date: Date, mealType: MealType) {
        selectedMealSlot = MealSlot(date: date, mealType: mealType)
        showingRecipePicker = true
    }

    func assignRecipe(_ recipe: Recipe, to slot: MealSlot, context: ModelContext) {
        let descriptor = FetchDescriptor<MealPlan>()
        if let existing = try? context.fetch(descriptor).first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: slot.date) && $0.mealType == slot.mealType
        }) {
            context.delete(existing)
        }

        let mealPlan = MealPlan(date: slot.date, mealType: slot.mealType, recipe: recipe)
        context.insert(mealPlan)
        try? context.save()
    }

    func removeMeal(_ mealPlan: MealPlan, context: ModelContext) {
        context.delete(mealPlan)
        try? context.save()
    }
}
