import XCTest
@testable import LLMSummarizer3

final class URLFetcherDecodeTests: XCTestCase {
    func test_decode_from_http_header_charset() throws {
        // Given iso-8859-1 encoded data
        let html = "<html><body>Caf\u{E9}</body></html>" // Café
        let data = html.data(using: .isoLatin1)!
        let resp = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html; charset=iso-8859-1"]
        )!
        let decoded = DefaultURLFetcher.decodeHTML(data: data, response: resp)
        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded!.contains("Café"))
    }
}

