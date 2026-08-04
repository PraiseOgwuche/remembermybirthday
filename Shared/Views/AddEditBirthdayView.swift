import SwiftUI
import SwiftData

struct AddEditBirthdayView: View {
    enum Mode {
        case add
        case addFromContact(contactIdentifier: String, name: String, phone: String)
        case edit(BirthdayPerson)

        var title: String {
            switch self {
            case .add: return "New Birthday"
            case .addFromContact(_, let name, _):
                return "Add \(BirthdayNameNormalizer.firstName(from: name))"
            case .edit: return "Edit"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: NotificationScheduler

    let mode: Mode

    @State private var name = ""
    @State private var nickname = ""
    @State private var relationship = ""
    @State private var phoneNumber = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var includeYear = false
    @State private var updateContactBirthday = true
    @State private var saveError: String?

    private var linkedContactId: String? {
        if case .addFromContact(let id, _, _) = mode { return id }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Nickname", text: $nickname)
                TextField("Relationship", text: $relationship)
                TextField("Phone", text: $phoneNumber)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .textContentType(.telephoneNumber)
            } footer: {
                Text("Phone lets Remember open Messages to them with your draft ready. Nickname is what you’ll see in reminders.")
            }

            Section("Birthday") {
                Toggle("Include birth year", isOn: $includeYear)
                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: [.date]
                )
                #if os(iOS)
                .datePickerStyle(.graphical)
                #endif
            }

            if linkedContactId != nil {
                Section {
                    Toggle("Also update Contacts birthday", isOn: $updateContactBirthday)
                } footer: {
                    Text("Keeps their contact card in sync with Remember.")
                }
            }

            Section("Notes") {
                TextField("Gift ideas, tone, reminders to yourself", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            if case .edit(let person) = mode {
                Section("Upcoming") {
                    LabeledContent("Next birthday") {
                        Text(person.nextBirthday, format: .dateTime.month().day().year())
                    }
                    LabeledContent("Countdown") {
                        Text(person.countdownLabel)
                    }
                }

                Section {
                    Button("Delete Birthday", role: .destructive) {
                        Task {
                            await notificationScheduler.cancel(for: person)
                            modelContext.delete(person)
                            dismiss()
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(mode.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        switch mode {
        case .edit(let person):
            name = person.name
            nickname = person.nickname
            relationship = person.relationship
            phoneNumber = person.phoneNumber
            notes = person.notes
            includeYear = person.birthYear != nil

            var components = DateComponents()
            components.month = person.birthMonth
            components.day = person.birthDay
            components.year = person.birthYear ?? Calendar.current.component(.year, from: Date())
            date = Calendar.current.date(from: components) ?? Date()

        case .addFromContact(_, let contactName, let phone):
            name = contactName
            phoneNumber = phone

        case .add:
            break
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year = includeYear ? calendar.component(.year, from: date) : nil
        let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        let person: BirthdayPerson
        switch mode {
        case .add:
            person = BirthdayPerson(
                name: trimmed,
                birthMonth: month,
                birthDay: day,
                birthYear: year,
                relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: phone
            )
            modelContext.insert(person)

        case .addFromContact(let contactId, _, _):
            person = BirthdayPerson(
                name: trimmed,
                birthMonth: month,
                birthDay: day,
                birthYear: year,
                relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: phone,
                contactIdentifier: contactId
            )
            modelContext.insert(person)

            if updateContactBirthday {
                do {
                    try ContactBirthdayMatcher.writeBirthday(
                        contactIdentifier: contactId,
                        month: month,
                        day: day,
                        year: year
                    )
                } catch {
                    saveError = "Saved in Remember, but couldn’t update Contacts: \(error.localizedDescription)"
                }
            }

        case .edit(let existing):
            existing.name = trimmed
            existing.birthMonth = month
            existing.birthDay = day
            existing.birthYear = year
            existing.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.phoneNumber = phone
            existing.updatedAt = Date()
            person = existing
        }

        try? modelContext.save()

        Task {
            await notificationScheduler.reschedule(for: person)
            if saveError == nil {
                dismiss()
            }
        }
    }
}
