import SwiftUI
import PhotosUI
import UIKit
import DesignSystem
import DataLayer

// MARK: - ProgressPhotosView

/// Progress photos: grid, PhotosUI import, detail, and side-by-side compare.
/// Image bytes live in `PhotoFileStore` (Application Support); only relative
/// paths are stored on `ProgressPhoto`.
public struct ProgressPhotosView: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var photos: [ProgressPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var pendingData: [(data: Data, item: PhotosPickerItem)] = []
    @State private var pendingTag: PhotoViewTag = .front
    @State private var pendingNote: String = ""
    @State private var showingImportSheet = false
    @State private var selected: ProgressPhoto?
    @State private var comparing: [ProgressPhoto] = []
    @State private var error: String?
    @State private var showingPicker = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if photos.isEmpty && !importing {
                    MFEmptyState(
                        icon: "photo.on.rectangle",
                        title: "No progress photos yet",
                        message: "Add front, side, and back photos over time to see how far you've come.",
                        actionTitle: "Add photos",
                        onAction: { showingPicker = true }
                    )
                    .mfCard()
                } else {
                    LazyVGrid(columns: columns, spacing: MFSpacing.md) {
                        ForEach(photos, id: \.id) { photo in
                            Button {
                                selected = photo
                            } label: {
                                ProgressPhotoTile(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Progress photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if photos.count >= 2 {
                    Button {
                        comparing = Array(photos.prefix(2))
                    } label: {
                        Image(systemName: "rectangle.split.2x1")
                    }
                    .accessibilityLabel("Compare photos")
                }
                Button {
                    showingPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add photos")
            }
        }
        // Hidden picker opened from the toolbar and the empty state.
        .background {
            PhotosPicker(
                isPresented: $showingPicker,
                selection: $pickerItems,
                maxSelectionCount: 6,
                matching: .images,
                photoLibrary: .shared()
            )
        }
        .onChange(of: pickerItems) { _, new in
            guard !new.isEmpty else { return }
            Task { await stageImport(new) }
        }
        .sheet(isPresented: $showingImportSheet) {
            PhotoImportSheet(
                count: pendingData.count,
                tag: $pendingTag,
                note: $pendingNote,
                onSave: { Task { await commitImport() } },
                onCancel: { pendingData = [] }
            )
        }
        .sheet(isPresented: Binding(
            get: { selected != nil },
            set: { if !$0 { selected = nil } }
        )) {
            if let photo = selected {
                PhotoDetailView(photo: photo) {
                    selected = nil
                    load()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { comparing.count == 2 },
            set: { if !$0 { comparing = [] } }
        )) {
            PhotoCompareView(photos: photos, initial: comparing)
        }
        .overlay {
            if importing {
                ProgressView("Importing…")
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
            }
        }
        .alert("Couldn't load photos", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task { load() }
        .onChange(of: env.revision) { _, _ in load() }
    }

    // MARK: Import pipeline

    /// PhotosPicker drives the flow through `pickerItems`; this stages the
    /// raw data so the user can tag the batch before anything is saved.
    private func stageImport(_ items: [PhotosPickerItem]) async {
        importing = true
        defer { importing = false }
        var staged: [(Data, PhotosPickerItem)] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                staged.append((data, item))
            }
        }
        pickerItems = []
        await MainActor.run {
            pendingData = staged
            pendingTag = .front
            pendingNote = ""
            if !staged.isEmpty { showingImportSheet = true }
        }
    }

    private func commitImport() async {
        let batch = pendingData
        let tag = pendingTag
        let noteText = pendingNote
        pendingData = []
        await MainActor.run { importing = true }
        defer {
            Task { @MainActor in
                importing = false
                load()
            }
        }
        // Capture the latest weight once so every photo in the batch shares it.
        let latestKg = (try? env.weights.latestWeight())?.weightKg
        for (data, _) in batch {
            guard let full = Self.downscaledJPEG(data, maxDimension: 1600),
                  let thumb = Self.downscaledJPEG(data, maxDimension: 400) else { continue }
            do {
                _ = try env.measurements.savePhoto(
                    jpegData: full,
                    thumbnailJPEGData: thumb,
                    takenAt: Date(),
                    viewTag: tag,
                    weightKgAtCapture: latestKg,
                    note: noteText.isEmpty ? nil : noteText
                )
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
        await MainActor.run {
            env.logTodayCompletion(kind: .progressPhoto)
        }
    }

    /// Downscale to a max dimension and re-encode as JPEG. Runs off the main
    /// thread; returns nil when the data isn't a decodable image.
    nonisolated static func downscaledJPEG(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    // MARK: Data

    private func load() {
        do {
            photos = Array(try env.measurements.photos(from: .distantPast, to: Date()).reversed())
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - PhotoImportSheet

/// Tag + note for a staged photo batch, applied before saving.
struct PhotoImportSheet: View {
    let count: Int
    @Binding var tag: PhotoViewTag
    @Binding var note: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("View", selection: $tag) {
                        ForEach(PhotoViewTag.allCases, id: \.self) { tag in
                            Text(tag.displayName).tag(tag)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("\(count) photo\(count == 1 ? "" : "s") will be tagged “\(tag.displayName)”."
                    )
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Add photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - File URL helpers

extension MeasurementRepository {
    /// File URL for a raw relative path (e.g. a stored thumbnail path).
    /// Implemented via the existing `fileURL(for:)` since only the relative
    /// path is used to resolve the location.
    func fileURL(relativePath: String) -> URL {
        fileURL(for: ProgressPhoto(relativePath: relativePath))
    }
}

extension TrackingEnvironment {
    /// Thumbnail when one was stored, otherwise the full image.
    func thumbnailURL(for photo: ProgressPhoto) -> URL {
        if let thumb = photo.thumbnailRelativePath {
            return measurements.fileURL(relativePath: thumb)
        }
        return measurements.fileURL(for: photo)
    }
}

// MARK: - ProgressPhotoTile

/// Grid tile: thumbnail (or full image), view-tag chip, date.
struct ProgressPhotoTile: View {
    @Environment(TrackingEnvironment.self) private var env
    let photo: ProgressPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: MFRadii.md)
                        .fill(MFColor.surfaceSunken)
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))

            Text(photo.viewTag.displayName)
                .font(MFFont.caption2.weight(.semibold))
                .foregroundColor(MFColor.textOnAccent)
                .padding(.horizontal, MFSpacing.sm)
                .padding(.vertical, MFSpacing.xs)
                .background(MFColor.accent)
                .clipShape(Capsule())
                .padding(MFSpacing.sm)
        }
        .overlay(alignment: .bottom) {
            Text(TrackingFormatting.monthDay.string(from: photo.takenAt))
                .font(MFFont.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, MFSpacing.sm)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(.bottom, MFSpacing.sm)
        }
        .task(id: photo.id) { await loadImage() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress photo, \(photo.viewTag.displayName), \(TrackingFormatting.shortDate.string(from: photo.takenAt))")
    }

    private func loadImage() async {
        let url = env.thumbnailURL(for: photo)
        let loaded = await Task.detached {
            guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
            return UIImage(data: data)
        }.value
        image = loaded
    }
}

// MARK: - PhotoDetailView

/// Full-size photo with metadata and delete.
struct PhotoDetailView: View {
    @Environment(TrackingEnvironment.self) private var env
    let photo: ProgressPhoto
    let onDelete: () -> Void

    @State private var image: UIImage?
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MFSpacing.md) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 300)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))

                    VStack(alignment: .leading, spacing: MFSpacing.sm) {
                        detailRow("Date", TrackingFormatting.shortDateTime.string(from: photo.takenAt))
                        detailRow("View", photo.viewTag.displayName)
                        if let kg = photo.weightKgAtCapture {
                            detailRow("Weight", TrackingFormatting.weight(kg, unit: env.weightUnit))
                        }
                        if let note = photo.note, !note.isEmpty {
                            detailRow("Note", note)
                        }
                    }
                    .mfCard()
                }
                .padding()
            }
            .background(MFColor.background)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
            .task { await loadImage() }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
            Spacer()
            Text(value)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textPrimary)
        }
    }

    private func loadImage() async {
        let url = env.measurements.fileURL(for: photo)
        let loaded = await Task.detached {
            guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
            return UIImage(data: data)
        }.value
        await MainActor.run { image = loaded }
    }

    private func delete() {
        do {
            try env.measurements.deletePhoto(photo)
            env.noteMutation()
            onDelete()
            dismiss()
        } catch {
            // Surface stays simple: dismissal is enough; files are best-effort.
            onDelete()
            dismiss()
        }
    }
}

// MARK: - PhotoCompareView

/// Side-by-side comparison of two progress photos with a draggable divider.
struct PhotoCompareView: View {
    @Environment(TrackingEnvironment.self) private var env
    let photos: [ProgressPhoto]

    @State private var leftID: UUID
    @State private var rightID: UUID
    @State private var divider: CGFloat = 0.5
    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    init(photos: [ProgressPhoto], initial: [ProgressPhoto]) {
        self.photos = photos
        _leftID = State(initialValue: initial.first?.id ?? photos.first!.id)
        _rightID = State(initialValue: initial.dropFirst().first?.id ?? photos.dropFirst().first!.id)
    }

    private var left: ProgressPhoto? { photos.first { $0.id == leftID } }
    private var right: ProgressPhoto? { photos.first { $0.id == rightID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: MFSpacing.md) {
                HStack {
                    Picker("Left", selection: $leftID) {
                        ForEach(photos, id: \.id) { photo in
                            Text("\(photo.viewTag.displayName) · \(TrackingFormatting.monthDay.string(from: photo.takenAt))")
                                .tag(photo.id)
                        }
                    }
                    .labelsHidden()
                    Spacer()
                    Picker("Right", selection: $rightID) {
                        ForEach(photos, id: \.id) { photo in
                            Text("\(photo.viewTag.displayName) · \(TrackingFormatting.monthDay.string(from: photo.takenAt))")
                                .tag(photo.id)
                        }
                    }
                    .labelsHidden()
                }
                .font(MFFont.caption)

                GeometryReader { geometry in
                    // Divider at x = divider * width. The left photo is fully
                    // visible underneath; the right photo is masked to the
                    // region right of the divider.
                    let cutX = geometry.size.width * divider
                    ZStack {
                        compareImage(leftImage)
                        compareImage(rightImage)
                            .mask {
                                Rectangle()
                                    .offset(x: cutX)
                            }
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 2)
                                    .offset(x: cutX - 1)
                                    .shadow(radius: 4)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                divider = min(0.95, max(0.05, value.location.x / geometry.size.width))
                            }
                    )
                    .accessibilityLabel("Photo comparison. Drag to move the divider.")
                }
                .frame(minHeight: 320)

                if let left, let right {
                    HStack {
                        caption(for: left, side: "Left")
                        Spacer()
                        caption(for: right, side: "Right")
                    }
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                }
                Spacer()
            }
            .padding()
            .background(MFColor.background)
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: leftID) { await load(side: .left) }
            .task(id: rightID) { await load(side: .right) }
        }
    }

    private func compareImage(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(MFColor.surfaceSunken)
                    .overlay { ProgressView() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    private func caption(for photo: ProgressPhoto, side: String) -> some View {
        VStack(alignment: side == "Left" ? .leading : .trailing, spacing: 2) {
            Text("\(photo.viewTag.displayName) · \(TrackingFormatting.shortDate.string(from: photo.takenAt))")
            if let kg = photo.weightKgAtCapture {
                Text(TrackingFormatting.weight(kg, unit: env.weightUnit))
                    .monospacedDigit()
            }
        }
    }

    private enum Side { case left, right }

    private func load(side: Side) async {
        let photo: ProgressPhoto? = side == .left ? left : right
        guard let photo else { return }
        let url = env.measurements.fileURL(for: photo)
        let loaded = await Task.detached {
            guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
            return UIImage(data: data)
        }.value
        await MainActor.run {
            switch side {
            case .left: leftImage = loaded
            case .right: rightImage = loaded
            }
        }
    }
}

#Preview("Progress photos") {
    withPreviewEnvironment { env in
        NavigationStack {
            ProgressPhotosView()
        }
        .environment(env)
    }
}
