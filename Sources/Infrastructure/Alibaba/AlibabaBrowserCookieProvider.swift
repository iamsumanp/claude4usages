import Foundation
import Domain

/// Resolves Alibaba Cloud authentication cookies from browser cookie stores.
///
/// Searches for aliyun.com / alibabacloud.com cookies across all supported browsers
/// using SweetCookieKit. Used when cookie source is set to "auto".
///
/// NOTE (Phase 1): SweetCookieKit removed from deps (Swift 6.2 required; Phase 2 removes this provider).
/// Browser cookie resolution is stubbed until Phase 2 cleanup.
public struct AlibabaBrowserCookieProvider: AlibabaCookieProviding {
    public init() {}

    public func extractBrowserCookies() -> String? {
        AppLog.probes.debug("Alibaba: Browser cookie extraction stubbed (SweetCookieKit removed in Phase 1)")
        return nil
    }
}
