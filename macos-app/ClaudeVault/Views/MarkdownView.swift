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

        case .task(let checked, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                inline(text)
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .table(let header, let rows):
            tableView(header: header, rows: rows)

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

    @ViewBuilder
    private func tableView(header: [String], rows: [[String]]) -> some View {
        let cols = max(header.count, 1)
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                GridRow {
                    ForEach(header.indices, id: \.self) { c in
                        inline(header[c]).bold()
                    }
                }
                Divider().gridCellColumns(cols)
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { c in
                            inline(c < rows[r].count ? rows[r][c] : "")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
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
    case task(checked: Bool, text: String)
    case quote(String)
    case code(String)
    case table(header: [String], rows: [[String]])
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

            // Tableau (GFM) : ligne d'en-tête « | … | » suivie d'une séparatrice.
            if trimmed.contains("|"), i + 1 < lines.count, isSeparatorRow(lines[i + 1]) {
                flushAll()
                let header = splitRow(trimmed)
                var rows: [[String]] = []
                i += 2 // saute en-tête + séparatrice
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.isEmpty || !t.contains("|") { break }
                    rows.append(splitRow(t))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
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

            // Case à cocher (avant les puces : "- [ ] …" / "- [x] …")
            if let task = parseTask(trimmed) {
                flushParagraph()
                blocks.append(.task(checked: task.0, text: task.1))
                i += 1
                continue
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

    private static func parseTask(_ s: String) -> (Bool, String)? {
        for marker in ["- ", "* ", "+ "] where s.hasPrefix(marker) {
            let rest = String(s.dropFirst(marker.count))
            let lower = rest.lowercased()
            if lower.hasPrefix("[ ]") {
                return (false, String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces))
            }
            if lower.hasPrefix("[x]") {
                return (true, String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    private static func parseBullet(_ s: String) -> String? {
        for marker in ["- ", "* ", "+ "] where s.hasPrefix(marker) {
            return String(s.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Découpe une ligne de tableau en cellules (retire les « | » externes).
    private static func splitRow(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Vrai si la ligne est une séparatrice de tableau (ex. "| --- | :--: |").
    private static func isSeparatorRow(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("|"), t.contains("-") else { return false }
        let cells = splitRow(t)
        guard !cells.isEmpty else { return false }
        for c in cells {
            let cc = c.trimmingCharacters(in: .whitespaces)
            if cc.isEmpty || !cc.allSatisfy({ $0 == "-" || $0 == ":" }) { return false }
        }
        return true
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
