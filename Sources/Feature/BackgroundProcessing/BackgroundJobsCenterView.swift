import SwiftUI
import Domain
import DesignSystem
import Data

/// Comprehensive Background Task Center sheet enabling users to monitor in-flight background jobs,
/// inspect completed PDF extractions, report compilations, data exports, and retry failed operations.
public struct BackgroundJobsCenterView: View {
    @ObservedObject var jobManager: BackgroundJobManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: String = "All"

    private let filterOptions = ["All", "Active", "Completed", "Failed"]

    public init(jobManager: BackgroundJobManager = .shared) {
        self.jobManager = jobManager
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Filter Segmented Picker
                        filterPicker

                        // Active Jobs Section
                        if !filteredActiveJobs.isEmpty {
                            activeJobsSection
                        }

                        // Recent Completed / History Section
                        if !filteredCompletedJobs.isEmpty {
                            completedJobsSection
                        }

                        // Empty State
                        if filteredActiveJobs.isEmpty && filteredCompletedJobs.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Background Tasks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .task {
                await jobManager.refreshJobs()
            }
        }
    }

    // MARK: - Filter Picker
    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(filterOptions, id: \.self) { option in
                Button {
                    selectedFilter = option
                } label: {
                    Text(option)
                        .font(VialrTypography.captionBold)
                        .foregroundColor(selectedFilter == option ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(selectedFilter == option ? VialrColors.accentTeal : VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusPill)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Active Jobs Section
    private var activeJobsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("IN PROGRESS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("\(filteredActiveJobs.count) active")
                    .font(VialrTypography.caption2)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(filteredActiveJobs) { job in
                BackgroundJobObserverView(
                    job: job,
                    onCancel: {
                        Task { await jobManager.cancelJob(id: job.id) }
                    }
                )
            }
        }
    }

    // MARK: - Completed Jobs Section
    private var completedJobsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("RECENT TASK HISTORY")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)

            ForEach(filteredCompletedJobs) { job in
                BackgroundJobObserverView(
                    job: job,
                    onRetry: {
                        Task { await jobManager.retryJob(id: job.id) }
                    }
                )
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 48))
                .foregroundColor(VialrColors.textTertiary)
                .padding(.top, 40)

            Text("No Tasks Found")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            Text("Background tasks such as PDF OCR extraction, clinician reports, and whole-account data exports will appear here in real-time.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var filteredActiveJobs: [BackgroundJob] {
        switch selectedFilter {
        case "Active", "All": return jobManager.activeJobs
        default: return []
        }
    }

    private var filteredCompletedJobs: [BackgroundJob] {
        switch selectedFilter {
        case "Completed": return jobManager.recentCompletedJobs.filter { $0.status == .completed }
        case "Failed": return jobManager.recentCompletedJobs.filter { $0.status == .failed || $0.status == .cancelled }
        case "All": return jobManager.recentCompletedJobs
        default: return []
        }
    }
}
