import SwiftData
import SwiftUI
import UIKit

@main
struct AdaptiveLayoutCheckApp: App {
    @StateObject private var controller: AppRuntimeController

    init() {
        UserDefaults.standard.set("zh-Hans", forKey: SettingsKeys.appLanguage)
        let controller = AppRuntimeController()
        let context = controller.container.mainContext
        if (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) == 0 {
            for flow in FlowType.allCases {
                for index in 0..<25 {
                    let name = flow == .expense ? (index < 18 ? "鞋靴" : "餐饮") : "工资"
                    let category = CategoryLibrary.category(named: name, flow: flow)!
                    context.insert(LedgerEntry(
                        createdAt: Date.now.addingTimeInterval(-Double(index)), amount: 100,
                        note: "QA \(flow.storageValue) \(index)", flow: flow, category: category
                    ))
                }
            }
            for index in 0..<4 {
                let goal = SavingsGoalRecord(
                    name: "QA goal \(index)", symbol: "target", currentAmount: 100,
                    targetAmount: 400, tintHex: 0x308BDD
                )
                context.insert(goal)
                context.insert(VaultDepositRecord(amount: 100, note: "QA deposit \(index)", goal: goal))
            }
            context.insert(TagRecord(name: "QA tag"))
            try? context.save()
        }
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            FixtureRoot()
                .environmentObject(controller)
                .modelContainer(controller.container)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .preferredColorScheme(.light)
                .background {
                    if #available(iOS 27.1, *) {
                        PoseRecorder()
                    }
                }
        }
    }
}

@available(iOS 27.1, *)
private struct PoseRecorder: View {
    @State private var measurement = Measurement()

    struct Measurement: Codable, Equatable {
        var processID: Int32 = ProcessInfo.processInfo.processIdentifier
        var telemetryPath: String = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("qa-pose.json").path
        var width: Double = 0
        var height: Double = 0
        var originX: Double = 0
        var originY: Double = 0
        var sceneX: Double = 0
        var sceneY: Double = 0
        var sceneWidth: Double = 0
        var sceneHeight: Double = 0
        var sceneIsActive = false
        var angle: Double?
        var status: String?
        var divisions: [Region] = []
    }

    struct Region: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let active: Bool
    }

    var body: some View {
        GeometryReader { _ in
            Color.clear
                .onGeometryChange(for: Measurement.self) { geometry in
                    Measurement(
                        width: geometry.size.width, height: geometry.size.height,
                        originX: geometry.frame(in: .global).minX, originY: geometry.frame(in: .global).minY,
                        divisions: geometry.reservedRegions(kind: .division, options: .includeInactive).map {
                            Region(x: $0.frame.minX, y: $0.frame.minY,
                                   width: $0.frame.width, height: $0.frame.height, active: $0.isActive)
                        }
                    )
                } action: { value in
                    measurement.width = value.width
                    measurement.height = value.height
                    measurement.originX = value.originX
                    measurement.originY = value.originY
                    measurement.divisions = value.divisions
                    save()
                }
                .onHingeChange { _, context in
                    measurement.angle = context.hinge?.angle.degrees
                    measurement.status = context.hinge.map { String(describing: $0.status) }
                    save()
                }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("qa.pose")
        .accessibilityLabel("QA pose")
        .accessibilityValue(String(data: (try? JSONEncoder().encode(measurement)) ?? Data(), encoding: .utf8) ?? "")
        .background {
            WindowSceneRecorder { frame, isActive in
                measurement.sceneX = frame.minX
                measurement.sceneY = frame.minY
                measurement.sceneWidth = frame.width
                measurement.sceneHeight = frame.height
                measurement.sceneIsActive = isActive
                save()
            }
        }
    }

    private func save() {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(measurement) else { return }
        try? data.write(to: directory.appendingPathComponent("qa-pose.json"), options: .atomic)
    }
}

private struct WindowSceneRecorder: UIViewRepresentable {
    let onChange: (CGRect, Bool) -> Void
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) { view.onChange = onChange }
    static func dismantleUIView(_ view: Probe, coordinator: Void) { view.timer?.invalidate() }

    final class Probe: UIView {
        var onChange: (CGRect, Bool) -> Void = { _, _ in }
        var timer: Timer?
        private var lastFrame: CGRect?
        private var lastIsActive: Bool?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            timer?.invalidate()
            guard window != nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self, let scene = self.window?.windowScene else { return }
                let frame = scene.coordinateSpace.convert(scene.coordinateSpace.bounds, to: scene.screen.coordinateSpace)
                let isActive = scene.activationState == .foregroundActive
                guard frame != self.lastFrame || isActive != self.lastIsActive else { return }
                self.lastFrame = frame
                self.lastIsActive = isActive
                self.onChange(frame, isActive)
            }
        }
        deinit { timer?.invalidate() }
    }
}

private struct FixtureRoot: View {
    @State private var width: CGFloat = 380
    @State private var commandedWorkspace = false
    @EnvironmentObject private var appRuntimeController: AppRuntimeController

    var body: some View {
        if ProcessInfo.processInfo.environment["QA_WORKSPACE_COMMANDS"] == "1" {
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: .simplifiedChinese, themeMode: .daylight)
                .environment(\.swWorkspaceOverride, commandedWorkspace)
                .background {
                    Color.clear
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("qa.commandDirectory")
                        .accessibilityValue(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path)
                }
                .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
                    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                          let data = try? Data(contentsOf: directory.appendingPathComponent("qa-workspace-command.json")),
                          let value = try? JSONDecoder().decode(Bool.self, from: data),
                          value != commandedWorkspace else { return }
                    commandedWorkspace = value
                }
        } else if ProcessInfo.processInfo.environment["QA_REAL_ROOT"] == "1" {
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: .simplifiedChinese, themeMode: .daylight)
        } else if ProcessInfo.processInfo.environment["QA_NATIVE_SIZE"] == "1" {
            MainTabView()
        } else {
            GeometryReader { geometry in
                MainTabView()
                    .environment(\.swWorkspaceOverride, width >= 600)
                    .frame(width: min(width, geometry.size.width))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Compact") { width = 380 }
                        .accessibilityIdentifier("qa.compact")
                    Button("Wide") { width = 1000 }
                        .accessibilityIdentifier("qa.wide")
                }
                .buttonStyle(.bordered)
                .padding(6)
            }
        }
    }
}
