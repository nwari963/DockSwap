import XCTest
@testable import DockSwapCore

final class PresetTests: XCTestCase {
    func testPresetCodable() throws {
        let preset = DockPreset(
            name: "dev",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItem(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))],
            others: [.spacer]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)
        let decoded = try JSONDecoder().decode(DockPreset.self, from: data)

        XCTAssertEqual(preset, decoded)
    }

    func testCaptureLiveDock() {
        let output = """
        Example\tfile:///Applications/Example.app/\tpersistentApps\t/Users/nwariri/Library/Preferences/com.apple.dock.plist\tcom.example.app
        \t\t\t\t
        """
        let preset = captureLiveDock(from: output, name: "test")

        XCTAssertEqual(preset.apps.count, 1)
        XCTAssertEqual(preset.others.count, 1)
        XCTAssertEqual(preset.others.first, .spacer)
    }
}

final class DockUtilTests: XCTestCase {
    func testParseDockList() {
        let output = """
        Example\tfile:///Applications/Example.app/\tpersistentApps\t/Users/nwariri/Library/Preferences/com.apple.dock.plist\tcom.example.app
        \t\t\t\t
        """
        let items = parseDockList(output)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.label, "Example")
    }
}

final class DiffEngineTests: XCTestCase {
    func testDiff() {
        let current = DockPreset(
            name: "current",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItem(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))]
        )
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            others: [.app(AppItem(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))]
        )

        let (removes, adds) = preset.diff(from: current)

        XCTAssertEqual(removes.count, 1)
        XCTAssertEqual(adds.count, 1)
    }
}
