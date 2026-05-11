import Foundation

struct UsageData: Equatable {
    let session: UsageWindow         // rolling 5-hour window
    let week: UsageWindow            // weekly all-models window
    let opus: UsageWindow?           // weekly Opus-only (may not exist on all plans)
    let lastUpdated: Date
}

struct UsageWindow: Equatable {
    let utilization: Double          // 0.0 ... 1.0
    let resetsAt: Date

    var displayPercent: Int { Int((utilization * 100).rounded()) }
    var safeValue: Double { min(max(utilization, 0), 1) }
}
