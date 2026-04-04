//
//  ClockView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct ClockView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showContent = false
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private func dateString(for date: Date) -> String {
        Self.dateFormatter.string(from: date).capitalized
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .trailing) {
                Text(timeline.date, style: .time)
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundColor(DashboardTheme(scheme: colorScheme).primaryText)
                    .shadow(radius: 5)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(dateString(for: timeline.date))
                    .font(.system(size: 30, weight: .medium, design: .default))
                    .foregroundColor(DashboardTheme(scheme: colorScheme).secondaryText)
                    .shadow(radius: 3)
                    .contentTransition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 6)
        .animation(Motion.enter.delay(0.05), value: showContent)
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
    }
}
#Preview("ClockView Preview") {
    ClockView()
        .padding()
        .background(GradientBackgroundView().ignoresSafeArea())
}
