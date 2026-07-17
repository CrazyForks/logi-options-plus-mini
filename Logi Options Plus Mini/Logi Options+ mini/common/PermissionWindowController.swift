import AppKit
import SwiftUI

/// 权限提示窗口控制器
/// 使用独立的 NSWindow 展示权限状态
final class PermissionWindowController {
    static let shared = PermissionWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    /// 显示权限提示窗口
    func showWindow() {
        // 如果窗口已存在，先关闭
        window?.close()
        
        // 创建 SwiftUI 视图
        let contentView = PermissionAlertView { [weak self] in
            self?.closeWindow()
        }
        
        // 创建窗口（使用透明背景以支持玻璃效果）
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = String(localized: "Permission Required")
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        self.window = window
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 关闭窗口
    func closeWindow() {
        window?.close()
        window = nil
    }
}
