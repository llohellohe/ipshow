import Foundation

struct GeoInfo {
    var country: String?
    var countryCode: String?
    var region: String?
    var city: String?
    var isp: String?
    var asn: String?
    var isProxy: Bool
    var isHosting: Bool
}

/// 多-Provider 归属地查询服务。请求强制走"直连通道"，避免被系统代理污染。
/// 查询 provider 由上层传入，本服务不做自动 fallback —— 失败时由用户在 UI 上手动切换其它源。
actor GeoLookupService {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.connectionProxyDictionary = [:]
        self.session = URLSession(configuration: config)
    }

    func lookup(ip: String, via provider: GeoProvider) async -> GeoInfo? {
        switch provider {
        case .ipApi:   return await viaIPAPI(ip: ip)
        case .ipApiIs: return await viaIPAPIIs(ip: ip)
        case .ipWhoIs: return await viaIPWhoIs(ip: ip)
        case .ipSb:    return await viaIPSB(ip: ip)
        case .ipInfo:  return await viaIPInfo(ip: ip)
        }
    }

    // MARK: - Helpers

    private func get(_ urlString: String, userAgent: String? = nil) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent {
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    /// 将 ISO 国家代码转为当前 Locale 下的国家全名（中文环境会转为中文名）。
    private func countryName(fromCode code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    // MARK: - 1. ip-api.com (HTTP)

    private struct IPAPIResp: Codable {
        let status: String
        let country: String?
        let countryCode: String?
        let regionName: String?
        let city: String?
        let isp: String?
        let asField: String?
        let proxy: Bool?
        let hosting: Bool?
        enum CodingKeys: String, CodingKey {
            case status, country, countryCode, regionName, city, isp, proxy, hosting
            case asField = "as"
        }
    }

    private func viaIPAPI(ip: String) async -> GeoInfo? {
        let fields = "status,country,countryCode,regionName,city,isp,as,proxy,hosting"
        guard let data = await get("http://ip-api.com/json/\(ip)?fields=\(fields)") else { return nil }
        guard let r = try? JSONDecoder().decode(IPAPIResp.self, from: data),
              r.status == "success" else { return nil }
        return GeoInfo(
            country: r.country, countryCode: r.countryCode,
            region: r.regionName, city: r.city,
            isp: r.isp, asn: r.asField,
            isProxy: r.proxy ?? false, isHosting: r.hosting ?? false
        )
    }

    // MARK: - 2. ipapi.is (HTTPS)

    private struct IPAPIIsResp: Codable {
        let is_proxy: Bool?
        let is_vpn: Bool?
        let is_tor: Bool?
        let is_datacenter: Bool?
        let asn: ASN?
        let company: Company?
        let location: Location?
        struct ASN: Codable { let asn: Int?; let org: String?; let route: String? }
        struct Company: Codable { let name: String? }
        struct Location: Codable {
            let country: String?; let country_code: String?
            let state: String?; let city: String?
        }
    }

    private func viaIPAPIIs(ip: String) async -> GeoInfo? {
        guard let data = await get("https://api.ipapi.is/?q=\(ip)") else { return nil }
        guard let r = try? JSONDecoder().decode(IPAPIIsResp.self, from: data) else { return nil }
        let asn = r.asn?.asn.map { "AS\($0)" }
        let isp = r.asn?.org ?? r.company?.name
        let isProxy = (r.is_proxy ?? false) || (r.is_vpn ?? false) || (r.is_tor ?? false)
        return GeoInfo(
            country: r.location?.country, countryCode: r.location?.country_code,
            region: r.location?.state, city: r.location?.city,
            isp: isp, asn: asn,
            isProxy: isProxy, isHosting: r.is_datacenter ?? false
        )
    }

    // MARK: - 3. ipwho.is (HTTPS)

    private struct IPWhoIsResp: Codable {
        let success: Bool?
        let country: String?
        let country_code: String?
        let region: String?
        let city: String?
        let connection: Connection?
        struct Connection: Codable {
            let asn: Int?; let org: String?; let isp: String?
        }
    }

    private func viaIPWhoIs(ip: String) async -> GeoInfo? {
        guard let data = await get("https://ipwho.is/\(ip)") else { return nil }
        guard let r = try? JSONDecoder().decode(IPWhoIsResp.self, from: data),
              r.success == true else { return nil }
        return GeoInfo(
            country: r.country, countryCode: r.country_code,
            region: r.region, city: r.city,
            isp: r.connection?.isp ?? r.connection?.org,
            asn: r.connection?.asn.map { "AS\($0)" },
            isProxy: false, isHosting: false
        )
    }

    // MARK: - 4. ip.sb (HTTPS)

    private struct IPSBResp: Codable {
        let country: String?
        let country_code: String?
        let region: String?
        let city: String?
        let isp: String?
        let organization: String?
        let asn: Int?
        let asn_organization: String?
    }

    private func viaIPSB(ip: String) async -> GeoInfo? {
        // ip.sb 对默认 URLSession UA 有时会返回 403，伪装为 curl 最稳定。
        guard let data = await get("https://api.ip.sb/geoip/\(ip)", userAgent: "curl/8") else { return nil }
        guard let r = try? JSONDecoder().decode(IPSBResp.self, from: data) else { return nil }
        return GeoInfo(
            country: r.country, countryCode: r.country_code,
            region: r.region, city: r.city,
            isp: r.isp ?? r.organization ?? r.asn_organization,
            asn: r.asn.map { "AS\($0)" },
            isProxy: false, isHosting: false
        )
    }

    // MARK: - 5. ipinfo.io (HTTPS, no token)

    private struct IPInfoResp: Codable {
        let country: String?   // 只有 country code（如 "US"）
        let region: String?
        let city: String?
        let org: String?       // 如 "AS15169 Google LLC"
    }

    private func viaIPInfo(ip: String) async -> GeoInfo? {
        guard let data = await get("https://ipinfo.io/\(ip)/json") else { return nil }
        guard let r = try? JSONDecoder().decode(IPInfoResp.self, from: data) else { return nil }
        var asn: String? = nil
        var isp: String? = r.org
        if let org = r.org {
            let parts = org.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = parts.first, first.hasPrefix("AS") {
                asn = String(first)
                isp = parts.count > 1 ? String(parts[1]) : nil
            }
        }
        return GeoInfo(
            country: countryName(fromCode: r.country),
            countryCode: r.country,
            region: r.region, city: r.city,
            isp: isp, asn: asn,
            isProxy: false, isHosting: false
        )
    }
}
