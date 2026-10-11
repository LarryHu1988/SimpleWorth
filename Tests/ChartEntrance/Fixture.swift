import Charts
import SwiftUI
import UIKit

@main
struct ChartEntranceCheckApp: App {
    var body: some Scene { WindowGroup { ChartFixture() } }
}

private struct ChartFixture: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = true
    @State private var samples = ""
    @State private var taps = 0
    @State private var checkTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Replay") { runCheck(rapid: false) }
                Button("Rapid") { runCheck(rapid: true) }
            }
            .tint(.gray)
            Text(samples).accessibilityIdentifier("samples")
            Text("taps=\(taps)").accessibilityIdentifier("taps")
            Text(String("reduce=\(reduceMotion),system=\(UIAccessibility.isReduceMotionEnabled)"))
                .accessibilityIdentifier("motion")

            VStack(spacing: 18) {
                ProgressRing(progress: 0.78, tint: .blue)
                    .frame(width: 94, height: 94)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.1))
                    Capsule().fill(Color.green)
                        .frame(width: 200)
                        .chartEntrance(.horizontal)
                }
                .frame(width: 280, height: 12)

                Chart(Array(1...4), id: \.self) { value in
                    BarMark(x: .value("Month", value), y: .value("Amount", value * 25))
                        .foregroundStyle(Color.pink)
                }
                .chartPlotStyle { plot in plot.chartEntrance(.vertical) }
                .chartOverlay { _ in
                    Color.clear.contentShape(Rectangle()).onTapGesture { taps += 1 }
                }
                .frame(height: 140)
                .accessibilityIdentifier("bars")

                Chart(Array(1...3), id: \.self) { value in
                    SectorMark(angle: .value("Amount", value), innerRadius: .ratio(0.58), angularInset: 2)
                        .foregroundStyle(Color.orange)
                }
                // Match the production chart's non-animated selection transaction.
                .transaction { $0.animation = nil }
                .chartPlotStyle { plot in plot.chartEntrance(.radial) }
                .chartOverlay { _ in
                    Color.clear.contentShape(Rectangle()).onTapGesture { taps += 1 }
                }
                .frame(height: 130)
                .accessibilityIdentifier("donut")
            }
            .environment(\.swChartPageIsActive, active)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.white)
    }

    private func runCheck(rapid: Bool) {
        checkTask?.cancel()
        samples = ""
        checkTask = Task { @MainActor in
            do {
                for _ in 0..<(rapid ? 6 : 1) {
                    active = false
                    try await Task.sleep(for: .milliseconds(50))
                    active = true
                    if rapid { try await Task.sleep(for: .milliseconds(60)) }
                }
                try await Task.sleep(for: .milliseconds(120))
                let early = capture("early")
                try await Task.sleep(for: .milliseconds(200))
                let middle = capture("middle")
                try await Task.sleep(for: .milliseconds(500))
                let final = capture("final")
                samples = [early, middle, final].map { $0.map(String.init).joined(separator: ",") }
                    .joined(separator: ";")
            } catch { }
        }
    }

    @MainActor
    private func capture(_ stage: String) -> [Int] {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: \.isKeyWindow)
        else { return [] }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(stage).png")
        try? image.pngData()?.write(to: output)
        guard let cgImage = image.cgImage else { return [] }
        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return [] }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let bytes = buffer.bindMemory(to: UInt8.self)
            var counts = [Int](repeating: 0, count: 4)
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
                if b > r + 60 && b > g + 30 { counts[0] += 1 }
                if g > r + 30 && g > b + 30 { counts[1] += 1 }
                if r > g + 80 && b > g + 30 { counts[2] += 1 }
                if r > g + 30 && g > b + 30 { counts[3] += 1 }
            }
            return counts
        }
    }
}
