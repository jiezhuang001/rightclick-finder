import Cocoa

// 宿主 App：一个常驻菜单栏的小程序，主要作用是作为扩展的容器。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "RightClick"
        let menu = NSMenu()
        menu.addItem(withTitle: "退出 RightClick", action: #selector(quit), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
