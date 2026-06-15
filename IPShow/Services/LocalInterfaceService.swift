import Foundation
import Darwin

struct LocalInterface: Identifiable, Hashable {
    let id: UUID
    let name: String
    let address: String
    let family: Family

    enum Family: String {
        case ipv4 = "IPv4"
        case ipv6 = "IPv6"
    }
}

/// 通过 getifaddrs 枚举本地网卡 IP。
enum LocalInterfaceService {

    static func enumerate(includeLoopback: Bool = false) -> [LocalInterface] {
        var results: [LocalInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return results
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP, (flags & IFF_RUNNING) == IFF_RUNNING else { continue }
            if !includeLoopback, (flags & IFF_LOOPBACK) != 0 { continue }

            guard let addr = ptr.pointee.ifa_addr else { continue }
            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let socklen: socklen_t = (family == UInt8(AF_INET))
                ? socklen_t(MemoryLayout<sockaddr_in>.size)
                : socklen_t(MemoryLayout<sockaddr_in6>.size)
            let ret = getnameinfo(addr, socklen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard ret == 0 else { continue }

            let ifname = String(cString: ptr.pointee.ifa_name)
            var address = String(cString: host)
            // 去掉 IPv6 zone id (e.g. fe80::1%en0)
            if let pct = address.firstIndex(of: "%") {
                address = String(address[..<pct])
            }

            results.append(LocalInterface(
                id: UUID(),
                name: ifname,
                address: address,
                family: family == UInt8(AF_INET) ? .ipv4 : .ipv6
            ))
        }
        // 排序：IPv4 优先，按接口名稳定排序
        results.sort {
            if $0.family != $1.family { return $0.family == .ipv4 }
            return $0.name < $1.name
        }
        return results
    }
}
