import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodLogRootView

/// The Food Log tab: collapsing calendar week banner, day timeline with
/// hour blocks, and the search footer.
///
/// Collapse behavior (matches the palette showcase demo): in `show` mode
/// the full banner collapses into a compact summary strip once the
/// timeline scrolls past 72pt; scrolling back to the top expands it again.
/// `showAndPin` never collapses; `hide` removes the banner entirely.
public struct FoodLogRootView: View {
    @State private var viewModel: FoodLogViewModel
    private let searchService: any FoodSearchService
    private let foods: any FoodRepository

    @AppStorage("mf.foodLog.weekBannerMode")
    private var bannerModeRaw: String = MFWeekBannerMode.show.rawValue

    @State private var isCollapsed = false
    @State private var summaryPage = 0
    @State private var activeSheet: FoodLogSheet?
    @State private var editorRequest: FoodEditorRequest?
    @State private var plateItems: [PlateItem] = []
    @State private var toastMessage: String?

    private var bannerMode: MFWeekBannerMode {
        MFWeekBannerMode(rawValue: bannerModeRaw) ?? .show
    }

    public init(
        logs: any LogRepository,
        foods: any FoodRepository,
        foodSearch: any FoodSearchService,
        program: any ProgramRepository,
        onFoodLogged: (() -> Void)? = nil
    ) {
        let viewModel = FoodLogViewModel(
            logs: logs,
            foods: foods,
            program: program
        )
        viewModel.onFoodLogged = onFoodLogged
        _viewModel = State(initialValue: viewModel)
        self.searchService = foodSearch
        self.foods = foods
    }

    public var body: some View {
        VStack(spacing: 0) {
            if bannerMode != .hide {
                headerView
                    .background(MFColor.background)
                    .zIndex(1)
            }

            ScrollView {
                VStack(spacing: 0) {
                    timelineView
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: TimelineOffsetKey.self,
                            value: geometry.frame(in: .named("foodTimeline")).minY
                        )
                    }
                )
                .padding(.bottom, MFSpacing.xl)
            }
            .coordinateSpace(name: "foodTimeline")
            .onPreferenceChange(TimelineOffsetKey.self) { minY in
                guard bannerMode == .show else { return }
                let collapsed = -minY > 72
                if collapsed != isCollapsed {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isCollapsed = collapsed
                    }
                }
            }

            searchFooter
        }
        .background(MFColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reload() }
        .onChange(of: bannerModeRaw) { _, _ in
            if bannerMode != .show { isCollapsed = false }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
        .sheet(item: $editorRequest) { request in
            editorView(for: request)
        }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                MFToast(message: message)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(spacing: 0) {
            navRow
                .padding(.horizontal, MFSpacing.lg)
                .padding(.vertical, MFSpacing.sm)

            if bannerMode == .showAndPin || !isCollapsed {
                weekStrip
                    .padding(.horizontal, MFSpacing.lg)
                    .padding(.bottom, MFSpacing.sm)
                summaryStrip
                    .padding(.horizontal, MFSpacing.lg)
                    .padding(.bottom, MFSpacing.sm)
            } else {
                compactSummary
                    .padding(.horizontal, MFSpacing.lg)
                    .padding(.bottom, MFSpacing.sm)
            }

            Divider().background(MFColor.separator)
        }
    }

    private var navRow: some View {
        HStack {
            Menu {
                Button("Copy day") { viewModel.copyCurrentDay(); showToast("Day copied") }
                if let pasteLabel = viewModel.clipboard.pasteLabel {
                    Button(pasteLabel) {
                        let count = viewModel.pasteIntoSelectedDay()
                        showToast(count > 0 ? "Pasted \(count) entr\(count == 1 ? "y" : "ies")" : "Nothing to paste")
                    }
                }
                Button(viewModel.isDayComplete ? "Reopen day" : "Mark day complete") {
                    viewModel.toggleDayComplete()
                }
                Button("Day note…") { activeSheet = .dayNote }
                Picker("Week banner", selection: weekBannerModeBinding) {
                    ForEach(MFWeekBannerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Divider()
                Button("Clear day", role: .destructive) { viewModel.clearDay() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(MFColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Day menu")
            }

            Spacer()

            Button { viewModel.shiftDay(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(MFColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous day")

            Text(dayTitle)
                .font(MFFont.title3)
                .foregroundColor(MFColor.textPrimary)
                .frame(minWidth: 120)
                .accessibilityAddTraits(.isHeader)

            Button { viewModel.shiftDay(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(MFColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next day")

            Spacer()

            // Balances the menu button so the title stays centered.
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var weekBannerModeBinding: Binding<MFWeekBannerMode> {
        Binding(
            get: { bannerMode },
            set: { bannerModeRaw = $0.rawValue }
        )
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.selectedDay) { return "Today" }
        if calendar.isDateInYesterday(viewModel.selectedDay) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: viewModel.selectedDay)
    }

    private var weekStrip: some View {
        let days = FoodLogViewModel.weekDays(containing: viewModel.selectedDay)
        return HStack(spacing: MFSpacing.sm) {
            ForEach(days, id: \.self) { day in
                MFDayPill(
                    dayLetter: narrowWeekdayLetter(for: day),
                    dateNumber: dayNumber(for: day),
                    hasLogged: viewModel.weekLoggedDays.contains(MFDates.startOfDay(day)),
                    isSelected: Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDay)
                ) {
                    viewModel.selectDay(day)
                }
            }
        }
    }

    private var summaryStrip: some View {
        TabView(selection: $summaryPage) {
            macroSummaryPage.tag(0)
            microSummaryPage.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 64)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index == summaryPage ? MFColor.textPrimary : MFColor.separator)
                        .frame(width: 6, height: 6)
                }
            }
            .offset(y: 10)
            .accessibilityHidden(true)
        }
        .padding(.bottom, 6)
        .accessibilityLabel("Day summary, page \(summaryPage + 1) of 2")
    }

    /// Macro letters lead the values on the timeline strip ("P 29 / 107") —
    /// see `MFMacroBadgePosition` for the per-surface research.
    private var macroSummaryPage: some View {
        HStack(spacing: MFSpacing.lg) {
            MFMacroMiniBar(
                eaten: viewModel.totals.calories, target: viewModel.goals.calories,
                color: MFColor.calories, badge: .flame, badgePosition: .leading, isKcal: true
            )
            MFMacroMiniBar(
                eaten: viewModel.totals.protein, target: viewModel.goals.protein,
                color: MFColor.protein, badge: .letter("P"), badgePosition: .leading
            )
            MFMacroMiniBar(
                eaten: viewModel.totals.fat, target: viewModel.goals.fat,
                color: MFColor.fat, badge: .letter("F"), badgePosition: .leading
            )
            MFMacroMiniBar(
                eaten: viewModel.totals.carbs, target: viewModel.goals.carbs,
                color: MFColor.carbs, badge: .letter("C"), badgePosition: .leading
            )
        }
    }

    private var microSummaryPage: some View {
        HStack(spacing: MFSpacing.lg) {
            ForEach(viewModel.microGoals, id: \.key) { item in
                MFMacroMiniBar(
                    eaten: viewModel.totals.total(item.key),
                    target: item.target,
                    color: MFColor.micro
                )
                .overlay(alignment: .topLeading) {
                    Text(item.key.displayName)
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textSecondary)
                        .offset(y: -2)
                }
            }
        }
    }

    private var compactSummary: some View {
        HStack(spacing: MFSpacing.md) {
            Text(dayTitle)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            macroSummaryPage
        }
    }

    // MARK: Timeline

    private var timelineView: some View {
        LazyVStack(spacing: MFSpacing.md, pinnedViews: []) {
            if let note = viewModel.dayNote, !note.isEmpty {
                dayNoteCard(note)
            }
            ForEach(hourBlocks) { block in
                FoodTimelineBlockView(
                    block: block,
                    onAdd: { activeSheet = .search(hour: block.hour) },
                    onSelectEntry: { entry in editorRequest = .editEntry(entry) },
                    onCopyBlock: {
                        FoodLogClipboard.shared.copyBlock(
                            label: Self.hourLabel(block.hour),
                            entries: block.entries
                        )
                        showToast("Copied \(block.entries.count) foods")
                    },
                    onDeleteEntry: { viewModel.deleteEntry($0) }
                )
                .padding(.horizontal, MFSpacing.lg)
            }
            if viewModel.entries.isEmpty {
                emptyState
                    .padding(.top, MFSpacing.xxxl)
            }
        }
        .padding(.top, MFSpacing.md)
    }

    private var hourBlocks: [FoodTimelineBlock] {
        let calendar = Calendar.current
        let hours = viewModel.entries.map { calendar.component(.hour, from: $0.timestamp) }
        let currentHour = calendar.component(.hour, from: Date())
        let firstHour = hours.min() ?? currentHour
        let lastHour = max(hours.max() ?? currentHour, currentHour)
        return (firstHour...lastHour).map { hour in
            FoodTimelineBlock(
                hour: hour,
                entries: viewModel.entries
                    .filter { calendar.component(.hour, from: $0.timestamp) == hour }
                    .sorted { $0.timestamp < $1.timestamp }
            )
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func dayNoteCard(_ note: String) -> some View {
        HStack(spacing: MFSpacing.sm) {
            Image(systemName: "note.text")
                .foregroundColor(MFColor.textSecondary)
            Text(note)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, MFSpacing.lg)
        .accessibilityLabel("Day note: \(note)")
    }

    private var emptyState: some View {
        VStack(spacing: MFSpacing.md) {
            MFFoodThumbnail(symbol: "fork.knife")
            Text("No foods logged yet")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Text("Search the food database to log your first meal.")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
            MFButton("Search foods", style: .secondary, size: .medium) {
                activeSheet = .search(hour: nil)
            }
            .frame(width: 200)
        }
        .padding(.horizontal, MFSpacing.xxl)
    }

    // MARK: Search footer

    private var searchFooter: some View {
        HStack(spacing: MFSpacing.sm) {
            Button { activeSheet = .search(hour: nil) } label: {
                HStack(spacing: MFSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(MFColor.textSecondary)
                    Text("Search for a food")
                        .font(MFFont.body)
                        .foregroundColor(MFColor.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, MFSpacing.lg)
                .padding(.vertical, MFSpacing.md)
                .background(MFColor.surfaceSunken)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Search for a food")

            MFIconButton(icon: "barcode.viewfinder", label: "Look up a barcode") {
                activeSheet = .barcode
            }
            .frame(width: 52, height: 52)
        }
        .padding(.horizontal, MFSpacing.lg)
        .padding(.vertical, MFSpacing.sm)
        .background(MFColor.background)
    }

    // MARK: Sheets

    private func sheetView(for sheet: FoodLogSheet) -> some View {
        Group {
            switch sheet {
            case .search(let hour):
                FoodSearchView(
                    searchService: searchService,
                    foods: foods,
                    onSelectFood: { food in
                        activeSheet = nil
                        editorRequest = .logFood(food: food, grams: food.servingSizeGrams, hour: hour)
                    },
                    onQuickAdd: {
                        activeSheet = nil
                        // Small delay so the sheet transition doesn't collide.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .quickAdd
                        }
                    },
                    onCreateCustomFood: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .customFood(nil)
                        }
                    },
                    onCreateRecipe: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .recipe(nil)
                        }
                    }
                )
            case .plate:
                PlateSheetView(
                    items: $plateItems,
                    goals: viewModel.goals,
                    dayTotals: viewModel.totals,
                    onLogPlate: { items in
                        let ok = viewModel.logPlate(items, timestamp: Date())
                        if ok {
                            plateItems = []
                            activeSheet = nil
                            showToast("Logged \(items.count) foods")
                        }
                    },
                    onSearch: { replaceSheet(with: .search(hour: nil)) },
                    onQuickAdd: { replaceSheet(with: .quickAdd) },
                    onLibrary: { replaceSheet(with: .library) },
                    onScan: { replaceSheet(with: .barcode) }
                )
            case .quickAdd:
                QuickAddView { calories, protein, fat, carbs, mealSlot in
                    if viewModel.quickAdd(
                        calories: calories, protein: protein, fat: fat,
                        carbs: carbs, mealSlot: mealSlot
                    ) {
                        activeSheet = nil
                        showToast("Quick add logged")
                    } else {
                        showToast("Couldn't log quick add")
                    }
                }
            case .customFood(let food):
                CustomFoodEditorView(food: food, foods: foods) { _ in
                    activeSheet = nil
                    showToast(food == nil ? "Custom food saved" : "Custom food updated")
                }
            case .recipe(let recipe):
                RecipeBuilderView(recipe: recipe, foods: foods, searchService: searchService) { _ in
                    activeSheet = nil
                    showToast(recipe == nil ? "Recipe saved" : "Recipe updated")
                }
            case .library:
                FoodLibraryView(
                    foods: foods,
                    onSelectFood: { food in
                        activeSheet = nil
                        editorRequest = .logFood(food: food, grams: food.servingSizeGrams, hour: nil)
                    },
                    onEditFood: { food in replaceSheet(with: .customFood(food)) },
                    onEditRecipe: { recipe in replaceSheet(with: .recipe(recipe)) }
                )
            case .dayNote:
                DayNoteSheet(note: viewModel.dayNote ?? "") { note in
                    viewModel.setDayNote(note)
                    activeSheet = nil
                }
            case .barcode:
                BarcodeLookupSheet(searchService: searchService, foods: foods) { food in
                    activeSheet = nil
                    editorRequest = .logFood(food: food, grams: food.servingSizeGrams, hour: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func editorView(for request: FoodEditorRequest) -> some View {
        switch request {
        case .logFood(let food, let grams, let hour):
            FoodDetailEditorView(
                food: food,
                initialGrams: grams,
                defaultDate: dateForHour(hour),
                onLog: { grams, mealSlot, date, note in
                    let ok = viewModel.logFood(food, grams: grams, mealSlot: mealSlot, timestamp: date, note: note)
                    if ok {
                        editorRequest = nil
                        showToast("Logged \(food.name)")
                    }
                },
                onAddToPlate: { grams, mealSlot, note in
                    plateItems.append(PlateItem(food: food, grams: grams, mealSlot: mealSlot, note: note))
                    editorRequest = nil
                    activeSheet = .plate
                }
            )
        case .editEntry(let entry):
            FoodDetailEditorView(
                entry: entry,
                onSave: { grams, mealSlot, date, note in
                    viewModel.updateEntry(entry, grams: grams, mealSlot: mealSlot, timestamp: date, note: note)
                    editorRequest = nil
                },
                onDelete: {
                    viewModel.deleteEntry(entry)
                    editorRequest = nil
                },
                onCopy: {
                    FoodLogClipboard.shared.copyFood(entry)
                    editorRequest = nil
                    showToast("Food copied")
                }
            )
        }
    }

    private func dateForHour(_ hour: Int?) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: hour ?? calendar.component(.hour, from: Date()),
                                 minute: 0, second: 0, of: viewModel.selectedDay) ?? viewModel.selectedDay
        return base
    }

    private func narrowWeekdayLetter(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: day)
    }

    private func dayNumber(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: day)
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { toastMessage = nil }
        }
    }

    /// Dismisses the current sheet, then presents another one. SwiftUI's
    /// `.sheet(item:)` doesn't reliably swap sheets in place, so the
    /// replacement is deferred until the dismissal lands.
    private func replaceSheet(with sheet: FoodLogSheet) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            activeSheet = sheet
        }
    }
}

// MARK: - Supporting types

private enum TimelineOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum FoodLogSheet: Identifiable {
    case search(hour: Int?)
    case plate
    case quickAdd
    case customFood(FoodItem?)
    case recipe(FoodItem?)
    case library
    case dayNote
    case barcode

    var id: String {
        switch self {
        case .search(let hour): return "search-\(hour.map(String.init) ?? "any")"
        case .plate: return "plate"
        case .quickAdd: return "quickAdd"
        case .customFood(let food): return "customFood-\(food?.id.uuidString ?? "new")"
        case .recipe(let recipe): return "recipe-\(recipe?.id.uuidString ?? "new")"
        case .library: return "library"
        case .dayNote: return "dayNote"
        case .barcode: return "barcode"
        }
    }
}

private enum FoodEditorRequest: Identifiable {
    case logFood(food: FoodItem, grams: Double, hour: Int?)
    case editEntry(LogEntry)

    var id: String {
        switch self {
        case .logFood(let food, _, let hour):
            return "log-\(food.id.uuidString)-\(hour.map(String.init) ?? "any")"
        case .editEntry(let entry):
            return "edit-\(entry.id.uuidString)"
        }
    }
}

#Preview("Food log") {
    struct Demo: View {
        var body: some View {
            NavigationStack {
                foodLogPreview
            }
        }

        @MainActor
        var foodLogPreview: some View {
            let store = try! DataStore(inMemory: true, seed: false)
            return FoodLogRootView(
                logs: store.logs,
                foods: store.foods,
                foodSearch: store.foodSearch,
                program: store.program
            )
            .mfThemed()
        }
    }
    return Demo()
}
