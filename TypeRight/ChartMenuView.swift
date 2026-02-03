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

/// SwiftUI chart view for displaying backspace ratio over time
struct ChartMenuView: View {
    @State private var selectedRange: ChartTimeRange = .day
    @State private var chartData: [HourlyStats] = []
    
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
                Chart {
                    // Threshold lines
                    RuleMark(y: .value("Warning", 5))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    RuleMark(y: .value("Danger", 10))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    // Data line
                    ForEach(chartData) { stat in
                        LineMark(
                            x: .value("Time", stat.hour),
                            y: .value("Ratio", stat.ratio)
                        )
                        .foregroundStyle(colorForRatio(stat.ratio))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Area fill under the line
                    ForEach(chartData) { stat in
                        AreaMark(
                            x: .value("Time", stat.hour),
                            y: .value("Ratio", stat.ratio)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colorForRatio(stat.ratio).opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...max(15, (chartData.map { $0.ratio }.max() ?? 10) + 2))
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
                let avgRatio = chartData.isEmpty ? 0 : chartData.map { $0.ratio }.reduce(0, +) / Double(chartData.count)
                Text("Avg: \(String(format: "%.1f%%", avgRatio))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(chartData.count) data points")
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
        chartData = historyManager.getStats(lastHours: selectedRange.hours)
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
