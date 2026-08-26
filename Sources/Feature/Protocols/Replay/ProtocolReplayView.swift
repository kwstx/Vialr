import SwiftUI
import Domain
import DesignSystem
import Analytics

/// Signature Protocol Replay View: A rich longitudinal timeline visualization
/// allowing users to scrub and play through the entire history of their protocol sequentially.
public struct ProtocolReplayView: View {
    @Bindable public var viewModel: ProtocolReplayViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ProtocolReplayViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.replaySequence.isEmpty {
                    emptyReplayView
                } else {
                    mainReplayCanvas
                }
            }
            .navigationTitle("Protocol Replay")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.pause()
                        dismiss()
                    }
                    .foregroundColor(VialrColors.accentTeal)
                }

                ToolbarItem(placement: .primaryAction) {
                    chapterMenu
                }
            }
            .task {
                await viewModel.loadReplayData()
            }
            .sheet(item: $viewModel.selectedDetailEvent) { event in
                eventDetailSheet(event)
            }
        }
    }

    // MARK: - 1. Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(VialrColors.accentTeal)
            Text("Assembling Longitudinal Replay Timeline...")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
        }
    }

    // MARK: - 2. Empty State View
    private var emptyReplayView: some View {
        VStack(spacing: VialrSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(VialrColors.textTertiary)

            Text("No Historical Events Found")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            Text("Log doses, measurements, or bloodwork associated with this protocol to replay history.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Dismiss") {
                dismiss()
            }
            .font(VialrTypography.captionBold)
            .foregroundColor(VialrColors.accentTeal)
            .padding(.top, 8)
        }
        .padding(VialrSpacing.xxl)
    }

    // MARK: - 3. Main Replay Canvas
    private var mainReplayCanvas: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: VialrSpacing.lg) {
                    // Header Status & Speed Controls
                    topControlBar

                    // Live Ground-Truth Protocol State HUD
                    ProtocolReplayHUDView(
                        state: viewModel.currentCumulativeState,
                        protocolModel: viewModel.protocolModel
                    )

                    // Central Spotlight Card (The Current Active Event in Time)
                    if let current = viewModel.currentEvent {
                        VStack(spacing: 6) {
                            HStack {
                                Text("EVENT \(viewModel.currentIndex + 1) OF \(viewModel.totalEventsCount)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(VialrColors.textTertiary)

                                Spacer()

                                Button {
                                    viewModel.selectedDetailEvent = current
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Inspect Frame")
                                        Image(systemName: "info.circle")
                                    }
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.accentTeal)
                                }
                            }
                            .padding(.horizontal, 4)

                            ProtocolReplayEventCard(event: current)
                                .id(current.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }

                    // Interactive Tactile Scrubber & Media Controls
                    mediaControllerSection

                    // Sequential History Mini-Reel (Horizontal Ribbon)
                    sequentialReelSection(proxy: proxy)
                }
                .padding(.horizontal, VialrSpacing.md)
                .padding(.top, VialrSpacing.sm)
                .padding(.bottom, 60)
            }
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - 4. Top Control Bar
    private var topControlBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: viewModel.protocolModel.colorHex))
                        .frame(width: 7, height: 7)

                    Text(viewModel.protocolModel.name)
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                        .lineLimit(1)
                }

                Text(viewModel.protocolModel.goalSummary.isEmpty ? "Protocol History Playback" : viewModel.protocolModel.goalSummary)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Playback Speed Selector Menu
            Menu {
                ForEach(ReplayPlaybackSpeed.allCases) { speed in
                    Button {
                        viewModel.setPlaybackSpeed(speed)
                    } label: {
                        HStack {
                            Text(speed.rawValue)
                            if viewModel.playbackSpeed == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 11))
                    Text(viewModel.playbackSpeed.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(VialrColors.accentTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 5. Media Controller Section
    private var mediaControllerSection: some View {
        VStack(spacing: VialrSpacing.md) {
            // Timestamp & Day Indicator
            if let current = viewModel.currentEvent {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(VialrColors.accentTeal)

                        Text(current.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(VialrTypography.footnoteBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    Spacer()

                    Text(current.protocolDay > 0 ? "Protocol Day \(current.protocolDay)" : "Pre-Protocol Baseline")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            // Tactile Scrubber Bar with Event Tick Marks
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track Background
                        Capsule()
                            .fill(VialrColors.cardSurfaceElevated)
                            .frame(height: 6)

                        // Colored Event Tick Marks along the timeline
                        if viewModel.totalEventsCount > 1 {
                            ForEach(Array(viewModel.replaySequence.events.enumerated()), id: \.element.id) { idx, ev in
                                let xPos = (Double(idx) / Double(viewModel.totalEventsCount - 1)) * geo.size.width
                                Circle()
                                    .fill(Color(hex: ev.badgeColorHex))
                                    .frame(width: idx == viewModel.currentIndex ? 6 : 4, height: idx == viewModel.currentIndex ? 6 : 4)
                                    .position(x: xPos, y: 3)
                            }
                        }

                        // Progress Fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [VialrColors.accentTeal, VialrColors.accentCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * viewModel.progressFraction), height: 6)
                    }
                    .frame(height: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.pause()
                                let fraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                                viewModel.seek(toFraction: fraction)
                            }
                    )
                }
                .frame(height: 12)
            }

            // Playback Media Controls
            HStack(spacing: 24) {
                // Jump to Start
                Button {
                    viewModel.jumpToStart()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 15))
                        .foregroundColor(viewModel.currentIndex > 0 ? VialrColors.textPrimary : VialrColors.textTertiary)
                }
                .disabled(viewModel.currentIndex == 0)

                // Step Back 1 Event
                Button {
                    viewModel.stepBackward()
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.currentIndex > 0 ? VialrColors.textPrimary : VialrColors.textTertiary)
                }
                .disabled(viewModel.currentIndex == 0)

                // Large Main Play / Pause Button
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VialrColors.accentTeal, VialrColors.accentCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: VialrColors.accentTeal.opacity(0.35), radius: 10, x: 0, y: 4)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(VialrColors.backgroundPrimary)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }

                // Step Forward 1 Event
                Button {
                    viewModel.stepForward()
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.currentIndex < viewModel.totalEventsCount - 1 ? VialrColors.textPrimary : VialrColors.textTertiary)
                }
                .disabled(viewModel.currentIndex >= viewModel.totalEventsCount - 1)

                // Jump to End
                Button {
                    viewModel.jumpToEnd()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 15))
                        .foregroundColor(viewModel.currentIndex < viewModel.totalEventsCount - 1 ? VialrColors.textPrimary : VialrColors.textTertiary)
                }
                .disabled(viewModel.currentIndex >= viewModel.totalEventsCount - 1)
            }
            .padding(.top, 4)

            // Loop Toggle Pill
            HStack {
                Spacer()
                Button {
                    withAnimation {
                        viewModel.autoLoop.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold))
                        Text(viewModel.autoLoop ? "Looping On" : "Looping Off")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(viewModel.autoLoop ? VialrColors.accentTeal : VialrColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.autoLoop ? VialrColors.accentTeal.opacity(0.12) : VialrColors.cardSurfaceElevated)
                    .cornerRadius(12)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - 6. Sequential Event Reel (Horizontal Mini-Map)
    private func sequentialReelSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("TIMELINE REEL")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("Tap any event to seek")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.replaySequence.events.enumerated()), id: \.element.id) { idx, ev in
                        let isSelected = idx == viewModel.currentIndex

                        Button {
                            viewModel.pause()
                            viewModel.seek(toIndex: idx)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: ev.badgeColorHex))
                                        .frame(width: 6, height: 6)

                                    Text(ev.protocolDay > 0 ? "Day \(ev.protocolDay)" : "Base")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)

                                    Spacer()

                                    Image(systemName: ev.iconName)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: ev.badgeColorHex))
                                }

                                Text(ev.title)
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textSecondary)
                                    .lineLimit(1)

                                Text(ev.subtitle)
                                    .font(.system(size: 9))
                                    .foregroundColor(VialrColors.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 130)
                            .padding(8)
                            .background(isSelected ? VialrColors.cardSurfaceElevated : VialrColors.cardBackground)
                            .cornerRadius(VialrSpacing.radiusSm)
                            .overlay(
                                RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                    .stroke(isSelected ? VialrColors.accentTeal : VialrColors.glassBorder, lineWidth: isSelected ? 1.5 : 0.8)
                            )
                            .scaleEffect(isSelected ? 1.04 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
                        }
                        .buttonStyle(.plain)
                        .id(idx)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - 7. Chapter Menu
    private var chapterMenu: some View {
        Menu {
            Section("Jump to Chapter") {
                ForEach(viewModel.chapters) { chapter in
                    Button {
                        viewModel.jumpToChapter(chapter)
                    } label: {
                        Label {
                            Text("\(chapter.title) (\(chapter.subtitle))")
                        } icon: {
                            Image(systemName: chapter.iconName)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .foregroundColor(VialrColors.accentTeal)
        }
    }

    // MARK: - 8. Event Detail Sheet
    private func eventDetailSheet(_ event: ProtocolReplayEvent) -> some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: VialrSpacing.lg) {
                        ProtocolReplayEventCard(event: event)

                        if let st = event.cumulativeState {
                            ProtocolReplayHUDView(state: st, protocolModel: viewModel.protocolModel)
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Frame Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.selectedDetailEvent = nil
                    }
                    .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}
