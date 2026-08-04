import SwiftUI

struct ContactAddMethodSheet: View {
    let candidate: ContactPromptCandidate
    var onVoice: () -> Void
    var onType: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add \(candidate.firstName)’s birthday")
                    .font(.title2.weight(.bold))

                Text("We’ll save it in Remember My Birthday and on their contact card.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    onVoice()
                } label: {
                    Label("Add by voice", systemImage: "mic.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onType()
                } label: {
                    Label("Type it in", systemImage: "keyboard")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(24)
            .background(RememberColors.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", action: onCancel)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }
}
