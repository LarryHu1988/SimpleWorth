import XCTest
import SwiftUI
@testable import AdaptiveLayoutCheck

final class LayoutTests: XCTestCase {
    func testWorkspaceRequiresInnerLandscape() {
        XCTAssertTrue(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 951, height: 669), isInnerDisplay: true, dynamicTypeSize: .large))
        XCTAssertFalse(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 669, height: 951), isInnerDisplay: true, dynamicTypeSize: .large))
        XCTAssertFalse(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 678, height: 466), isInnerDisplay: false, dynamicTypeSize: .large))
        XCTAssertFalse(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 951, height: 669), isInnerDisplay: false, dynamicTypeSize: .large))
        XCTAssertFalse(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 500, height: 669), isInnerDisplay: true, dynamicTypeSize: .large))
        XCTAssertFalse(SWAdaptiveLayout.usesWorkspace(size: CGSize(width: 951, height: 669), isInnerDisplay: true, dynamicTypeSize: .accessibility3))
    }

    func testColumnsRespectSpaceAndAccessibility() {
        XCTAssertFalse(SWAdaptiveLayout.usesColumns(width: 599, dynamicTypeSize: .large))
        XCTAssertTrue(SWAdaptiveLayout.usesColumns(width: 600, dynamicTypeSize: .large))
        XCTAssertTrue(SWAdaptiveLayout.usesColumns(width: 1000, dynamicTypeSize: .xxxLarge))
        XCTAssertFalse(SWAdaptiveLayout.usesColumns(width: 1000, dynamicTypeSize: .accessibility1))
        XCTAssertFalse(SWAdaptiveLayout.usesColumns(width: 1000, dynamicTypeSize: .accessibility5))
    }
}
