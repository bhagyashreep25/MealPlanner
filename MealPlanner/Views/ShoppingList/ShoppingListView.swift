import SwiftUI

struct ShoppingListView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MPSpacing.lg) {
            Spacer()
            MPEmptyState(
                icon: "cart",
                title: "Shopping List",
                subtitle: "Coming soon — generate shopping lists from your meal plan"
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MPAdaptiveColors.background(for: colorScheme))
    }
}
