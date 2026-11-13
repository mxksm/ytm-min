import AppKit

enum PlayerAction: String {
    case previous, next, togglePlayback, play, pause, volumeUp, volumeDown
    case toggleSize, toggleAutoHide, toggleTransparency, snap, quit, reload
    var allowsRepeat: Bool { self == .volumeUp || self == .volumeDown }
}

enum KeyboardShortcuts {
    static func action(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags,
                       expanded: Bool) -> PlayerAction? {
        let modifiers = modifiers.intersection([.command, .control, .option, .shift])
        let key = characters?.lowercased() ?? ""
        if modifiers == .command {
            return ["e": .toggleSize, "s": .snap, "t": .toggleTransparency, "q": .quit, "r": .reload][key]
        }
        guard modifiers.isEmpty else { return nil }
        switch keyCode {
        case 98: return .previous // F7 in standard function-key mode
        case 100: return .togglePlayback // F8
        case 101: return .next // F9
        case 53 where expanded: return .toggleSize
        default: break
        }
        // Expanded-window letters are handled in the DOM to preserve text input.
        guard !expanded else { return nil }
        switch keyCode {
        case 36, 49: return .togglePlayback
        case 123: return .previous
        case 124: return .next
        default: return ["j": .volumeDown, "k": .volumeUp, "-": .volumeDown, "=": .volumeUp,
                         "h": .previous, "l": .next, "p": .togglePlayback, "e": .toggleSize,
                         "f": .toggleAutoHide, "s": .snap, "t": .toggleTransparency, "q": .quit][key]
        }
    }
}
