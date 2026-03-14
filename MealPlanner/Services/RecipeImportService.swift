import Foundation
import Vision
import UIKit

struct ParsedRecipe {
    var name: String = ""
    var ingredients: [(name: String, quantity: String)] = []
    var steps: [String] = []
    var prepTime: Int = 0
    var cookTime: Int = 0
    var servings: Int = 1
    var tags: [String] = []
    var sourceURL: String? = nil
    var imageURL: String? = nil
}

actor RecipeImportService {

    // MARK: - URL Import

    func parseFromURL(_ urlString: String) async throws -> ParsedRecipe {
        guard let url = URL(string: urlString) else {
            throw ImportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw ImportError.parseError("Could not read page content")
        }

        // Try JSON-LD first (most recipe sites use this)
        if var recipe = parseJSONLD(from: html, sourceURL: urlString) {
            // If JSON-LD found a recipe but steps are empty, try HTML fallback for steps only
            if recipe.steps.isEmpty {
                let htmlParsed = parseHeuristic(from: html, sourceURL: urlString)
                recipe.steps = htmlParsed.steps
            }
            return recipe
        }

        // Fallback: heuristic HTML parsing
        return parseHeuristic(from: html, sourceURL: urlString)
    }

    // MARK: - JSON-LD Parsing (schema.org Recipe)

    private func parseJSONLD(from html: String, sourceURL: String) -> ParsedRecipe? {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let jsonData = jsonString.data(using: .utf8) else { continue }

            if let recipe = tryParseRecipeJSON(jsonData, sourceURL: sourceURL) {
                return recipe
            }
        }

        return nil
    }

    private func tryParseRecipeJSON(_ data: Data, sourceURL: String) -> ParsedRecipe? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let candidates: [[String: Any]]
        if let obj = json as? [String: Any] {
            candidates = findRecipeObjects(in: obj)
        } else if let arr = json as? [[String: Any]] {
            candidates = arr.flatMap { findRecipeObjects(in: $0) }
        } else {
            return nil
        }

        guard let recipe = candidates.first else { return nil }
        return extractRecipe(from: recipe, sourceURL: sourceURL)
    }

    private func findRecipeObjects(in obj: [String: Any]) -> [[String: Any]] {
        let typeValue = obj["@type"]
        var isRecipe = false

        if let typeStr = typeValue as? String {
            isRecipe = typeStr.lowercased() == "recipe"
        } else if let typeArr = typeValue as? [String] {
            isRecipe = typeArr.contains { $0.lowercased() == "recipe" }
        }

        if isRecipe { return [obj] }

        if let graph = obj["@graph"] as? [[String: Any]] {
            return graph.filter { item in
                if let t = item["@type"] as? String { return t.lowercased() == "recipe" }
                if let t = item["@type"] as? [String] { return t.contains { $0.lowercased() == "recipe" } }
                return false
            }
        }

        return []
    }

    private func extractRecipe(from json: [String: Any], sourceURL: String) -> ParsedRecipe {
        var parsed = ParsedRecipe()
        parsed.sourceURL = sourceURL

        parsed.name = decodeHTML(json["name"] as? String ?? "")

        // Ingredients
        if let ingredients = json["recipeIngredient"] as? [String] {
            parsed.ingredients = ingredients.map { raw in
                let decoded = decodeHTML(raw)
                let parts = splitIngredient(decoded)
                return (name: parts.name, quantity: parts.quantity)
            }
        }

        // Steps
        parsed.steps = extractInstructions(from: json["recipeInstructions"])

        // Times
        parsed.prepTime = parseDuration(json["prepTime"])
        parsed.cookTime = parseDuration(json["cookTime"])
        if parsed.cookTime == 0 {
            let total = parseDuration(json["totalTime"])
            if total > parsed.prepTime {
                parsed.cookTime = total - parsed.prepTime
            }
        }

        // Servings
        if let yield = json["recipeYield"] as? String {
            parsed.servings = extractNumber(from: yield) ?? 1
        } else if let yield = json["recipeYield"] as? [String], let first = yield.first {
            parsed.servings = extractNumber(from: first) ?? 1
        } else if let yield = json["recipeYield"] as? Int {
            parsed.servings = yield
        }

        // Tags
        for key in ["recipeCategory", "recipeCuisine"] {
            if let val = json[key] as? String {
                parsed.tags.append(decodeHTML(val))
            } else if let arr = json[key] as? [String] {
                parsed.tags.append(contentsOf: arr.map { decodeHTML($0) })
            }
        }

        // Image URL
        if let img = json["image"] as? String {
            parsed.imageURL = img
        } else if let img = json["image"] as? [String], let first = img.first {
            parsed.imageURL = first
        } else if let img = json["image"] as? [String: Any] {
            parsed.imageURL = img["url"] as? String
        } else if let arr = json["image"] as? [[String: Any]], let first = arr.first {
            parsed.imageURL = first["url"] as? String
        }

        return parsed
    }

    // MARK: - Instruction Extraction

    private func extractInstructions(from value: Any?) -> [String] {
        guard let value = value else { return [] }

        // Single HTML string — split on <li>, <p>, <br>, or newlines
        if let str = value as? String {
            return parseInstructionString(str)
        }

        // Array of plain strings
        if let arr = value as? [String] {
            return arr.flatMap { parseInstructionString($0) }
        }

        // Array of objects
        if let arr = value as? [[String: Any]] {
            var steps: [String] = []
            for item in arr {
                steps.append(contentsOf: extractStepFromObject(item))
            }
            return steps
        }

        // Single object
        if let obj = value as? [String: Any] {
            return extractStepFromObject(obj)
        }

        return []
    }

    private func parseInstructionString(_ str: String) -> [String] {
        let decoded = decodeHTML(str)
        // Split on HTML block elements first
        var text = decoded
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</li>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</p>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</div>"#, with: "\n", options: [.regularExpression, .caseInsensitive])

        // Strip remaining HTML tags
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .filter { $0.count > 3 }
    }

    private func extractStepFromObject(_ item: [String: Any]) -> [String] {
        let itemType = (item["@type"] as? String)?.lowercased() ?? ""

        // HowToSection — recurse into itemListElement
        if itemType == "howtosection" {
            if let subItems = item["itemListElement"] {
                return extractInstructions(from: subItems)
            }
            return []
        }

        // Has itemListElement without being a HowToSection
        if let subItems = item["itemListElement"] {
            return extractInstructions(from: subItems)
        }

        // Direct step — try text, then description, then name
        for key in ["text", "description", "name"] {
            if let text = item[key] as? String {
                let steps = parseInstructionString(text)
                if !steps.isEmpty { return steps }
            }
        }

        return []
    }

    // MARK: - Heuristic HTML Parsing (fallback)

    private func parseHeuristic(from html: String, sourceURL: String) -> ParsedRecipe {
        var parsed = ParsedRecipe()
        parsed.sourceURL = sourceURL

        // Extract title
        if let titleMatch = html.range(of: #"<title[^>]*>(.*?)</title>"#, options: .regularExpression) {
            parsed.name = stripHTML(String(html[titleMatch]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " | ").first?
                .components(separatedBy: " - ").first ?? ""
        }

        // Strategy: find instruction blocks by many common patterns
        let instructionPatterns = [
            // WPRM (WP Recipe Maker) - very common
            #"class\s*=\s*["'][^"']*wprm-recipe-instruction[^"']*["'][^>]*>([\s\S]*?)</(?:div|section|ol|ul)"#,
            // Tasty Recipes plugin
            #"class\s*=\s*["'][^"']*tasty-recipe[s]?-instructions[^"']*["'][^>]*>([\s\S]*?)</(?:div|section)"#,
            // Generic class patterns
            #"class\s*=\s*["'][^"']*(?:recipe-instruction|recipe-direction|recipe-step|recipe-method)[^"']*["'][^>]*>([\s\S]*?)</(?:div|section|ol|ul)"#,
            #"class\s*=\s*["'][^"']*(?:instruction|direction)[s]?[^"']*["'][^>]*>([\s\S]*?)</(?:div|section|ol|ul)"#,
            // Ordered lists containing step content (broader)
            #"<ol[^>]*>([\s\S]*?)</ol>"#
        ]

        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let block = String(html[range])
                        let steps = parseInstructionString(block)
                        if steps.count >= 2 {
                            parsed.steps = steps
                            break
                        }
                    }
                }
                if !parsed.steps.isEmpty { break }
            }
        }

        // If still empty, try extracting all <li> items that are long enough to be steps
        if parsed.steps.isEmpty {
            let liPattern = #"<li[^>]*>([\s\S]*?)</li>"#
            if let regex = try? NSRegularExpression(pattern: liPattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                var candidates: [String] = []
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let text = stripHTML(decodeHTML(String(html[range])))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.count > 20 && text.count < 500 {
                            candidates.append(text)
                        }
                    }
                }
                // If we found a decent number of long <li> items, they're likely steps
                if candidates.count >= 3 {
                    parsed.steps = candidates
                }
            }
        }

        // Try to find ingredients by common class names
        let ingredientPatterns = [
            #"class\s*=\s*["'][^"']*(?:wprm-recipe-ingredient|tasty-recipe[s]?-ingredient|recipe-ingredient|ingredient)[^"']*["'][^>]*>([\s\S]*?)</(?:div|section|ul|ol)"#
        ]

        for pattern in ingredientPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let block = stripHTML(String(html[range]))
                        let lines = block.components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { $0.count > 2 && $0.count < 120 }
                        for line in lines {
                            let parts = splitIngredient(line)
                            parsed.ingredients.append((name: parts.name, quantity: parts.quantity))
                        }
                    }
                }
            }
        }

        return parsed
    }

    // MARK: - OCR Import

    func parseFromImage(_ image: UIImage) async throws -> ParsedRecipe {
        guard let cgImage = image.cgImage else {
            throw ImportError.parseError("Could not process image")
        }

        let text = try await recognizeText(in: cgImage)
        return parseOCRText(text)
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - OCR Text Parsing

    private func parseOCRText(_ text: String) -> ParsedRecipe {
        var parsed = ParsedRecipe()
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return parsed }

        // First non-empty line is likely the recipe name
        parsed.name = lines.first ?? ""

        enum Section { case none, ingredients, directions }
        var currentSection: Section = .none

        // Only these explicit headers change sections — NO auto-switching
        let ingredientHeaders = ["ingredients", "ingredient list", "ingredient"]
        let directionHeaders = ["directions", "direction", "instructions", "instruction",
                                "method", "methods", "preparation", "how to make",
                                "how to cook", "procedure", "steps"]

        for line in lines.dropFirst() {
            let lower = line.lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if this line is a section header (short line matching a keyword)
            if line.count < 40 {
                if ingredientHeaders.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
                    currentSection = .ingredients
                    continue
                }
                if directionHeaders.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
                    currentSection = .directions
                    continue
                }
            }

            // Classify lines based on current section
            switch currentSection {
            case .ingredients:
                // Skip ingredient sub-headers like "Fettuccine Pasta", "Creamy Beans", "Vegan Alfredo Sauce"
                // These are short, don't start with a number/fraction, and are typically Title Case
                if isIngredientSubHeader(line) {
                    continue
                }
                if line.count > 2 && line.count < 150 {
                    // If this line doesn't start with a quantity, it's a continuation
                    // of the previous ingredient (OCR split a long line)
                    if !startsWithQuantity(line) && !parsed.ingredients.isEmpty {
                        let lastIndex = parsed.ingredients.count - 1
                        parsed.ingredients[lastIndex].name += " " + line
                    } else {
                        let parts = splitIngredient(line)
                        parsed.ingredients.append((name: parts.name, quantity: parts.quantity))
                    }
                }

            case .directions:
                // Skip "Notes" section header and everything after
                if line.count < 20 && (lower == "notes" || lower == "note" || lower.hasPrefix("nutrition")) {
                    break
                }
                if line.count > 3 {
                    let cleaned = cleanStepText(line)
                    if !cleaned.isEmpty {
                        // If this line is NOT a numbered step (no "1.", "2." prefix),
                        // it's a continuation of the previous step — merge it
                        if !isNumberedStep(line) && !parsed.steps.isEmpty {
                            let lastIndex = parsed.steps.count - 1
                            parsed.steps[lastIndex] += " " + cleaned
                        } else {
                            parsed.steps.append(cleaned)
                        }
                    }
                }

            case .none:
                // Before any section header, try to auto-detect
                if startsWithQuantity(line) && line.count < 120 {
                    currentSection = .ingredients
                    let parts = splitIngredient(line)
                    parsed.ingredients.append((name: parts.name, quantity: parts.quantity))
                } else if isNumberedStep(line) {
                    currentSection = .directions
                    let cleaned = cleanStepText(line)
                    if !cleaned.isEmpty {
                        parsed.steps.append(cleaned)
                    }
                }
            }
        }

        return parsed
    }

    /// Check if line starts with a quantity (number, fraction, or measurement)
    private func startsWithQuantity(_ line: String) -> Bool {
        return line.range(of: #"^[\d½¼¾⅓⅔⅛⅜⅝⅞]"#, options: .regularExpression) != nil
    }

    /// Check if line is a numbered direction step like "1. Add the...", "2) Cook..."
    private func isNumberedStep(_ line: String) -> Bool {
        return line.range(of: #"^\d+[\.\)]\s+\w"#, options: .regularExpression) != nil && line.count > 15
    }

    /// Ingredient sub-headers like "Fettuccine Pasta", "Vegan Alfredo Sauce", "For the filling"
    /// Short lines that don't start with a quantity and aren't section headers
    private func isIngredientSubHeader(_ line: String) -> Bool {
        // Must be short-ish
        guard line.count < 50 else { return false }
        // Must NOT start with a number or fraction (those are actual ingredients)
        guard !startsWithQuantity(line) else { return false }
        // Must NOT look like an ingredient (no quantity words)
        let lower = line.lowercased()
        let hasUnit = ["cup", "tbsp", "tsp", "oz", "lb", "gram", "ml", "clove", "can", "pinch", "dash"]
            .contains(where: { lower.contains($0) })
        if hasUnit { return false }
        // Likely a sub-header: short text, often Title Case
        return line.count < 40 && !line.contains(",")
    }

    /// Strip leading step numbers/bullets from direction text
    private func cleanStepText(_ line: String) -> String {
        line.replacingOccurrences(of: #"^[\d\.\)\-\•\*]+\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func splitIngredient(_ raw: String) -> (name: String, quantity: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[\-\•\*]+\s*"#, with: "", options: .regularExpression)

        let quantityPattern = #"^([\d½¼¾⅓⅔⅛⅜⅝⅞\s\/\.]+\s*(?:cups?|tbsp|tsp|Tbsp|Tsp|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|grams?|g|kg|ml|liters?|l|cloves?|cans?|pieces?|slices?|bunch|bunches|pinch|dash|handful|large|medium|small|whole)?)\s+(.+)"#
        if let regex = try? NSRegularExpression(pattern: quantityPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let qty = Range(match.range(at: 1), in: trimmed).map { String(trimmed[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
            let name = Range(match.range(at: 2), in: trimmed).map { String(trimmed[$0]).trimmingCharacters(in: .whitespaces) } ?? trimmed
            if !qty.isEmpty && !name.isEmpty {
                return (name: name, quantity: qty)
            }
        }

        return (name: trimmed, quantity: "")
    }

    private func extractNumber(from string: String) -> Int? {
        let digits = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }

    private func parseDuration(_ value: Any?) -> Int {
        guard let str = value as? String else { return 0 }
        var minutes = 0
        if let hourMatch = str.range(of: #"(\d+)H"#, options: .regularExpression) {
            let numStr = str[hourMatch].replacingOccurrences(of: "H", with: "")
            minutes += (Int(numStr) ?? 0) * 60
        }
        if let minMatch = str.range(of: #"(\d+)M"#, options: .regularExpression) {
            let numStr = str[minMatch].replacingOccurrences(of: "M", with: "")
            minutes += Int(numStr) ?? 0
        }
        return minutes
    }

    private func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    // MARK: - HTML Entity Decoding

    private func decodeHTML(_ string: String) -> String {
        var result = string

        // Numeric entities (&#189; &#8531;)
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let numRange = Range(match.range(at: 1), in: result),
                      let codePoint = UInt32(String(result[numRange])),
                      let scalar = Unicode.Scalar(codePoint) else { continue }
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }

        // Hex entities (&#x00BD;)
        let hexPattern = #"&#x([0-9A-Fa-f]+);"#
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let hexRange = Range(match.range(at: 1), in: result),
                      let codePoint = UInt32(String(result[hexRange]), radix: 16),
                      let scalar = Unicode.Scalar(codePoint) else { continue }
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }

        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
            "&frac12;": "½", "&frac13;": "⅓", "&frac14;": "¼",
            "&frac34;": "¾", "&frac23;": "⅔", "&frac18;": "⅛",
            "&deg;": "°"
        ]
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }
}

// MARK: - Errors

enum ImportError: LocalizedError {
    case invalidURL
    case parseError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Please enter a valid URL"
        case .parseError(let msg): return msg
        case .networkError(let msg): return msg
        }
    }
}
