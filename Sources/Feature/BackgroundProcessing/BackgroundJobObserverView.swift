import SwiftUI
import Domain
import DesignSystem

/// Reusable SwiftUI component that observes a background processing job in real-time,
/// showing animated status indicators, progressive step descriptions, smooth progress bars,
/// and contextual actions (cancel, retry, view results).
public struct BackgroundJobObserverView: View {
    public let job: BackgroundJob
    public var onCancel: (() -> Void)? = nil
    public var onRetry: (() -> Void)? = nil
    public var onViewResults: (() -> Void)? = nil
    public var onDismiss: (() -> Void)? = nil

    public init(
        job: BackgroundJob,
        onCancel: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        onViewResults: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.job = job
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onViewResults = onViewResults
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Header Row: Job Type Icon, Title & Status Pill
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: job.jobType.systemIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.jobType.displayName)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textPrimary)

                    Text(job.status.displayName.uppercased())
                        .font(VialrTypography.caption2Bold)
                        .foregroundColor(statusColor)
                }

                Spacer()

                if job.status == .processing {
                    ProgressView()
                        .tint(VialrColors.accentTeal)
                        .scaleEffect(0.9)
                } else if job.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(VialrColors.accentEmerald)
                } else if job.status == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(VialrColors.accentCrimson)
                }
            }

            // Current Step Description
            Text(job.stepDescription)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: job.stepDescription)

            // Progress Bar & Percentage
            if job.isActive {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: job.progress, total: 1.0)
                        .tint(VialrColors.accentTeal)
                        .animation(.linear(duration: 0.3), value: job.progress)

                    HStack {
                        Text("Progress")
                            .font(VialrTypography.caption2)
                            .foregroundColor(VialrColors.textTertiary)
                        Spacer()
                        Text(job.formattedProgress)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                if job.isActive, let onCancel = onCancel {
                    Button(role: .destructive, action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Cancel Task")
                        }
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentCrimson)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(VialrColors.accentCrimson.opacity(0.12))
                        .cornerRadius(VialrSpacing.radiusPill)
                    }
                    .buttonStyle(.plain)
                }

                if job.status == .failed, let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Task")
                        }
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.backgroundPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(VialrColors.accentTeal)
                        .cornerRadius(VialrSpacing.radiusPill)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if job.status == .completed, let onViewResults = onViewResults {
                    Button(action: onViewResults) {
                        HStack(spacing: 4) {
                            Text("View Results")
                            Image(systemName: "arrow.right")
                        }
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.backgroundPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(VialrColors.accentEmerald)
                        .cornerRadius(VialrSpacing.radiusPill)
                    }
                    .buttonStyle(.plain)
                } else if job.isFinished, let onDismiss = onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusLg)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusLg)
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch job.status {
        case .queued: return VialrColors.textTertiary
        case .processing: return VialrColors.accentTeal
        case .completed: return VialrColors.accentEmerald
        case .failed: return VialrColors.accentCrimson
        case .cancelled: return VialrColors.textTertiary
        }
    }
}
