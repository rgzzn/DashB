//
//  ClockView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import SwiftUI

struct ClockView: View {
    @State private var currentTime = Date()
    @State private var showContent = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    var dateString: String {
        Self.dateFormatter.string(from: currentTime).capitalized
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Text(currentTime, style: .time)
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .shadow(radius: 5)
                .contentTransition(.numericText())
                .animation(Motion.standard, value: currentTime)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(dateString)
                .font(.system(size: 30, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
                .shadow(radius: 3)
                .contentTransition(.opacity)
                .animation(Motion.calm, value: dateString)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
        .onReceive(timer) { input in
            currentTime = input
        }
    }
}
#Preview("ClockView Preview") {
    ClockView()
        .padding()
        .background(GradientBackgroundView().ignoresSafeArea())
}
