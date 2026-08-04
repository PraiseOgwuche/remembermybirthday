import WidgetKit
import SwiftUI

struct UpcomingBirthdayEntry: TimelineEntry {
    let date: Date
    let person: WidgetPersonSnapshot?
    let nextPeople: [WidgetPersonSnapshot]
}

struct UpcomingBirthdayProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingBirthdayEntry {
        UpcomingBirthdayEntry(
            date: Date(),
            person: WidgetPersonSnapshot(
                id: UUID().uuidString,
                displayName: "Alex",
                firstName: "Alex",
                shortDate: "Aug 20",
                daysUntil: 12,
                countdownLabel: "12 days",
                draft: "Happy birthday, Alex! Hope today treats you well.",
                phone: "",
                birthMonth: 8
            ),
            nextPeople: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingBirthdayEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingBirthdayEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> UpcomingBirthdayEntry {
        let snapshot = WidgetSnapshotStore.load()
        return UpcomingBirthdayEntry(
            date: Date(),
            person: snapshot.people.first,
            nextPeople: Array(snapshot.people.dropFirst().prefix(3))
        )
    }
}

struct RememberWidgetEntryView: View {
    var entry: UpcomingBirthdayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let person = entry.person {
                switch family {
                case .systemSmall:
                    smallView(person)
                case .systemMedium:
                    mediumView(person)
                default:
                    largeView(person)
                }
            } else {
                emptyView
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remember My Birthday")
                .font(.headline)
            Text("Add birthdays in the app to see who’s next.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func smallView(_ person: WidgetPersonSnapshot) -> some View {
        Link(destination: RememberDeepLink.url(action: .message, personId: personUUID(person))) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.countdownLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(person.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(person.shortDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Draft →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func mediumView(_ person: WidgetPersonSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.headline)
                Text("\(person.countdownLabel) · \(person.shortDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(person.draft)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                actionLink("Send", action: .send, person: person)
                actionLink("Schedule", action: .schedule, person: person)
                actionLink("Draft", action: .message, person: person)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func largeView(_ person: WidgetPersonSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.title3.weight(.semibold))
                Text("\(person.countdownLabel) · \(person.shortDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(person.draft)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            HStack(spacing: 8) {
                actionLink("Send", action: .send, person: person)
                actionLink("Schedule", action: .schedule, person: person)
                actionLink("Draft", action: .message, person: person)
            }

            if !entry.nextPeople.isEmpty {
                Divider()
                Text("Coming up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(entry.nextPeople) { next in
                    Link(destination: RememberDeepLink.url(action: .detail, personId: personUUID(next))) {
                        HStack {
                            Text(next.displayName)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(next.countdownLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func actionLink(_ title: String, action: RememberDeepLink.Action, person: WidgetPersonSnapshot) -> some View {
        Link(destination: RememberDeepLink.url(action: action, personId: personUUID(person))) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
    }

    private func personUUID(_ person: WidgetPersonSnapshot) -> UUID {
        UUID(uuidString: person.id) ?? UUID()
    }
}

struct RememberWidget: Widget {
    let kind = "RememberWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingBirthdayProvider()) { entry in
            RememberWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Upcoming birthday")
        .description("Next birthday, draft preview, and jump to Send or Schedule.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct RememberWidgetBundle: WidgetBundle {
    var body: some Widget {
        RememberWidget()
    }
}
