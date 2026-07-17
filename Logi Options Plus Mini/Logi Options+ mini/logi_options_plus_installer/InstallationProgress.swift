import SwiftUI
import SwiftGlass

/// Installation progress step enumeration
enum InstallationStep: Int, CaseIterable {
    case idle = 0
    case downloading = 1
    case extracting = 2
    case backup = 3
    case uninstalling = 4
    case restoring = 5
    case installing = 6
    case completed = 7
    case failed = -1
    
    var title: String {
        switch self {
        case .idle: return String(localized: "Ready")
        case .downloading: return String(localized: "Download")
        case .extracting: return String(localized: "Extract")
        case .backup: return String(localized: "Backup")
        case .uninstalling: return String(localized: "Uninstall")
        case .restoring: return String(localized: "Restore")
        case .installing: return String(localized: "Install")
        case .completed: return String(localized: "Done")
        case .failed: return String(localized: "Failed")
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .downloading: return "arrow.down.circle"
        case .extracting: return "archivebox"
        case .backup: return "doc.on.doc"
        case .uninstalling: return "trash"
        case .restoring: return "arrow.counterclockwise"
        case .installing: return "shippingbox"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    /// Steps to display in progress bar (excluding idle and failed)
    static var displaySteps: [InstallationStep] {
        [.downloading, .extracting, .backup, .uninstalling, .restoring, .installing, .completed]
    }
    
    /// Steps to display for install operation
    static var installSteps: [InstallationStep] {
        [.downloading, .extracting, .backup, .uninstalling, .restoring, .installing, .completed]
    }
    
    /// Steps to display for uninstall operation
    static var uninstallSteps: [InstallationStep] {
        [.downloading, .extracting, .uninstalling, .completed]
    }
    
    /// Steps to display for fix operation
    static var fixSteps: [InstallationStep] {
        [.downloading, .extracting, .installing, .completed]
    }
    
    /// Get steps based on operation mode
    static func stepsFor(mode: OperationMode) -> [InstallationStep] {
        switch mode {
        case .install:
            return installSteps
        case .uninstall:
            return uninstallSteps
        case .fix:
            return fixSteps
        case .idle:
            return displaySteps
        }
    }
}

/// Progress bar node view
struct ProgressNode: View {
    let step: InstallationStep
    let currentStep: InstallationStep
    let failedAtStep: InstallationStep?
    let isActive: Bool
    let isCompleted: Bool
    
    @State private var pulseAnimation = false
    
    var nodeColor: Color {
        // Only the failed step turns red
        if currentStep == .failed, let failedStep = failedAtStep, step == failedStep {
            return .red
        }
        if isCompleted {
            return .green
        }
        if isActive {
            return .blue
        }
        return .gray.opacity(0.4)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .fill(nodeColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                // Active pulse animation
                if isActive && currentStep != .failed {
                    Circle()
                        .stroke(nodeColor, lineWidth: 2)
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)
                }
                
                // Icon
                Image(systemName: isCompleted ? "checkmark" : step.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCompleted || isActive ? .white : nodeColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isCompleted || isActive ? nodeColor : Color.clear)
                            .frame(width: 24, height: 24)
                    )
            }
            
            // Step title
            Text(step.title)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? nodeColor : .secondary)
                .lineLimit(1)
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                pulseAnimation = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
    }
}

/// Progress connector line between nodes
struct ProgressConnector: View {
    let isCompleted: Bool
    let isActive: Bool
    let isFailed: Bool
    
    var lineColor: Color {
        if isFailed {
            return .red.opacity(0.3)
        }
        if isCompleted {
            return .green
        }
        if isActive {
            return .blue.opacity(0.5)
        }
        return .gray.opacity(0.2)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 2)
                
                // Progress line
                Rectangle()
                    .fill(lineColor)
                    .frame(width: isCompleted || isFailed ? geometry.size.width : (isActive ? geometry.size.width * 0.5 : 0), height: 2)
                    .animation(.easeInOut(duration: 0.3), value: isCompleted)
                    .animation(.easeInOut(duration: 0.3), value: isActive)
            }
        }
        .frame(height: 2)
    }
}

/// Main installation progress view
struct InstallationProgressView: View {
    @ObservedObject var controller: InstallerController
    @Binding var showActivityLog: Bool
    @State private var isHovered = false
    
    /// Get the steps to display based on current operation mode
    private var displaySteps: [InstallationStep] {
        InstallationStep.stepsFor(mode: controller.operationMode)
    }
    
    /// Check if a step is completed based on its position in the current step sequence
    private func isStepCompleted(_ step: InstallationStep, at index: Int) -> Bool {
        guard controller.currentStep != .idle else { return false }
        // If current step is completed, all steps are completed
        if controller.currentStep == .completed {
            return true
        }
        // When failed, steps before the failed step are considered completed
        if controller.currentStep == .failed, let failedStep = controller.failedAtStep {
            guard let failedIndex = displaySteps.firstIndex(of: failedStep) else { return false }
            return index < failedIndex
        }
        guard let currentIndex = displaySteps.firstIndex(of: controller.currentStep) else { return false }
        return index < currentIndex
    }
    
    /// Check if a step is currently active
    private func isStepActive(_ step: InstallationStep) -> Bool {
        // When failed, the failed step is considered active
        if controller.currentStep == .failed, let failedStep = controller.failedAtStep {
            return step == failedStep
        }
        return step == controller.currentStep && controller.currentStep != .idle
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(displaySteps.enumerated()), id: \.element) { index, step in
                let isCompleted = isStepCompleted(step, at: index)
                let isActive = isStepActive(step)
                
                ProgressNode(
                    step: step,
                    currentStep: controller.currentStep,
                    failedAtStep: controller.failedAtStep,
                    isActive: isActive,
                    isCompleted: isCompleted
                )
                .frame(width: 50)
                
                if index < displaySteps.count - 1 {
                    let nextStep = displaySteps[index + 1]
                    let connectorCompleted = isStepCompleted(nextStep, at: index + 1)
                    // Connector is active when the next node is the current active step
                    let connectorActive = isStepActive(nextStep) && controller.currentStep != .failed
                    // Connector is failed when the next node is the failed step
                    let connectorFailed = controller.currentStep == .failed && nextStep == controller.failedAtStep
                    
                    ProgressConnector(
                        isCompleted: connectorCompleted,
                        isActive: connectorActive,
                        isFailed: connectorFailed
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .cornerRadius(12)
        .glass(
            radius: 12,
            color: .gray
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: controller.currentStep)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            let willShowActivityLog = !showActivityLog
            let animation = willShowActivityLog
                ? Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)
                : .timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.24)
            withAnimation(animation) {
                showActivityLog.toggle()
            }
        }
        .help(showActivityLog ? String(localized: "Click to hide activity log") : String(localized: "Click to show activity log"))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var controller = InstallerController()
        @State private var showActivityLog = false
        
        var body: some View {
            VStack(spacing: 20) {
                InstallationProgressView(controller: controller, showActivityLog: $showActivityLog)
                
                Text("Activity Log: \(showActivityLog ? "Visible" : "Hidden")")
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Start") {
                        controller.currentStep = .downloading
                    }
                    Button("Next") {
                        if let nextStep = InstallationStep(rawValue: controller.currentStep.rawValue + 1) {
                            controller.currentStep = nextStep
                        }
                    }
                    Button("Failed") {
                        controller.failedAtStep = controller.currentStep
                        controller.currentStep = .failed
                    }
                    Button("Reset") {
                        controller.currentStep = .idle
                        controller.failedAtStep = nil
                    }
                }
            }
            .padding()
            .frame(width: 500)
        }
    }
    
    return PreviewWrapper()
}
