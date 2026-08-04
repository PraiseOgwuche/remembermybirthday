import SwiftUI

struct PersonDetailView: View {
    let person: BirthdayPerson

    @State private var giftIdeas: [GiftIdea] = []

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(person.displayName)
                        .font(.title.weight(.bold))
                    Text(countdownLine)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }

            Section("Details") {
                LabeledContent("Birthday") {
                    Text(person.formattedDate)
                }
                if person.hasPhoneNumber {
                    LabeledContent("Phone") {
                        Text(person.phoneNumber)
                    }
                }
                if !person.relationship.isEmpty {
                    LabeledContent("Relationship") {
                        Text(person.relationship)
                    }
                }
                if !person.nickname.isEmpty {
                    LabeledContent("Nickname") {
                        Text(person.nickname)
                    }
                }
                if !person.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(person.notes)
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !giftIdeas.isEmpty {
                Section {
                    ForEach(giftIdeas) { idea in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(idea.title)
                                .font(.body.weight(.semibold))
                            Text(idea.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    Button("Shuffle ideas") {
                        giftIdeas = GiftIdeasProvider.ideas(for: person, limit: 5)
                    }
                    .font(.subheadline.weight(.medium))
                } header: {
                    Text("Gift ideas")
                } footer: {
                    Text("On-device ideas from relationship and notes. Add tastes in Notes for better picks.")
                }
            }

            Section {
                NavigationLink(value: BirthdayRoute.message(person.id)) {
                    Label("Draft birthday message", systemImage: "text.bubble")
                        .font(.body.weight(.semibold))
                }
                NavigationLink(value: BirthdayRoute.edit(person.id)) {
                    Label("Edit person", systemImage: "pencil")
                }
            } footer: {
                if person.hasScheduledSend, let when = person.scheduledSendAt {
                    Text("Send scheduled for \(when.formatted(date: .abbreviated, time: .shortened)). You’ll get a notification with Send / Review.")
                } else if person.hasPhoneNumber {
                    Text("Draft a message, then Send in Messages — or Schedule for birthday morning.")
                } else {
                    Text("Add a phone number to enable Send in Messages for \(person.firstName).")
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(person.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if giftIdeas.isEmpty {
                giftIdeas = GiftIdeasProvider.ideas(for: person, limit: 5)
            }
        }
    }

    private var countdownLine: String {
        switch person.daysUntil {
        case 0:
            return "Birthday is today · \(person.shortDate)"
        case 1:
            return "Birthday is tomorrow · \(person.shortDate)"
        default:
            return "In \(person.daysUntil) days · \(person.shortDate)"
        }
    }
}
