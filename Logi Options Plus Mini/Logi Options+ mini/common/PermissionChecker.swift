import AppKit
import Combine
import Foundation
import Logging

/// 权限检查结果通知
extension Notification.Name {
    static let permissionCheckCompleted = Notification.Name("permissionCheckCompleted")
}

/// macOS 权限检查器
/// 用于打开系统设置页面
final class PermissionChecker: ObservableObject {
    static let shared = PermissionChecker()
    
    private init() {}
    
    /// 检查全盘访问权限
    /// 通过尝试读取 TCC 数据库来判断是否有全盘访问权限
    var hasFullDiskAccess: Bool {
        // TCC.db 是受保护的系统文件，只有获得全盘访问权限才能读取
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.isReadableFile(atPath: tccPath)
    }
    
    /// 打开系统设置的隐私与安全页面
    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
    
    /// 打开全盘访问设置页面
    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    /// 打开 App 管理设置页面
    func openAppManagementSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles")!
        NSWorkspace.shared.open(url)
    }
    
    /// 显示权限提示窗口
    func showPermissionWindow() {
        PermissionWindowController.shared.showWindow()
    }
}
