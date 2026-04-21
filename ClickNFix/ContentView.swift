import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var viewModel: ClickNFixViewModel
    @State private var pendingFix: FixType?
    @State private var showTerminal = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel)

            ScrollView {
                VStack(spacing: 0) {
                    OptionsBarView(viewModel: viewModel)
                    Divider()

                    ForEach(FixCategory.allCases, id: \.rawValue) { category in
                        let fixes = FixType.fixes(for: category)
                        if !fixes.isEmpty {
                            CategorySectionView(
                                category: category,
                                fixes: fixes,
                                viewModel: viewModel,
                                pendingFix: $pendingFix
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 380)

            Divider()

            ActionBarView(viewModel: viewModel, showTerminal: $showTerminal)

            if showTerminal {
                Divider()
                TerminalOutputView(viewModel: viewModel)
            }
        }
        .frame(width: 480)
        .background(.background)
        .alert(item: $pendingFix) { fix in
            Alert(
                title: Text("Confirm: \(fix.displayName)"),
                message: Text(fix.requiresConfirmation
                    ? "This will modify or delete caches and system metadata. A backup will be created first. Continue?"
                    : "Continue with \(fix.displayName)?"),
                primaryButton: .destructive(Text("Run Fix")) { viewModel.run(fix: fix) },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var viewModel: ClickNFixViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title2)
                .foregroundStyle(severityColor)
                .animation(.easeInOut(duration: 0.4), value: viewModel.issueSeverity)

            VStack(alignment: .leading, spacing: 1) {
                Text("ClickNFix")
                    .font(.headline)
                Text("macOS System Repair")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SeverityBadgeView(severity: viewModel.issueSeverity)

            Button {
                viewModel.scanSystem()
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var severityColor: Color {
        switch viewModel.issueSeverity {
        case .none: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Severity Badge

private struct SeverityBadgeView: View {
    let severity: IssueSeverity

    var body: some View {
        Group {
            switch severity {
            case .none:
                EmptyView()
            case .warning:
                badge(label: "Issues Found", color: .orange)
            case .critical:
                badge(label: "Critical", color: .red)
            }
        }
    }

    private func badge(label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Options Bar

private struct OptionsBarView: View {
    @ObservedObject var viewModel: ClickNFixViewModel

    var body: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $viewModel.dryRunMode) {
                Label("Dry Run", systemImage: "eye")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Preview actions without modifying the system")

            Toggle(isOn: $viewModel.createSnapshotBeforeBatch) {
                Label("Snapshot before batch", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Create a Time Machine local snapshot before running all fixes")

            Spacer()

            if viewModel.dryRunMode {
                Text("DRY RUN")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// MARK: - Category Section

private struct CategorySectionView: View {
    let category: FixCategory
    let fixes: [FixType]
    @ObservedObject var viewModel: ClickNFixViewModel
    @Binding var pendingFix: FixType?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: category.sfSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(category.rawValue.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(fixes) { fix in
                    FixRowView(
                        fix: fix,
                        viewModel: viewModel,
                        pendingFix: $pendingFix
                    )
                    if fix != fixes.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Fix Row

private struct FixRowView: View {
    let fix: FixType
    @ObservedObject var viewModel: ClickNFixViewModel
    @Binding var pendingFix: FixType?

    var body: some View {
        let status = viewModel.status(for: fix)

        HStack(spacing: 11) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { viewModel.selectedFixes.contains(fix) },
                set: { on in
                    if on { viewModel.selectedFixes.insert(fix) }
                    else { viewModel.selectedFixes.remove(fix) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            // Icon tile
            FixIconView(fix: fix, status: status)

            // Text block
            VStack(alignment: .leading, spacing: 2) {
                Text(fix.displayName)
                    .font(.body.weight(.medium))
                Text(fix.fixDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            // Status + Run
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: status)
                RunButton(fix: fix, status: status, pendingFix: $pendingFix, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

// MARK: - Fix Icon

private struct FixIconView: View {
    let fix: FixType
    let status: FixExecutionStatus

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconBg)
                .frame(width: 34, height: 34)

            if case .running = status {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: fix.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconFg)
            }
        }
    }

    private var iconBg: Color {
        switch status {
        case .success: return Color.green.opacity(0.18)
        case .failure: return Color.red.opacity(0.15)
        case .running: return Color.blue.opacity(0.12)
        case .applicable: return Color.orange.opacity(0.13)
        default: return Color.primary.opacity(0.07)
        }
    }

    private var iconFg: Color {
        switch status {
        case .success: return .green
        case .failure: return .red
        case .applicable: return .orange
        default: return categoryColor(for: fix.category)
        }
    }

    private func categoryColor(for category: FixCategory) -> Color {
        switch category {
        case .system: return .blue
        case .storage: return .orange
        case .network: return .teal
        case .cloud: return .indigo
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: FixExecutionStatus

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .idle: return "Idle"
        case .applicable: return "Recommended"
        case .running: return "Running"
        case .success: return "Done ✓"
        case .failure: return "Failed ✕"
        }
    }

    private var bg: Color {
        switch status {
        case .idle: return Color.primary.opacity(0.07)
        case .applicable: return Color.orange.opacity(0.14)
        case .running: return Color.blue.opacity(0.13)
        case .success: return Color.green.opacity(0.15)
        case .failure: return Color.red.opacity(0.14)
        }
    }

    private var fg: Color {
        switch status {
        case .idle: return .secondary
        case .applicable: return .orange
        case .running: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }
}

// MARK: - Run Button

private struct RunButton: View {
    let fix: FixType
    let status: FixExecutionStatus
    @Binding var pendingFix: FixType?
    @ObservedObject var viewModel: ClickNFixViewModel

    var body: some View {
        Button {
            if fix.requiresConfirmation {
                pendingFix = fix
            } else {
                viewModel.run(fix: fix)
            }
        } label: {
            if case .running = status {
                Text("Running…")
            } else {
                Text("Run")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(status == .running)
    }
}

// MARK: - Action Bar

private struct ActionBarView: View {
    @ObservedObject var viewModel: ClickNFixViewModel
    @Binding var showTerminal: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Progress row
            HStack(spacing: 8) {
                ProgressView(value: viewModel.progress)
                    .frame(maxWidth: .infinity)
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)

            HStack(spacing: 8) {
                Button {
                    viewModel.runAllSelectedFixes()
                } label: {
                    Label("Run All Selected", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    viewModel.undoLastFix()
                } label: {
                    Label("Undo Last Fix", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!viewModel.canUndo)

                Spacer()

                Button {
                    viewModel.viewLastLog()
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("View last log file")

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        showTerminal.toggle()
                    }
                } label: {
                    Image(systemName: showTerminal ? "chevron.down" : "terminal")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(showTerminal ? "Hide terminal output" : "Show terminal output")
            }
            .padding(.horizontal, 14)

            if let msg = viewModel.lastMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Terminal Output

private struct TerminalOutputView: View {
    @ObservedObject var viewModel: ClickNFixViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(viewModel.terminalOutput)
                    .id("terminalBottom")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(height: 160)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .onChange(of: viewModel.terminalOutput) { _ in
                withAnimation { proxy.scrollTo("terminalBottom", anchor: .bottom) }
            }
        }
    }
}
