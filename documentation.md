# Yak Back - Technical Documentation

> A Matrix-themed iOS soundboard app built with SwiftUI, SwiftData, and AVFoundation.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Data Models](#data-models)
4. [Audio Engine](#audio-engine)
5. [Views & UI Components](#views--ui-components)
6. [Monetization](#monetization)
7. [Siri Shortcuts Integration](#siri-shortcuts-integration)
8. [Theme System](#theme-system)
9. [Key Features](#key-features)
10. [Configuration](#configuration)

---

## Architecture Overview

Yak Back follows a **SwiftUI + SwiftData** architecture with the Observable macro pattern.

```
┌─────────────────────────────────────────────────────────────┐
│                        Yak_BackApp                          │
│                    (App Entry Point)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌────────────────┐  │
│  │ ContentView │────│ AudioEngine │────│  StoreManager  │  │
│  │  (Main UI)  │    │ (Playback)  │    │   (IAP/Pro)    │  │
│  └─────────────┘    └─────────────┘    └────────────────┘  │
│         │                                                   │
│         ├── SoundControlsView (per-sound controls)         │
│         ├── RecordingView (microphone recording)           │
│         ├── WaveformTrimView (audio trimming)              │
│         └── SettingsView (app settings)                    │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                      SwiftData Layer                        │
│  ┌─────────────┐              ┌─────────────┐              │
│  │  SoundItem  │              │ SoundFolder │              │
│  └─────────────┘              └─────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
Yak Back/
├── Yak Back/
│   ├── Yak_BackApp.swift        # App entry point, ModelContainer setup
│   ├── ContentView.swift         # Main soundboard grid view
│   ├── SoundControlsView.swift   # Per-sound controls (volume, EQ, etc.)
│   ├── SoundPadView.swift        # Individual sound pad button
│   ├── RecordingView.swift       # Microphone recording UI
│   ├── WaveformTrimView.swift    # Audio trimming with waveform display
│   ├── SettingsView.swift        # App settings & Pro upgrade
│   ├── OnboardingView.swift      # First-launch tutorial
│   │
│   ├── AudioEngine.swift         # Multi-track audio playback engine
│   ├── StoreManager.swift        # In-app purchase management
│   │
│   ├── SoundItem.swift           # SwiftData model for sounds
│   ├── SoundFolder.swift         # SwiftData model for folders
│   │
│   ├── Theme.swift               # MatrixTheme colors & fonts
│   ├── MatrixRainView.swift      # Animated Matrix rain background
│   ├── NativeAdView.swift        # AdMob native ad component
│   │
│   ├── PlaySoundIntent.swift     # Siri Shortcuts intent
│   ├── AppShortcuts.swift        # App Shortcuts provider
│   │
│   ├── Info.plist                # App configuration
│   └── Assets/
│       └── Nasalization Rg.otf   # Custom font
│
├── CHANGELOG.md
└── documentation.md
```

---

## Data Models

### SoundItem (`SoundItem.swift`)

The primary data model for sounds stored via SwiftData.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `name` | `String` | Display name |
| `fileName` | `String` | Audio file name in Documents |
| `dateAdded` | `Date` | Creation timestamp |
| `volume` | `Float` | Volume level (0.0-1.0) |
| `speed` | `Float` | Playback speed (0.25-2.0) |
| `loopCount` | `Int` | Loop count (-1 = infinite) |
| `eqBass` | `Float` | Bass EQ (-12 to +12 dB) |
| `eqMid` | `Float` | Mid EQ (-12 to +12 dB) |
| `eqTreble` | `Float` | Treble EQ (-12 to +12 dB) |
| `volumeBoost` | `Float?` | Volume multiplier (1.0-2.0) |
| `colorHue` | `Double` | Pad color hue (0.0-1.0) |
| `isFavorite` | `Bool?` | Favorite status |
| `sortOrder` | `Int?` | Custom sort position |
| `folderName` | `String?` | Assigned folder name |
| `trimStart` | `Double?` | Trim start time |
| `trimEnd` | `Double?` | Trim end time |

**Computed Properties:**
- `fileURL` - Full path to audio file in Documents
- `effectiveVolumeBoost` - Safe unwrap with default 1.0
- `effectiveFavorite` - Safe unwrap with default false
- `effectiveSortOrder` - Safe unwrap with default Int.max

### SoundFolder (`SoundFolder.swift`)

Folder organization for sounds.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `name` | `String` | Folder name |
| `colorHue` | `Double` | Color hue for folder tab |
| `sortOrder` | `Int` | Tab display order |
| `dateCreated` | `Date` | Creation timestamp |

---

## Audio Engine

### TrackPlayer (`AudioEngine.swift`)

Individual track player with real-time parameter control.

**Audio Processing Chain:**
```
AVAudioPlayerNode → AVAudioUnitEQ (3-band) → AVAudioUnitTimePitch → MainMixer
```

**EQ Configuration:**
- Band 0: Low Shelf @ 100Hz
- Band 1: Parametric @ 1000Hz
- Band 2: High Shelf @ 6000Hz

**Key Methods:**
- `loadFile(url:)` - Load audio file into buffer
- `play(loops:)` - Start playback with loop count
- `stop()` / `pause()` / `resume()` - Playback control

### AudioEngine (`AudioEngine.swift`)

Multi-track manager supporting simultaneous playback.

**Features:**
- Automatic session configuration (`.playback` category)
- Engine start/stop on demand
- Track lifecycle management
- Background playback support

**Key Methods:**
- `play(sound:)` - Play a SoundItem
- `stop(soundID:)` - Stop specific track
- `stopAll()` - Stop all tracks
- `isPlaying(soundID:)` - Check playback state

**Static Utilities:**
- `convertVideoToM4A(inputURL:outputFileName:)` - Extract audio from video
- `copyAudioFile(inputURL:outputFileName:)` - Copy audio to Documents

---

## Views & UI Components

### ContentView (`ContentView.swift`)

Main soundboard interface.

**Features:**
- Responsive grid (3 cols phone, 5 cols iPad)
- Search bar with real-time filtering
- Folder tabs with horizontal scroll
- Drag & drop reordering
- Context menus for quick actions
- Import sheet (video/audio/recording)
- Ad banner (hidden for Pro users)

**State Management:**
- `@Query` for sounds and folders from SwiftData
- `@State` for UI state (sheets, alerts, selection)
- `@AppStorage` for user preferences

### SoundControlsView (`SoundControlsView.swift`)

Detailed controls for a single sound.

**Control Sections:**
1. **Header** - Icon, name, date
2. **Playback** - Play/Pause/Stop/Restart
3. **Volume** - Slider + boost control
4. **Speed** - Slider + presets (0.5x-2x)
5. **Loop** - Count selector + presets
6. **Timer** - Delayed playback (5s-5m)
7. **Equalizer** - 3-band with reset
8. **Color** - Hue picker
9. **Trim** - Opens WaveformTrimView
10. **Actions** - Export, Delete

### SoundPadView (`SoundPadView.swift`)

Individual sound button in the grid.

**Visual States:**
- Default: Dark gradient with border
- Playing: Brighter gradient, glow effect, waveform icon
- Pressed: Scale down animation

**Interactions:**
- Tap: Navigate to SoundControlsView
- Long press: Opens rename dialog

### RecordingView (`RecordingView.swift`)

Microphone recording interface.

**Components:**
- 20-bar level meter (green/yellow/red zones)
- Timer display (MM:SS.ms format)
- Record/Stop button with visual feedback
- Name input after recording
- Discard/Save options

**AudioRecorder Class:**
- Permission handling
- Disk space checking
- AAC recording @ 44.1kHz
- Real-time metering

### WaveformTrimView (`WaveformTrimView.swift`)

Visual audio trimming tool.

**Features:**
- 100-bar waveform visualization
- Draggable start/end handles
- Dimmed regions outside selection
- Time labels with duration
- Destructive trim (creates new file)

### SettingsView (`SettingsView.swift`)

App configuration.

**Sections:**
- **Pro**: Upgrade button or unlocked status
- **About**: Version, developer info
- **Legal**: Privacy Policy, Terms of Use links
- **Preferences**: Haptic feedback toggle
- **Actions**: Replay onboarding
- **Storage**: Total sounds storage used

### OnboardingView (`OnboardingView.swift`)

First-launch tutorial (5 pages).

**Pages:**
1. Welcome + app intro
2. Import & convert features
3. Recording feature
4. EQ & effects
5. Multi-track playback

---

## Monetization

### StoreManager (`StoreManager.swift`)

In-app purchase management using StoreKit 2.

**Product:**
- ID: `com.jimwas.yakback.pro`
- Type: Non-consumable (one-time purchase)

**Features:**
- Product loading
- Purchase flow
- Restore purchases
- Transaction listening
- Entitlement verification

**Pro Benefits:**
- No advertisements
- Unlimited sounds (free tier: 9 sounds max)

**Key Properties:**
- `isPro` - Current entitlement status
- `proProduct` - Loaded Product object
- `freeTierSoundLimit = 9` - Sound limit for free users

**Key Methods:**
- `canAddSound(currentCount:)` - Check if user can add more sounds
- `remainingSounds(currentCount:)` - Get remaining slots for free tier

### NativeAdView (`NativeAdView.swift`)

AdMob native ad integration.

**Configuration:**
- App ID: `ca-app-pub-3057383894764696~9253301655`
- Ad Unit: `ca-app-pub-3057383894764696/5067079401`

**Components:**
- `NativeAdViewModel` - Ad loading with delegate
- `AdBannerView` - SwiftUI wrapper (conditional on Pro)
- `NativeAdRepresentable` - UIKit bridge

**Styling:**
- Matches Matrix theme
- Custom Nasalization font
- Green accent colors

---

## Siri Shortcuts Integration

### PlaySoundIntent (`PlaySoundIntent.swift`)

App Intent for Siri and Shortcuts app.

**Usage:**
- "Play [sound name] on Yak Back"
- Shortcuts app automation

**Components:**
- `SoundEntity` - AppEntity representing a sound
- `SoundEntityQuery` - Query for searching sounds
- `PlaySoundIntent` - The actual intent

**Behavior:**
- Runs without opening app
- Uses AVAudioPlayer for playback
- Waits for completion before returning

---

## Theme System

### MatrixTheme (`Theme.swift`)

Centralized theming with Matrix-inspired aesthetics.

**Colors:**
| Name | RGB | Usage |
|------|-----|-------|
| `green` | (0, 1, 0.255) | Primary accent |
| `darkGreen` | (0, 0.4, 0.1) | Gradients |
| `dimGreen` | (0, 0.6, 0.15) | Secondary text |
| `background` | (0.02, 0.02, 0.03) | App background |
| `cardBackground` | (0.05, 0.08, 0.05) | Card surfaces |
| `cardBorder` | green @ 50% | Card borders |
| `glowColor` | green @ 60% | Glow effects |

**Font:**
- `Nasalization Rg.otf` - Custom sci-fi font
- `MatrixTheme.font(_ size:)` - Helper function

**Components:**
- `MatrixText` - Styled text view
- `GlowingBorder` - View modifier for glowing borders
- `MatrixSlider` - Custom slider matching theme

### MatrixRainView (`MatrixRainView.swift`)

Animated background with falling characters.

**Configuration:**
- Random characters from Matrix-style set
- Variable speeds and opacities
- Used at low opacity (0.1-0.15) as background

---

## Key Features

### Sound Limit (Free vs Pro)

**Free Tier:**
- Maximum 9 sounds
- Ads displayed at bottom
- Upgrade prompts when limit reached

**Pro Tier:**
- Unlimited sounds
- No advertisements
- One-time purchase

**Implementation:**
- `StoreManager.freeTierSoundLimit = 9`
- `canAddSound(currentCount:)` checks limit
- Import handlers respect limit during batch import
- Upgrade sheet shown when limit reached

### Multi-track Audio

- Each sound gets independent TrackPlayer
- All players share single AVAudioEngine
- Real-time parameter changes (volume, EQ, speed)
- Automatic cleanup when playback ends

### Folder Organization

- Create unlimited folders
- Assign sounds to folders
- Filter view by folder
- Delete folder moves sounds to "All"

### Search & Sort

- Real-time search by name
- Favorites pinned to top
- Custom sort order via drag/drop
- Newest sounds shown first (default)

---

## Configuration

### Info.plist Keys

| Key | Value | Purpose |
|-----|-------|---------|
| `UIAppFonts` | Nasalization Rg.otf | Custom font |
| `NSMicrophoneUsageDescription` | Recording permission message |
| `GADApplicationIdentifier` | AdMob App ID |
| `SKAdNetworkItems` | Ad attribution networks |

### App Storage Keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hasCompletedOnboarding` | Bool | false | Skip onboarding |
| `launchCount` | Int | 0 | Review prompt timing |
| `hapticEnabled` | Bool | true | Haptic feedback |

### Audio Session

- Category: `.playback`
- Mode: `.default`
- Options: `.mixWithOthers`

---

## Development Notes

### Adding New Features

1. **New Sound Property**: Add to `SoundItem.swift` as optional for migration safety
2. **New Setting**: Add `@AppStorage` key and UI in `SettingsView`
3. **New Sound Control**: Add section in `SoundControlsView`

### Testing

- Use `inMemory: true` in ModelConfiguration for previews
- Test Pro features by temporarily setting `isPro = true`
- Test ads in simulator with test ad unit IDs

### Building

- Requires iOS 17.0+
- Swift 5.9+
- Xcode 15+
- GoogleMobileAds SDK via SPM

---

## API Reference Quick Links

| Component | File | Line |
|-----------|------|------|
| Sound model | `SoundItem.swift` | 12 |
| Audio playback | `AudioEngine.swift` | 161 |
| IAP handling | `StoreManager.swift` | 11 |
| Main grid | `ContentView.swift` | 13 |
| Sound controls | `SoundControlsView.swift` | 11 |
| Recording | `RecordingView.swift` | 112 |
| Trimming | `WaveformTrimView.swift` | 11 |
| Theme | `Theme.swift` | 10 |
| Siri intent | `PlaySoundIntent.swift` | 63 |
