import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ClickNFixViewModel
    @State private var pendingFix: FixType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ClickNFix")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Scan") {
                    viewModel.scanSystem()
                }
            }

            Toggle("Dry Run", isOn: $viewModel.dryRunMode)
                .help("Preview actions without modifying the system")
            Toggle("Create local snapshot before batch", isOn: $viewModel.createSnapshotBeforeBatch)

            GroupBox("Fixes") {
                ForEach(FixType.allCases) { fix in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedFixes.contains(fix) },
                            set: { isSelected in
                                if isSelected { viewModel.selectedFixes.insert(fix) }
                                else { viewModel.selectedFixes.remove(fix) }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(fix.displayName)
                                Text(viewModel.status(for: fix).description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        Spacer()
                        Button("Run") {
                            if fix.requiresConfirmation {
                                pendingFix = fix
                            } else {
                                viewModel.run(fix: fix)
                            }
                        }
                    }
                    Divider()
                }
            }

            HStack {
                Button("Run All Recommended Fixes") {
                    viewModel.runAllSelectedFixes()
                }
                .buttonStyle(.borderedProminent)

                Button("Undo Last Fix") {
                    viewModel.undoLastFix()
                }
                .disabled(!viewModel.canUndo)
            }

            HStack {
                ProgressView(value: viewModel.progress)
                Text(viewModel.progressText)
                    .font(.caption)
                    .frame(width: 130, alignment: .trailing)
            }

            GroupBox("Terminal Output") {
                ScrollView {
                    Text(viewModel.terminalOutput)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(height: 200)
            }

            HStack {
                Button("View Last Log") {
                    viewModel.viewLastLog()
                }
                Spacer()
                if let message = viewModel.lastMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 460)
        .alert(item: $pendingFix) { fix in
            Alert(
                title: Text("Confirm \(fix.displayName)"),
                message: Text("This operation can modify or delete caches and system metadata. Continue?"),
                primaryButton: .destructive(Text("Continue")) { viewModel.run(fix: fix) },
                secondaryButton: .cancel()
            )
        }
    }
}
