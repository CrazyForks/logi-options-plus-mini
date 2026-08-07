import AppKit
import SwiftUI

/// 权限提示窗口控制器
/// 使用独立的 NSWindow 展示权限状态
final class PermissionWindowController: NSObject {
    static let shared = PermissionWindowController()
    
    private var window: NSWindow?
    private var positioningTimer: Timer?
    private let windowSpacing: CGFloat = 8
    
    private override init() {
        super.init()
    }
    
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
        window.level = .normal
        window.delegate = self
        
        self.window = window
        startPositioningNextToSystemSettings()
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 关闭窗口
    func closeWindow() {
        positioningTimer?.invalidate()
        positioningTimer = nil
        window?.close()
        window = nil
    }

    /// 系统设置启动和切换页面需要一点时间，因此在权限窗口显示期间持续跟踪其位置。
    private func startPositioningNextToSystemSettings() {
        positioningTimer?.invalidate()
        positionNextToSystemSettingsIfPossible()

        positioningTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.positionNextToSystemSettingsIfPossible()
        }
    }

    /// 优先紧贴系统设置右侧；空间不足时放到左侧，确保不会遮挡系统设置。
    private func positionNextToSystemSettingsIfPossible() {
        guard let window,
              let settingsFrame = systemSettingsWindowFrame(),
              let targetScreen = screen(containingMostOf: settingsFrame) else {
            return
        }

        let visibleFrame = targetScreen.visibleFrame
        let windowSize = window.frame.size
        let topAlignedY = min(
            max(settingsFrame.maxY - windowSize.height, visibleFrame.minY),
            visibleFrame.maxY - windowSize.height
        )
        let rightX = settingsFrame.maxX + windowSpacing

        if rightX + windowSize.width <= visibleFrame.maxX {
            window.setFrameOrigin(NSPoint(x: rightX, y: topAlignedY))
            return
        }

        // 多显示器环境下，优先使用系统设置右侧的相邻屏幕。
        if let rightScreen = NSScreen.screens
            .filter({ $0.visibleFrame.minX >= settingsFrame.maxX })
            .min(by: { $0.visibleFrame.minX < $1.visibleFrame.minX }) {
            let y = min(
                max(settingsFrame.maxY - windowSize.height, rightScreen.visibleFrame.minY),
                rightScreen.visibleFrame.maxY - windowSize.height
            )
            window.setFrameOrigin(NSPoint(x: rightScreen.visibleFrame.minX, y: y))
            return
        }

        let leftX = settingsFrame.minX - windowSpacing - windowSize.width
        if leftX >= visibleFrame.minX {
            window.setFrameOrigin(NSPoint(x: leftX, y: topAlignedY))
        }
    }

    /// 获取系统设置最主要的可见窗口，并把 Quartz 的左上角坐标转换为 AppKit 坐标。
    private func systemSettingsWindowFrame() -> NSRect? {
        guard let systemSettings = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.systempreferences"
        ).first,
              let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return nil
        }

        let quartzFrame = windowList.compactMap { windowInfo -> CGRect? in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == systemSettings.processIdentifier,
                  let layer = windowInfo[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary else {
                return nil
            }

            var bounds = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &bounds),
                  bounds.width > 100,
                  bounds.height > 100 else {
                return nil
            }
            return bounds
        }
        .max(by: { $0.width * $0.height < $1.width * $1.height })

        guard let quartzFrame, let mainScreen = NSScreen.screens.first else {
            return nil
        }

        return NSRect(
            x: quartzFrame.minX,
            y: mainScreen.frame.maxY - quartzFrame.maxY,
            width: quartzFrame.width,
            height: quartzFrame.height
        )
    }

    private func screen(containingMostOf frame: NSRect) -> NSScreen? {
        NSScreen.screens.max {
            $0.frame.intersection(frame).width * $0.frame.intersection(frame).height
                < $1.frame.intersection(frame).width * $1.frame.intersection(frame).height
        }
    }
}

extension PermissionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        positioningTimer?.invalidate()
        positioningTimer = nil
        window = nil
    }
}
