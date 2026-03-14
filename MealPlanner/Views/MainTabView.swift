import SwiftUI
import SwiftData

enum TabItem: Int, CaseIterable {
    case recipes, calendar, suggestions, shopping

    var title: String {
        switch self {
        case .recipes: return "Recipes"
        case .calendar: return "Calendar"
        case .suggestions: return "Suggest"
        case .shopping: return "Shopping"
        }
    }

    var icon: String {
        switch self {
        case .recipes: return "book"
        case .calendar: return "calendar"
        case .suggestions: return "lightbulb"
        case .shopping: return "cart"
        }
    }

    var iconFilled: String {
        switch self {
        case .recipes: return "book.fill"
        case .calendar: return "calendar"
        case .suggestions: return "lightbulb.fill"
        case .shopping: return "cart.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: TabItem = .recipes
    @State private var viewModel = RecipeViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .recipes:
                    RecipeListView(viewModel: viewModel)
                case .calendar:
                    CalendarView()
                case .suggestions:
                    SuggestionsView()
                case .shopping:
                    ShoppingListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, MPSpacing.sm)
        .padding(.top, MPSpacing.md)
        .padding(.bottom, MPSpacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: TabItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: MPSpacing.xs) {
                Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? MPColors.primary : MPColors.textTertiary)
                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)

                Text(tab.title)
                    .font(MPTypography.small(selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? MPColors.primary : MPColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MPSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self, ShoppingItem.self], inMemory: true)
}
