import PottDesign
import SwiftUI
import WidgetKit

@main
struct PottWidgetBundle: WidgetBundle {
    var body: some Widget {
        LeftWidget()
    }
}

/// "How much is left?" on the home screen and the lock screen.
struct LeftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.ms-solutions.pott.left", provider: Provider()) { entry in
            LeftView(entry: entry)
                .containerBackground(Palette.background.color, for: .widget)
        }
        .configurationDisplayName("Left this month")
        .description("What is left after your fixed costs.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct Entry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // The app reloads the widget after every change; the daily refresh only rolls the month over.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(
            Timeline(entries: [Entry(date: .now, snapshot: WidgetSnapshot.read())], policy: .after(tomorrow)))
    }
}

struct LeftView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    init(entry: Entry) {
        self.entry = entry
        MainActor.assumeIsolated { PottFonts.register() }
    }

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.hasIncome {
            switch family {
            case .accessoryCircular:
                Gauge(value: snapshot.ratio) {
                    Text("Pott")
                } currentValueLabel: {
                    Text(snapshot.amount(snapshot.leftCents)).minimumScaleFactor(0.4)
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text(snapshot.leftCents < 0 ? "Short this month" : "Left this month").font(.caption)
                    Text(snapshot.amount(abs(snapshot.leftCents))).font(.title3.bold())
                    Gauge(value: snapshot.ratio) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
                }
            case .accessoryInline:
                Text("Left: \(snapshot.amount(snapshot.leftCents))")
            case .systemMedium:
                HStack(spacing: 18) {
                    ring(snapshot)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Income").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                        Text(snapshot.amount(snapshot.incomeCents)).textRole(.amount).foregroundStyle(
                            Palette.text.color)
                        Text("\(Int((snapshot.ratio * 100).rounded())) % left")
                            .textRole(.caption)
                            .foregroundStyle(Palette.secondaryText.color)
                    }
                    Spacer(minLength: 0)
                }
            default:
                ring(snapshot)
            }
        } else {
            VStack(spacing: 6) {
                Text("Pott").textRole(.section).foregroundStyle(Palette.accentText.color)
                Text("Open Pott and enter your income.")
                    .textRole(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.secondaryText.color)
            }
        }
    }

    private func ring(_ snapshot: WidgetSnapshot) -> some View {
        let short = snapshot.leftCents < 0
        return ZStack {
            Circle().stroke(Palette.track.color, lineWidth: 11)
            Circle()
                .trim(from: 0, to: short ? 0 : snapshot.ratio)
                .stroke(Palette.ring.color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(short ? "short" : "left").textRole(.caption).foregroundStyle(Palette.secondaryText.color)
                Text(snapshot.amount(abs(snapshot.leftCents)))
                    .textRole(.amount)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(short ? Palette.negative.color : Palette.accentText.color)
            }
            .padding(14)
        }
        .padding(4)
    }
}
