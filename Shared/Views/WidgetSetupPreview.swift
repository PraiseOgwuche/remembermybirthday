import SwiftUI

/// Home Screen widget preview used in onboarding.
struct WidgetSetupPreview: View {
    let size: AppSettingsStore.PreferredWidgetSize

    var body: some View {
        Group {
            switch size {
            case .small:
                smallPreview
                    .frame(width: 148, height: 148)
            case .medium:
                mediumPreview
                    .frame(width: 320, height: 148)
            case .large:
                largePreview
                    .frame(width: 320, height: 320)
            }
        }
        .background(RememberColors.elevatedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var smallPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("12 DAYS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Alex")
                .font(.headline)
            Text("Aug 20")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("Draft →")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alex")
                    .font(.headline)
                Text("12 days · Aug 20")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Happy birthday, Alex! Hope today treats you well — grateful for you.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                chip("Send")
                chip("Schedule")
                chip("Draft")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var largePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alex")
                    .font(.title3.weight(.semibold))
                Text("12 days · Aug 20")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Happy birthday, Alex! Hope today treats you well — grateful for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack(spacing: 8) {
                chip("Send")
                chip("Schedule")
                chip("Draft")
            }
            Divider()
            Text("Coming up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            row("Sam", "18 days")
            row("Jordan", "24 days")
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
    }

    private func row(_ name: String, _ when: String) -> some View {
        HStack {
            Text(name)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(when)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
