import SwiftUI
import SwiftGlass

/// 权限提示视图
/// 当缺少必要权限时显示，引导用户授权
struct PermissionAlertView: View {
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with glass effect
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text("Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This application requires the following permissions to function properly:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            AppManagementRowView(
                action: {
                    PermissionChecker.shared.openAppManagementSettings()
                }
            )
            
            // Footer buttons with glass effect
            HStack(spacing: 12) {
                Button("Later") {
                    onDismiss?()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(VisualEffectView().ignoresSafeArea())
    }
}

/// App Management 权限行视图
/// 由于 App Management 权限无法获取状态，只能在使用时验证，因此不显示已授权/未授权状态
struct AppManagementRowView: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Info icon (neutral status)
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Management")
                        .font(.headline)
                    
                    Text("Required to install and manage applications")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Grant button with glass effect
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .cornerRadius(12)
        .glass(
            radius: 12,
            color: .blue,
            material: .thinMaterial,
            gradientOpacity: 0.4,
            shadowRadius: 6
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.blue.opacity(0.4) : Color.blue.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        // App icon for drag and drop authorization
        VStack(spacing: 8) {
            DraggableAppIconView()
            Text("Drag this app icon to App Management list for quick authorization:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
}

/// 可拖放的 App 图标视图
struct DraggableAppIconView: View {
    @State private var isDragging = false
    @State private var isHovered = false
    
    var body: some View {
        // App icon only with glass effect
        if let appIcon = NSApp.applicationIconImage {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: isDragging ? 12 : 6, x: 0, y: isDragging ? 8 : 4)
                .scaleEffect(isDragging ? 1.15 : (isHovered ? 1.05 : 1.0))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .glass(
                    radius: 12,
                    color: .white,
                    material: .ultraThinMaterial,
                    gradientOpacity: isHovered ? 0.6 : 0.4,
                    shadowRadius: isHovered ? 8 : 4
                )
                .draggable(appFileURL) {
                    // Drag preview
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                }
                .onDrag {
                    isDragging = true
                    return NSItemProvider(object: appFileURL as NSURL)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
    
    /// 获取当前应用的文件 URL
    private var appFileURL: URL {
        URL(fileURLWithPath: Bundle.main.bundlePath)
    }
}

#Preview {
    PermissionAlertView(
        onDismiss: {}
    )
}
