import Foundation
import SwiftSoup

final class SwiftSoupContentParser: ContentParser {
    func extract(html: String, baseURL: URL) throws -> ParsedArticle {
        do {
            let doc = try SwiftSoup.parse(html, baseURL.absoluteString)

            // Title
            let title = try doc.title().trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove unwanted tags
            try doc.select("script,style,noscript,nav,footer,header,aside").remove()

            // Candidate blocks
            let candidatesSelector = "article, main, section, div, p"
            let elements = try doc.select(candidatesSelector)

            var best: (Element, Double)?
            for el in elements.array() {
                let text = try el.text().trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count > 10 else { continue }

                let links = try el.select("a")
                let linkTextLen = try links.array().reduce(0) { $0 + (try $1.text()).count }
                let totalLen = text.count
                let linkDensity = totalLen > 0 ? Double(linkTextLen) / Double(totalLen) : 0

                let tagWeight: Double
                switch el.tagName().lowercased() {
                case "article": tagWeight = 3.0
                case "main": tagWeight = 2.5
                case "section": tagWeight = 2.0
                case "div": tagWeight = 1.0
                case "p": tagWeight = 0.5
                default: tagWeight = 1.0
                }

                let score = Double(totalLen) * tagWeight * (1.0 - min(linkDensity, 0.8))
                if best == nil || score > best!.1 { best = (el, score) }
            }

            guard let bestEl = best?.0 else { throw AppError.contentParseFailed }
            let markdown = try Self.toMarkdown(bestEl, baseURL: baseURL)
            guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppError.emptyContent }
            return ParsedArticle(title: title, contentMarkdown: markdown)
        } catch let err as AppError {
            throw err
        } catch {
            throw AppError.contentParseFailed
        }
    }

    private static func toMarkdown(_ root: Element, baseURL: URL) throws -> String {
        var lines: [String] = []
        try walk(node: root, baseURL: baseURL, lines: &lines, headingLevel: 0)
        // Collapse excessive blank lines
        var result: [String] = []
        var blank = false
        for l in lines {
            if l.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !blank { result.append("") }
                blank = true
            } else {
                result.append(l)
                blank = false
            }
        }
        return result.joined(separator: "\n")
    }

    private static func walk(node: Node, baseURL: URL, lines: inout [String], headingLevel: Int) throws {
        if let el = node as? Element {
            let name = el.tagName().lowercased()
            if name == "h1" || name == "h2" || name == "h3" || name == "h4" || name == "h5" || name == "h6" {
                let level = Int(String(name.dropFirst())) ?? 1
                let text = try el.text()
                lines.append(String(repeating: "#", count: max(1, level)) + " " + text)
                lines.append("")
                return
            }
            if name == "p" || name == "li" || name == "blockquote" {
                let text = try renderInline(el, baseURL: baseURL)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append(text)
                    lines.append("")
                }
                return
            }
            if name == "pre" || name == "code" { // code blocks
                let text = try el.text()
                lines.append("```\n\(text)\n```")
                lines.append("")
                return
            }
            // Traverse children
            for child in el.getChildNodes() {
                try walk(node: child, baseURL: baseURL, lines: &lines, headingLevel: headingLevel)
            }
        } else if let textNode = node as? TextNode {
            let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append(text) }
        }
    }

    private static func renderInline(_ el: Element, baseURL: URL) throws -> String {
        var output = ""
        for node in el.getChildNodes() {
            if let t = node as? TextNode {
                output += t.text()
            } else if let child = node as? Element {
                let name = child.tagName().lowercased()
                switch name {
                case "a":
                    let text = try child.text()
                    let href = try child.attr("href")
                    let url = URL(string: href, relativeTo: baseURL)?.absoluteString ?? href
                    output += "[\(text)](\(url))"
                case "strong", "b":
                    output += "**\(try child.text())**"
                case "em", "i":
                    output += "_\(try child.text())_"
                case "code":
                    output += "`\(try child.text())`"
                case "br":
                    output += "\n"
                default:
                    output += (try? child.text()) ?? ""
                }
            }
        }
        return output
    }
}
