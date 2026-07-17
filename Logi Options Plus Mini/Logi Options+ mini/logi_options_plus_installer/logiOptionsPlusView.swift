import SwiftUI
import SwiftGlass

struct LogiOptionsPlusView: View {
    @EnvironmentObject var logStore: LogStore
    @State private var isLoading: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var isFixing: Bool = false
    @State private var showFixConfirmation: Bool = false
    @State private var updateTextIsLoading: Bool = false
    @State private var installedVersionUpdateLoading: Bool = false
    @ObservedObject var controller: InstallerController
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var logiOptionsPlusLatestVersion: String = ""
    @AppStorage("showUninstallButton") private var showUninstallButton: Bool = false
    @State private var isFeatureListHovered: Bool = false

    init(controller: InstallerController) {
        self.controller = controller
    }
    
    func fetchLatestVersion() async {
        self.logiOptionsPlusLatestVersion = await getLogiOptionsPlusLatestVersion()
    }
    
    @ViewBuilder
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(alignment: .leading, spacing: 10) {
                Text("Select the features to install:")
                    .font(.headline)
                
                List {
                    ForEach(controller.features, id: \.self) { feature in
                        Toggle(feature.description, isOn: Binding(
                            get: { controller.selectedFeatures.contains(feature) },
                            set: { isSelected in
                                if isSelected {
                                    controller.selectedFeatures.insert(feature)
                                } else {
                                    controller.selectedFeatures.remove(feature)
                                }
                                controller.saveSelectedFeatures()
                            }
                        ))
                        .help(feature.help)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.thinMaterial)
                .frame(minHeight: 320)
                .cornerRadius(10)
                .glass(
                    radius: 10,
                    color: .gray
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFeatureListHovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isFeatureListHovered ? 1.002 : 1.0, anchor: .top)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFeatureListHovered)
                .onHover { hovering in
                    isFeatureListHovered = hovering
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Logi Options+ installed version: \(installedVersionUpdateLoading ? "Updating..." : controller.installedVersion)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                if !installedVersionUpdateLoading {
                                    Task {
                                        installedVersionUpdateLoading = true
                                        try await Task.sleep(nanoseconds: 100_000_000)
                                        controller.updateInstalledVersion()
                                        installedVersionUpdateLoading = false
                                    }
                                }
                            }
                        if self.logiOptionsPlusLatestVersion != "" && self.logiOptionsPlusLatestVersion != "Unknown" {
                                                    
                            Text("Logi Options+ latest stable version: \(self.logiOptionsPlusLatestVersion)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .onTapGesture {
                                    if !updateTextIsLoading {
                                        Task {
                                            updateTextIsLoading = true
                                            self.logiOptionsPlusLatestVersion = "Updating..."
                                            await fetchLatestVersion()
                                            updateTextIsLoading = false
                                        }
                                    }
                                }
                        }
                    }
                        
                    Spacer()
                    HStack(spacing: 0) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.5)
                            } else {
                                Button(action: {
                                    Task {
                                        isLoading = true
                                        await controller.install()
                                        isLoading = false
                                    }
                                }) {
                                    Text("Install/Reinstall")
                                        .font(.headline)
                                }
                                .buttonStyle(.borderedProminent)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                .glass(
                                    radius: 20,
                                    color: .blue,
                                    material: .regularMaterial,
                                    gradientOpacity: 0.7,
                                    shadowColor: .blue,
                                    shadowRadius: 10
                                )
                                .disabled(isUninstalling || isFixing)
                            }
                        }
                        .frame(width: 140, height: 20)

                        if showUninstallButton {
                            ZStack {
                                if isUninstalling {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.5)
                                } else {
                                    let isDisabled = isLoading || isFixing
                                    let buttonColor: Color = isDisabled ? .pink.opacity(0.4) : .red
                                    
                                    Button(action: {
                                        Task {
                                            isUninstalling = true
                                            await controller.uninstall()
                                            isUninstalling = false
                                        }
                                    }) {
                                        Text("Uninstall")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(buttonColor)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(5)
                                    .glass(
                                        radius: 20,
                                        color: buttonColor,
                                        material: .regularMaterial,
                                        gradientOpacity: isDisabled ? 0.3 : 0.7,
                                        shadowColor: buttonColor,
                                        shadowRadius: isDisabled ? 5 : 10
                                    )
                                    .disabled(isDisabled)
                                }
                            }
                            .frame(width: 60, height: 20)
                        }

                        ZStack {
                            if isFixing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.5)
                            } else {
                                let isDisabled = isLoading || isUninstalling
                                let buttonColor: Color = isDisabled ? .gray.opacity(0.4) : .gray
                                
                                Menu {
                                    Button {
                                        showFixConfirmation = true
                                    } label: {
                                        Label(String(localized: "Fix Certificate Issue"), systemImage: "checkmark.seal")
                                    }
                                    
                                    Button {
                                        Task {
                                            isFixing = true
                                            await controller.scanJavaScriptErrorFiles()
                                            isFixing = false
                                        }
                                    } label: {
                                        Label(String(localized: "Fix JavaScript Error"), systemImage: "exclamationmark.triangle")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wrench.and.screwdriver")
                                            .symbolEffect(.bounce, value: isFixing)
                                    }
                                    .font(.headline)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 44, height: 28)
                                .background(buttonColor)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                .glass(
                                    radius: 20,
                                    color: buttonColor,
                                    material: .regularMaterial,
                                    gradientOpacity: isDisabled ? 0.3 : 0.7,
                                    shadowColor: buttonColor,
                                    shadowRadius: isDisabled ? 5 : 10
                                )
                                .disabled(isDisabled)
                                .confirmationDialog(String(localized: "Run Fix Tool"), isPresented: $showFixConfirmation) {
                                    Button(String(localized: "Confirm")) {
                                        Task {
                                            isFixing = true
                                            await controller.fix()
                                            isFixing = false
                                        }
                                    }
                                    Button(String(localized: "View Details")) {
                                        openURL(URL(string: "https://support.logi.com/hc/zh-cn/articles/37493733117847-Options-and-G-HUB-macOS-Certificate-Issue")!)
                                    }
                                    Button(String(localized: "Cancel"), role: .cancel) { }
                                } message: {
                                    Text("The fix operation launches the official repair tool to resolve startup issues.\n\nDetail:\n https://support.logi.com/hc/zh-cn/articles/37493733117847-Options-and-G-HUB-macOS-Certificate-Issue")
                                }
                                .confirmationDialog(String(localized: "Confirm Delete Files"), isPresented: $controller.showDeleteFilesConfirmation) {
                                    Button(String(localized: "Delete"), role: .destructive) {
                                        Task {
                                            isFixing = true
                                            await controller.confirmDeleteFiles()
                                            isFixing = false
                                        }
                                    }
                                    Button(String(localized: "View Details")) {
                                        openURL(URL(string: "https://support.logi.com/hc/zh-cn/articles/37493733117847-Options-and-G-HUB-macOS-Certificate-Issue")!)
                                    }
                                    Button(String(localized: "Cancel"), role: .cancel) {
                                        controller.filesToDelete = []
                                    }
                                } message: {
                                    Text("The following \(controller.filesToDelete.count) file(s) will be deleted:\n\n\(controller.filesToDelete.map { $0.lastPathComponent }.joined(separator: "\n"))\n\nThese corrupted config backup files may cause JavaScript errors in Logi Options+.")
                                }
                                .confirmationDialog(String(localized: "Fix JavaScript Error"), isPresented: $controller.showNoFilesToDeleteAlert) {
                                    Button(String(localized: "View Details")) {
                                        openURL(URL(string: "https://support.logi.com/hc/zh-cn/articles/37493733117847-Options-and-G-HUB-macOS-Certificate-Issue")!)
                                    }
                                    Button(String(localized: "OK"), role: .cancel) { }
                                } message: {
                                    Text("No corrupted config backup files found.\n\nIf you're still experiencing JavaScript errors, please visit the official support page for more solutions.")
                                }
                            }
                        }
                        .frame(width: 60, height: 20)
                    }
                }
                
                Divider()
                
                // Installation progress indicator - always visible, click to toggle activity log drawer
                InstallationProgressView(controller: controller, showActivityLog: $controller.showActivityLog)
                
                Spacer(minLength: 0)
            }
            .padding()
            .zIndex(0)
            
            // Activity log backdrop (kept alive to avoid disappearing before drawer removal finishes)
            Color.black
                .opacity(controller.showActivityLog ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(controller.showActivityLog)
                .onTapGesture {
                    guard controller.showActivityLog else { return }
                    withAnimation(.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.24)) {
                        controller.showActivityLog = false
                    }
                }
                .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.32), value: controller.showActivityLog)
                .zIndex(10)

            // Activity log drawer overlay
            if controller.showActivityLog {
                // Drawer panel
                ActivityLogDrawerView(
                    logStore: logStore,
                    colorScheme: colorScheme,
                    showActivityLog: $controller.showActivityLog
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom)
                            .combined(with: .scale(scale: 0.92, anchor: .bottom))
                    )
                )
                .zIndex(20)
            }
        }
        .frame(minWidth: 600, minHeight: 460, maxHeight: 460)
        .task {
            controller.loadSelectedFeatures()
            await fetchLatestVersion()
        }
    }
}

/// Activity log drawer view
struct ActivityLogDrawerView: View {
    @ObservedObject var logStore: LogStore
    let colorScheme: ColorScheme
    @Binding var showActivityLog: Bool
    
    @State private var isHoveringHandle: Bool = false
    @State private var dragOffsetY: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Drawer handle - tap to close
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(isHoveringHandle ? Color.primary.opacity(0.6) : Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .scaleEffect(isHoveringHandle ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringHandle)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringHandle = hovering
            }
            .onTapGesture {
                withAnimation(.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.24)) {
                    showActivityLog = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        dragOffsetY = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 0 {
                            withAnimation(.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.24)) {
                                dragOffsetY = 0
                                showActivityLog = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                dragOffsetY = 0
                            }
                        }
                    }
            )
            .help(String(localized: "Click to close"))
            
            // Header - tap "Activity Log" to clear
            HStack {
                Button(action: {
                    logStore.clearMessages()
                }) {
                    Text("Activity Log")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Click to clear log"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Log content
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 2) {
                        ForEach(logStore.messages) { message in
                            Text(message.content)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                        }
                    }
                    .id("scrollId")
                    .onChange(of: logStore.messages) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("scrollId", anchor: .bottom)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: 200)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .offset(y: dragOffsetY)
    }
}

struct LogiOptionsPlusViewWrapper: View {
    @StateObject private var logStore = LogStore()
    var body: some View {
        LogiOptionsPlusView(controller: InstallerController())
            .environmentObject(logStore)
    }
}

#Preview{
    LogiOptionsPlusViewWrapper()
}
