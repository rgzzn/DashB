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
    @Environment(\.colorScheme) private var colorScheme
    @State private var availableCalendars: [CalendarInfo] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showContent = false
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

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
                        .tint(theme.primaryText)
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
                                                .foregroundStyle(theme.primaryText)
                                            Text(
                                                isSelected
                                                    ? L10n.string("calendarSelection.visible")
                                                    : L10n.string("calendarSelection.inactive")
                                            )
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(theme.secondaryText)
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
                    .foregroundStyle(theme.primaryText)
                Text("calendarSelection.subtitle")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 620, height: 620)
                .blur(radius: 120)
                .offset(x: -420, y: -220)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.17 : 0.1))
                .frame(width: 560, height: 560)
                .blur(radius: 100)
                .offset(x: 420, y: -180)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color.indigo.opacity(0.2)
                        : Color.white.opacity(0.1)
                )
                .frame(width: 520, height: 520)
                .blur(radius: 110)
                .offset(x: 420, y: 180)
        }
        .ignoresSafeArea()
    }
}

private struct CalendarSelectionPanelStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var tint: Color = .clear
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.panelMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryText.opacity(0.08), .clear, tint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .dashBLiquidGlass(
                cornerRadius: 24,
                tint: theme.glassTint,
                staticTintOpacity: colorScheme == .dark ? 0.12 : 0.08
            )
            .shadow(color: theme.panelShadow, radius: 24, y: 10)
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
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.black.opacity(0.88) : theme.primaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        prominent
                            ? Color.white.opacity(0.9)
                            : theme.panelFill.opacity(colorScheme == .dark ? 1.25 : 0.96)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        prominent ? Color.clear : theme.focusStroke.opacity(isFocused ? 0.8 : 0.4),
                        lineWidth: isFocused ? 1.6 : 1
                    )
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
            .dashBLiquidGlass(
                cornerRadius: 20,
                tint: prominent ? .white : theme.glassTint,
                interactive: true,
                interactiveTintOpacity: colorScheme == .dark ? 0.24 : 0.16
            )
            .scaleEffect(isFocused ? 1.05 : 1)
            .shadow(color: theme.focusShadow.opacity(isFocused ? 1 : 0.5), radius: isFocused ? 24 : 16, y: isFocused ? 10 : 6)
            .animation(Motion.focus, value: isFocused)
    }
}

private extension View {
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
