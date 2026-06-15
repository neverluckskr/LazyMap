# LazyMap — план проекта

Карта для iOS: смесь **Bump** (след «где ты ездил») и **Waze** (карта + маршрут + скорость).

## Стек
- **SwiftUI** — весь UI
- **MapKit** — карта, dark/light, отрисовка маршрута и следа (нативно, бесплатно)
- **CoreLocation** — позиция, скорость (км/ч), запись трека
- **SwiftData** — хранение пройденных точек
- **Liquid Glass** (нативный, iOS 26): `.glassEffect()`, `.buttonStyle(.glass)`, `GlassEffectContainer`
- Минимальная iOS: **26.0**

> ℹ️ iOS 27 / Xcode 27 на июнь 2026 — только developer beta (публично в сентябре 2026), и **Codemagic их пока не собирает** (максимум Xcode 26.5). Поднимем таргет до 27, когда Codemagic добавит Xcode 27 — это правка одной строки в `project.yml` + `codemagic.yaml`.

## Сборка (как у MyApp)
- **XcodeGen** (`project.yml`) генерит `.xcodeproj` — **Mac не нужен для написания кода**.
- **Codemagic** (`codemagic.yaml`, `mac_mini_m1`, Xcode 26) собирает **unsigned IPA**.
- Flow: код пишется на Windows → push в GitHub → Codemagic собирает → IPA.
- Разрешения геолокации задаём через `INFOPLIST_KEY_*` в `project.yml` (Info.plist отдельный не нужен, `GENERATE_INFOPLIST_FILE: YES`).

## Фичи и решение
| Фича | Как делаем |
|------|-----------|
| 🌗 Dark / Light | Тумблер в UI → `.preferredColorScheme`; карта MapKit сама адаптируется |
| 🏎️ Скорость км/ч | `CLLocation.speed` (м/с) × 3.6, плашка-спидометр поверх карты |
| 🟣 След «где ездил» | Пишем GPS-точки → рисуем кружками-оверлеем; кнопка вкл/выкл записи |
| 🧭 Маршрут | `MKDirections` строит путь A→B, рисуем линией + время/расстояние |

## Архитектура (файлы)
```
LazyMap/
├── LazyMapApp.swift           // точка входа
├── ContentView.swift          // корневой экран с картой + оверлеями
├── Map/
│   ├── MapView.swift          // обёртка карты MapKit
│   ├── ThemeToggle.swift      // переключатель dark/light
│   └── SpeedBadge.swift       // плашка км/ч
├── Location/
│   └── LocationManager.swift  // CoreLocation: позиция, скорость, запись
├── Trail/
│   ├── TrailStore.swift       // сохранение/загрузка точек (SwiftData)
│   ├── TrailPoint.swift       // модель точки (lat, lon, time)
│   └── TrailOverlay.swift     // отрисовка кружков на карте
└── Routing/
    └── RouteService.swift     // MKDirections, маршрут линией
```

## Порядок работы (этапы)
1. **Скелет**: проект + карта на весь экран, показ моей позиции.
2. **Dark/Light**: тумблер переключения темы.
3. **Спидометр**: км/ч из CoreLocation, плашка снизу.
4. **След (главная фишка)**: запись точек + отрисовка кружками + кнопка старт/стоп + сохранение между запусками.
5. **Маршрут**: ввод точки назначения → линия + ETA.
6. **Полировка**: иконки, анимации, follow-режим камеры.

## Что нужно от тебя (позже)
- Repo на GitHub + подключить к Codemagic (как у MyApp).
- Разрешения геолокации идут в `project.yml`:
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`,
  `INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription`.
- Для реального GPS/скорости — установить IPA на iPhone (на симуляторе скорость симулируется маршрутом).

## Отложено на потом
- Полный turn-by-turn с голосом (как Waze) — отдельный большой этап, возможно Mapbox SDK.
- Соц-фича Waze (метки ДТП/камер от юзеров) — нужен бэкенд.
