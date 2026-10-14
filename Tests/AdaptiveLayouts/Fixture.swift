import SwiftData
import SwiftUI
import UIKit

@main
struct AdaptiveLayoutCheckApp: App {
    @StateObject private var controller: AppRuntimeController

    init() {
        let language = ProcessInfo.processInfo.environment["QA_LANGUAGE"] ?? "zh-Hans"
        UserDefaults.standard.set(language, forKey: SettingsKeys.appLanguage)
        let controller = AppRuntimeController()
        let context = controller.container.mainContext
        let rowCount = min(max(Int(ProcessInfo.processInfo.environment["QA_SCROLL_ROWS"] ?? "25") ?? 25, 25), 300)
        let previousRowCount = UserDefaults.standard.object(forKey: "qa.fixture.rowCount") as? Int ?? 25
        let stressContent = ProcessInfo.processInfo.environment["QA_WIDTH_STRESS"] == "1"
        let previousStressContent = UserDefaults.standard.bool(forKey: "qa.fixture.widthStress")
        if (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) == 0 || previousRowCount != rowCount
            || stressContent != previousStressContent {
            for entry in (try? context.fetch(FetchDescriptor<LedgerEntry>())) ?? [] { context.delete(entry) }
            for flow in FlowType.allCases {
                for index in 0..<rowCount {
                    let name = flow == .expense ? (index < 18 ? "鞋靴" : "餐饮") : "工资"
                    let category = CategoryLibrary.category(named: name, flow: flow)!
                    context.insert(LedgerEntry(
                        createdAt: Date.now.addingTimeInterval(-Double(index)), amount: stressContent ? 12_345_678.9 : 100,
                        note: stressContent ? "QA \(flow.storageValue) \(index) - Daily shopping and a longer note" : "QA \(flow.storageValue) \(index)",
                        flow: flow, category: category,
                        tagNames: rowCount > 25 || stressContent ? ["QA tag", "生活", "待核对", "长标签换行验证"] : []
                    ))
                }
            }
            if (try? context.fetchCount(FetchDescriptor<SavingsGoalRecord>())) == 0 {
                for index in 0..<4 {
                    let goal = SavingsGoalRecord(
                        name: "QA goal \(index)", symbol: "target", currentAmount: 100,
                        targetAmount: 400, tintHex: 0x308BDD
                    )
                    context.insert(goal)
                    context.insert(VaultDepositRecord(amount: 100, note: "QA deposit \(index)", goal: goal))
                }
            }
            if (try? context.fetchCount(FetchDescriptor<TagRecord>())) == 0 { context.insert(TagRecord(name: "QA tag")) }
            for goal in (try? context.fetch(FetchDescriptor<SavingsGoalRecord>())) ?? [] {
                goal.currentAmount = stressContent ? 12_345_678.9 : 100
                goal.targetAmount = stressContent ? 99_999_999 : 400
            }
            try? context.save()
            UserDefaults.standard.set(rowCount, forKey: "qa.fixture.rowCount")
            UserDefaults.standard.set(stressContent, forKey: "qa.fixture.widthStress")
        }
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            FixtureRoot()
                .environmentObject(controller)
                .modelContainer(controller.container)
                .environment(\.locale, Locale(identifier: ProcessInfo.processInfo.environment["QA_LANGUAGE"] ?? "zh-Hans"))
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
        var interfaceOrientation = 0
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
            WindowSceneRecorder { frame, isActive, orientation in
                measurement.sceneX = frame.minX
                measurement.sceneY = frame.minY
                measurement.sceneWidth = frame.width
                measurement.sceneHeight = frame.height
                measurement.sceneIsActive = isActive
                measurement.interfaceOrientation = orientation
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
    let onChange: (CGRect, Bool, Int) -> Void
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) { view.onChange = onChange }
    static func dismantleUIView(_ view: Probe, coordinator: Void) { view.timer?.invalidate() }

    final class Probe: UIView {
        var onChange: (CGRect, Bool, Int) -> Void = { _, _, _ in }
        var timer: Timer?
        private var lastFrame: CGRect?
        private var lastIsActive: Bool?
        private var lastOrientation: Int?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            timer?.invalidate()
            guard window != nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self, let scene = self.window?.windowScene else { return }
                let frame = scene.coordinateSpace.convert(scene.coordinateSpace.bounds, to: scene.screen.coordinateSpace)
                let isActive = scene.activationState == .foregroundActive
                let orientation = scene.effectiveGeometry.interfaceOrientation.rawValue
                guard frame != self.lastFrame || isActive != self.lastIsActive || orientation != self.lastOrientation else { return }
                self.lastFrame = frame
                self.lastIsActive = isActive
                self.lastOrientation = orientation
                self.onChange(frame, isActive, orientation)
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
        if let width = ProcessInfo.processInfo.environment["QA_CONTAINER_WIDTH"].flatMap(Double.init) {
            GeometryReader { geometry in
                AppRootView(appRuntimeController: appRuntimeController, appLanguage: fixtureLanguage, themeMode: .daylight)
                    .environment(\.swWorkspaceOverride, false)
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(width: min(max(0, width), geometry.size.width))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if ProcessInfo.processInfo.environment["QA_WORKSPACE_COMMANDS"] == "1" {
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: fixtureLanguage, themeMode: .daylight)
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
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: fixtureLanguage, themeMode: .daylight)
        } else if ProcessInfo.processInfo.environment["QA_NATIVE_SIZE"] == "1" {
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: fixtureLanguage, themeMode: .daylight)
        } else if ProcessInfo.processInfo.environment["QA_SYNTHETIC_SIZE"] == "1" {
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
        } else {
            AppRootView(appRuntimeController: appRuntimeController, appLanguage: fixtureLanguage, themeMode: .daylight)
        }
    }

    private var fixtureLanguage: AppLanguage {
        AppLanguage(rawValue: ProcessInfo.processInfo.environment["QA_LANGUAGE"] ?? "zh-Hans") ?? .simplifiedChinese
    }
}
