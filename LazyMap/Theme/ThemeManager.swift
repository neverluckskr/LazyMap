import SwiftUI

/// Управляет выбором темы: системная / светлая / тёмная.
/// Выбор сохраняется между запусками через @AppStorage.
final class ThemeManager: ObservableObject {
    enum Preference: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        /// nil = следовать системной теме.
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }

        var label: String {
            switch self {
            case .system: return "Системная"
            case .light:  return "Светлая"
            case .dark:   return "Тёмная"
            }
        }

        var iconName: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light:  return "sun.max.fill"
            case .dark:   return "moon.fill"
            }
        }
    }

    /// Акцентный цвет приложения (#13).
    enum Accent: String, CaseIterable, Identifiable {
        case blue, green, orange, pink, purple, red

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue:   return .blue
            case .green:  return .green
            case .orange: return .orange
            case .pink:   return .pink
            case .purple: return .purple
            case .red:    return .red
            }
        }

        var label: String {
            switch self {
            case .blue:   return "Синий"
            case .green:  return "Зелёный"
            case .orange: return "Оранжевый"
            case .pink:   return "Розовый"
            case .purple: return "Фиолетовый"
            case .red:    return "Красный"
            }
        }
    }

    @AppStorage("colorSchemePreference") private var storedValue: String = Preference.system.rawValue
    @AppStorage("accentColor") private var storedAccent: String = Accent.blue.rawValue

    @Published var preference: Preference = .system {
        didSet { storedValue = preference.rawValue }
    }

    @Published var accent: Accent = .blue {
        didSet { storedAccent = accent.rawValue }
    }

    init() {
        preference = Preference(rawValue: storedValue) ?? .system
        accent = Accent(rawValue: storedAccent) ?? .blue
    }

    /// Переключает темы по кругу: системная → светлая → тёмная → ...
    func cycle() {
        let all = Preference.allCases
        guard let idx = all.firstIndex(of: preference) else { return }
        preference = all[(idx + 1) % all.count]
    }
}
