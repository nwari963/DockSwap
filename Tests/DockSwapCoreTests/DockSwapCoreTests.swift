import XCTest
@testable import DockSwapCore

final class PresetTests: XCTestCase {
    func testPresetCodable() throws {
        let preset = DockPreset(
            name: "dev",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))],
            others: [.spacer]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)
        let decoded = try JSONDecoder().decode(DockPreset.self, from: data)

        XCTAssertEqual(preset, decoded)

        // JSON must match ticket 001: app carries an identity object; spacer is {"type":"spacer"}.
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let apps = object["apps"] as! [[String: Any]]
        let app = apps[0]
        XCTAssertEqual(app["type"] as? String, "app")
        XCTAssertTrue(app["identity"] is [String: Any])
        let others = object["others"] as! [[String: Any]]
        XCTAssertEqual(others[0]["type"] as? String, "spacer")
    }

    func testCaptureLiveDock() {
        // Row 1: app (tab-separated). Row 2: spacer (trailing blank row).
        let output = """
        Example\tfile:///Applications/Example.app/\tpersistentApps\t/Users/nwariri/Library/Preferences/com.apple.dock.plist\tcom.example.app
        \t\tpersistentOthers\t\t
        """
        let preset = captureLiveDock(from: output, name: "test")

        XCTAssertEqual(preset.apps.count, 1)
        XCTAssertEqual(preset.others.count, 1)
        XCTAssertEqual(preset.others.first, .spacer)
    }

    func testCaptureLiveDockSkipsRecentApps() {
        let output = "Recents\tfile:///Applications/Recents.app/\trecent-apps\t/plist\tcom.example.recents\n"
        let preset = captureLiveDock(from: output, name: "test")
        XCTAssertEqual(preset.apps.count, 0)
        XCTAssertEqual(preset.others.count, 0)
    }
}

final class DockUtilTests: XCTestCase {
    func testParseDockList() {
        let output = """
        Example\tfile:///Applications/Example.app/\tpersistentApps\t/Users/nwariri/Library/Preferences/com.apple.dock.plist\tcom.example.app
        \t\t\t\t
        """
        let items = parseDockList(output)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.label, "Example")
        XCTAssertTrue(items.last?.isSpacerRow ?? false)
    }

    func testResolvePathEnvWins() throws {
        setenv("DOCKSWAP_DOCKUTIL_PATH", "/usr/bin/true".cString(using: .utf8), 1)
        defer { unsetenv("DOCKSWAP_DOCKUTIL_PATH") }
        // /usr/bin/true prints no version → resolved() must refuse it as not-dockutil.
        XCTAssertThrowsError(try DockUtil.resolved()) { error in
            XCTAssertEqual(error as? DockSwapError, .dockutilMissing)
        }
    }

    func testParseDockutilVersion() {
        XCTAssertEqual(parseDockutilVersion("3.1.3")?.major, 3)
        XCTAssertEqual(parseDockutilVersion("dockutil: version 2.1.0")?.major, 2)
        XCTAssertNil(parseDockutilVersion("nonsense"))
    }
}

final class DiffEngineTests: XCTestCase {
    func testDiff() {
        let current = DockPreset(
            name: "current",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))]
        )
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            others: [.app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.app", path: "/Applications/Example.app")))]
        )

        let (removes, adds) = diff(preset, from: current)

        XCTAssertEqual(removes.count, 1)
        XCTAssertEqual(adds.count, 1)
    }

    func testDiffSpacerNotRemoved() {
        let current = DockPreset(
            name: "current",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            others: [.spacer]
        )
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            others: []
        )

        let (removes, adds) = diff(preset, from: current)

        XCTAssertTrue(removes.isEmpty)
        XCTAssertTrue(adds.isEmpty)
    }
}