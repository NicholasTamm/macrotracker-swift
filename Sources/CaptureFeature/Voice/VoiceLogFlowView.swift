import SwiftUI
import AVFoundation
import Speech
import DataLayer
import DesignSystem

// MARK: - VoiceRecognizer

/// Live speech-to-text via `SFSpeechRecognizer` + `AVAudioEngine`.
/// Publishes partial transcripts while recording; the final transcript is
/// available after `stop()`.
@MainActor
public final class VoiceRecognizer: ObservableObject {
    @Published public private(set) var transcript = ""
    @Published public private(set) var isRecording = false
    @Published public var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    public init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    public var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    public func start() {
        errorMessage = nil
        guard let recognizer else {
            errorMessage = "Speech recognition isn't supported for this language."
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. Check your connection and try again."
            return
        }
        cancelPrevious()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the microphone."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "Couldn't start the microphone."
            return
        }

        audioEngine = engine
        recognitionRequest = request
        transcript = ""
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || result?.isFinal == true
            Task { @MainActor [weak self] in
                if let text { self?.transcript = text }
                if finished { self?.finish() }
            }
        }
    }

    public func stop() {
        finish()
    }

    private func finish() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cancelPrevious() {
        recognitionTask?.cancel()
        recognitionTask = nil
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        recognitionRequest = nil
    }
}

// MARK: - VoiceLogFlowView

/// Voice logging: record → transcript → parsed, editable item candidates
/// (source `.voiceEstimate`) → optional database match → log.
///
/// Acceptance: voice input always produces an editable draft.
public struct VoiceLogFlowView: View {
    private let deps: CaptureDependencies

    @StateObject private var permissions = MFPermissionCenter()
    @StateObject private var recognizer = VoiceRecognizer()
    @State private var candidates: [VoiceDraftCandidate] = []
    @State private var mealSlot: MealSlot = .other
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var matchTargetID: UUID?

    private struct VoiceDraftCandidate: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var grams: Double
        var match: FoodSearchResult?
    }

    public init(deps: CaptureDependencies) {
        self.deps = deps
    }

    public var body: some View {
        Group {
            if candidates.isEmpty {
                recordView
            } else {
                reviewView
            }
        }
        .navigationTitle("Voice log")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Record

    private var recordView: some View {
        VStack(spacing: MFSpacing.lg) {
            let micOK = permissions.microphone.isGranted
            let speechOK = permissions.speech.isGranted
            if !(micOK && speechOK) {
                MFEmptyState(
                    icon: "mic.fill",
                    title: "Voice logging needs two permissions",
                    message: "Microphone access to hear you, and speech recognition to turn it into text. Nothing is recorded until you tap the button.",
                    actionTitle: "Allow access",
                    onAction: {
                        Task {
                            await permissions.requestVoicePermissions()
                            permissions.refresh()
                        }
                    }
                )
                .padding(MFSpacing.lg)
                if permissions.microphone == .denied || permissions.speech == .denied {
                    MFPermissionDeniedView(
                        icon: "mic.fill",
                        title: "Permission needed",
                        message: "Voice logging was denied. You can re-enable it in Settings."
                    )
                }
            } else {
                VStack(spacing: MFSpacing.lg) {
                    Spacer()
                    recordButton
                    transcriptCard
                    Spacer()
                    Text("Try: \"150 grams chicken breast and 1 cup of rice\"")
                        .font(MFFont.footnote)
                        .foregroundColor(MFColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MFSpacing.xl)
                }
                .padding(MFSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
        .onAppear { permissions.refresh() }
    }

    private var recordButton: some View {
        Button {
            if recognizer.isRecording {
                recognizer.stop()
                acceptTranscript()
            } else {
                recognizer.start()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(recognizer.isRecording ? MFColor.danger : MFColor.accent)
                    .frame(width: 88, height: 88)
                Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(recognizer.isRecording ? "Stop recording" : "Start recording")
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text(recognizer.isRecording ? "Listening…" : "What did you eat?")
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
            ScrollView {
                Text(
                    recognizer.transcript.isEmpty
                        ? "Tap the microphone and describe your meal."
                        : recognizer.transcript
                )
                .font(MFFont.body)
                .foregroundColor(
                    recognizer.transcript.isEmpty ? MFColor.textTertiary : MFColor.textPrimary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, maxHeight: 180)
            if let error = recognizer.errorMessage {
                Text(error)
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.danger)
            }
            if recognizer.isRecording {
                MFButton("Done", style: .secondary, size: .medium) {
                    recognizer.stop()
                    acceptTranscript()
                }
            }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }

    private func acceptTranscript() {
        let text = recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        candidates = VoiceFoodParser.parse(text).map {
            VoiceDraftCandidate(name: $0.name, grams: $0.estimatedGrams)
        }
    }

    // MARK: Review

    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't log", message: errorMessage)
                }
                MFBanner(
                    kind: .info,
                    title: "Check the details",
                    message: "Voice estimates are rough — fix names and amounts, or match an item to your food database for real nutrition."
                )
                Text("Heard \(candidates.count) item\(candidates.count == 1 ? "" : "s")")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)

                ForEach($candidates) { $candidate in
                    candidateEditor(candidate: $candidate)
                }

                MFSegmentedControl(options: MealSlot.allCases, selection: $mealSlot) {
                    $0.displayName
                }

                HStack(spacing: MFSpacing.md) {
                    MFButton("Start over", style: .secondary, size: .medium) {
                        candidates = []
                        recognizer.errorMessage = nil
                    }
                    MFButton(
                        "Log \(candidates.count) item\(candidates.count == 1 ? "" : "s")",
                        style: .primary,
                        size: .medium,
                        icon: "plus",
                        isLoading: isWorking,
                        action: logAll
                    )
                    .disabled(!canLog || isWorking)
                }
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
        .sheet(item: matchTargetBinding) { target in
            FoodMatchSheet(search: deps.search, initialQuery: target.name) { result in
                if let index = candidates.firstIndex(where: { $0.id == target.id }) {
                    candidates[index].match = result
                }
            }
        }
    }

    private func candidateEditor(candidate: Binding<VoiceDraftCandidate>) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            HStack {
                MFTextField("Item name", placeholder: "e.g. Chicken breast", text: candidate.name)
                Button {
                    candidates.removeAll { $0.id == candidate.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(MFColor.danger)
                }
                .accessibilityLabel("Remove item")
            }
            HStack {
                MFStepper(
                    value: candidate.grams,
                    step: 10,
                    range: 1...5000,
                    unit: "g",
                    label: "Amount"
                )
                Spacer()
            }
            if let match = candidate.wrappedValue.match {
                HStack(spacing: MFSpacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(MFColor.success)
                    Text("Matched: \(match.displayName)")
                        .font(MFFont.footnote)
                        .foregroundColor(MFColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Button {
                matchTargetID = candidate.wrappedValue.id
            } label: {
                Label(
                    candidate.wrappedValue.match == nil ? "Match to database" : "Change match",
                    systemImage: "magnifyingglass"
                )
                .font(MFFont.footnote.weight(.semibold))
                .foregroundColor(MFColor.accent)
            }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }

    /// Sheet target carrying the candidate's id + current name.
    private var matchTargetBinding: Binding<MatchTarget?> {
        Binding(
            get: {
                guard let id = matchTargetID,
                      let candidate = candidates.first(where: { $0.id == id })
                else { return nil }
                return MatchTarget(id: candidate.id, name: candidate.name)
            },
            set: { matchTargetID = $0?.id }
        )
    }

    private struct MatchTarget: Identifiable {
        let id: UUID
        let name: String
    }

    private var canLog: Bool {
        !candidates.isEmpty && candidates.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.grams > 0
        }
    }

    // MARK: Log

    private func logAll() {
        errorMessage = nil
        guard canLog else { return }
        isWorking = true
        let snapshot = candidates
        let slot = mealSlot
        Task {
            do {
                try await MainActor.run {
                    for candidate in snapshot {
                        let food: FoodItem
                        if let match = candidate.match {
                            if let id = match.localFoodID,
                               let existing = try deps.foods.food(id: id)
                            {
                                food = existing
                            } else if let product = match.offProduct {
                                food = try deps.search.importOFFProduct(product)
                            } else {
                                food = try voiceFood(for: candidate)
                            }
                        } else {
                            food = try voiceFood(for: candidate)
                        }
                        try deps.log.logFood(
                            food,
                            grams: candidate.grams,
                            mealSlot: slot,
                            timestamp: Date(),
                            note: candidate.match == nil ? "Voice estimate — nutrition not matched" : nil,
                            source: .voice
                        )
                    }
                    // One user action = one hook fire, even for multi-item
                    // scans; the streak layer is per-day idempotent anyway.
                    deps.noteFoodLogged()
                }
                await MainActor.run {
                    candidates = []
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Persists an unmatched voice candidate as a voice-estimate food.
    @MainActor
    private func voiceFood(for candidate: VoiceDraftCandidate) throws -> FoodItem {
        try deps.foods.saveFood(
            name: candidate.name,
            brand: "",
            barcode: nil,
            servingDescription: "",
            servingSizeGrams: candidate.grams,
            nutrientsPer100g: [:],
            source: .voiceEstimate
        )
    }
}
