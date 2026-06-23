import Foundation

enum CCHActiveSessionRefreshInterval {
    static let defaultIdleSeconds = 3
    static let defaultActiveSeconds = 1
    static let allowedIdleSeconds = [1, 3, 5]
    static let allowedActiveSeconds = [1, 3]

    static func sanitizedIdleSeconds(_ seconds: Int) -> Int {
        allowedIdleSeconds.contains(seconds) ? seconds : defaultIdleSeconds
    }

    static func sanitizedActiveSeconds(_ seconds: Int) -> Int {
        allowedActiveSeconds.contains(seconds) ? seconds : defaultActiveSeconds
    }

    static func idleTimeInterval(seconds: Int) -> TimeInterval {
        TimeInterval(sanitizedIdleSeconds(seconds))
    }

    static func activeTimeInterval(seconds: Int) -> TimeInterval {
        TimeInterval(sanitizedActiveSeconds(seconds))
    }
}
