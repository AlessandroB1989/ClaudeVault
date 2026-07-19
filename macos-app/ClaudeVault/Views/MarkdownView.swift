import SwiftUI

/// Rendu Markdown natif (aucune dépendance tierce) : titres, paragraphes,
/// listes à puces/numérotées, citations, blocs de code, règles horizontales,
/// et formatage inline (gras, italique, code, liens) via AttributedString.
struct MarkdownView: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(MarkdownParser.parse(text).enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .textSelection(.enabled)
        }
    }

    // MARK: - Rendu d'un bloc

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 6 : 2)

        case .paragraph(let text):
            inline(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                inline(text).fixedSize(horizontal: false, vertical: true)
            }

        case .ordered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).").foregroundStyle(.secondary).monospacedDigit()
                inline(text).fixedSize(horizontal: false, vertical: true)
            }

        case .quote(let text):
            HStack(spacing: 8) {
                Rectangle().fill(.tint).frame(width: 3)
                inline(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .code(let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .textSelection(.enabled)

        case .rule:
            Divider().padding(.vertical, 4)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle.weight(.bold)
        case 2: return .title.weight(.semibold)
        case 3: return .title2.weight(.semibold)
        case 4: return .title3.weight(.semibold)
        case 5: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }

    /// Formatage inline (gras/italique/code/liens) via AttributedString.
    private func inline(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }
}

// MARK: - Parseur

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case ordered(number: Int, text: String)
    case quote(String)
    case code(String)
    case rule
}

enum MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.components(separatedBy: "\n")

        var paragraph: [String] = []
        var quote: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }
        func flushQuote() {
            if !quote.isEmpty {
                blocks.append(.quote(quote.joined(separator: " ")))
                quote.removeAll()
            }
        }
        func flushAll() { flushParagraph(); flushQuote() }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Bloc de code délimité par ```
            if trimmed.hasPrefix("```") {
                flushAll()
                var code: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.code(code.joined(separator: "\n")))
                i += 1 // saute le ``` de fermeture
                continue
            }

            // Ligne vide → fin de bloc
            if trimmed.isEmpty {
                flushAll()
                i += 1
                continue
            }

            // Règle horizontale
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushAll()
                blocks.append(.rule)
                i += 1
                continue
            }

            // Titre
            if let heading = parseHeading(trimmed) {
                flushAll()
                blocks.append(heading)
                i += 1
                continue
            }

            // Citation
            if trimmed.hasPrefix(">") {
                flushParagraph()
                let content = String(trimmed.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                quote.append(content)
                i += 1
                continue
            } else {
                flushQuote()
            }

            // Liste à puces
            if let bullet = parseBullet(trimmed) {
                flushParagraph()
                blocks.append(.bullet(bullet))
                i += 1
                continue
            }

            // Liste numérotée
            if let (n, txt) = parseOrdered(trimmed) {
                flushParagraph()
                blocks.append(.ordered(number: n, text: txt))
                i += 1
                continue
            }

            // Paragraphe
            paragraph.append(trimmed)
            i += 1
        }
        flushAll()
        return blocks
    }

    private static func parseHeading(_ s: String) -> MarkdownBlock? {
        var level = 0
        var idx = s.startIndex
        while idx < s.endIndex, s[idx] == "#", level < 6 {
            level += 1
            idx = s.index(after: idx)
        }
        guard level > 0, idx < s.endIndex, s[idx] == " " else { return nil }
        let text = String(s[idx...]).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    private static func parseBullet(_ s: String) -> String? {
        for marker in ["- ", "* ", "+ "] where s.hasPrefix(marker) {
            return String(s.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseOrdered(_ s: String) -> (Int, String)? {
        // "12. texte" ou "12) texte"
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        guard !digits.isEmpty, idx < s.endIndex,
              s[idx] == "." || s[idx] == ")" else { return nil }
        let afterPunct = s.index(after: idx)
        guard afterPunct < s.endIndex, s[afterPunct] == " " else { return nil }
        let text = String(s[afterPunct...]).trimmingCharacters(in: .whitespaces)
        return (Int(digits) ?? 0, text)
    }
}
