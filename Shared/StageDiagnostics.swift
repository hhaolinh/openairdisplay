import Foundation

/// Opt-in timing only: no pixels, cursor coordinates, or window titles.
/// Samples use the local monotonic clock; cross-device clocks are not mixed.
final class StageDiagnostics {
    let enabled: Bool

    init(enabled: Bool = UserDefaults.standard.bool(forKey: "diagnostics")) {
        self.enabled = enabled
    }
    private let lock = NSLock()
    private var samples: [String: [Double]] = [:]
    private var previous: [String: Double] = [:]
    private var timer: DispatchSourceTimer?
    private let worker = DispatchQueue(label: "display.diagnostics")

    static var now: Double { ProcessInfo.processInfo.systemUptime * 1000 }

    func record(_ stage: String, _ milliseconds: Double) {
        guard enabled, milliseconds.isFinite, milliseconds >= 0 else { return }
        lock.lock()
        if samples[stage, default: []].count < 4096 {
            samples[stage, default: []].append(milliseconds)
        }
        lock.unlock()
    }

    func tick(_ stage: String) {
        guard enabled else { return }
        let now = Self.now
        lock.lock()
        if let last = previous[stage], samples[stage, default: []].count < 4096 {
            samples[stage, default: []].append(now - last)
        }
        previous[stage] = now
        lock.unlock()
    }

    func start(role: String, queue: DispatchQueue, report: @escaping ([String: Any]) -> Void) {
        guard enabled, timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: worker)
        var round = 0
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let submitted = Self.now
            queue.async { self.record("workerQueueMs", Self.now - submitted) }
            DispatchQueue.main.async { self.record("mainQueueMs", Self.now - submitted) }
            round += 1
            if round % 20 == 0 {
                let snapshot = self.snapshot(role: role)
                report(snapshot)
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() { timer?.cancel(); timer = nil }
    deinit { timer?.cancel() }

    func snapshot(role: String) -> [String: Any] {
        lock.lock()
        let batch = samples
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
        var stages: [String: Any] = [:]
        for (name, values) in batch {
            let values = values.sorted()
            guard let maximum = values.last else { continue }
            stages[name] = ["n": values.count, "p50": values[(values.count - 1) / 2],
                            "p95": values[Int(Double(values.count - 1) * 0.95)],
                            "max": maximum, "over50": values.filter { $0 > 50 }.count]
        }
        return ["type": "diagnostics", "version": 1, "role": role,
                "time": Date().timeIntervalSince1970, "stages": stages]
    }

    static func log(_ report: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }
        Log.info("DIAG \(json)")
    }
}
