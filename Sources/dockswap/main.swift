import Foundation
import ArgumentParser
import DockSwapCore

/// The `dockswap` CLI.
@main
struct DockSwap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dockswap",
        abstract: "Save and switch macOS Dock presets",
        version: "1.0.0",
        subcommands: [Save.self, Switch.self, List.self, Delete.self],
        defaultSubcommand: Picker.self
    )

    /// Honours the exit-code contract (ticket 004): usage errors exit 1
    /// (argument-parser's default is 64), and DockSwapError maps to 2-6.
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch {
            if let e = error as? DockSwapError {
                FileHandle.standardError.write(Data("\(e.description)\n".utf8))
                Foundation.exit(e.exitCode)
            } else {
                // ParserError .helpRequested / .versionRequested arrive here wrapped
                // in CommandError; their description is an enum payload string.
                let desc = String(describing: error)
                if desc.contains("helpRequested") {
                    print(DockSwap.helpMessage(includeHidden: false, columns: nil))
                    Foundation.exit(0)
                } else if desc.contains("versionRequested") {
                    print(DockSwap.configuration.version)
                    Foundation.exit(0)
                } else {
                    FileHandle.standardError.write(Data("Error: \(desc)\n".utf8))
                    Foundation.exit(1)
                }
            }
        }
    }
}

/// Stable `list --json` shape (ticket 004).
struct ListSummary: Codable {
    let name: String
    let apps: Int
    let others: Int
    let updatedAt: String
}

/// Save the current dock as a preset.
struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save the current dock as a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    mutating func run() throws {
        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        let preset = try engine.captureCurrentPreset()
        try preset.save(to: name)
        print("Saved preset \"\(name)\"")
    }
}

/// Switch to a preset.
struct Switch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Switch to a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    @Flag(name: .shortAndLong, help: "Show what would be changed without applying")
    var dryRun = false

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        let preset = try DockPreset.load(named: name)
        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        if dryRun {
            let (removes, adds) = diff(preset, from: try engine.captureCurrentPreset())
            print("Would remove: \(removes.map { $0.item.description }.joined(separator: ", "))")
            print("Would add: \(adds.map { $0.item.description }.joined(separator: ", "))")
        } else {
            let changed = try engine.apply(preset)
            if !quiet {
                print(changed ? "Switched to preset \"\(name)\"" : "Already applied")
            }
        }
    }
}

/// List presets.
struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List presets"
    )

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        let presets = try DockPreset.list()
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let summaries = presets.map {
                ListSummary(name: $0.name, apps: $0.apps.count, others: $0.others.count, updatedAt: $0.updatedAt)
            }
            let data = try encoder.encode(summaries)
            print(String(data: data, encoding: .utf8)!)
        } else if !quiet {
            for preset in presets {
                print("- \(preset.name)")
            }
        }
    }
}

/// Delete a preset.
struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        try DockPreset.delete(named: name)
        if !quiet {
            print("Deleted preset \"\(name)\"")
        }
    }
}

/// The TUI picker.
struct Picker: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open the TUI picker"
    )

    mutating func run() throws {
        let presets = try DockPreset.list()
        guard !presets.isEmpty else {
            print("No presets found")
            return
        }

        guard let selected = try ANSIPicker(presets: presets).run() else {
            print("Cancelled")
            return
        }

        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        let changed = try engine.apply(selected)
        if !changed {
            print("Already applied: \(selected.name)")
        }
    }
}