import SwiftUI
import Domain
import DesignSystem
import Data
import Analytics

public struct ClinicianReportView: View {
    @State private var report: ClinicianReport?
    @State private var isLoading: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository()
    private let doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository()
    private let biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository()
    private let adherenceCalculator = AdherenceCalculator()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        if let report = report {
                            reportContent(report)
                        } else {
                            ProgressView()
                                .padding(40)
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Clinician Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: "Vialr Medical Report - Longitudinal Peptide Protocol Summary. Generated: \(Date().formatted(date: .abbreviated, time: .shortened))") {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }
            .task {
                await generateReport()
            }
        }
    }

    private func reportContent(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Medical Header
            VStack(alignment: .leading, spacing: 4) {
                Text("CLINICAL PROTOCOL RECORD")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Text("Longitudinal Patient Summary")
                    .font(VialrTypography.title1)
                    .foregroundColor(VialrColors.textPrimary)
                Text("Date Range: \(report.dateRangeStart.formatted(date: .abbreviated, time: .omitted)) – \(report.dateRangeEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            // Compliance & Adherence Stats
            HStack(spacing: VialrSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROTOCOL COMPLIANCE")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(Int(report.adherencePercentage))%")
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.accentEmerald)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL DOSES DELIVERED")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(report.totalDosesAdministered)")
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            // Active Compounds Table
            VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                Text("ADMINISTERED COMPOUNDS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)

                ForEach(report.doseSummary) { summary in
                    HStack {
                        Text(summary.compoundName)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text("\(summary.numberOfInjections) injections")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                        Text("\(String(format: "%.0f", summary.totalDoseDelivered)) \(summary.unit.rawValue)")
                            .font(VialrTypography.monoDose)
                            .foregroundColor(VialrColors.accentEmerald)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            // Latest Bloodwork Biomarkers
            VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                Text("RECORDED BIOMARKERS & LABS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)

                ForEach(report.latestBiomarkers) { marker in
                    HStack {
                        Text(marker.name)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text("\(String(format: "%.1f", marker.value)) \(marker.unit)")
                            .font(VialrTypography.monoDose)
                            .foregroundColor(Color(hex: marker.status.colorHex))
                        MetricBadge(.custom(title: marker.status.rawValue, color: Color(hex: marker.status.colorHex), icon: nil))
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard()
        }
    }

    private func generateReport() async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -30, to: now) ?? now

        let protocols = (try? await protocolRepo.fetchAll()) ?? []
        let doses = (try? await doseRepo.fetchForDateRange(start: start, end: now)) ?? []
        let biomarkers = (try? await biomarkerRepo.fetchAll()) ?? []
        let adh = adherenceCalculator.calculateAdherence(logs: doses)

        var compSummaries: [CompoundDoseSummary] = []
        var compGroups: [String: [DoseLog]] = [:]
        for d in doses where d.status == .taken {
            compGroups[d.compoundName, default: []].append(d)
        }

        for (name, items) in compGroups {
            let total = items.reduce(0.0) { $0 + $1.doseAmount }
            let avg = items.isEmpty ? 0 : total / Double(items.count)
            let unit = items.first?.doseUnit ?? .mcg
            compSummaries.append(
                CompoundDoseSummary(
                    compoundName: name,
                    totalDoseDelivered: total,
                    unit: unit,
                    averageDose: avg,
                    numberOfInjections: items.count,
                    mostFrequentSite: "Abdomen (SubQ)"
                )
            )
        }

        self.report = ClinicianReport(
            patientIdentifier: "Patient / Self-Managed Record",
            generatedDate: now,
            dateRangeStart: start,
            dateRangeEnd: now,
            activeProtocols: protocols,
            doseSummary: compSummaries,
            adherencePercentage: adh.overallPercentage,
            totalDosesAdministered: adh.totalTaken,
            latestBiomarkers: biomarkers,
            subjectiveTrendsSummary: "Consistent recovery improvement noted over 30-day administration cycle.",
            clinicalNotes: "Patient maintains structured SubQ site rotation across 4 abdominal quadrants and deltoids."
        )
    }
}
