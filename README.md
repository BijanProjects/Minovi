# ChronoSense — Flutter

> Understand your time. Reflect on your hours. Live intentionally.

ChronoSense is a privacy-first, offline time-journaling app that divides your waking hours into customizable intervals and prompts you to reflect on each one.

## Architecture

**Clean Architecture + Riverpod MVVM**

```
lib/
├── core/           # DI providers, IntervalEngine algorithm, ChronoResult type
├── data/           # SQLite database, DAOs, mappers, preferences, LRU cache
├── domain/         # Models (JournalEntry, Mood, ActivityTag, TimeSlot, etc.)
├── notification/   # Local notification scheduling
├── ui/
│   ├── components/ # TimeSlotCard, MoodSelector, TagSelector
│   ├── design/     # Spacing, Radius, Elevation tokens
│   ├── navigation/ # GoRouter with premium Material 3 transitions
│   ├── screens/    # day/, entry/, month/, settings/
│   └── theme/      # Colors, Typography, Theme
└── util/           # TimeUtils, Constants
```

## Features

- **Day View** — Time slot cards with mood accent bars, staggered animations, auto-scroll
- **Entry Editor** — Description, 7-mood animated selector, 10-activity tag chips
- **Month View** — Calendar grid, stats summary, mood distribution, activity bar charts
- **Settings** — Wake/sleep time pickers, interval selection, notification toggle
- **Notifications** — Exact alarm scheduling at each interval boundary
- **Premium Animations** — Fade-through tab transitions, spring-physics mood selector, staggered list reveals, shared-axis entry navigation

## Getting Started

```bash
flutter pub get
flutter run
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.27+ |
| State Management | Riverpod |
| Navigation | GoRouter |
| Database | sqflite |
| Preferences | shared_preferences |
| Notifications | flutter_local_notifications |
| Design System | Material 3 |

## Color System

Indigo primary (`#6366F1`) / Amber secondary (`#F59E0B`) / Slate neutrals — light & dark themes.

## License

Private — All rights reserved.
