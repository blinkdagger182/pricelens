import SwiftUI

struct AppUpdateSheet: View {
    let policy: AppVersionPolicy
    let requirement: AppUpdateRequirement
    let currentVersion: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    private var isRequired: Bool {
        requirement == .required
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.76)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                icon

                VStack(spacing: 10) {
                    Text(isRequired ? "Update required" : "Update available")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.accent)

                    Text(policy.updateTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(policy.updateMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                versionPills

                if !policy.releaseNotes.isEmpty {
                    releaseNotes
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Update now", action: onUpdate)

                    if !isRequired {
                        Button("Not now", action: onDismiss)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.96))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.20), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: AppTheme.accent.opacity(0.24), radius: 32, y: 12)
            .padding(.horizontal, 22)
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.16))
                .frame(width: 78, height: 78)
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.55), lineWidth: 1))

            Image(systemName: isRequired ? "arrow.down.circle.fill" : "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.top, 4)
    }

    private var versionPills: some View {
        HStack(spacing: 10) {
            versionPill(title: "Installed", value: currentVersion, highlighted: false)
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            versionPill(title: "Latest", value: policy.latestVersion, highlighted: true)
        }
        .padding(.vertical, 4)
    }

    private func versionPill(title: String, value: String, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(highlighted ? AppTheme.accent : AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(highlighted ? AppTheme.accent.opacity(0.4) : AppTheme.border, lineWidth: 1)
        )
    }

    private var releaseNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(policy.releaseNotes.prefix(4), id: \.self) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surfaceSecondary.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}
