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
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
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

            Text(dateString)
                .font(.system(size: 30, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
                .shadow(radius: 3)
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

