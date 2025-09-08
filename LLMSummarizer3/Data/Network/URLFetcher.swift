import Foundation

protocol URLFetcher {
    func fetch(url: URL) async throws -> String
}

final class DefaultURLFetcher: URLFetcher {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AppError.network(NSError(domain: "no_http", code: -1)) }
            guard 200..<300 ~= http.statusCode else { throw AppError.httpStatus(http.statusCode) }

            if let html = Self.decodeHTML(data: data, response: http) {
                Telemetry.shared.logEvent(.fetchFinished, props: [
                    .urlDomain: url.host ?? "",
                    .durationMs: String(Int(Date().timeIntervalSince(start) * 1000)),
                    .chars: String(html.count)
                ])
                return html
            } else {
                throw AppError.charsetDetectionFailed
            }
        } catch {
            Telemetry.shared.logEvent(.fetchFailed, props: [
                .urlDomain: url.host ?? "",
                .errorCode: String((error as NSError).code)
            ])
            throw AppError.network(error)
        }
    }

    static func decodeHTML(data: Data, response: HTTPURLResponse) -> String? {
        // 1) BOM detection
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return String(data: data, encoding: .utf8) }
        if data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16BigEndian) }
        if data.starts(with: [0xFF, 0xFE]) { return String(data: data, encoding: .utf16LittleEndian) }

        // 2) HTTP header charset
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           let charset = contentType.split(separator: ";")
               .map({ $0.trimmingCharacters(in: .whitespaces) })
               .first(where: { $0.lowercased().starts(with: "charset=") })?
               .split(separator: "=").last {
            let enc = String(charset).trimmingCharacters(in: .whitespacesAndNewlines) as CFString
            let cfEnc = CFStringConvertIANACharSetNameToEncoding(enc)
            if cfEnc != kCFStringEncodingInvalidId {
                let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
                return String(data: data, encoding: String.Encoding(rawValue: nsEnc))
            }
        }

        // 3) meta charset
        if let ascii = String(data: data.prefix(4096), encoding: .ascii) {
            if let range = ascii.range(of: "charset=", options: .caseInsensitive) {
                let after = ascii[range.upperBound...]
                let end = after.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "." }) ?? after.endIndex
                let encName = String(after[..<end]) as CFString
                let cfEnc = CFStringConvertIANACharSetNameToEncoding(encName)
                if cfEnc != kCFStringEncodingInvalidId {
                    let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
                    return String(data: data, encoding: String.Encoding(rawValue: nsEnc))
                }
            }
        }

        // 4) fallback UTF-8
        return String(data: data, encoding: .utf8)
    }
}
