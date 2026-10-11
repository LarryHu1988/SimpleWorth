import SwiftUI
import UIKit

struct LedgerEntry { let id: Int }
enum SWTheme {
    static let accentGreen = Color.green
    static let accentBlue = Color.blue
}
enum HapticService {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
extension String {
    func appLocalized(in locale: Locale) -> String { self }
}
struct LedgerRow: View {
    let entry: LedgerEntry
    var tagTintHexByName: [String: Int]
    var refundAmount: Double
    var body: some View {
        Text("Entry \(entry.id)")
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.gray.opacity(0.15))
    }
}

@main struct RowGestureCheckApp: App {
    var body: some Scene { WindowGroup { Fixture() } }
}
struct Fixture: View {
    @State private var edit = 0
    @State private var copy = 0
    @State private var refund = 0
    @State private var delete = 0
    var body: some View {
        VStack {
            Text("edit=\(edit),copy=\(copy),refund=\(refund),delete=\(delete)")
                .accessibilityIdentifier("events")
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        Text("Header").frame(height: 120)
                        LazyVStack(spacing: 10) {
                            ForEach(0..<40, id: \.self) { id in
                                SwipeableLedgerRow(
                                    entry: LedgerEntry(id: id),
                                    onTap: { edit += 1 },
                                    onCopy: { copy += 1 },
                                    onRefund: { refund += 1 },
                                    onDelete: { delete += 1 }
                                ).id(id)
                            }
                        }.padding(16)
                    }.padding(16)
                }.onAppear { reader.scrollTo(8, anchor: .center) }
            }
        }
    }
}
