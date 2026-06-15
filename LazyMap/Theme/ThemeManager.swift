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

    @AppStorage("colorSchemePreference") private var storedValue: String = Preference.system.rawValue

    @Published var preference: Preference = .system {
        didSet { storedValue = preference.rawValue }
    }

    init() {
        preference = Preference(rawValue: storedValue) ?? .system
    }

    /// Переключает темы по кругу: системная → светлая → тёмная → ...
    func cycle() {
        let all = Preference.allCases
        guard let idx = all.firstIndex(of: preference) else { return }
        preference = all[(idx + 1) % all.count]
    }
}
