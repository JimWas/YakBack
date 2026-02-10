# Changelog

All notable changes to Yak Back will be documented in this file.

## [Unreleased]

### Added
- **Premium Sound Limit Feature**: Free users are now limited to 9 sounds maximum
  - Upgrade prompt appears when limit is reached
  - Pro users enjoy unlimited sounds
  - Import handlers respect limits when batch importing
  - Beautiful Matrix-themed upgrade prompt with feature list

### Changed
- Updated Settings Pro section to show "Unlimited sounds + No ads" benefits
- StoreManager now includes `freeTierSoundLimit`, `canAddSound()`, and `remainingSounds()` helpers

---

## [1.0.0] - 2026-02-01

### Added

#### Core Soundboard Features
- **Sound Pad Grid**: Responsive grid layout (3 columns on iPhone, 5 on iPad)
- **Multi-track Playback**: Play multiple sounds simultaneously with independent controls
- **Stop All Button**: Instantly stop all playing sounds

#### Sound Import
- **Video Import**: Extract audio from videos in your camera roll (converts to M4A)
- **Audio Import**: Direct import of MP3, WAV, M4A, AIF files
- **Recording**: Built-in microphone recorder with level meters

#### Sound Controls (per sound)
- **Volume Control**: 0-100% with visual slider
- **Volume Boost**: Up to 2x amplification
- **Speed Control**: 0.25x to 2x playback speed with presets
- **Loop Control**: 1-99 loops or infinite loop mode
- **3-Band Equalizer**: Bass, Mid, Treble (-12dB to +12dB)
- **Timer Playback**: Delayed playback (5s, 10s, 30s, 1m, 5m presets)
- **Color Customization**: Full hue spectrum for pad colors
- **Waveform Trimming**: Visual trim editor with start/end handles

#### Organization
- **Folders**: Create custom folders to organize sounds
- **Favorites**: Star sounds to pin them to the top
- **Drag & Drop Reorder**: Reorder sounds within the grid
- **Search**: Real-time search filtering by sound name
- **Context Menu**: Right-click/long-press for quick actions

#### Export & Sharing
- **Save to Files**: Export sounds via iOS Share Sheet

#### Monetization
- **AdMob Integration**: Native ads for free users (styled to match theme)
- **Pro Upgrade**: One-time purchase removes ads and unlocks unlimited sounds
- **Restore Purchases**: Recover previous purchases

#### Siri Shortcuts
- **Play Sound Intent**: "Play [sound name] on Yak Back"
- **Sound Entity Query**: Searchable sound list for Shortcuts app

#### User Experience
- **Onboarding**: 5-screen tutorial introducing features
- **Matrix Theme**: Custom "Nasalization" font, green glow effects, rain animation
- **Haptic Feedback**: Configurable touch feedback
- **Dark Mode**: Native dark theme (forced)
- **Review Prompts**: Smart review requests at launches 5, 15, 50

#### Settings
- **Haptic Toggle**: Enable/disable haptic feedback
- **Storage Info**: View total storage used by sounds
- **Replay Onboarding**: Reset onboarding to view tutorial again
- **Privacy Policy & Terms**: Links to legal documents

#### Data Persistence
- **SwiftData**: Local storage for sounds and folders
- **File Management**: Audio files stored in Documents directory
