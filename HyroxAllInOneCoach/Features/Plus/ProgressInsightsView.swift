import SwiftUI
import Charts

struct ProgressInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let repository: TrainingRepository
    @State private var weekCount = 4
    private var data: TrainingInsights { TrainingInsights(sessions: repository.sessions, weekCount: weekCount) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    Picker("Time period", selection: $weekCount) {
                        Text("4 weeks").tag(4); Text("8 weeks").tag(8); Text("12 weeks").tag(12)
                    }.pickerStyle(.segmented)
                    overview
                    if data.records.isEmpty { emptyState }
                    weeklyVolume
                    if !data.records.isEmpty { mix; effort }
                    Text("Based on saved sessions with at least one completed step. Early finishes and recovery count. Durations are logged session time, not sensor-measured activity. Editing or deleting records updates these insights.")
                        .font(.footnote).foregroundStyle(TrainingTheme.secondary)
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .navigationTitle("Progress insights").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .trainingScreen()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: weekCount)
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlusBadge()
            Text("Your effort.\nThe bigger picture.").font(.largeTitle.bold())
            Text("Look for a rhythm that works for you—not a score to chase.").font(.body).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(Int(data.totalMinutes.rounded())) minutes logged").font(.title2.bold())
            HStack(spacing: 24) {
                stat("Sessions", value: data.records.count)
                stat("Training days", value: data.trainingDays)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).trainingPanel()
    }
    private func stat(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value)").font(.title2.weight(.semibold)).foregroundStyle(TrainingTheme.mint)
            Text(title).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }.accessibilityElement(children: .combine)
    }
    private var weeklyVolume: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Weekly training volume", subtitle: "Logged minutes · weeks start with your calendar")
            Chart(data.weeks) { week in
                BarMark(x: .value("Week starting", week.date, unit: .weekOfYear), y: .value("Logged minutes", week.minutes))
                    .foregroundStyle(TrainingTheme.mint.gradient).cornerRadius(5)
                    .accessibilityLabel(week.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(Int(week.minutes.rounded())) minutes, \(week.sessions) sessions")
            }
            .chartYScale(domain: 0...max(10, (data.weeks.map(\.minutes).max() ?? 0) * 1.15))
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine().foregroundStyle(TrainingTheme.border); AxisValueLabel() } }
            .frame(height: 190)
            Text("More isn’t always better. Lighter weeks and rest are part of sustainable training.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            DisclosureGroup("Read weekly totals") {
                VStack(spacing: 10) {
                    ForEach(data.weeks) { week in
                        HStack {
                            Text(week.date, format: .dateTime.month(.abbreviated).day())
                            Spacer()
                            Text("\(week.sessions) sessions · \(Int(week.minutes.rounded())) min")
                        }.font(.subheadline).accessibilityElement(children: .combine)
                    }
                }.padding(.top, 10)
            }.font(.subheadline)
        }.trainingPanel()
    }
    private var mix: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Your workout balance", subtitle: "Share of saved sessions in this period")
            ForEach(data.mix) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Label(item.family.category, systemImage: item.family.symbol); Spacer(); Text("\(item.count)") }
                        .font(.subheadline)
                    ProgressView(value: Double(item.count), total: Double(max(1, data.records.count))).tint(TrainingTheme.mint)
                }.accessibilityElement(children: .combine)
            }
        }.trainingPanel()
    }
    private var effort: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "How training felt", subtitle: "Your self-reported effort, not a fitness assessment")
            if data.effortRecords.isEmpty {
                Text("Add an effort rating when you save or edit a session to see it here.").font(.body).foregroundStyle(TrainingTheme.secondary)
            } else {
                Chart(data.effortRecords) { record in
                    PointMark(x: .value("Session date", record.startedAt), y: .value("Effort", TrainingInsights.effortValue(record.effort)))
                        .foregroundStyle(TrainingTheme.mint).symbolSize(55)
                        .accessibilityLabel("\(record.workout.title), \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
                        .accessibilityValue(record.effort?.title ?? "Not rated")
                }
                .chartYScale(domain: 0.8...4.2)
                .chartYAxis { AxisMarks(position: .leading, values: [1, 2, 3, 4]) { mark in
                    AxisGridLine().foregroundStyle(TrainingTheme.border)
                    AxisValueLabel { Text(effortLabel(mark.as(Int.self) ?? 0)).font(.caption2) }
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 180)
                Text("Harder isn’t better. Use these ratings to notice your own balance of easy and challenging days.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }.trainingPanel()
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your story starts with one session", systemImage: "chart.bar.xaxis").font(.headline)
            Text("No demo history, no invented progress. Save a workout and your real training will appear here.").font(.body).foregroundStyle(TrainingTheme.secondary)
        }.trainingPanel()
    }
    private func effortLabel(_ value: Int) -> String {
        switch value { case 1: "Easy"; case 2: "Comfortable"; case 3: "Challenging"; case 4: "Very hard"; default: "" }
    }
}
