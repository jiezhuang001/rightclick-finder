import Cocoa
import FinderSync
import Darwin

struct FileTemplate {
    let title: String
    let resource: String   // 模板文件名（不含扩展名）
    let ext: String        // 扩展名
    let base: String       // 新建时的默认文件名（不含扩展名）
}

let newFileTemplates: [FileTemplate] = [
    FileTemplate(title: "Word 文档", resource: "Word", ext: "docx", base: "新建 Word 文档"),
    FileTemplate(title: "Excel 表格", resource: "Excel", ext: "xlsx", base: "新建 Excel 表格"),
    FileTemplate(title: "PPT 演示", resource: "PPT", ext: "pptx", base: "新建 PPT 演示"),
    FileTemplate(title: "文本文档", resource: "TXT", ext: "txt", base: "新建文本文档"),
    FileTemplate(title: "Markdown", resource: "Markdown", ext: "md", base: "新建 Markdown"),
    FileTemplate(title: "XML", resource: "XML", ext: "xml", base: "新建 XML"),
    FileTemplate(title: "RTF", resource: "RTF", ext: "rtf", base: "新建 RTF"),
]

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // 沙盒里 FileManager 返回的是容器路径，这里用 getpwuid 拿真实主目录，
        // 否则扩展会监控容器里不存在的目录，菜单永远不出现。
        let homePath: String
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            homePath = String(cString: dir)
        } else {
            homePath = NSHomeDirectory()
        }
        let home = URL(fileURLWithPath: homePath, isDirectory: true)
        let desktop = home.appendingPathComponent("Desktop")
        let downloads = home.appendingPathComponent("Downloads")
        let documents = home.appendingPathComponent("Documents")
        FIFinderSyncController.default().directoryURLs = Set([home, desktop, downloads, documents])
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "RightClick")

        // 「新建文件」子菜单
        let newFile = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        newFile.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        let newFileMenu = NSMenu(title: "新建文件")
        for (index, t) in newFileTemplates.enumerated() {
            newFileMenu.addItem(makeItem(for: t, index: index))
        }
        newFile.submenu = newFileMenu
        menu.addItem(newFile)

        return menu
    }

    private func makeItem(for template: FileTemplate, index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: template.title, action: #selector(createFromTemplate(_:)), keyEquivalent: "")
        item.target = self
        // 菜单会跨进程（XPC）传给 Finder 显示，representedObject 无法序列化会丢失。
        // tag（整数）跨进程安全，用索引 + 1 标识模板（0 表示未设置）。
        item.tag = index + 1
        return item
    }

    // 按模板在当前 Finder 目录里新建文件。
    @objc private func createFromTemplate(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        guard index >= 0 && index < newFileTemplates.count else {
            NSLog("[RightClick] 无效的菜单 tag: %ld", sender.tag)
            return
        }
        let template = newFileTemplates[index]

        guard let dir = FIFinderSyncController.default().targetedURL() else {
            NSLog("[RightClick] 无法获取当前 Finder 目录")
            return
        }

        let dest = makeUnique(dir.appendingPathComponent(template.base + "." + template.ext))
        let bundle = Bundle(for: FinderSync.self)

        if let src = bundle.url(forResource: template.resource, withExtension: template.ext) {
            do {
                try FileManager.default.copyItem(at: src, to: dest)
                NSLog("[RightClick] 已创建: %@", dest.path)
            } catch {
                NSLog("[RightClick] 复制模板失败: %@", error.localizedDescription)
            }
        } else {
            NSLog("[RightClick] 找不到模板资源 %@.%@，改为创建空文件", template.resource, template.ext)
            let ok = FileManager.default.createFile(atPath: dest.path, contents: Data())
            NSLog("[RightClick] 创建空文件 %@: %@", ok ? "成功" : "失败", dest.path)
        }
    }

    private func makeUnique(_ url: URL) -> URL {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var candidate = url
        var i = 2
        while fm.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem) \(i)" : "\(stem) \(i).\(ext)"
            candidate = dir.appendingPathComponent(name)
            i += 1
        }
        return candidate
    }
}
