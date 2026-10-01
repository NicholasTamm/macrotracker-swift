import SwiftUI
import DesignSystem
import DataLayer

// MARK: - BarcodeLookupSheet

/// Manual barcode entry → `FoodSearchService.lookupBarcode` (local foods,
/// then cached and live Open Food Facts). Camera scanning itself belongs
/// to issue #5 (CaptureFeature); this sheet covers typed/pasted codes.
public struct BarcodeLookupSheet: View {
    @State private var viewModel: FoodSearchViewModel
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let onSelectFood: (FoodItem) -> Void

    public init(
        searchService: any FoodSearchService,
        foods: any FoodRepository,
        onSelectFood: @escaping (FoodItem) -> Void
    ) {
        _viewModel = State(initialValue: FoodSearchViewModel(
            searchService: searchService,
            foods: foods
        ))
        self.onSelectFood = onSelectFood
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        MFTextField(
                            "Barcode",
                            placeholder: "e.g. 012345678905",
                            text: $viewModel.barcodeEntry,
                            keyboard: .numberPad
                        )
                        MFButton("Look up", style: .secondary, size: .medium) {
                            Task { await viewModel.lookupBarcode(viewModel.barcodeEntry) }
                        }
                        .frame(width: 110)
                    }
                } footer: {
                    Text("Camera barcode scanning arrives with Capture (issue #5).")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textTertiary)
                }

                if let result = viewModel.barcodeResult {
                    Section("Match") {
                        MFFoodSearchRow(
                            name: result.name,
                            brand: result.brand.isEmpty ? nil : result.brand,
                            kcal: result.caloriesPer100g,
                            protein: result.proteinPer100g,
                            carbs: 0,
                            fat: 0,
                            servingText: "100",
                            unitText: "g",
                            openmojiHex: MFFoodIconMapper.hex(forName: result.name)
                        ) {
                            do {
                                onSelectFood(try viewModel.resolveFood(for: result))
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else if viewModel.barcodeLookupFailed {
                    Section {
                        Text("No food found for that barcode. Create it as a custom food from search.")
                            .font(MFFont.subheadline)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
            }
            .navigationTitle("Barcode lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't open food", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }
}

// MARK: - DayNoteSheet

/// Edit the selected day's note.
public struct DayNoteSheet: View {
    @State private var note: String
    private let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(note: String, onSave: @escaping (String) -> Void) {
        _note = State(initialValue: note)
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("How did today go?", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    MFButton("Save note", style: .primary, size: .large) {
                        onSave(note)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Day note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
