import SwiftUI

struct CoachHistoryView: View {
    @Environment(CoachStore.self) private var coach
    @Environment(\.dismiss) private var dismiss
    @State private var delete: CoachConversation?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(coach.snapshot?.conversations ?? []) { conversation in
                        HStack {
                            Button {
                                Task { await coach.openConversation(conversation.id); dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(conversation.title).font(.headline).foregroundStyle(TrainingTheme.primary)
                                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(TrainingTheme.secondary)
                                }.padding(.vertical, 6)
                            }.buttonStyle(.plain)
                            Spacer()
                            Button { delete = conversation } label: { Image(systemName: "trash").frame(minWidth: 44, minHeight: 44) }
                                .tint(.red).accessibilityLabel("Delete conversation")
                        }.listRowBackground(TrainingTheme.surface)
                    }
                } footer: { Text("Your 30 most recent conversations. Opening a chat shows its latest 80 replies.") }
                if coach.snapshot?.conversations.isEmpty != false {
                    ContentUnavailableView("A fresh conversation", systemImage: "bubble.left", description: Text("Your saved Coach chats will appear here."))
                }
                if let message = coach.message { Text(message).font(.subheadline) }
            }.scrollContentBackground(.hidden).trainingScreen()
                .navigationTitle("Conversations").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete this conversation?", isPresented: Binding(get: { delete != nil }, set: { if !$0 { delete = nil } }), titleVisibility: .visible) {
                    if let delete { Button("Delete conversation", role: .destructive) { Task { await coach.deleteConversation(delete.id) }; self.delete = nil } }
                } message: { Text("Messages will be removed from your Coach history. Used credits are not returned.") }
        }
    }
}
struct CoachAccountView: View {
    @Environment(CoachStore.self) private var coach
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var privacy = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Coach account") {
                    Label(coach.account.email, systemImage: "envelope.badge.shield.half.filled")
                    Text("Your workouts stay on-device. Only Coach chats and credits use your account.").font(.subheadline)
                }
                Section("AI privacy") {
                    Text("Cloud stores your conversations. OpenAI receives the messages and recent chat context to generate replies; today's workout is only sent when you turn on sharing.")
                    Button("Privacy & limitations") { privacy = true }
                    if coach.wallet?.consented == true {
                        Button("Withdraw AI consent") { Task { await coach.consent(false) } }
                    }
                }
                Section {
                    Button("Sign out of Coach") {
                        Task { await coach.signOut(); if coach.account.userId == nil { dismiss() } }
                    }.disabled(coach.purchasing)
                    Button("Delete Coach account", role: .destructive) { deleting = true }
                        .disabled(coach.busy || coach.sending || coach.purchasing)
                } footer: {
                    Text("Deleting removes your account and chats and forfeits unused purchased credits. It does not delete local workouts or cancel Hybrid Plus. Minimal transaction and monthly-allowance identifiers are retained to prevent duplicate grants and handle refunds.")
                }
                if let message = coach.message { Section { Text(message) } }
            }.scrollContentBackground(.hidden).trainingScreen()
                .navigationTitle("Coach account").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $privacy) { PlusPrivacyView() }
                .confirmationDialog("Permanently delete your Coach account?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete account & chats", role: .destructive) {
                        Task { await coach.deleteAccount(); if coach.account.userId == nil { dismiss() } }
                    }
                } message: { Text("Unused purchased credits will be lost. Local training and Hybrid Plus are not deleted.") }
        }
    }
}
