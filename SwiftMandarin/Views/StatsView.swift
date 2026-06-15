//
//  StatsView.swift
//  SwiftMandarin
//
//  Created by Claude on 2025.
//

import SwiftUI
import Charts

/// Main analytics dashboard view showing learning progress and activity
/// Features GitHub-style contribution chart and stacked bar charts
/// Adapts layout for iPhone, iPad, and macOS platforms
struct StatsView: View {
    @Environment(LearningActivityStore.self) private var activityStore
    @Environment(LearningProgressStore.self) private var progressStore
    @Environment(SavedTermsStore.self) private var termsStore
    
    @State private var barChartTimeRange: BarChartTimeRange = .week
    @State private var selectedContributionDate: DailyActivity?
    @State private var selectedMasterySegment: VocabularyMasterySegment?
    @State private var selectedPOSSegment: String?
    @Namespace private var namespace
    
    enum BarChartTimeRange: String, CaseIterable {
        case week = "7 Days"
        case twoWeeks = "14 Days"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            }
        }
    }

    enum VocabularyMasterySegment: String, CaseIterable {
        case learning = "Learning"
        case mastered = "Mastered"
    }
    
    /// Platform detection for adaptive layouts
    private var isCompactWidth: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    /// Number of days to show in contribution heatmap based on platform
    private var contributionDays: Int {
        if isCompactWidth {
            return 180 // 6 months for iPhone
        } else {
            return 365 // Full year for iPad/macOS
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: isCompactWidth ? 16 : 24) {
                // Hero stats with streak
                heroSection
                
                // Full-width contribution heatmap (adaptive based on platform)
                contributionSection
                
                // Stacked bar chart (daily/weekly by parts of speech)
                stackedBarChartSection
                
                // Two pie charts - layout adapts to platform
                pieChartsRow
                
                // Quick stats grid
                quickStatsSection
            }
            .padding(.vertical, isCompactWidth ? 12 : 16)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .navigationTitle("Statistics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        Group {
            if isCompactWidth {
                // iPhone: Vertical stack with compact cards
                VStack(spacing: 12) {
                    // Current streak - prominent display
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.orange.gradient)
                            Text("\(activityStore.currentStreak)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("day streak")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if activityStore.currentStreak > 0 {
                                Text("Keep it up!")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .glassEffectCompat(cornerRadius: 16)
                    
                    // Secondary stats in horizontal row
                    HStack(spacing: 12) {
                        CompactStatCard(
                            icon: "trophy.fill",
                            value: "\(activityStore.longestStreak)",
                            label: "Best",
                            color: .yellow
                        )
                        
                        CompactStatCard(
                            icon: "book.closed.fill",
                            value: "\(termsStore.savedTerms.count)",
                            label: "Words",
                            color: .blue
                        )
                        
                        CompactStatCard(
                            icon: "checkmark.circle.fill",
                            value: "\(termsStore.masteredCount)",
                            label: "Mastered",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)
            } else {
                // iPad/macOS: Original horizontal layout
                HStack(spacing: 16) {
                    // Current streak - prominent display
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.orange.gradient)
                            Text("\(activityStore.currentStreak)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        Text("day streak")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassEffectCompat(cornerRadius: 20)
                    
                    // Secondary stats
                    VStack(spacing: 12) {
                        HeroStatItem(
                            icon: "trophy.fill",
                            value: "\(activityStore.longestStreak)",
                            label: "Best Streak",
                            color: .yellow
                        )
                        
                        HeroStatItem(
                            icon: "book.closed.fill",
                            value: "\(termsStore.savedTerms.count)",
                            label: "Words Saved",
                            color: .blue
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassEffectCompat(cornerRadius: 20)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Contribution Heatmap Section (Adaptive)
    
    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 8 : 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity Heatmap")
                        .font(isCompactWidth ? .headline : .title3.weight(.semibold))
                    Text(isCompactWidth ? "Past 6 Months" : "Past Year")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            let maxScore = contributionMaxScore

            // Adaptive contribution grid - shows fewer days on iPhone
            ContributionHeatmap(
                activities: activityStore.activitiesForLastDays(contributionDays),
                selectedDate: $selectedContributionDate,
                isCompact: isCompactWidth,
                colorForScore: { score in
                    contributionColor(forScore: score, maxScore: maxScore)
                }
            )
            .padding(.horizontal, isCompactWidth ? 0 : 4)

            // Legend
            HStack(spacing: 16) {
                Spacer()
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 3) {
                    let steps: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
                    ForEach(0..<steps.count, id: \.self) { index in
                        let score = Int(Double(maxScore) * steps[index])
                        RoundedRectangle(cornerRadius: 3)
                            .fill(contributionColor(forScore: score, maxScore: maxScore))
                            .frame(width: 14, height: 14)
                    }
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            
            // Selected date detail
            if let selected = selectedContributionDate {
                selectedDateDetail(selected)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func selectedDateDetail(_ activity: DailyActivity) -> some View {
        HStack(spacing: 14) {
            Group {
                Label("\(activity.wordsLearned)", systemImage: "character.book.closed")
                Label("\(activity.reviewsCompleted)", systemImage: "checkmark.circle")
                Label("\(activity.translationsMade)", systemImage: "globe")
                Label("\(activity.questionsGraded)", systemImage: "checkmark.rectangle.stack")
            }
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            // Keep the date intact; let the metric counts shrink instead.
            Text(activity.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var contributionMaxScore: Int {
        let activities = activityStore.activitiesForLastDays(contributionDays)
        let maxActivityScore = activities.map(\.activityScore).max() ?? 0
        let baseline = max(5, Int(ceil(Double(activityStore.totalWordsLearned) / 30.0)))
        return max(maxActivityScore, baseline)
    }

    private func contributionColor(forScore score: Int, maxScore: Int) -> Color {
        guard score > 0 else { return Color.gray.opacity(0.25) }
        let maxValue = max(1, maxScore)
        let normalized = min(1.0, log1p(Double(score)) / log1p(Double(maxValue)))
        let saturation = 0.25 + (0.55 * normalized)
        let brightness = 0.95 - (0.35 * normalized)
        return Color(hue: 0.33, saturation: saturation, brightness: brightness)
    }
    
    // MARK: - Stacked Bar Chart Section (Daily/Weekly by Parts of Speech)
    
    private var stackedBarChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Words Learned")
                        .font(.title3.weight(.semibold))
                    Text("By Part of Speech")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Time range toggle
                HStack(spacing: 0) {
                    ForEach(BarChartTimeRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.smooth) {
                                barChartTimeRange = range
                            }
                        } label: {
                            Text(range.rawValue)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(barChartTimeRange == range ? .primary : .secondary)
                        .background {
                            if barChartTimeRange == range {
                                Capsule()
                                    .fill(.tint.opacity(0.15))
                                    .matchedGeometryEffect(id: "barChartRange", in: namespace)
                            }
                        }
                    }
                }
                .glassEffectCapsuleCompat()
            }
            .padding(.horizontal)
            
            let chartData = prepareStackedBarData()
            
            if chartData.isEmpty || chartData.allSatisfy({ $0.count == 0 }) {
                emptyChartPlaceholder(
                    icon: "chart.bar.fill",
                    message: "Save words to see breakdown by type"
                )
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Words", item.count)
                    )
                    .foregroundStyle(by: .value("Type", item.partOfSpeech))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(posColorScale)
                .chartLegend(position: .bottom, alignment: .center, spacing: 12)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.tertiary)
                        AxisValueLabel()
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(.clear)
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    private var posColorScale: KeyValuePairs<String, Color> {
        [
            PartOfSpeechCategory.noun.rawValue: .blue,
            PartOfSpeechCategory.verb.rawValue: .green,
            PartOfSpeechCategory.adjective.rawValue: .orange,
            PartOfSpeechCategory.adverb.rawValue: .purple,
            PartOfSpeechCategory.pronoun.rawValue: .pink,
            PartOfSpeechCategory.preposition.rawValue: .teal,
            PartOfSpeechCategory.conjunction.rawValue: .indigo,
            PartOfSpeechCategory.interjection.rawValue: .red,
            PartOfSpeechCategory.classifier.rawValue: .cyan,
            PartOfSpeechCategory.particle.rawValue: .mint,
            PartOfSpeechCategory.other.rawValue: .gray
        ]
    }
    
    private func colorForPartOfSpeech(_ pos: String) -> Color {
        switch pos {
        case PartOfSpeechCategory.noun.rawValue: return .blue
        case PartOfSpeechCategory.verb.rawValue: return .green
        case PartOfSpeechCategory.adjective.rawValue: return .orange
        case PartOfSpeechCategory.adverb.rawValue: return .purple
        case PartOfSpeechCategory.pronoun.rawValue: return .pink
        case PartOfSpeechCategory.preposition.rawValue: return .teal
        case PartOfSpeechCategory.conjunction.rawValue: return .indigo
        case PartOfSpeechCategory.interjection.rawValue: return .red
        case PartOfSpeechCategory.classifier.rawValue: return .cyan
        case PartOfSpeechCategory.particle.rawValue: return .mint
        default: return .gray
        }
    }
    
    private func prepareStackedBarData() -> [StackedBarDataPoint] {
        let activities = activityStore.activitiesForLastDays(barChartTimeRange.days)
        var result: [StackedBarDataPoint] = []
        
        for activity in activities {
            // Add data points for each part of speech
            for category in PartOfSpeechCategory.allCases {
                let count = activity.wordsByPartOfSpeech[category.rawValue] ?? 0
                if count > 0 {
                    result.append(StackedBarDataPoint(
                        date: activity.date,
                        partOfSpeech: category.rawValue,
                        count: count
                    ))
                }
            }
            
            // If no words that day, add a zero point for "Other" so the day shows
            if activity.wordsLearned == 0 {
                result.append(StackedBarDataPoint(
                    date: activity.date,
                    partOfSpeech: PartOfSpeechCategory.other.rawValue,
                    count: 0
                ))
            }
        }
        
        return result
    }
    
    // MARK: - Pie Charts Row
    
    private var pieChartsRow: some View {
        #if os(iOS)
        let isWideLayout = UIDevice.current.userInterfaceIdiom == .pad
        let layout = isWideLayout ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        #else
        // macOS is always wide enough for the side-by-side layout.
        let layout = AnyLayout(HStackLayout(spacing: 16))
        #endif

        return layout {
            masteryPieChart
            partsOfSpeechPieChart
        }
        .padding(.horizontal)
    }
    
    private var masteryPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vocabulary Mastery")
                .font(.headline)

            let masteryData = calculateVocabularyMasteryDistribution()
            let total = masteryData.reduce(0) { $0 + $1.count }

            if masteryData.isEmpty {
                emptyChartPlaceholder(
                    icon: "brain.head.profile",
                    message: "Save words to track mastery"
                )
                .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        Chart(masteryData, id: \.segment) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.55),
                                outerRadius: selectedMasterySegment == item.segment ? .ratio(1.0) : .ratio(0.92),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Level", item.segment.rawValue))
                            .cornerRadius(4)
                            .opacity(selectedMasterySegment == nil || selectedMasterySegment == item.segment ? 1.0 : 0.4)
                        }
                        .chartLegend(.hidden)
                        .chartForegroundStyleScale([
                            VocabularyMasterySegment.learning.rawValue: Color.orange,
                            VocabularyMasterySegment.mastered.rawValue: Color.green
                        ])
                        .chartAngleSelection(value: $selectedMasteryAngle)
                        .frame(height: 140)

                        // Center label showing selected segment info
                        VStack(spacing: 2) {
                            if let selected = selectedMasterySegment,
                               let item = masteryData.first(where: { $0.segment == selected }) {
                                Text("\(item.count)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(colorForVocabularyMastery(selected))
                                Text(selected.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(colorForVocabularyMastery(selected))
                            } else {
                                Text("\(total)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Custom legend with better wrapping
                    FlowLayout(spacing: 8) {
                        ForEach(masteryData, id: \.segment) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForVocabularyMastery(item.segment))
                                    .frame(width: 8, height: 8)
                                Text(item.segment.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onChange(of: selectedMasteryAngle) { _, newValue in
                    updateMasterySelection(from: newValue, data: masteryData)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func colorForVocabularyMastery(_ segment: VocabularyMasterySegment) -> Color {
        switch segment {
        case .learning: return Color.orange
        case .mastered: return Color.green
        }
    }
    
    @State private var selectedMasteryAngle: Int?
    @State private var selectedPOSAngle: Int?
    
    private func updateMasterySelection(from angle: Int?, data: [(segment: VocabularyMasterySegment, count: Int)]) {
        guard let angle = angle else {
            selectedMasterySegment = nil
            return
        }

        var cumulative = 0
        for item in data {
            cumulative += item.count
            if angle <= cumulative {
                selectedMasterySegment = item.segment
                return
            }
        }
        selectedMasterySegment = nil
    }
    
    private func updatePOSSelection(from angle: Int?, data: [(partOfSpeech: String, count: Int)]) {
        guard let angle = angle else {
            selectedPOSSegment = nil
            return
        }
        
        var cumulative = 0
        for item in data {
            cumulative += item.count
            if angle <= cumulative {
                selectedPOSSegment = item.partOfSpeech
                return
            }
        }
        selectedPOSSegment = nil
    }
    
    private var partsOfSpeechPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vocabulary by Type")
                .font(.headline)
            
            let posData = calculatePartsOfSpeechDistribution()
            let total = posData.reduce(0) { $0 + $1.count }
            
            if posData.isEmpty {
                emptyChartPlaceholder(
                    icon: "text.book.closed",
                    message: "Save words to see breakdown"
                )
                .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        Chart(posData, id: \.partOfSpeech) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.55),
                                outerRadius: selectedPOSSegment == item.partOfSpeech ? .ratio(1.0) : .ratio(0.92),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Type", item.partOfSpeech))
                            .cornerRadius(4)
                            .opacity(selectedPOSSegment == nil || selectedPOSSegment == item.partOfSpeech ? 1.0 : 0.4)
                        }
                        .chartLegend(.hidden)
                        .chartForegroundStyleScale(posColorScale)
                        .chartAngleSelection(value: $selectedPOSAngle)
                        .frame(height: 140)
                        
                        // Center label showing selected segment info
                        VStack(spacing: 2) {
                            if let selected = selectedPOSSegment,
                               let item = posData.first(where: { $0.partOfSpeech == selected }) {
                                Text("\(item.count)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(colorForPartOfSpeech(selected))
                                Text(selected)
                                    .font(.caption)
                                    .foregroundStyle(colorForPartOfSpeech(selected))
                            } else {
                                Text("\(total)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Custom legend with better wrapping
                    FlowLayout(spacing: 8) {
                        ForEach(posData, id: \.partOfSpeech) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForPartOfSpeech(item.partOfSpeech))
                                    .frame(width: 8, height: 8)
                                Text(item.partOfSpeech)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onChange(of: selectedPOSAngle) { _, newValue in
                    updatePOSSelection(from: newValue, data: posData)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func emptyChartPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func calculateVocabularyMasteryDistribution() -> [(segment: VocabularyMasterySegment, count: Int)] {
        let total = termsStore.savedTerms.count
        guard total > 0 else { return [] }

        let mastered = termsStore.masteredCount
        let learning = max(0, total - mastered)

        return [
            (segment: .learning, count: learning),
            (segment: .mastered, count: mastered)
        ]
    }
    
    private func calculatePartsOfSpeechDistribution() -> [(partOfSpeech: String, count: Int)] {
        var distribution: [String: Int] = [:]
        
        for term in termsStore.savedTerms {
            let category = PartOfSpeechCategory.categorize(term.partOfSpeech)
            distribution[category.rawValue, default: 0] += 1
        }
        
        return distribution
            .map { (partOfSpeech: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickStatCell(
                    value: "\(termsStore.savedTerms.count)",
                    label: "Total Words",
                    icon: "character.book.closed"
                )
                QuickStatCell(
                    value: "\(progressStore.progress.count)",
                    label: "Cards Studied",
                    icon: "rectangle.stack"
                )
                QuickStatCell(
                    value: "\(activityStore.totalReviewsCompleted)",
                    label: "Reviews",
                    icon: "checkmark.circle"
                )
                QuickStatCell(
                    value: "\(activityStore.totalTranslationsMade)",
                    label: "Translations",
                    icon: "globe"
                )
                QuickStatCell(
                    value: "\(activityStore.totalQuestionsGraded)",
                    label: "Questions Graded",
                    icon: "checkmark.rectangle.stack"
                )
                QuickStatCell(
                    value: String(format: "%.1f", averageDailyReviews),
                    label: "Avg/Day",
                    icon: "chart.bar"
                )
                QuickStatCell(
                    value: "\(termsStore.masteredCount)",
                    label: "Words Mastered",
                    icon: "checkmark.circle.fill"
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    private var averageDailyReviews: Double {
        let activities = activityStore.activitiesForLastDays(30)
        let total = activities.reduce(0) { $0 + $1.reviewsCompleted }
        let daysWithActivity = activities.filter { $0.reviewsCompleted > 0 }.count
        return daysWithActivity > 0 ? Double(total) / Double(daysWithActivity) : 0
    }
    
    private var masteredCardCount: Int {
        progressStore.progress.values.filter { $0.masteryLevel == .mastered }.count
    }
}

// MARK: - Data Models

struct StackedBarDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let partOfSpeech: String
    let count: Int
}

// MARK: - Supporting Views

struct HeroStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Compact stat card for iPhone layouts
struct CompactStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffectCompat(cornerRadius: 12)
    }
}

// MARK: - Full-width Adaptive Contribution Heatmap

struct ContributionHeatmap: View {
    let activities: [DailyActivity]
    @Binding var selectedDate: DailyActivity?
    var isCompact: Bool = false
    let colorForScore: (Int) -> Color
    
    private var spacing: CGFloat { isCompact ? 2 : 3 }
    private let rows: Int = 7 // Days of week
    private var labelWidth: CGFloat { isCompact ? 16 : 20 }
    private var monthLabelHeight: CGFloat { isCompact ? 14 : 16 }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (isCompact ? 24 : 32) - labelWidth
            let weeks = Int(ceil(Double(activities.count) / 7.0))
            
            // Calculate cell size to fit all weeks in available width
            let totalSpacing = CGFloat(weeks - 1) * spacing
            let minCellSize: CGFloat = isCompact ? 6 : 8
            let maxCellSize: CGFloat = isCompact ? 10 : 14
            let cellSize = max(minCellSize, min(maxCellSize, (availableWidth - totalSpacing) / CGFloat(weeks)))
            let totalHeight = CGFloat(rows) * cellSize + CGFloat(rows - 1) * spacing
            
            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                HStack(alignment: .top, spacing: isCompact ? 2 : 4) {
                    // Day labels - show fewer on compact
                    VStack(alignment: .trailing, spacing: spacing) {
                        ForEach(Array((isCompact ? ["", "M", "", "W", "", "F", ""] : ["", "M", "", "W", "", "F", ""]).enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: isCompact ? 7 : 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: labelWidth, height: cellSize)
                        }
                    }
                    
                    // Weeks grid - fills available width
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: spacing) {
                                ForEach(0..<rows, id: \.self) { dayOfWeek in
                                    let index = week * 7 + dayOfWeek
                                    if index < activities.count {
                                        ContributionCell(
                                            activity: activities[index],
                                            size: cellSize,
                                            isSelected: selectedDate?.dateKey == activities[index].dateKey,
                                            colorForScore: colorForScore,
                                            onTap: {
                                                withAnimation(.smooth(duration: 0.2)) {
                                                    if selectedDate?.dateKey == activities[index].dateKey {
                                                        selectedDate = nil
                                                    } else {
                                                        selectedDate = activities[index]
                                                    }
                                                }
                                            }
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: isCompact ? 1 : 2)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Month labels row
                HStack(spacing: 0) {
                    // Spacer for day label column
                    Spacer()
                        .frame(width: labelWidth + (isCompact ? 2 : 4))
                    
                    // Month labels positioned under their respective weeks
                    monthLabelsView(weeks: weeks, cellSize: cellSize)
                }
            }
            .padding(.horizontal, isCompact ? 8 : 16)
            .frame(height: totalHeight + monthLabelHeight + 4)
        }
        .frame(height: calculateHeight())
    }
    
    @ViewBuilder
    private func monthLabelsView(weeks: Int, cellSize: CGFloat) -> some View {
        let monthPositions = calculateMonthPositions(weeks: weeks, cellSize: cellSize)
        
        ZStack(alignment: .leading) {
            ForEach(monthPositions, id: \.month) { monthInfo in
                Text(monthInfo.label)
                    .font(.system(size: isCompact ? 7 : 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .offset(x: monthInfo.xOffset)
            }
        }
        .frame(height: monthLabelHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private struct MonthPosition: Hashable {
        let month: Int
        let year: Int
        let label: String
        let xOffset: CGFloat
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(month)
            hasher.combine(year)
        }
        
        static func == (lhs: MonthPosition, rhs: MonthPosition) -> Bool {
            lhs.month == rhs.month && lhs.year == rhs.year
        }
    }
    
    private func calculateMonthPositions(weeks: Int, cellSize: CGFloat) -> [MonthPosition] {
        guard !activities.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        
        var positions: [MonthPosition] = []
        var lastMonth: Int = -1
        var lastYear: Int = -1
        
        for week in 0..<weeks {
            // Check the first day of each week
            let index = week * 7
            guard index < activities.count else { continue }
            
            let date = activities[index].date
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            
            // If this is a new month, record its position
            if month != lastMonth || year != lastYear {
                let xOffset = CGFloat(week) * (cellSize + spacing)
                positions.append(MonthPosition(
                    month: month,
                    year: year,
                    label: monthFormatter.string(from: date),
                    xOffset: xOffset
                ))
                lastMonth = month
                lastYear = year
            }
        }
        
        return positions
    }
    
    private func calculateHeight() -> CGFloat {
        // Estimate height based on typical cell size (smaller for compact mode)
        let estimatedCellSize: CGFloat = isCompact ? 8 : 11
        let estimatedSpacing: CGFloat = isCompact ? 2 : 3
        return CGFloat(rows) * estimatedCellSize + CGFloat(rows - 1) * estimatedSpacing + monthLabelHeight + (isCompact ? 8 : 12)
    }
}

struct ContributionCell: View {
    let activity: DailyActivity
    let size: CGFloat
    let isSelected: Bool
    let colorForScore: (Int) -> Color
    let onTap: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: max(2, size * 0.15))
            .fill(colorForActivity)
            .frame(width: size, height: size)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: max(2, size * 0.15))
                        .strokeBorder(.tint, lineWidth: 2)
                }
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .onTapGesture(perform: onTap)
    }
    
    private var colorForActivity: Color {
        colorForScore(activity.activityScore)
    }
}

// MARK: - MasteryLevel Extensions

extension MasteryLevel {
    var sortOrder: Int {
        switch self {
        case .new: return 0
        case .learning: return 1
        case .familiar: return 2
        case .proficient: return 3
        case .mastered: return 4
        }
    }
    
    var displayName: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .familiar: return "Familiar"
        case .proficient: return "Proficient"
        case .mastered: return "Mastered"
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(LearningActivityStore.shared)
    .environment(LearningProgressStore.shared)
    .environment(SavedTermsStore.shared)
}
