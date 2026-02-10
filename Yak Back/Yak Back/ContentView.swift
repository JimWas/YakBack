//
//  ContentView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import StoreKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SoundItem.dateAdded, order: .reverse) private var sounds: [SoundItem]
    @Query(sort: \SoundFolder.sortOrder) private var folders: [SoundFolder]

    @State private var audioEngine = AudioEngine()
    @State private var storeManager = StoreManager()
    @StateObject private var interstitialManager = InterstitialAdManager()
    @State private var selectedSound: SoundItem?
    @State private var showImportSheet = false
    @State private var videoPickerItems: [PhotosPickerItem] = []
    @State private var showAudioImporter = false
    @State private var showRecorder = false
    @State private var showSettings = false
    @State private var isConverting = false
    @State private var conversionProgress: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var renamingSound: SoundItem?
    @State private var renameText = ""

    // New feature states
    @State private var searchText = ""
    @State private var selectedFolder: String? = nil // nil = "All"
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var draggingSound: SoundItem?
    @State private var showUpgradePrompt = false
    @State private var isPurchasing = false
    @State private var interstitialTask: Task<Void, Never>?

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("hasSeenSettingsTip") private var hasSeenSettingsTip = false
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var filteredSounds: [SoundItem] {
        var result = sounds

        // Filter by folder
        if let folder = selectedFolder {
            result = result.filter { $0.folderName == folder }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort: favorites first, then by sortOrder, then by date
        result.sort { a, b in
            if a.effectiveFavorite != b.effectiveFavorite {
                return a.effectiveFavorite && !b.effectiveFavorite
            }
            if a.effectiveSortOrder != b.effectiveSortOrder {
                return a.effectiveSortOrder < b.effectiveSortOrder
            }
            return a.dateAdded > b.dateAdded
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MatrixRainView()
                    .opacity(0.15)

                VStack(spacing: 0) {
                    headerView
                    searchBar
                    folderTabs
                    soundboardGrid
                    AdBannerView(showAd: !storeManager.isPro)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationDestination(item: $selectedSound) { sound in
                SoundControlsView(sound: sound, audioEngine: audioEngine, showAds: !storeManager.isPro)
            }
            .sheet(isPresented: $showImportSheet) {
                importOptionsSheet
            }
            .sheet(isPresented: $showRecorder) {
                RecordingView(showAds: !storeManager.isPro)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(storeManager: storeManager)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: videoPickerItems) { _, newItems in
                handleVideoPickerItems(newItems)
            }
            .fileImporter(
                isPresented: $showAudioImporter,
                allowedContentTypes: [.audio, .mp3, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                handleAudioImport(result: result)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Rename Sound", isPresented: Binding(
                get: { renamingSound != nil },
                set: { if !$0 { renamingSound = nil } }
            )) {
                TextField("Sound name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingSound = nil }
                Button("Save") {
                    if let sound = renamingSound, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        sound.name = renameText.trimmingCharacters(in: .whitespaces)
                    }
                    renamingSound = nil
                }
            } message: {
                Text("Enter a new name for this sound.")
            }
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Create") {
                    let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let folder = SoundFolder(name: trimmed)
                        folder.sortOrder = folders.count
                        modelContext.insert(folder)
                    }
                    newFolderName = ""
                }
            } message: {
                Text("Enter a name for the new folder.")
            }
            .sheet(isPresented: $showUpgradePrompt) {
                upgradePromptSheet
            }
            .overlay {
                if isConverting {
                    conversionOverlay
                }
            }
            .onAppear {
                interstitialManager.loadAd()
                startInterstitialSchedule()
            }
            .onChange(of: storeManager.isPro) { _, _ in
                if storeManager.isPro {
                    interstitialTask?.cancel()
                    interstitialTask = nil
                } else {
                    startInterstitialSchedule()
                }
            }
            .onDisappear {
                interstitialTask?.cancel()
                interstitialTask = nil
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YAK BACK")
                        .font(MatrixTheme.font(28))
                        .foregroundStyle(MatrixTheme.green)
                        .shadow(color: MatrixTheme.glowColor, radius: 10)
                        .accessibilityAddTraits(.isHeader)

                    Text("DIGITAL SOUNDBOARD")
                        .font(MatrixTheme.font(10))
                        .foregroundStyle(MatrixTheme.dimGreen)
                        .tracking(4)
                        .accessibilityHidden(true)
                }

                Spacer()

                if !audioEngine.playingSoundIDs.isEmpty {
                    Button {
                        audioEngine.stopAll()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .accessibilityLabel("Stop all sounds")
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(MatrixTheme.dimGreen)
                }
                .accessibilityLabel("Settings")

                Button {
                    if storeManager.canAddSound(currentCount: sounds.count) {
                        showImportSheet = true
                    } else {
                        showUpgradePrompt = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(MatrixTheme.green)
                        .shadow(color: MatrixTheme.glowColor, radius: 8)
                }
                .accessibilityLabel("Add new sound")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if !audioEngine.playingSoundIDs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundStyle(MatrixTheme.green)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                        .accessibilityHidden(true)
                    MatrixText(
                        text: "\(audioEngine.playingSoundIDs.count) TRACK\(audioEngine.playingSoundIDs.count == 1 ? "" : "S") PLAYING",
                        size: 10,
                        color: MatrixTheme.dimGreen
                    )
                }
                .padding(.horizontal)
                .accessibilityLabel("\(audioEngine.playingSoundIDs.count) tracks playing")
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, MatrixTheme.green.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal)
                .accessibilityHidden(true)
        }
    }

    private var soundboardGrid: some View {
        Group {
            if sounds.isEmpty {
                emptyStateView
            } else if filteredSounds.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(MatrixTheme.dimGreen)
                    MatrixText(text: "NO MATCHES", size: 16, color: MatrixTheme.dimGreen)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredSounds) { sound in
                            let showTip = !hasSeenSettingsTip && sound.id == filteredSounds.first?.id
                            SoundPadView(
                                sound: sound,
                                isPlaying: audioEngine.isPlaying(soundID: sound.id),
                                onTap: {
                                    handleSoundTap(sound)
                                },
                                onLongPress: {
                                    hasSeenSettingsTip = true
                                    selectedSound = sound
                                },
                                onSettingsTap: {
                                    hasSeenSettingsTip = true
                                    selectedSound = sound
                                },
                                onStopTap: {
                                    audioEngine.stop(soundID: sound.id)
                                },
                                showSettingsTip: showTip
                            )
                            .contextMenu {
                                Button {
                                    sound.effectiveFavorite.toggle()
                                } label: {
                                    Label(
                                        sound.effectiveFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: sound.effectiveFavorite ? "star.slash" : "star.fill"
                                    )
                                }

                                Button {
                                    renameText = sound.name
                                    renamingSound = sound
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                if !folders.isEmpty {
                                    Menu("Move to Folder") {
                                        Button("None (Remove from folder)") {
                                            sound.folderName = nil
                                        }
                                        ForEach(folders) { folder in
                                            Button(folder.name) {
                                                sound.folderName = folder.name
                                            }
                                        }
                                    }
                                }
                            }
                            .draggable(sound.id.uuidString) {
                                SoundPadView(
                                    sound: sound,
                                    isPlaying: false,
                                    onTap: {},
                                    onLongPress: {},
                                    onSettingsTap: {},
                                    onStopTap: {},
                                    showSettingsTip: false
                                )
                                .frame(width: 80, height: 80)
                                .opacity(0.8)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let draggedIDString = items.first,
                                      let draggedID = UUID(uuidString: draggedIDString),
                                      let draggedSound = sounds.first(where: { $0.id == draggedID }),
                                      draggedSound.id != sound.id else { return false }

                                let targetOrder = sound.effectiveSortOrder
                                draggedSound.effectiveSortOrder = targetOrder
                                // Shift other items
                                for s in filteredSounds where s.id != draggedSound.id {
                                    if s.effectiveSortOrder >= targetOrder {
                                        s.effectiveSortOrder += 1
                                    }
                                }
                                return true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MatrixTheme.dimGreen)
            TextField("", text: $searchText, prompt: Text("Search sounds...").foregroundStyle(MatrixTheme.dimGreen.opacity(0.6)))
                .font(MatrixTheme.font(13))
                .foregroundStyle(MatrixTheme.green)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MatrixTheme.dimGreen)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MatrixTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .glowingBorder(color: MatrixTheme.dimGreen, lineWidth: 0.5)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderTab(name: "All", isSelected: selectedFolder == nil) {
                    selectedFolder = nil
                }

                ForEach(folders) { folder in
                    folderTab(name: folder.name, isSelected: selectedFolder == folder.name) {
                        selectedFolder = folder.name
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            // Remove folder assignment from sounds
                            for sound in sounds where sound.folderName == folder.name {
                                sound.folderName = nil
                            }
                            if selectedFolder == folder.name {
                                selectedFolder = nil
                            }
                            modelContext.delete(folder)
                        } label: {
                            Label("Delete Folder", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showNewFolderAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(MatrixTheme.dimGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MatrixTheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MatrixTheme.cardBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func folderTab(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MatrixText(text: name.uppercased(), size: 11, color: isSelected ? .black : MatrixTheme.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? MatrixTheme.green : MatrixTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MatrixTheme.cardBorder, lineWidth: isSelected ? 0 : 0.5))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(MatrixTheme.dimGreen)
                .accessibilityHidden(true)

            Text("NO SOUNDS LOADED")
                .font(MatrixTheme.font(18))
                .foregroundStyle(MatrixTheme.dimGreen)

            Text("Tap + to import video, audio,\nor record from your microphone")
                .font(MatrixTheme.font(12))
                .foregroundStyle(MatrixTheme.dimGreen.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                if storeManager.canAddSound(currentCount: sounds.count) {
                    showImportSheet = true
                } else {
                    showUpgradePrompt = true
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    MatrixText(text: "ADD SOUNDS", size: 14)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(MatrixTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glowingBorder()
            }
            .accessibilityLabel("Add sounds to your soundboard")

            Spacer()
        }
    }

    private var importOptionsSheet: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Capsule()
                    .fill(MatrixTheme.dimGreen)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                MatrixText(text: "ADD SOUND", size: 20)
                    .padding(.top, 4)

                PhotosPicker(selection: $videoPickerItems, maxSelectionCount: 10, matching: .videos) {
                    HStack {
                        Image(systemName: "film.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(MatrixTheme.green)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            MatrixText(text: "IMPORT VIDEO", size: 13)
                            MatrixText(text: "Extract audio from camera roll", size: 10, color: MatrixTheme.dimGreen)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(MatrixTheme.dimGreen)
                    }
                    .padding(14)
                    .background(MatrixTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .glowingBorder()
                }
                .accessibilityLabel("Import Video: Extract audio from camera roll")

                importOptionButton(
                    icon: "music.note",
                    title: "IMPORT AUDIO",
                    subtitle: "MP3, WAV, M4A, AIF files"
                ) {
                    showImportSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAudioImporter = true
                    }
                }

                importOptionButton(
                    icon: "mic.fill",
                    title: "RECORD",
                    subtitle: "Record from microphone"
                ) {
                    showImportSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showRecorder = true
                    }
                }

                Spacer()
            }
            .padding()
        }
        .presentationDetents([.height(340)])
    }

    private func importOptionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(MatrixTheme.green)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    MatrixText(text: title, size: 13)
                    MatrixText(text: subtitle, size: 10, color: MatrixTheme.dimGreen)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(MatrixTheme.dimGreen)
            }
            .padding(14)
            .background(MatrixTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .glowingBorder()
        }
        .accessibilityLabel("\(title): \(subtitle)")
    }

    private var conversionOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(MatrixTheme.green)
                    .scaleEffect(1.5)

                MatrixText(text: "CONVERTING", size: 16)

                MatrixText(text: conversionProgress, size: 12, color: MatrixTheme.dimGreen)
            }
            .padding(32)
            .background(MatrixTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .glowingBorder()
            .accessibilityLabel("Converting video to audio, please wait")
        }
    }

    private var upgradePromptSheet: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(MatrixTheme.dimGreen)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 10)

                MatrixText(text: "SOUND LIMIT REACHED", size: 20)

                VStack(spacing: 8) {
                    MatrixText(
                        text: "Free accounts are limited to \(StoreManager.freeTierSoundLimit) sounds.",
                        size: 13,
                        color: MatrixTheme.dimGreen
                    )
                    MatrixText(
                        text: "Subscribe to Pro for unlimited sounds!",
                        size: 13,
                        color: MatrixTheme.dimGreen
                    )
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    proFeatureRow(icon: "infinity", text: "Unlimited sounds")
                    proFeatureRow(icon: "xmark.circle", text: "No advertisements")
                    proFeatureRow(icon: "heart.fill", text: "Support development")
                }
                .padding()
                .background(MatrixTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glowingBorder()

                Button {
                    isPurchasing = true
                    Task {
                        await storeManager.purchase()
                        isPurchasing = false
                        if storeManager.isPro {
                            showUpgradePrompt = false
                        }
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.black)
                            Text("SUBSCRIBE TO PRO")
                                .font(MatrixTheme.font(14))
                                .foregroundStyle(.black)
                            Text("•")
                                .foregroundStyle(.black.opacity(0.5))
                            Text(storeManager.proProduct?.displayPrice ?? "$2.99/mo")
                                .font(MatrixTheme.font(14))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(MatrixTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: MatrixTheme.glowColor, radius: 8)
                }
                .disabled(isPurchasing)

                Button {
                    Task { await storeManager.restorePurchases() }
                } label: {
                    MatrixText(text: "Restore Purchases", size: 12, color: MatrixTheme.dimGreen)
                }

                Button {
                    showUpgradePrompt = false
                } label: {
                    MatrixText(text: "Maybe Later", size: 12, color: MatrixTheme.dimGreen.opacity(0.7))
                }

                Spacer()
            }
            .padding()
        }
        .presentationDetents([.height(520)])
    }

    private func proFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(MatrixTheme.green)
                .frame(width: 24)
            MatrixText(text: text, size: 13)
            Spacer()
        }
    }

    private func handleSoundTap(_ sound: SoundItem) {
        if hapticEnabled { haptic.impactOccurred() }
        audioEngine.play(sound: sound)
    }

    private func startInterstitialSchedule() {
        guard interstitialTask == nil, !storeManager.isPro else { return }
        interstitialTask = Task { [weak storeManager] in
            while !Task.isCancelled {
                let delaySeconds = Int.random(in: 90...300)
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
                if Task.isCancelled { return }
                if storeManager?.isPro == false {
                    await MainActor.run {
                        if !showRecorder {
                            interstitialManager.showIfAvailable()
                        }
                    }
                }
            }
        }
    }

    private func checkDiskSpace() -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: docs.path),
           let freeSpace = attrs[.systemFreeSize] as? Int64,
           freeSpace < 10_000_000 {
            errorMessage = "Not enough storage space. Please free up at least 10 MB before importing."
            showError = true
            return false
        }
        return true
    }

    private func handleVideoPickerItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        guard checkDiskSpace() else { return }

        showImportSheet = false

        // Check how many sounds can be added
        let remaining = storeManager.remainingSounds(currentCount: sounds.count)
        let itemsToProcess: [PhotosPickerItem]
        let limitReached: Bool

        if storeManager.isPro {
            itemsToProcess = items
            limitReached = false
        } else if remaining == 0 {
            showUpgradePrompt = true
            videoPickerItems = []
            return
        } else {
            itemsToProcess = Array(items.prefix(remaining))
            limitReached = items.count > remaining
        }

        isConverting = true
        let total = itemsToProcess.count

        Task {
            for (index, item) in itemsToProcess.enumerated() {
                conversionProgress = total > 1
                    ? "Converting \(index + 1) of \(total)..."
                    : "Extracting audio..."

                do {
                    guard let videoData = try await item.loadTransferable(type: Data.self) else {
                        continue
                    }

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    try videoData.write(to: tempURL)

                    let displayName = item.itemIdentifier?.prefix(12).description ?? "Video"
                    let sanitized = displayName.replacingOccurrences(of: "[^a-zA-Z0-9_\\- ]", with: "_", options: .regularExpression)
                    let outputFileName = "\(sanitized)_\(UUID().uuidString.prefix(6)).m4a"

                    let outputURL = try await AudioEngine.convertVideoToM4A(
                        inputURL: tempURL,
                        outputFileName: outputFileName
                    )

                    try? FileManager.default.removeItem(at: tempURL)

                    let sound = SoundItem(name: "Video Import \(total > 1 ? "\(index + 1)" : "")", fileName: outputURL.lastPathComponent)
                    modelContext.insert(sound)
                } catch {
                    errorMessage = "Conversion failed for video \(index + 1): \(error.localizedDescription)"
                    showError = true
                }
            }

            isConverting = false
            videoPickerItems = []

            // Show upgrade prompt if we hit the limit during import
            if limitReached {
                showUpgradePrompt = true
            }
        }
    }

    private func handleAudioImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard checkDiskSpace() else { return }

            // Check how many sounds can be added
            let remaining = storeManager.remainingSounds(currentCount: sounds.count)
            let urlsToProcess: [URL]
            let limitReached: Bool

            if storeManager.isPro {
                urlsToProcess = urls
                limitReached = false
            } else if remaining == 0 {
                showUpgradePrompt = true
                return
            } else {
                urlsToProcess = Array(urls.prefix(remaining))
                limitReached = urls.count > remaining
            }

            for url in urlsToProcess {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let fileName = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension.lowercased()
                let sanitized = fileName.replacingOccurrences(of: "[^a-zA-Z0-9_\\- ]", with: "_", options: .regularExpression)
                let outputFileName = "\(sanitized)_\(UUID().uuidString.prefix(6)).\(ext)"

                do {
                    let outputURL = try AudioEngine.copyAudioFile(inputURL: url, outputFileName: outputFileName)
                    let sound = SoundItem(name: fileName, fileName: outputURL.lastPathComponent)
                    modelContext.insert(sound)
                } catch {
                    errorMessage = "Import failed for \"\(fileName)\": \(error.localizedDescription)"
                    showError = true
                }
            }

            // Show upgrade prompt if we hit the limit during import
            if limitReached {
                showUpgradePrompt = true
            }

        case .failure(let error):
            if !error.localizedDescription.contains("cancel") {
                errorMessage = "Import failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SoundItem.self, inMemory: true)
}
