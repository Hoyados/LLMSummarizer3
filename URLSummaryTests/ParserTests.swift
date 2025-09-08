import XCTest
@testable import LLMSummarizer3

final class ParserTests: XCTestCase {
    func test_parse_news_sample() throws {
        let html = """
        <html><head><title>News Title</title></head>
        <body>
          <header>menu</header>
          <article>
            <h1>Big Headline</h1>
            <p>First paragraph of content.</p>
            <p>Second paragraph with a <a href=\"/link\">link</a>.</p>
          </article>
          <footer>copyright</footer>
        </body>
        </html>
        """
        let parser = SwiftSoupContentParser()
        let out = try parser.extract(html: html, baseURL: URL(string: "https://example.com/news")!)
        XCTAssertEqual(out.title, "News Title")
        XCTAssertTrue(out.contentMarkdown.contains("Big Headline"))
        XCTAssertTrue(out.contentMarkdown.contains("[link](https://example.com/link)"))
    }

    func test_parse_empty_fails() {
        let html = "<html><body><div>no content</div></body></html>"
        let parser = SwiftSoupContentParser()
        XCTAssertThrowsError(try parser.extract(html: html, baseURL: URL(string: "https://e.com")!))
    }
}

