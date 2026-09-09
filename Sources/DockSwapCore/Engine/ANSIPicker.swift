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
        drawUI(selectedIndex: selectedIndex)

        // Handle input
        while true {
            let key = readKey()
            switch key {
            case .up:
                selectedIndex = max(0, selectedIndex - 1)
                drawUI(selectedIndex: selectedIndex)
            case .down:
                selectedIndex = min(presets.count - 1, selectedIndex + 1)
                drawUI(selectedIndex: selectedIndex)
            case .enter:
                return presets[selectedIndex]
            case .q, .esc:
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
    private func drawUI(selectedIndex: Int) {
        // Clear screen
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        // Draw title
        print("DockSwap Presets", terminator: "")
        print("\u{001B}[1;34m\u{001B}[47m", terminator: "")
        print("\u{001B}[0m\n", terminator: "")

        // Draw items
        for (index, preset) in presets.enumerated() {
            if index == selectedIndex {
                print("\u{001B}[7m", terminator: "") // Reverse video
            }
            print("[\u{001B}[1;33m\(index + 1)\u{001B}[0m] \(preset.name)")
            if index == selectedIndex {
                print("\u{001B}[0m", terminator: "") // Reset
            }
        }

        // Draw instructions
        print("\nUse arrow keys to navigate, Enter to select, q/Esc to cancel", terminator: "")
    }

    /// Read a key from stdin.
    private func readKey() -> Key {
        let c = getchar()
        if c == 27 {
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
    case up, down, enter, q, esc, number(Int), unknown
}
