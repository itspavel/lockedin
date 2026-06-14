import Foundation

/// Claude model pricing for the local cost estimator. Rates are USD per 1M tokens
/// (input / output). Cache reads bill ~0.1× input; 5-minute cache writes ~1.25× input
/// (we assume the default ephemeral TTL). Matched by model-ID prefix so suffixed IDs
/// like "claude-opus-4-8[1m]" resolve correctly.
enum Pricing {
    private static let rates: [(prefix: String, input: Double, output: Double)] = [
        ("claude-fable-5",   10, 50),
        ("claude-mythos-5",  10, 50),
        ("claude-opus-4-8",   5, 25),
        ("claude-opus-4-7",   5, 25),
        ("claude-opus-4-6",   5, 25),
        ("claude-opus-4-5",   5, 25),
        ("claude-sonnet-4-6", 3, 15),
        ("claude-sonnet-4-5", 3, 15),
        ("claude-haiku-4-5",  1,  5),
    ]

    /// (input, output) USD per 1M tokens. Falls back to Opus-tier for unknown models.
    static func rate(for model: String) -> (input: Double, output: Double) {
        for r in rates where model.hasPrefix(r.prefix) { return (r.input, r.output) }
        return (5, 25)
    }

    /// Estimated USD cost for one bucket of token counts at a model's rates.
    static func cost(model: String, _ c: TokenCounts) -> Double {
        let r = rate(for: model)
        let perInput = r.input / 1_000_000
        let perOutput = r.output / 1_000_000
        return Double(c.input) * perInput
             + Double(c.output) * perOutput
             + Double(c.cacheRead) * (perInput * 0.1)     // cache read: 0.1× input
             + Double(c.cacheWrite) * (perInput * 1.25)   // 5-min write: 1.25× input
             + Double(c.cacheWrite1h) * (perInput * 2.0)  // 1-hour write: 2× input
    }

    /// Short friendly model label for the mix display, e.g. "Opus 4.8", "Fable 5".
    static func shortName(_ model: String) -> String {
        let map: [(String, String)] = [
            ("claude-fable-5", "Fable 5"), ("claude-mythos-5", "Mythos 5"),
            ("claude-opus-4-8", "Opus 4.8"), ("claude-opus-4-7", "Opus 4.7"),
            ("claude-opus-4-6", "Opus 4.6"), ("claude-opus-4-5", "Opus 4.5"),
            ("claude-sonnet-4-6", "Sonnet 4.6"), ("claude-sonnet-4-5", "Sonnet 4.5"),
            ("claude-haiku-4-5", "Haiku 4.5"),
        ]
        for (p, n) in map where model.hasPrefix(p) { return n }
        return model
    }
}

extension Int {
    /// Compact token count: 1240000 -> "1.24M", 47000 -> "47k".
    var tokensCompact: String {
        if self >= 1_000_000 { return String(format: "%.2fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.0fk", Double(self) / 1_000) }
        return "\(self)"
    }
}

extension Double {
    /// "$3.40" style cost.
    var usd: String { String(format: "$%.2f", self) }
}
