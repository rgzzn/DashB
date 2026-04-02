//
//  CalendarSelectionView.swift
//  DashB
//
//  Created by Luca Ragazzini on 24/01/26.
//

import Combine
import SwiftUI

struct CalendarSelectionView<Service: CalendarService>: View {
    let service: Service
    @Binding var selectedConfigs: [CalendarInfo]
    @Environment(\.dismiss) private var dismiss
    @State private var availableCalendars: [CalendarInfo] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showContent = false

    let basicColors = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#A2845E", "#8E8E93",
    ]

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .overlay {
                    CalendarSubmenuBackdrop()
                }
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                if isLoading {
                    Spacer()
                    ProgressView("calendarSelection.loading")
                        .tint(.white)
                    Spacer()
                } else if let error = errorMsg {
                    Spacer()
                    VStack(spacing: 18) {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Button("common.retry") { loadCalendars() }
                            .buttonStyle(CalendarSubmenuButtonStyle(prominent: true))
                            .accessibilityLabel("calendarSelection.accessibility.retryLoading")
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(availableCalendars) { cal in
                                let isSelected = selectedConfigs.contains(where: { $0.id == cal.id })

                                VStack(alignment: .leading, spacing: 18) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(cal.name)
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(
                                                isSelected
                                                    ? L10n.string("calendarSelection.visible")
                                                    : L10n.string("calendarSelection.inactive")
                                            )
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.56))
                                        }

                                        Spacer()

                                        Toggle(
                                            "",
                                            isOn: Binding(
                                                get: { isSelected },
                                                set: { active in
                                                    if active {
                                                        if !isSelected {
                                                            var newCal = cal
                                                            newCal.colorHex = basicColors[0]
                                                            selectedConfigs.append(newCal)
                                                        }
                                                    } else {
                                                        selectedConfigs.removeAll(where: {
                                                            $0.id == cal.id
                                                        })
                                                    }
                                                }
                                            )
                                        )
                                        .toggleStyle(.switch)
                                        .accessibilityLabel(
                                            L10n.string(
                                                "calendarSelection.accessibility.selectCalendar",
                                                cal.name
                                            )
                                        )
                                    }

                                    if isSelected {
                                        HStack(spacing: 20) {
                                            ForEach(basicColors, id: \.self) { hex in
                                                let isCurrent =
                                                    selectedConfigs.first(where: { $0.id == cal.id })?
                                                    .colorHex == hex

                                                Button {
                                                    if let index = selectedConfigs.firstIndex(where: {
                                                        $0.id == cal.id
                                                    }) {
                                                        selectedConfigs[index].colorHex = hex
                                                    }
                                                } label: {
                                                    Circle()
                                                        .fill(Color(hex: hex))
                                                        .frame(width: 48, height: 48)
                                                        .overlay(
                                                            Circle()
                                                                .stroke(
                                                                    Color.white,
                                                                    lineWidth: isCurrent ? 4 : 0)
                                                        )
                                                        .shadow(radius: isCurrent ? 7 : 0)
                                                }
                                                .buttonStyle(ColorButtonStyle())
                                                .accessibilityLabel(
                                                    L10n.string(
                                                        "calendarSelection.accessibility.colorForCalendar",
                                                        hex,
                                                        cal.name
                                                    )
                                                )
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.leading, 4)
                                    }
                                }
                                .padding(26)
                                .modifier(
                                    CalendarSelectionPanelStyle(
                                        tint: isSelected ? .cyan.opacity(0.05) : .clear
                                    )
                                )
                            }
                        }
                        .padding(40)
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 14)
            .animation(Motion.enter, value: showContent)
        }
        .onAppear {
            loadCalendars()
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("calendarSelection.title")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("calendarSelection.subtitle")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            Button("common.done") { dismiss() }
                .buttonStyle(CalendarSubmenuButtonStyle(prominent: false))
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }

    private func loadCalendars() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let fetched = try await service.fetchAvailableCalendars()
                await MainActor.run {
                    self.availableCalendars = fetched
                    for cal in fetched {
                        if !selectedConfigs.contains(where: { $0.id == cal.id }) {
                            var newCal = cal
                            newCal.colorHex =
                                basicColors[
                                    availableCalendars.firstIndex(where: { $0.id == cal.id }) ?? 0
                                        % basicColors.count]
                            selectedConfigs.append(newCal)
                        }
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = friendlyErrorMessage(from: error)
                    isLoading = false
                }
            }
        }
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return L10n.string("calendarSelection.error.noInternet")
            case .timedOut:
                return L10n.string("calendarSelection.error.timeout")
            default:
                return L10n.string("calendarSelection.error.generic")
            }
        }
        return L10n.string("calendarSelection.error.generic")
    }
}

struct ColorButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.18 : 1.0)
            .shadow(color: .white.opacity(isFocused ? 0.45 : 0), radius: 10)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isFocused ? 4 : 0)
                    .padding(-6)
            )
            .animation(Motion.focus, value: isFocused)
            .dashBDisableSystemFocusEffect()
    }
}

private struct CalendarSubmenuBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 620, height: 620)
                .blur(radius: 120)
                .offset(x: -420, y: -220)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 560, height: 560)
                .blur(radius: 100)
                .offset(x: 420, y: -180)
        }
        .ignoresSafeArea()
    }
}

private struct CalendarSelectionPanelStyle: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), .clear, tint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .calendarSelectionGlass(cornerRadius: 24)
            .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
    }
}

private struct CalendarSubmenuButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        Button(role: nil, action: configuration.trigger) {
            configuration.label
        }
        .dashBDisableSystemFocusEffect()
        .modifier(CalendarButtonChrome(prominent: prominent))
        .buttonStyle(.plain)
    }
}

private struct CalendarButtonChrome: ViewModifier {
    let prominent: Bool
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        prominent
                            ? Color.white.opacity(0.9)
                            : Color(red: 0.12, green: 0.17, blue: 0.27).opacity(0.86)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(prominent ? Color.clear : Color.cyan.opacity(0.2), lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isFocused ? 0.08 : 0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .calendarSelectionGlass(cornerRadius: 20, tint: prominent ? .white : .cyan, interactive: true)
            .scaleEffect(isFocused ? 1.012 : 1)
            .shadow(color: Color.cyan.opacity(isFocused ? 0.12 : 0.06), radius: 18, y: 8)
            .animation(Motion.focus, value: isFocused)
    }
}

private extension View {
    @ViewBuilder
    func calendarSelectionGlass(
        cornerRadius: CGFloat,
        tint: Color = .white,
        interactive: Bool = false
    ) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(
                interactive
                    ? .regular.tint(tint.opacity(0.15)).interactive()
                    : .regular.tint(tint.opacity(0.08)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
        }
    }

    @ViewBuilder
    func dashBDisableSystemFocusEffect() -> some View {
        if #available(tvOS 17.0, iOS 17.0, macOS 14.0, visionOS 1.0, watchOS 10.0, *) {
            self
                .focusEffectDisabled()
                .hoverEffectDisabled(true)
        } else {
            self
        }
    }
}

final class MockCalendarService: ObservableObject, CalendarService {
    @Published var isConnected: Bool = true
    let serviceName: String = "Mock Calendars"

    func startDeviceAuth() async throws -> DeviceAuthInfo {
        DeviceAuthInfo(
            userCode: "ABCD-1234",
            verificationUri: "https://example.com/link",
            deviceCode: "device",
            expiresIn: 600,
            interval: 5
        )
    }

    func pollForToken(deviceCode: String, interval: Int) async throws -> Bool { false }

    func logout() {}

    func fetchAvailableCalendars() async throws -> [CalendarInfo] {
        [
            CalendarInfo(id: "1", name: L10n.string("calendarSelection.mock.personal"), colorHex: "#FF3B30"),
            CalendarInfo(id: "2", name: L10n.string("calendarSelection.mock.work"), colorHex: "#34C759"),
            CalendarInfo(id: "3", name: L10n.string("calendarSelection.mock.projects"), colorHex: "#007AFF"),
        ]
    }

    func fetchEvents(for calendarIDs: [String]) async throws -> [DashboardEvent] { [] }
}

struct CalendarSelectionPreviewContainer: View {
    @State private var selected: [CalendarInfo] = []
    var body: some View {
        CalendarSelectionView(service: MockCalendarService(), selectedConfigs: $selected)
            .background(GradientBackgroundView().ignoresSafeArea())
    }
}

#Preview {
    CalendarSelectionPreviewContainer()
}
