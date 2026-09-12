import Foundation

/// A dependency-free ANSI raw-mode picker.
public struct ANSIPicker {
    public let presets: [DockPreset]

    public init(presets: [DockPreset]) {
        self.presets = presets
    }

    /// Run the picker and return the selected preset.
    public func run() throws -> DockPreset? {
        // Set raw mode
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        var rawCopy = raw
        rawCopy.c_lflag &= ~(tcflag_t(ICANON) | tcflag_t(ECHO))
        tcsetattr(STDIN_FILENO, TCSANOW, &rawCopy)
        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        }

        // Hide cursor
        print("\u{001B}[?25l", terminator: "")
        defer {
            print("\u{001B}[?25h", terminator: "")
        }

        // Draw initial UI
        var selectedIndex = 0
        // 005: "second Enter on preset shows item list before apply" — the first
        // Enter on a preset previews it; Enter again on the same, still-highlighted
        // preset applies it. Moving the selection cancels the preview.
        var previewIndex: Int? = nil
        drawUI(selectedIndex: selectedIndex, previewIndex: previewIndex)

        // Handle input
        while true {
            let key = readKey()
            switch key {
            case .up:
                selectedIndex = max(0, selectedIndex - 1)
                previewIndex = nil
                drawUI(selectedIndex: selectedIndex, previewIndex: previewIndex)
            case .down:
                selectedIndex = min(presets.count - 1, selectedIndex + 1)
                previewIndex = nil
                drawUI(selectedIndex: selectedIndex, previewIndex: previewIndex)
            case .enter:
                if previewIndex == selectedIndex {
                    return presets[selectedIndex]
                }
                previewIndex = selectedIndex
                drawUI(selectedIndex: selectedIndex, previewIndex: previewIndex)
            case .q, .esc, .eof:
                return nil
            case .number(let n):
                if n > 0 && n <= presets.count {
                    return presets[n - 1]
                }
            default:
                break
            }
        }
    }

    /// Draw the UI.
    private func drawUI(selectedIndex: Int, previewIndex: Int?) {
        // Clear screen
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Draw title
        print("DockSwap Presets", terminator: "")
        print("\u{001B}[1;34m\u{001B}[47m", terminator: "")
        print("\u{001B}[0m\n", terminator: "")

        // Draw items (name + item count, ticket 005)
        for (index, preset) in presets.enumerated() {
            if index == selectedIndex {
                print("\u{001B}[7m", terminator: "") // Reverse video
            }
            let itemCount = preset.apps.count + preset.others.count
            print("[\u{001B}[1;33m\(index + 1)\u{001B}[0m] \(preset.name)  \(itemCount) items")
            if index == selectedIndex {
                print("\u{001B}[0m", terminator: "") // Reset
            }
        }

        if let previewIndex, previewIndex == selectedIndex {
            let preset = presets[previewIndex]
            print("\n\(preset.name):")
            for item in preset.apps + preset.others {
                print("  \(item.description)")
            }
            print("\nEnter again to apply, arrows to cancel preview, q/Esc to quit", terminator: "")
        } else {
            print("\nUse arrow keys to navigate, Enter to preview, q/Esc to cancel", terminator: "")
        }
    }

    /// Read a key from stdin.
    private func readKey() -> Key {
        let c = getchar()
        if c == EOF {
            return .eof
        } else if c == 27 {
            let next = getchar()
            if next == 91 {
                let code = getchar()
                switch code {
                case 65: return .up
                case 66: return .down
                default: return .unknown
                }
            } else {
                return .esc
            }
        } else if c == 10 {
            return .enter
        } else if c == 113 {
            return .q
        } else if c >= 49 && c <= 57 {
            return .number(Int(c) - 48)
        } else {
            return .unknown
        }
    }
}

/// Keys that the picker can handle.
private enum Key {
    // .eof is distinct from .unknown: an unrecognized real keypress is safe to
    // ignore and keep reading, but getchar() returning EOF (stdin closed/not a
    // tty) means there is nothing left to read — treating that as .unknown
    // spun the main loop at 100% CPU forever instead of exiting.
    case up, down, enter, q, esc, number(Int), unknown, eof
}
