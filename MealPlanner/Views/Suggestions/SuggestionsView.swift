import SwiftUI

struct SuggestionsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MPSpacing.lg) {
            Spacer()
            MPEmptyState(
                icon: "lightbulb",
                title: "Recipe Suggestions",
                subtitle: "Coming soon — enter ingredients you have and get recipe recommendations"
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MPAdaptiveColors.background(for: colorScheme))
    }
}
