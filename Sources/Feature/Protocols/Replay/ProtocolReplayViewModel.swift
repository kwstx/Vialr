import SwiftUI
import Observation
import Domain
import Analytics
import Data

@Observable
public final class ProtocolReplayViewModel: @unchecked Sendable {
    // MARK: - State Properties
    public var protocolModel: ProtocolModel
    public var replaySequence: ProtocolReplaySequence = ProtocolReplaySequence(protocolId: UUID(), protocolName: "")
    public var currentIndex: Int = 0
    public var isPlaying: Bool = false
    public var playbackSpeed: ReplayPlaybackSpeed = .normal
    public var selectedFilter: ReplayCategoryFilter = .all
    public var isLoading: Bool = false
    public var autoLoop: Bool = false
    public var selectedDetailEvent: ProtocolReplayEvent?

    // MARK: - Dependencies
    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let measurementRepo: MeasurementRepositoryProtocol
    private let labRepo: LabPanelRepositoryProtocol
    private let revisionRepo: ProtocolRevisionRepositoryProtocol
    private let symptomRepo: SymptomRepositoryProtocol
    private let siteEventRepo: InjectionSiteEventRepositoryProtocol
    private let engine: ProtocolReplayEngine

    private var playbackTask: Task<Void, Never>?

    public init(
        protocolModel: ProtocolModel,
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        measurementRepo: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        labRepo: LabPanelRepositoryProtocol = LocalLabPanelRepository(),
        revisionRepo: ProtocolRevisionRepositoryProtocol = LocalProtocolRevisionRepository(),
        symptomRepo: SymptomRepositoryProtocol = LocalSymptomRepository(),
        siteEventRepo: InjectionSiteEventRepositoryProtocol = LocalInjectionSiteEventRepository(),
        engine: ProtocolReplayEngine = ProtocolReplayEngine()
    ) {
        self.protocolModel = protocolModel
        self.protocolRepo = protocolRepo
        self.doseRepo = doseRepo
        self.measurementRepo = measurementRepo
        self.labRepo = labRepo
        self.revisionRepo = revisionRepo
        self.symptomRepo = symptomRepo
        self.siteEventRepo = siteEventRepo
        self.engine = engine
    }

    deinit {
        playbackTask?.cancel()
    }

    // MARK: - Computed Properties

    public var filteredEvents: [ProtocolReplayEvent] {
        guard let targetCategory = selectedFilter.category else {
            return replaySequence.events
        }
        return replaySequence.events.filter { $0.category == targetCategory || $0.category == .milestone }
    }

    public var currentEvent: ProtocolReplayEvent? {
        guard !replaySequence.events.isEmpty, currentIndex >= 0, currentIndex < replaySequence.events.count else {
            return nil
        }
        return replaySequence.events[currentIndex]
    }

    public var currentCumulativeState: ReplayCumulativeState? {
        currentEvent?.cumulativeState
    }

    public var progressFraction: Double {
        guard replaySequence.events.count > 1 else { return 0.0 }
        return Double(currentIndex) / Double(replaySequence.events.count - 1)
    }

    public var chapters: [ReplayChapter] {
        replaySequence.chapters
    }

    public var totalEventsCount: Int {
        replaySequence.events.count
    }

    // MARK: - Data Loading

    @MainActor
    public func loadReplayData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let dosesAsync = doseRepo.fetchAll()
            async let measurementsAsync = measurementRepo.fetchAll()
            async let labsAsync = labRepo.fetchAll()
            async let revisionsAsync = revisionRepo.fetchRevisions(forProtocol: protocolModel.id)
            async let symptomsAsync = symptomRepo.fetchAll()
            async let siteEventsAsync = siteEventRepo.fetchAll()

            let (doses, measurements, labs, revisions, symptoms, siteEvents) = try await (
                dosesAsync,
                measurementsAsync,
                labsAsync,
                revisionsAsync,
                symptomsAsync,
                siteEventsAsync
            )

            let sequence = engine.buildReplaySequence(
                for: protocolModel,
                doses: doses,
                measurements: measurements,
                labPanels: labs,
                protocolRevisions: revisions,
                symptomLogs: symptoms,
                injectionSiteEvents: siteEvents
            )

            self.replaySequence = sequence
            self.currentIndex = 0
        } catch {
            print("[ProtocolReplayViewModel] Error compiling replay sequence: \(error)")
        }
    }

    // MARK: - Playback Controller Actions

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard !replaySequence.events.isEmpty else { return }
        
        // If at the end, restart from beginning
        if currentIndex >= replaySequence.events.count - 1 {
            currentIndex = 0
        }

        isPlaying = true
        startPlaybackLoop()
    }

    public func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    public func stepForward() {
        pause()
        if currentIndex < replaySequence.events.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentIndex += 1
            }
        }
    }

    public func stepBackward() {
        pause()
        if currentIndex > 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentIndex -= 1
            }
        }
    }

    public func jumpToStart() {
        pause()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentIndex = 0
        }
    }

    public func jumpToEnd() {
        pause()
        if !replaySequence.events.isEmpty {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentIndex = replaySequence.events.count - 1
            }
        }
    }

    public func seek(toFraction fraction: Double) {
        guard !replaySequence.events.isEmpty else { return }
        let clamped = min(1.0, max(0.0, fraction))
        let targetIndex = Int(round(clamped * Double(replaySequence.events.count - 1)))
        seek(toIndex: targetIndex)
    }

    public func seek(toIndex index: Int) {
        guard !replaySequence.events.isEmpty else { return }
        let target = min(replaySequence.events.count - 1, max(0, index))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            currentIndex = target
        }
    }

    public func jumpToChapter(_ chapter: ReplayChapter) {
        pause()
        seek(toIndex: chapter.eventIndex)
    }

    public func setPlaybackSpeed(_ speed: ReplayPlaybackSpeed) {
        self.playbackSpeed = speed
        if isPlaying {
            // Restart loop with new interval
            playbackTask?.cancel()
            startPlaybackLoop()
        }
    }

    public func setCategoryFilter(_ filter: ReplayCategoryFilter) {
        self.selectedFilter = filter
    }

    // MARK: - Playback Loop Engine

    private func startPlaybackLoop() {
        playbackTask?.cancel()

        playbackTask = Task { @MainActor in
            while self.isPlaying && !Task.isCancelled {
                let intervalNanos = UInt64(self.playbackSpeed.stepIntervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: intervalNanos)

                if Task.isCancelled || !self.isPlaying { break }

                if self.currentIndex < self.replaySequence.events.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.currentIndex += 1
                    }
                } else {
                    if self.autoLoop {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.currentIndex = 0
                        }
                    } else {
                        self.pause()
                        break
                    }
                }
            }
        }
    }
}
