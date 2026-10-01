//  StrategyRootView.swift
//  StrategyFeature — the Strategy tab root: program summary, today's
//  targets, expenditure estimate, and the weekly check-in.
//
//  The tab no longer embeds TrackingHub (issue #14); that stays the
//  tracking home screen in TrackingFeature.

import SwiftUI
import DesignSystem
import CoachingEngine
import DataLayer

/// Strategy tab root. Owns a `StrategyViewModel` fed by
/// ``StrategyDependencies``; AppShell wraps this in the tab's
/// `NavigationStack`.
public struct StrategyRootView: View {
    @State private var viewModel: StrategyViewModel
    @State private var showingEditProgram = false
    @State private var showingManualTargets = false

    public init(dependencies: StrategyDependencies) {
        _viewModel = State(initialValue: StrategyViewModel(dependencies: dependencies))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.danger)
                        .mfCard()
                }
                if let program = viewModel.program {
                    ProgramSummaryCard(program: program) {
                        showingEditProgram = true
                    }
                }
                TodayTargetsCard(
                    targets: viewModel.todayTargets,
                    kind: viewModel.todayKind,
                    usedEstimatedWeight: viewModel.usedEstimatedWeight
                )
                ExpenditureCard(estimate: viewModel.estimate)
                if let program = viewModel.program, let settings = viewModel.settings {
                    CheckInCard(
                        report: viewModel.report,
                        lastCheckIn: viewModel.lastCheckIn,
                        checkInWeekday: settings.checkInWeekday,
                        programStyle: program.programStyle,
                        onRun: { viewModel.runCheckIn() },
                        onAccept: { viewModel.acceptProposal() },
                        onDecline: { viewModel.declineProposal() },
                        onEditTargets: { showingManualTargets = true }
                    )
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Strategy")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditProgram = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit program")
                .disabled(viewModel.program == nil)
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showingEditProgram) {
            if let program = viewModel.program {
                EditProgramSheet(program: program) { draft in
                    viewModel.saveProgramEdits(draft)
                }
            }
        }
        .sheet(isPresented: $showingManualTargets) {
            if let targets = viewModel.todayTargets {
                ManualTargetsSheet(current: targets) { newTargets in
                    viewModel.saveManualTargets(newTargets)
                }
            }
        }
    }
}

#Preview("Strategy") {
    // Previews run on the main actor; build a real in-memory store like
    // TrackingFeature's preview support does (no stubs to keep in sync
    // with the repository protocols).
    MainActor.assumeIsolated {
        let store = try! DataStore(inMemory: true, seed: false)
        StrategyRootView(dependencies: StrategyDependencies(
            logs: store.logs,
            weights: store.weights,
            steps: store.steps,
            program: store.program
        ))
    }
}
