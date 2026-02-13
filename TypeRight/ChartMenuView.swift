//
//  ChartMenuView.swift
//  TypeRight
//
//  Created by Claude on 03.02.26.
//

import SwiftUI
import Charts

/// Time range options for the chart
enum ChartTimeRange: String, CaseIterable {
    case day = "24h"
    case week = "7d"
    case month = "30d"
    
    var hours: Int {
        switch self {
        case .day: return 24
        case .week: return 24 * 7
        case .month: return 24 * 30
        }
    }
    
    var labelFormat: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.hour()
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.day().month(.abbreviated)
        }
    }
}

/// Data point for the chart
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let ratio: Double
    let isInterpolated: Bool
}

/// SwiftUI chart view for displaying backspace ratio over time
struct ChartMenuView: View {
    @State private var selectedRange: ChartTimeRange = .day
    @State private var chartData: [ChartDataPoint] = []
    
    private let historyManager = HistoryDataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(ChartTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            // Chart
            if chartData.isEmpty {
                VStack {
                    Spacer()
                    Text("No data yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(height: 140)
            } else {
                let maxY = max(15, (chartData.map { $0.ratio }.max() ?? 10) + 2)
                
                // Create gradient for the line
                // Note: Gradient stops are 0...1 where 0 is bottom? No, typically standard LinearGradient is top-to-bottom or defined start/end.
                // We want:
                // Red (> 10)
                // Orange (5..10)
                // Green (< 5)
                // Let's use a vertical gradient.
                // Ratio of 5 in domain 0...maxY is 5/maxY.
                // Ratio of 10 in domain 0...maxY is 10/maxY.
                 
                let stop5 = 5.0 / maxY
                let stop10 = 10.0 / maxY
                
                let gradientColors: [Color] = [.green, .orange, .red]
                // To make hard stops or smooth transitions?
                // "if at some time point... interpolate". The user wants smooth lines.
                // A smooth gradient is probably better looking than hard stripes for a line chart.
                // But precisely matching the "<5 green, 5-10 orange" logic implies thresholds.
                // Let's try a smooth gradient that roughly aligns.
                // Or better: use `.alignsMarkStylesWithPlotDomain` if available, or just a generic gradient.
                // Given the previous code was discrete colors, a gradient is an approximation.
                // Let's use a Gradient that maps color stops.
                
                let gradient = LinearGradient(
                    stops: [
                        .init(color: .green, location: 0),
                        .init(color: .green, location: stop5),
                        .init(color: .orange, location: stop5),
                        .init(color: .orange, location: stop10),
                        .init(color: .red, location: stop10),
                        .init(color: .red, location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                Chart {
                    // Threshold lines
                    RuleMark(y: .value("Warning", 5))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    RuleMark(y: .value("Danger", 10))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    // Data line
                    // We must use a single LineMark for the interpolation to work across the whole series?
                    // Or ForEach with a constant Style.
                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Ratio", point.ratio)
                        )
                    }
                    .foregroundStyle(gradient)
                    .interpolationMethod(.catmullRom)
                    
                    // Area fill under the line
                    ForEach(chartData) { point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Ratio", point.ratio)
                        )
                    }
                    .foregroundStyle(gradient.opacity(0.3))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...maxY)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: selectedRange.labelFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 5, 10, 15]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 140)
                .padding(.horizontal, 4)
            }
            
            // Summary stats
            HStack {
                // Calculation: Filter out interpolated points for average calculation to avoid skewing?
                // Or include them? Interpolated points represent estimated reality, so maybe include.
                // But let's stick to real data for the average to be accurate to "recorded" history.
                let realPoints = chartData.filter { !$0.isInterpolated }
                let avgRatio = realPoints.isEmpty ? 0 : realPoints.map { $0.ratio }.reduce(0, +) / Double(realPoints.count)
                
                Text("Avg: \(String(format: "%.1f%%", avgRatio))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(realPoints.count) records")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .frame(width: 280)
        .onAppear {
            loadData()
        }
        .onChange(of: selectedRange) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        // Fetch a bit more data to ensure we have context for the start of the chart
        // Adding 4 hours of buffer (2 hours look-behind + safety)
        let stats = historyManager.getStats(lastHours: selectedRange.hours + 4)
        chartData = processData(stats, hours: selectedRange.hours)
    }
    
    private func processData(_ stats: [HourlyStats], hours: Int) -> [ChartDataPoint] {
        // 1. Align data to continuous timeline
        // 2. Apply Weighted Moving Average Smoothing (5-point window)
        // 3. Interpolate remaining gaps
        
        // ... (timeline generation same as before)
        let now = Date()
        let calendar = Calendar.current
        
        let endHour = historyManager.startOfHour(for: now)
        let startHour = historyManager.startOfHour(for: now.addingTimeInterval(-Double(hours) * 3600))
        
        let statsDict = Dictionary(uniqueKeysWithValues: stats.map { ($0.hour, $0) })
        
        var hourSequence: [Date] = []
        var currentHook = startHour
        while currentHook <= endHour {
            hourSequence.append(currentHook)
            currentHook = calendar.date(byAdding: .hour, value: 1, to: currentHook)!
        }
        
        func getStats(for date: Date) -> (keys: Int, backspaces: Int) {
            if let stat = statsDict[date] {
                return (stat.keystrokes, stat.backspaces)
            }
            return (0, 0)
        }
        
        var smoothedPoints: [(date: Date, ratio: Double?)] = []
        
        for i in 0..<hourSequence.count {
            let currentHour = hourSequence[i]
            
            // Define 5-point window: [current-2h ... current+2h]
            var totalKeys = 0
            var totalBackspaces = 0
            
            for offset in -2...2 {
                if let targetHour = calendar.date(byAdding: .hour, value: offset, to: currentHour) {
                    let s = getStats(for: targetHour)
                    totalKeys += s.keys
                    totalBackspaces += s.backspaces
                }
            }
            
            if totalKeys > 0 {
                let ratio = (Double(totalBackspaces) / Double(totalKeys)) * 100
                smoothedPoints.append((currentHour, ratio))
            } else {
                smoothedPoints.append((currentHour, nil))
            }
        }
        
        // ... (Interpolation logic same as before)
        
        var finalPoints: [ChartDataPoint] = []
        
        let validIndices = smoothedPoints.indices.filter { smoothedPoints[$0].ratio != nil }
        
        guard let firstValidIdx = validIndices.first, let lastValidIdx = validIndices.last else {
            return []
        }
        
        for i in firstValidIdx...lastValidIdx {
            let item = smoothedPoints[i]
            
            if let ratio = item.ratio {
                finalPoints.append(ChartDataPoint(date: item.date, ratio: ratio, isInterpolated: false))
            } else {
                let prevIdx = validIndices.filter { $0 < i }.max()!
                let nextIdx = validIndices.filter { $0 > i }.min()!
                
                let prevItem = smoothedPoints[prevIdx]
                let nextItem = smoothedPoints[nextIdx]
                
                let prevRatio = prevItem.ratio!
                let nextRatio = nextItem.ratio!
                
                let totalDiff = nextItem.date.timeIntervalSince(prevItem.date)
                let currentDiff = item.date.timeIntervalSince(prevItem.date)
                let factor = currentDiff / totalDiff
                
                let interpolatedRatio = prevRatio + (nextRatio - prevRatio) * factor
                
                finalPoints.append(ChartDataPoint(date: item.date, ratio: interpolatedRatio, isInterpolated: true))
            }
        }
        
        return finalPoints
    }
    
    private func colorForRatio(_ ratio: Double) -> Color {
        switch ratio {
        case ..<5:
            return .green
        case 5..<10:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    ChartMenuView()
        .frame(width: 300, height: 220)
}
