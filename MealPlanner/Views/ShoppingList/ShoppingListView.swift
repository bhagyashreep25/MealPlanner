import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @State private var viewModel = ShoppingListViewModel()
    @Query private var shoppingItems: [ShoppingItem]
    @Query private var mealPlans: [MealPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private var uncheckedCount: Int {
        shoppingItems.filter { !$0.isChecked }.count
    }

    private var checkedCount: Int {
        shoppingItems.filter { $0.isChecked }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, MPSpacing.xl)
                    .padding(.top, MPSpacing.md)

                if shoppingItems.isEmpty {
                    Spacer()
                    MPEmptyState(
                        icon: "cart",
                        title: "Shopping list is empty",
                        subtitle: "Tap the buttons below to get started"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: MPSpacing.lg) {
                            ForEach(viewModel.groupedItems(shoppingItems), id: \.category) { group in
                                categorySection(group.category, items: group.items)
                            }
                        }
                        .padding(.horizontal, MPSpacing.xl)
                        .padding(.top, MPSpacing.lg)
                        .padding(.bottom, 140)
                    }
                }
            }

            // Bottom action buttons
            bottomButtons
        }
        .background(MPAdaptiveColors.background(for: colorScheme))
        .sheet(isPresented: $viewModel.showingAddItem) {
            addItemSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: MPSpacing.xs) {
            HStack {
                Text("Shopping List")
                    .font(MPTypography.largeTitle())
                    .foregroundColor(MPAdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
                if checkedCount > 0 {
                    Button(action: {
                        withAnimation {
                            viewModel.clearChecked(shoppingItems, context: modelContext)
                        }
                    }) {
                        HStack(spacing: MPSpacing.xs) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                            Text("Clear Done")
                                .font(MPTypography.caption(.medium))
                        }
                        .foregroundColor(MPColors.error.opacity(0.8))
                    }
                }
            }

            if !shoppingItems.isEmpty {
                Text("\(uncheckedCount) item\(uncheckedCount == 1 ? "" : "s") remaining")
                    .font(MPTypography.callout())
                    .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: MPSpacing.md) {
            Button(action: { viewModel.showingAddItem = true }) {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Item")
                        .font(MPTypography.callout(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MPSpacing.md + 2)
                .background(MPColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.xl))
            }

            Button(action: {
                viewModel.generateFromMealPlan(
                    mealPlans: mealPlans,
                    existingItems: shoppingItems,
                    context: modelContext
                )
            }) {
                HStack(spacing: MPSpacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                    Text("From Plan")
                        .font(MPTypography.callout(.semibold))
                }
                .foregroundColor(MPColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MPSpacing.md + 2)
                .background(MPColors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: MPRadius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: MPRadius.xl)
                        .stroke(MPColors.primary.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, MPSpacing.xl)
        .padding(.top, MPSpacing.md)
        .padding(.bottom, 72)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Category Section

    private func categorySection(_ category: String, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: MPSpacing.sm) {
            // Category header
            HStack(spacing: MPSpacing.sm) {
                Image(systemName: categoryIcon(category))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MPColors.primary)
                Text(category)
                    .font(MPTypography.caption(.bold))
                    .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                    .textCase(.uppercase)
                    .tracking(0.5)

                let remaining = items.filter { !$0.isChecked }.count
                if remaining < items.count {
                    Text("\(remaining)/\(items.count)")
                        .font(MPTypography.small())
                        .foregroundColor(MPColors.textTertiary)
                }
            }

            // Items
            VStack(spacing: 0) {
                ForEach(items) { item in
                    shoppingItemRow(item)

                    if item.id != items.last?.id {
                        Divider()
                            .foregroundColor(MPColors.divider.opacity(0.5))
                            .padding(.leading, 44)
                    }
                }
            }
            .background(MPAdaptiveColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
            .shadow(color: MPColors.shadow, radius: 4, x: 0, y: 1)
        }
    }

    private func shoppingItemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: MPSpacing.md) {
            // Checkbox
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleItem(item, context: modelContext)
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(item.isChecked ? MPColors.primary : MPColors.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if item.isChecked {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(MPColors.primary)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Name & quantity
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(MPTypography.body(item.isChecked ? .regular : .medium))
                    .foregroundColor(
                        item.isChecked
                        ? MPAdaptiveColors.textSecondary(for: colorScheme)
                        : MPAdaptiveColors.textPrimary(for: colorScheme)
                    )
                    .strikethrough(item.isChecked, color: MPColors.textTertiary)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(MPTypography.small())
                        .foregroundColor(MPColors.textTertiary)
                }
            }

            Spacer()

            // Delete
            Button(action: {
                withAnimation {
                    viewModel.deleteItem(item, context: modelContext)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MPColors.textTertiary)
                    .padding(MPSpacing.sm)
            }
        }
        .padding(.horizontal, MPSpacing.md)
        .padding(.vertical, MPSpacing.sm + 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleItem(item, context: modelContext)
            }
        }
    }

    // MARK: - Add Item Sheet

    private var addItemSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MPSpacing.xl) {
                VStack(alignment: .leading, spacing: MPSpacing.md) {
                    Text("ITEM NAME")
                        .font(MPTypography.caption(.semibold))
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                        .tracking(0.5)
                    MPTextField(placeholder: "e.g. Basmati Rice", text: $viewModel.newItemName)
                }

                VStack(alignment: .leading, spacing: MPSpacing.md) {
                    Text("QUANTITY (OPTIONAL)")
                        .font(MPTypography.caption(.semibold))
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                        .tracking(0.5)
                    MPTextField(placeholder: "e.g. 1 kg", text: $viewModel.newItemQuantity)
                }

                VStack(alignment: .leading, spacing: MPSpacing.md) {
                    Text("CATEGORY")
                        .font(MPTypography.caption(.semibold))
                        .foregroundColor(MPAdaptiveColors.textSecondary(for: colorScheme))
                        .tracking(0.5)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MPSpacing.sm) {
                            ForEach(viewModel.defaultCategories, id: \.self) { category in
                                MPChip(
                                    label: category,
                                    isSelected: viewModel.newItemCategory == category
                                ) {
                                    viewModel.newItemCategory = category
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, MPSpacing.xl)
            .padding(.top, MPSpacing.lg)
            .background(MPAdaptiveColors.background(for: colorScheme))
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.showingAddItem = false }
                        .foregroundColor(MPColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { viewModel.addItem(context: modelContext) }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(
                            viewModel.newItemName.isEmpty ? MPColors.textTertiary : MPColors.primary
                        )
                        .disabled(viewModel.newItemName.isEmpty)
                }
            }
        }
    }

    // MARK: - Category Icons

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Produce": return "leaf"
        case "Dairy": return "cup.and.saucer"
        case "Meat & Seafood": return "fish"
        case "Grains & Bread": return "birthday.cake"
        case "Spices & Seasonings": return "flame"
        case "Canned & Packaged": return "shippingbox"
        case "Frozen": return "snowflake"
        case "Beverages": return "waterbottle"
        case "Snacks": return "popcorn"
        case "Ingredients": return "fork.knife"
        default: return "bag"
        }
    }
}
