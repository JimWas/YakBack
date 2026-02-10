# Yak Back - App Store Submission Checklist

## App Store Connect Setup

- [ ] Create a new app record in App Store Connect with bundle ID `JimWas.Yak-Back`
- [ ] Set pricing (Free or paid)
- [ ] Select primary category: **Music**
- [ ] Select age rating (likely 4+ since no objectionable content)
- [ ] Write app description (max 4000 characters)
- [ ] Write subtitle (max 30 characters), e.g. "Digital Soundboard"
- [ ] Write promotional text (max 170 characters)
- [ ] Add keywords (max 100 characters, comma-separated), e.g. "soundboard,sound effects,audio,equalizer,mixer,sound pad,loop,record"
- [ ] Set support URL
- [ ] Set marketing URL (optional)

## Screenshots

- [ ] iPhone 6.7" display (iPhone 15 Pro Max) - minimum 3, up to 10
- [ ] iPhone 6.1" display (iPhone 15 Pro) - minimum 3, up to 10
- [ ] iPad Pro 12.9" (6th gen) - required if supporting iPad
- [ ] iPad Pro 11" - required if supporting iPad

Tip: Use the iOS Simulator to capture screenshots. Show the soundboard grid, the sound controls/EQ view, the recording view, and the import options.

## Web Pages (Required)

- [ ] Create privacy policy page at `https://jimwas.com/yakback/privacy`
- [ ] Create terms of use page at `https://jimwas.com/yakback/terms`
- [ ] Enter the privacy policy URL in App Store Connect under "App Privacy"

## App Privacy (Data Collection)

- [ ] Complete the App Privacy questionnaire in App Store Connect
- [ ] Yak Back does not collect any user data or use analytics, so you should be able to declare "Data Not Collected" for all categories
- [ ] Confirm no third-party SDKs are collecting data

## Font License

- [ ] Verify the Nasalization Rg.otf font license permits embedding in a commercially distributed iOS app
- [ ] If the license is restrictive, either purchase a commercial license or replace with a free alternative

## App Icon

- [ ] Verify the app icon displays correctly in Xcode's asset catalog (1024x1024 required for App Store)
- [ ] Confirm it looks good at small sizes (home screen, notifications, settings)

## Testing Before Submission

- [ ] Test on a real iPhone device (not just Simulator)
- [ ] Test importing a video file and converting to audio
- [ ] Test importing audio files (MP3, WAV, M4A, AIF)
- [ ] Test recording from microphone
- [ ] Test denying microphone permission and verify the denied state UI works
- [ ] Test playback controls: play, pause, stop, restart
- [ ] Test equalizer adjustments (bass, mid, treble)
- [ ] Test speed adjustment with presets
- [ ] Test loop count (1x, 3x, 5x, 10x, infinite)
- [ ] Test volume and volume boost
- [ ] Test playing multiple sounds simultaneously
- [ ] Test deleting a sound
- [ ] Test saving/exporting a sound to Files
- [ ] Test the onboarding flow (reset via Settings > Replay Onboarding)
- [ ] Test on iPad to verify the 5-column grid layout
- [ ] Test with VoiceOver enabled to verify accessibility
- [ ] Test with low disk space if possible

## Archive and Upload

- [ ] In Xcode: Product > Archive
- [ ] In the Organizer window, click "Distribute App"
- [ ] Select "App Store Connect" and upload
- [ ] Wait for App Store Connect to finish processing the build (usually 15-30 min)
- [ ] Select the build in App Store Connect under your app version

## Final Submission

- [ ] Review all metadata one last time
- [ ] Submit for review
- [ ] Apple review typically takes 24-48 hours
