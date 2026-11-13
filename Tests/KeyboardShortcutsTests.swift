import AppKit

@main
struct KeyboardShortcutsTests {
    static func main() {
        for expanded in [false, true] {
            for (code, expected) in [(UInt16(98), PlayerAction.previous), (100, .togglePlayback), (101, .next)] {
                precondition(KeyboardShortcuts.action(keyCode: code, characters: nil, modifiers: [], expanded: expanded) == expected)
                precondition(KeyboardShortcuts.action(keyCode: code, characters: nil, modifiers: [.function], expanded: expanded) == expected)
            }
            precondition(KeyboardShortcuts.action(keyCode: 12, characters: "q", modifiers: .command, expanded: expanded) == .quit)
            precondition(KeyboardShortcuts.action(keyCode: 12, characters: "q", modifiers: [.command, .shift], expanded: expanded) == nil)
        }
        precondition(KeyboardShortcuts.action(keyCode: 38, characters: "j", modifiers: [], expanded: false) == .volumeDown)
        precondition(KeyboardShortcuts.action(keyCode: 40, characters: "k", modifiers: [], expanded: false) == .volumeUp)
        precondition(KeyboardShortcuts.action(keyCode: 38, characters: "j", modifiers: [], expanded: true) == nil)
        precondition(KeyboardShortcuts.action(keyCode: 40, characters: "k", modifiers: .control, expanded: false) == nil)
        precondition(KeyboardShortcuts.action(keyCode: 53, characters: nil, modifiers: [], expanded: true) == .toggleSize)
        precondition(PlayerAction.volumeDown.allowsRepeat && !PlayerAction.next.allowsRepeat)
        print("Native keyboard mapping checks passed.")
    }
}
