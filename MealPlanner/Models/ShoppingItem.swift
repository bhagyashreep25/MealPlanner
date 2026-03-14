import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var quantity: String
    var category: String
    var isChecked: Bool

    init(name: String, quantity: String = "", category: String = "Other", isChecked: Bool = false) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.category = category
        self.isChecked = isChecked
    }
}
