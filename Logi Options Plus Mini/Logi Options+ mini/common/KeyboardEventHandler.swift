//
//  KeyboardEventHandler.swift
//  Logi Options Plus Mini
//
//  Created by Qetesh Wong on 1/3/2025.
//

import SwiftUI

// MARK: - 窗口管理工具
struct WindowManager {
    /// 关闭当前活跃窗口
    static func closeCurrentWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }
}

// MARK: - 键盘事件处理组件
struct KeyboardEventView: NSViewRepresentable {
    let onKeyDown: (UInt16) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardEventNSView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyboardEventNSView: NSView {
    var onKeyDown: ((UInt16) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

// MARK: - View 扩展，提供便利方法
extension View {
    /// 添加 Esc 键关闭窗口功能
    func escapeKeyToClose() -> some View {
        self.background(
            KeyboardEventView { keyCode in
                if keyCode == 53 { // Esc key code
                    WindowManager.closeCurrentWindow()
                }
            }
        )
    }
    
    /// 添加自定义键盘事件处理
    func onKeyDown(_ action: @escaping (UInt16) -> Void) -> some View {
        self.background(
            KeyboardEventView(onKeyDown: action)
        )
    }
}

// MARK: - 常用键码常量
struct KeyCodes {
    static let escape: UInt16 = 53
    static let enter: UInt16 = 36
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let tab: UInt16 = 48
}
