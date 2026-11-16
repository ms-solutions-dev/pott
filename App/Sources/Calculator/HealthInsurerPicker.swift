import PottCore
import PottDesign
import SwiftUI
import TaxDE

/// The health insurer row in "More details": the chosen insurer and its additional contribution,
/// or the average, or a rate typed in. Opens a searchable list.
struct HealthInsurerRow: View {
    @Binding var rate: Decimal
    @Binding var insurer: String?
    var year: Int
    var region: String

    @State private var showsSheet =
        ProcessInfo.processInfo.arguments.contains("-PottInsurerOpen")
    @State private var flash = false

    var body: some View {
        let data = HealthInsurerList.forYear(year)
        VStack(alignment: .leading, spacing: 8) {
            Text("Health insurance").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            Button {
                showsSheet = true
            } label: {
                HStack(spacing: 12) {
                    InsurerBadge(
                        text: insurer.flatMap { data?.list.insurer(named: $0)?.monogram } ?? badgeFallback)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title(data?.list)).textRole(.bodyStrong).lineLimit(1)
                        Text(subtitle(data?.list)).textRole(.caption).foregroundStyle(
                            Palette.secondaryText.color
                        )
                        .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(Self.percent(rate)).textRole(.amount)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText.color)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .frame(minHeight: 52)
                .background(
                    Palette.accent.color.opacity(flash ? 0.35 : 0),
                    in: .rect(cornerRadius: 14, style: .continuous)
                )
                .contentShape(.rect)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, -6)
            .accessibilityLabel(Text("Health insurance: \(title(data?.list)), \(Self.percent(rate))"))
            .accessibilityHint(Text("Choose your health insurer or enter the rate"))
            .accessibilityIdentifier("healthInsurerRow")

            if let list = data?.list, let name = insurer, let current = list.insurer(named: name),
                let listed = current.additionalRate ?? (current.scope == .sector ? 0 : nil), listed != rate
            {
                Button {
                    take(rate: listed, insurer: name)
                } label: {
                    Text("The list says \(Self.percent(listed)) since \(Self.date(list)). Use it")
                        .textRole(.caption)
                        .foregroundStyle(Palette.accentText.color)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showsSheet) {
            if let data {
                HealthInsurerSheet(
                    data: data, year: year, region: region, rate: rate, insurer: insurer
                ) { newRate, newInsurer in
                    take(rate: newRate, insurer: newInsurer)
                }
            }
        }
    }

    private var badgeFallback: String { insurer == nil && isAverage ? "Ø" : "%" }

    private var isAverage: Bool {
        HealthInsurerList.forYear(year).flatMap { data in
            (data.list.average(for: year) ?? data.list.average(for: data.list.year))?.rate
        } == rate
    }

    private func title(_ list: HealthInsurerList?) -> String {
        if let insurer { return insurer }
        return isAverage ? String(localized: "Average") : String(localized: "Own rate")
    }

    private func subtitle(_ list: HealthInsurerList?) -> String {
        if insurer != nil, let list {
            return String(localized: "Additional contribution · as of \(Self.date(list))")
        }
        return isAverage
            ? String(localized: "Average additional contribution \(String(year))")
            : String(localized: "entered by you")
    }

    private func take(rate newRate: Decimal, insurer newInsurer: String?) {
        rate = newRate
        insurer = newInsurer
        withAnimation(.easeOut(duration: 0.15)) { flash = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) { flash = false }
    }

    static func percent(_ rate: Decimal) -> String {
        rate.formatted(.number.precision(.fractionLength(2))) + " %"
    }

    static func date(_ list: HealthInsurerList) -> String {
        var style = Date.FormatStyle(date: .numeric, time: .omitted)
        style.timeZone = .gmt
        return list.asOfDate?.formatted(style) ?? list.asOf
    }
}

/// Letters of an insurer on a small tile.
struct InsurerBadge: View {
    var text: String
    var size: CGFloat = 38

    var body: some View {
        Text(text)
            .font(TextRole.amount.font)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(4)
            .foregroundStyle(Palette.accentText.color)
            .frame(width: size, height: size)
            .background(Palette.raised.color, in: .rect(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Search the bundled list, or type the rate in.
struct HealthInsurerSheet: View {
    var data: (list: HealthInsurerList, isFromEarlierYear: Bool)
    var year: Int
    var region: String
    var rate: Decimal
    var insurer: String?
    var choose: (Decimal, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var manual = false
    @State private var query =
        ProcessInfo.processInfo.arguments.firstIndex(of: "-PottInsurerQuery").map {
            index in
            ProcessInfo.processInfo.arguments.dropFirst(index + 1).first ?? ""
        } ?? ""
    @State private var onlyRegion = true
    @State private var manualText = ""
    @FocusState private var searchFocused: Bool

    private var average: Decimal? {
        (data.list.average(for: year) ?? data.list.average(for: data.list.year))?.rate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health insurer").textRole(.section).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") { dismiss() }
                    .textRole(.bodyStrong)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .foregroundStyle(Palette.onAccent.color)
                    .background(Palette.accent.color, in: .capsule)
                    .buttonStyle(PressScaleStyle())
            }
            Picker("Mode", selection: $manual.animation(.spring(duration: 0.35))) {
                Text("Find insurer").tag(false)
                Text("Enter percent").tag(true)
            }
            .pickerStyle(.segmented)

            if manual {
                manualEntry.transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                listMode.transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Palette.card.color)
        .onAppear {
            manualText = rate.formatted(.number.precision(.fractionLength(2)))
            if !ProcessInfo.processInfo.arguments.contains("-PottNoFocus") { searchFocused = true }
        }
    }

    private var stateName: String {
        GermanState.all.first { $0.code == region }?.name ?? region
    }

    private var results: [HealthInsurer] {
        data.list.search(query, openIn: onlyRegion ? region : nil)
    }

    private var listMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondaryText.color)
                TextField("Name, e.g. TK or AOK", text: $query)
                    .textRole(.body)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondaryText.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear search"))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Palette.raised.color, in: .rect(cornerRadius: 14, style: .continuous))

            HStack {
                Chip(String(localized: "Open in \(stateName)"), isSelected: onlyRegion) {
                    withAnimation(.snappy) { onlyRegion.toggle() }
                }
                Spacer()
                Text("\(results.count) insurers").textRole(.caption).foregroundStyle(
                    Palette.secondaryText.color)
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    if query.isEmpty, let average {
                        row(
                            badge: "Ø", name: AttributedString(String(localized: "Don’t know")),
                            detail: String(
                                localized: "Average for \(String(year)), set by the health ministry"),
                            rate: average, selected: insurer == nil && rate == average, highlightBadge: true
                        ) { pick(average, nil) }
                    }
                    ForEach(results) { item in
                        row(
                            badge: item.monogram, name: highlighted(item.name), detail: scopeText(item),
                            rate: item.additionalRate, selected: insurer == item.name
                        ) { pick(item.additionalRate ?? 0, item.name) }
                    }
                    if results.isEmpty {
                        emptyText
                            .textRole(.caption)
                            .foregroundStyle(Palette.secondaryText.color)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    Text(sourceLine)
                        .textRole(.caption)
                        .foregroundStyle(Palette.secondaryText.color)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .animation(.snappy, value: query)
                .animation(.snappy, value: onlyRegion)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var emptyText: Text {
        onlyRegion
            ? Text(
                "No insurer matches “\(query)” in \(stateName). Turn the filter off or enter the percent yourself."
            )
            : Text("No insurer matches “\(query)”. Enter the percent yourself.")
    }

    private var sourceLine: String {
        let date = HealthInsurerRow.date(data.list)
        if data.isFromEarlierYear {
            return String(
                localized:
                    "Rates of \(String(data.list.year)) as of \(date), GKV-Spitzenverband. The rates for \(String(year)) are not out yet."
            )
        }
        return String(
            localized:
                "Additional contribution \(String(data.list.year)) · GKV-Spitzenverband · as of \(date)")
    }

    private func row(
        badge: String, name: AttributedString, detail: String, rate: Decimal?, selected: Bool,
        highlightBadge: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if highlightBadge {
                    Text(badge)
                        .font(TextRole.amount.font)
                        .foregroundStyle(Palette.onAccent.color)
                        .frame(width: 34, height: 34)
                        .background(Palette.accent.color, in: .rect(cornerRadius: 11, style: .continuous))
                } else {
                    InsurerBadge(text: badge, size: 34)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).textRole(.bodyStrong).lineLimit(2)
                    Text(detail).textRole(.caption).foregroundStyle(Palette.secondaryText.color).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(rate.map(HealthInsurerRow.percent) ?? "–")
                    .textRole(.amount)
                    .foregroundStyle(selected ? Palette.accentText.color : Palette.text.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .background(
                selected ? Palette.accent.color.opacity(0.14) : .clear,
                in: .rect(cornerRadius: 14, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func highlighted(_ name: String) -> AttributedString {
        var text = AttributedString(name)
        guard !query.isEmpty,
            let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        else { return text }
        text[range].backgroundColor = Palette.accent.color.opacity(0.35)
        return text
    }

    private func scopeText(_ insurer: HealthInsurer) -> String {
        switch insurer.scope {
        case .nationwide: String(localized: "nationwide")
        case .company: String(localized: "employees of the company only")
        case .sector: String(localized: "agriculture, no additional contribution")
        case .states:
            insurer.states.compactMap { code in GermanState.all.first { $0.code == code }?.name }
                .formatted(.list(type: .and, width: .short))
        }
    }

    private func pick(_ newRate: Decimal, _ newInsurer: String?) {
        choose(newRate, newInsurer)
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            dismiss()
        }
    }

    private var manualValue: Decimal? {
        let normalized = manualText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(
            in: .whitespaces)
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
            value >= 0, value < 10
        else { return nil }
        return value
    }

    private var manualEntry: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("2,90", text: $manualText)
                    .font(.custom("BarlowCondensed-ExtraBold", size: 56, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 170)
                    .accessibilityLabel(Text("Additional contribution in percent"))
                Text("%")
                    .font(.custom("BarlowCondensed-ExtraBold", size: 36, relativeTo: .title))
                    .foregroundStyle(Palette.accentText.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Palette.background.color, in: .rect(cornerRadius: 20, style: .continuous))

            HStack(spacing: 8) {
                step(-Decimal(string: "0.1")!)
                if let average {
                    Chip(String(localized: "Ø \(average.formatted())"), isSelected: false) {
                        manualText = average.formatted(.number.precision(.fractionLength(2)))
                    }
                }
                step(Decimal(string: "0.1")!)
            }
            Text(
                "It is in your insurer’s letter or on its website, usually called “Zusatzbeitrag”. As an employee you pay half, your employer the other half."
            )
            .textRole(.caption)
            .foregroundStyle(Palette.secondaryText.color)
            .multilineTextAlignment(.center)
            Button("Take over") {
                if let value = manualValue { pick(value, nil) }
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(manualValue == nil)
            .opacity(manualValue == nil ? 0.5 : 1)
            Spacer(minLength: 0)
        }
    }

    private func step(_ delta: Decimal) -> some View {
        Chip("\(delta > 0 ? "+" : "−") \((delta > 0 ? delta : -delta).formatted())", isSelected: false) {
            let value = max(0, (manualValue ?? average ?? 0) + delta)
            manualText = value.formatted(.number.precision(.fractionLength(2)))
        }
        .accessibilityLabel(Text(delta > 0 ? "Increase by 0.1" : "Decrease by 0.1"))
    }
}
