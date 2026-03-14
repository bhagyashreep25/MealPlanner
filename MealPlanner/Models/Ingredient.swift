import Foundation
import SwiftData

@Model
final class Ingredient {
    var id: UUID
    var name: String
    var quantity: String // e.g. "2 cups", "1 tbsp"
    var recipe: Recipe?

    init(name: String, quantity: String = "") {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
    }
}
