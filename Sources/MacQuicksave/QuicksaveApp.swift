import AppKit

@main
struct QuicksaveApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = QuicksaveAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
