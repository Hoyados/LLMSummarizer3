import Foundation

protocol ContentParser {
    func extract(html: String, baseURL: URL) throws -> ParsedArticle
}

struct ParsedArticle: Equatable {
    let title: String
    let contentMarkdown: String
}

