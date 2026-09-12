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

    /// Regression test: a plain https:// URL tile whose href ends in "/"
    /// (the common case — most homepages do) was misclassified as a folder
    /// because classification used to key off a trailing "/" instead of the
    /// "file://" scheme, then corrupted the url by stripping a "file://"-
    /// length prefix that was never there. Found via manual QA: a captured
    /// "https://anthropic.com/" turned into a bogus "/anthropic.com" folder,
    /// which dockutil then couldn't find to remove on the next switch.
    func testCaptureLiveDockURLTileNotMisclassifiedAsFolder() {
        let output = "Anthropic\thttps://anthropic.com/\tpersistentOthers\t/plist\t\n"
        let preset = captureLiveDock(from: output, name: "test")
        XCTAssertEqual(preset.others, [.url(URLItemPayload(title: "Anthropic", url: "https://anthropic.com/"))])
    }

    /// Regression test: real dockutil 3.1.3 represents an added spacer with
    /// a literal "spacer" label and a synthetic <home>/spacer url — not the
    /// fully-empty row ticket 001's research assumed. Without recognizing
    /// this, a captured spacer became a bogus URL item eligible for removal,
    /// violating ticket 003 rule 5 ("spacers are never removal candidates").
    func testCaptureLiveDockRecognizesRealSpacerRow() {
        let output = "spacer\t/Users/example/spacer\tpersistentOthers\t/plist\t\n"
        let preset = captureLiveDock(from: output, name: "test")
        XCTAssertEqual(preset.others, [.spacer])
    }
}

final class ErrorTests: XCTestCase {
    /// 002: "print dockutil's stderr verbatim prefixed with the failing dockutil command."
    func testDockutilFailedDescriptionIncludesCommand() {
        let error = DockSwapError.dockutilFailed(
            command: ["--remove", "Safari", "--section", "apps"],
            output: "dockutil: no such item",
            exitCode: 1
        )
        XCTAssertEqual(error.description, "dockutil --remove Safari --section apps: dockutil: no such item")
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

private final class MockDockUtil: DockUtilExecuting {
    var listOutput = ""
    var versionOutput = "3.1.3"
    var applyArgs: [String] = []

    func run(_ args: [String]) throws -> String {
        if args == ["--list"] { return listOutput }
        if args == ["--version"] { return versionOutput }
        applyArgs = args
        return ""
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

    /// Regression test for two bugs fixed together: `apply()` used to re-emit
    /// `--add spacer` for every preset spacer whenever anything else in the
    /// section differed (breaking 003's "switching twice is idempotent"), and
    /// its `--add` value for apps was the bundleId instead of the path dockutil
    /// requires.
    func testApplySkipsExistingSpacerAndAddsAppByPath() throws {
        let mock = MockDockUtil()
        mock.listOutput = """
        Old\tfile:///Applications/Old.app/\tpersistentApps\t/plist\tcom.example.old
        \t\tpersistentApps\t\t
        """
        let engine = DockDiffEngine(dockUtil: mock)
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [
                .spacer,
                .app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.new", path: "/Applications/New.app"))),
            ]
        )

        let result = try engine.apply(preset)

        XCTAssertEqual(result?.removed, 1)
        XCTAssertEqual(result?.added, 1)
        XCTAssertFalse(mock.applyArgs.contains("spacer"), "existing spacer must not be re-added")
        XCTAssertTrue(mock.applyArgs.contains("/Applications/New.app"), "app add must use path, not bundleId")
        XCTAssertFalse(mock.applyArgs.contains("com.example.new"), "bundleId is not a valid --add value")
    }

    /// Regression test for a bug only manual QA against a real Dock caught:
    /// dockutil's anchor flag is `--after <label>`, a flag distinct from
    /// `--position` (which only takes an index or beginning/end/middle).
    /// `--position after <label>` is rejected by the real binary, even
    /// though every mocked test here was happy with it.
    func testAnchoredAddUsesAfterFlagNotPositionAfter() throws {
        let mock = MockDockUtil()
        mock.listOutput = "Existing\tfile:///Applications/Existing.app/\tpersistentApps\t/plist\tcom.example.existing\n"
        let engine = DockDiffEngine(dockUtil: mock)
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [
                .app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.existing", path: "/Applications/Existing.app"))),
                .app(AppItemPayload(identity: AppIdentity(bundleId: "com.example.new", path: "/Applications/New.app"))),
            ]
        )

        _ = try engine.apply(preset)

        XCTAssertEqual(mock.applyArgs, ["--add", "/Applications/New.app", "--section", "apps", "--after", "com.example.existing"])
    }

    /// 003 rule 1 only matches on bundleId when *both* sides have one; two
    /// different path-only apps must not falsely match via `nil == nil`
    /// (which would make `diff` see no change at all here).
    func testDiffDoesNotConflatePathOnlyApps() {
        let current = DockPreset(
            name: "current",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItemPayload(identity: AppIdentity(path: "/Applications/A.app")))]
        )
        let preset = DockPreset(
            name: "preset",
            createdAt: "2026-09-06T00:00:00Z",
            updatedAt: "2026-09-06T00:00:00Z",
            apps: [.app(AppItemPayload(identity: AppIdentity(path: "/Applications/B.app")))]
        )

        let (removes, adds) = diff(preset, from: current)

        XCTAssertEqual(removes.count, 1)
        XCTAssertEqual(adds.count, 1)
    }

    /// 001: preset metadata should snapshot the *real* dockutil/macOS versions,
    /// not a hardcoded placeholder.
    func testCaptureCurrentPresetSnapshotsRealVersions() throws {
        let mock = MockDockUtil()
        mock.versionOutput = "3.1.3"
        let engine = DockDiffEngine(dockUtil: mock)

        let preset = try engine.captureCurrentPreset()

        XCTAssertEqual(preset.dockutilVersion, "3.1.3")
        XCTAssertEqual(preset.macOSVersion, ProcessInfo.processInfo.operatingSystemVersionString)
    }
}