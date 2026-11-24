import SwiftUI

struct CoachSignInView: View {
    @Environment(CoachStore.self) private var coach
    @State private var email = ""
    @State private var code = ""
    @FocusState private var focus: Field?
    private enum Field { case email, code }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(coach.account.sentTo == nil ? "Your Coach, across devices." : "Check your email").font(.title3.bold())
            if let sent = coach.account.sentTo { codeEntry(sent) } else { emailEntry }
            if let message = coach.account.message { Text(message).font(.subheadline).foregroundStyle(TrainingTheme.secondary) }
            Text("Only Coach needs an account. Your workouts stay on this iPhone and remain available without signing in.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }.trainingPanel()
    }
    private var emailEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sign in to keep your replies and credit balance together. No password needed.").foregroundStyle(TrainingTheme.secondary)
            TextField("Email address", text: $email)
                .textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(14).background(TrainingTheme.inset, in: RoundedRectangle(cornerRadius: 14))
                .focused($focus, equals: .email).accessibilityLabel("Coach account email")
            Button {
                focus = nil
                Task { await coach.account.sendCode(email: email) }
            } label: { Label(coach.account.busy ? "Sending…" : "Email me a sign-in code", systemImage: "envelope") }
                .buttonStyle(TrainingButtonStyle()).disabled(coach.account.busy || email.isEmpty)
        }
    }
    private func codeEntry(_ sent: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enter the code sent to \(sent). If your email contains a sign-in link instead, open it on this iPhone.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            TextField("Email code", text: $code)
                .textContentType(.oneTimeCode).keyboardType(.numberPad)
                .padding(14).background(TrainingTheme.inset, in: RoundedRectangle(cornerRadius: 14))
                .focused($focus, equals: .code).accessibilityLabel("One-time email code")
            Button {
                focus = nil
                Task { await coach.account.verify(code: code) }
            } label: { Text(coach.account.busy ? "Verifying…" : "Verify & meet Coach") }
                .buttonStyle(TrainingButtonStyle()).disabled(coach.account.busy || code.isEmpty)
            Button("Use a different email") { code = ""; coach.account.changeEmail() }.frame(minHeight: 44).disabled(coach.account.busy)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let seconds = max(0, Int(ceil(coach.account.resendAfter.timeIntervalSince(timeline.date))))
                Button(seconds > 0 ? "Resend in \(seconds)s" : "Send another email") {
                    Task { await coach.account.sendCode(email: sent) }
                }.frame(minHeight: 44).disabled(seconds > 0 || coach.account.busy)
            }
        }
    }
}
