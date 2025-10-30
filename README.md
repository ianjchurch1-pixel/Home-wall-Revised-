# Home-Wall//
//  WallScannerView.swift
//  Home Wall
//
//  ARKit-based wall scanning functionality
//

import SwiftUI
import ARKit
import RealityKit
import Combine

struct WallScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var scannerViewModel = WallScannerViewModel()
    
    let onImageCaptured: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(viewModel: scannerViewModel)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Capture count indicator
                    Text("Photos: \(scannerViewModel.capturedImages.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding()
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    if scannerViewModel.isTracking {
                        Text(scannerViewModel.capturedImages.isEmpty ? "Move slowly to scan the wall" : "Continue scanning or tap Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Move device to start tracking")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                    
                    // Tracking quality indicator
                    if scannerViewModel.isTracking {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(scannerViewModel.trackingQualityColor)
                                .frame(width: 12, height: 12)
                            Text(scannerViewModel.trackingQualityText)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                }
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 40) {
                    // Manual capture button
                    Button {
                        scannerViewModel.captureImage()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(!scannerViewModel.isTracking)
                    .opacity(scannerViewModel.isTracking ? 1.0 : 0.5)
                    
                    // Done button (if images captured)
                    if !scannerViewModel.capturedImages.isEmpty {
                        Button {
                            if let compositeImage = scannerViewModel.createCompositeImage() {
                                onImageCaptured(compositeImage)
                                dismiss()
                            }
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(Color.white)
                                .cornerRadius(25)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            scannerViewModel.startSession()
        }
        .onDisappear {
            scannerViewModel.stopSession()
        }
    }
}

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: WallScannerViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        viewModel.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - View Model
class WallScannerViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var capturedImages: [UIImage] = []
    @Published var isTracking = false
    @Published var trackingQuality: ARCamera.TrackingState.Reason?
    
    var arView: ARView?
    private var lastCaptureTime: Date?
    private let autoCaptureInterval: TimeInterval = 2.0 // Auto-capture every 2 seconds
    
    var trackingQualityColor: Color {
        guard isTracking else { return .red }
        if let reason = trackingQuality {
            switch reason {
            case .excessiveMotion, .insufficientFeatures:
                return .yellow
            default:
                return .green
            }
        }
        return .green
    }
    
    var trackingQualityText: String {
        guard isTracking else { return "Not tracking" }
        if let reason = trackingQuality {
            switch reason {
            case .excessiveMotion:
                return "Move slower"
            case .insufficientFeatures:
                return "Point at wall"
            default:
                return "Good tracking"
            }
        }
        return "Good tracking"
    }
    
    func startSession() {
        guard let arView = arView else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        // Remove sceneDepth - only works on LiDAR devices
        
        arView.session.delegate = self
        arView.session.run(configuration)
    }
    
    func stopSession() {
        arView?.session.pause()
    }
    
    func captureImage() {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame else { return }
        
        // Convert pixel buffer to UIImage with correct orientation
        let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Fix orientation - AR images are always landscape, rotate to portrait
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        capturedImages.append(image)
        lastCaptureTime = Date()
    }
    
    func createCompositeImage() -> UIImage? {
        guard !capturedImages.isEmpty else { return nil }
        
        // For now, return the middle image (best quality usually)
        // In production, you'd stitch images together
        let middleIndex = capturedImages.count / 2
        return capturedImages[middleIndex]
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            switch frame.camera.trackingState {
            case .normal:
                self.isTracking = true
                self.trackingQuality = nil
                
                // Auto-capture if enough time has passed
                if let lastCapture = self.lastCaptureTime,
                   Date().timeIntervalSince(lastCapture) >= self.autoCaptureInterval {
                    self.captureImage()
                } else if self.lastCaptureTime == nil {
                    // First capture
                    self.captureImage()
                }
                
            case .limited(let reason):
                self.isTracking = true
                self.trackingQuality = reason
                
            case .notAvailable:
                self.isTracking = false
                self.trackingQuality = nil
            }
        }
    }
}

#Preview {
    WallScannerView { image in
        print("Captured image: \(image.size)")
    }
}

import SwiftUI
import AVKit

struct BetaVideosView: View {
    let wall: ClimbingWall
    let climb: Climb
    let onUpdate: (Climb) -> Void
    
    @State private var updatedClimb: Climb
    @State private var showVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var showVideoNameAlert = false
    @State private var newVideoUploaderName = ""
    @State private var newVideoNotes = ""
    @State private var videoToDelete: BetaVideo?
    @State private var showDeleteConfirmation = false
    @State private var selectedVideo: BetaVideo?
    @State private var showVideoPlayer = false
    @Environment(\.dismiss) var dismiss
    
    init(wall: ClimbingWall, climb: Climb, onUpdate: @escaping (Climb) -> Void) {
        self.wall = wall
        self.climb = climb
        self.onUpdate = onUpdate
        _updatedClimb = State(initialValue: climb)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.8))
            
            Text("No Beta Videos Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add your first beta video to help climbers")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showVideoPicker = true
            } label: {
                Label("Add Beta Video", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.white, Color.gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.top)
        }
    }
    
    private var videoListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(updatedClimb.betaVideos.sorted(by: { $0.uploadDate > $1.uploadDate })) { video in
                    BetaVideoRowView(
                        video: video,
                        onPlay: {
                            print("Playing video: \(video.videoURL.path)")
                            print("Video file exists: \(FileManager.default.fileExists(atPath: video.videoURL.path))")
                            print("About to set selectedVideo and showVideoPlayer")
                            selectedVideo = video
                            print("selectedVideo set to: \(selectedVideo?.videoURL.lastPathComponent ?? "nil")")
                            showVideoPlayer = true
                            print("showVideoPlayer set to: \(showVideoPlayer)")
                        },
                        onDelete: {
                            videoToDelete = video
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var videoPlayerView: some View {
        if let video = selectedVideo {
            let _ = print("fullScreenCover triggered, showVideoPlayer: \(showVideoPlayer)")
            let _ = print("Creating VideoPlayerView with URL: \(video.videoURL.path)")
            VideoPlayerView(videoURL: video.videoURL)
        } else {
            let _ = print("ERROR: selectedVideo is nil in fullScreenCover!")
            Color.black.ignoresSafeArea()
        }
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            if updatedClimb.betaVideos.isEmpty {
                emptyStateView
            } else {
                videoListView
            }
        }
        .navigationTitle("Beta Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showVideoPicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(videoURL: $selectedVideoURL, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            videoPlayerView
        }
        .alert("Add Beta Video", isPresented: $showVideoNameAlert) {
            TextField("Your name", text: $newVideoUploaderName)
            TextField("Notes (optional)", text: $newVideoNotes)
            Button("Cancel", role: .cancel) {
                selectedVideoURL = nil
                newVideoUploaderName = ""
                newVideoNotes = ""
            }
            Button("Add") {
                addVideo()
            }
        } message: {
            Text("Who's uploading this beta video?")
        }
        .alert("Delete Video", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    deleteVideo(video)
                }
            }
        } message: {
            Text("Are you sure you want to delete this beta video? This action cannot be undone.")
        }
        .onChange(of: showVideoPlayer) { newValue in
            print("showVideoPlayer changed to: \(newValue)")
            if newValue {
                print("Video player should now show")
                print("selectedVideo is: \(selectedVideo?.videoURL.lastPathComponent ?? "nil")")
            }
        }
        .onAppear {
            print("BetaVideosView appeared")
            print("Climb has \(updatedClimb.betaVideos.count) beta videos")
            for (index, video) in updatedClimb.betaVideos.enumerated() {
                let exists = FileManager.default.fileExists(atPath: video.videoURL.path)
                print("Video \(index): \(video.videoURL.lastPathComponent) - exists: \(exists)")
            }
        }
        .onChange(of: selectedVideoURL) { newValue in
            if newValue != nil {
                showVideoNameAlert = true
            }
        }
    }
    
    private func addVideo() {
        guard let videoURL = selectedVideoURL else { return }
        
        print("addVideo called with URL: \(videoURL.path)")
        print("File exists at addVideo time: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        let uploaderName = newVideoUploaderName.isEmpty ? "Anonymous" : newVideoUploaderName
        let notes = newVideoNotes.isEmpty ? nil : newVideoNotes
        
        let newVideo = BetaVideo(
            videoURL: videoURL,
            uploaderName: uploaderName,
            notes: notes
        )
        
        print("Created BetaVideo with URL: \(newVideo.videoURL.path)")
        print("File exists after BetaVideo creation: \(FileManager.default.fileExists(atPath: newVideo.videoURL.path))")
        
        updatedClimb.betaVideos.append(newVideo)
        print("Appended to betaVideos array, count now: \(updatedClimb.betaVideos.count)")
        
        onUpdate(updatedClimb)
        print("Called onUpdate")
        
        // Check one more time after update
        print("File still exists after onUpdate: \(FileManager.default.fileExists(atPath: newVideo.videoURL.path))")
        
        // Reset
        selectedVideoURL = nil
        newVideoUploaderName = ""
        newVideoNotes = ""
    }
    
    private func deleteVideo(_ video: BetaVideo) {
        updatedClimb.betaVideos.removeAll { $0.id == video.id }
        
        // Also delete the video file from storage
        try? FileManager.default.removeItem(at: video.videoURL)
        
        onUpdate(updatedClimb)
        videoToDelete = nil
    }
}

// Row view for each beta video
struct BetaVideoRowView: View {
    let video: BetaVideo
    let onPlay: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Video thumbnail
            VideoThumbnailView(videoURL: video.videoURL)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        
                        // Play icon overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }
                )
                .onTapGesture {
                    onPlay()
                }
            
            // Video info
            VStack(alignment: .leading, spacing: 6) {
                Text(video.uploaderName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let notes = video.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Text(video.uploadDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Video thumbnail view that generates thumbnail from video file
struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                // Loading state
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        Task {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 200, height: 200) // Generate at 2x for retina
            
            do {
                // Generate thumbnail at 6 seconds into video
                let time = CMTime(seconds: 6, preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.thumbnail = uiImage
                    self.isLoading = false
                }
            } catch {
                print("Error generating thumbnail: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BetaVideosView(
            wall: ClimbingWall(name: "Sample Wall", image: UIImage(systemName: "photo")!),
            climb: Climb(name: "Test Climb", betaVideos: []),
            onUpdate: { _ in }
        )
    }
}

import SwiftUI
import AVKit
import Combine

struct ClimbDetailView: View {
    let wall: ClimbingWall
    let climb: Climb
    let onUpdate: (Climb) -> Void
    let onDelete: () -> Void
    
    @State private var currentClimb: Climb
    @State private var showTickSheet = false
    @State private var selectedGrade = "V0"
    @State private var selectedRating: Int = 3
    @State private var holdSize: CGFloat = 40
    @State private var dragStartLocation: CGPoint?
    @State private var draggedHoldIndex: Int?
    @State private var dragStartPosition: CGPoint?
    @State private var recentlyAddedHoldIndex: Int?
    @State private var recentHoldImageSize: CGSize?
    @State private var recentHoldContainerSize: CGSize?
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageScale: CGFloat = 1.0
    @State private var lastImageOffset: CGSize = .zero
    @State private var showEstablishNameAlert = false
    @State private var establishName = ""
    @Environment(\.dismiss) var dismiss
    
    init(wall: ClimbingWall, climb: Climb, onUpdate: @escaping (Climb) -> Void, onDelete: @escaping () -> Void) {
        self.wall = wall
        self.climb = climb
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._currentClimb = State(initialValue: climb)
    }
    
    var body: some View {
        ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 8) {
                        // Climb info at top
                        VStack(spacing: 8) {
                            // Open Project badge
                            if currentClimb.isEstablished && !currentClimb.isTicked {
                                Text("Open Project")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.2))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.orange, lineWidth: 1)
                                    )
                            }
                            
                            // Tick button (only shown when climb is established)
                            if currentClimb.isEstablished {
                                Button {
                                        if let grade = currentClimb.difficulty {
                                            selectedGrade = grade
                                        }
                                        if let rating = currentClimb.rating {
                                            selectedRating = rating
                                        }
                                        showTickSheet = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(currentClimb.isTicked ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                                                    .frame(width: 50, height: 50)
                                                
                                                if currentClimb.isTicked {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 32))
                                                        .foregroundColor(.green)
                                                } else {
                                                    Image(systemName: "checkmark.circle")
                                                        .font(.system(size: 32))
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }
                                            
                                            if let grade = currentClimb.difficulty {
                                                Text(grade)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                
                                                // Show send count if more than one
                                                if currentClimb.sendCount > 1 {
                                                    Text("\(currentClimb.sendCount)x")
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                }
                                            } else {
                                                Text("Tick")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Wall image with interactive hold marking
                        if let image = wall.image {
                            GeometryReader { geometry in
                                ZStack(alignment: .center) {
                                    // Image and holds together (so they scale together)
                                    ZStack {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                        
                                        // Display holds for this climb
                                        ForEach(currentClimb.holds.indices, id: \.self) { index in
                                            Circle()
                                                .stroke(colorForHold(currentClimb.holds[index].color), lineWidth: 3)
                                                .frame(
                                                    width: currentClimb.holds[index].size(containerSize: geometry.size),
                                                    height: currentClimb.holds[index].size(containerSize: geometry.size)
                                                )
                                                .position(currentClimb.holds[index].position(imageSize: image.size, containerSize: geometry.size))
                                        }
                                    }
                                    .scaleEffect(imageScale)
                                    .offset(imageOffset)
                                    
                                    // Interactive overlay for hold marking (only when not established)
                                    if !currentClimb.isEstablished {
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        if dragStartLocation == nil {
                                                            dragStartLocation = value.startLocation
                                                            
                                                            // Transform screen coords to image coords accounting for scale and offset around center
                                                            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                                            let adjustedLocation = CGPoint(
                                                                x: center.x + (value.startLocation.x - center.x - imageOffset.width) / imageScale,
                                                                y: center.y + (value.startLocation.y - center.y - imageOffset.height) / imageScale
                                                            )
                                                            
                                                            // Check if tapping an existing hold
                                                            for (index, hold) in currentClimb.holds.enumerated() {
                                                                let holdPos = hold.position(imageSize: image.size, containerSize: geometry.size)
                                                                let holdSz = hold.size(containerSize: geometry.size)
                                                                let tapRadius = holdSz / 2 + 10
                                                                let distance = sqrt(pow(holdPos.x - adjustedLocation.x, 2) + pow(holdPos.y - adjustedLocation.y, 2))
                                                                if distance < tapRadius {
                                                                    draggedHoldIndex = index
                                                                    dragStartPosition = holdPos
                                                                    // Clear recently added if dragging a different hold
                                                                    if recentlyAddedHoldIndex != index {
                                                                        recentlyAddedHoldIndex = nil
                                                                    }
                                                                    break
                                                                }
                                                            }
                                                        }
                                                        
                                                        // If dragging a hold, update its position
                                                        if let holdIndex = draggedHoldIndex, let startPos = dragStartPosition {
                                                            // Calculate new position accounting for zoom
                                                            let newPosition = CGPoint(
                                                                x: startPos.x + (value.translation.width / imageScale),
                                                                y: startPos.y + (value.translation.height / imageScale)
                                                            )
                                                            
                                                            // Create new hold with updated position
                                                            let oldHold = currentClimb.holds[holdIndex]
                                                            let newHold = SavedHold(
                                                                position: newPosition,
                                                                color: oldHold.holdColor,
                                                                size: oldHold.size(containerSize: geometry.size),
                                                                imageSize: image.size,
                                                                containerSize: geometry.size
                                                            )
                                                            currentClimb.holds[holdIndex] = newHold
                                                        }
                                                    }
                                                    .onEnded { value in
                                                        let dragDistance = sqrt(
                                                            pow(value.location.x - value.startLocation.x, 2) +
                                                            pow(value.location.y - value.startLocation.y, 2)
                                                        )
                                                        
                                                        // If minimal movement, treat as tap
                                                        if dragDistance < 10 {
                                                            // Transform screen coords to image coords
                                                            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                                            let adjustedLocation = CGPoint(
                                                                x: center.x + (value.location.x - center.x - imageOffset.width) / imageScale,
                                                                y: center.y + (value.location.y - center.y - imageOffset.height) / imageScale
                                                            )
                                                            handleTap(at: adjustedLocation, imageSize: image.size, containerSize: geometry.size)
                                                        }
                                                        
                                                        // Reset
                                                        dragStartLocation = nil
                                                        draggedHoldIndex = nil
                                                        dragStartPosition = nil
                                                    }
                                            )
                                    }
                                }
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            imageScale = lastImageScale * value
                                        }
                                        .onEnded { value in
                                            lastImageScale = imageScale
                                            // Limit scale
                                            if imageScale < 1.0 {
                                                withAnimation {
                                                    imageScale = 1.0
                                                    lastImageScale = 1.0
                                                }
                                            } else if imageScale > 5.0 {
                                                imageScale = 5.0
                                                lastImageScale = 5.0
                                            }
                                        }
                                )
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            // Only pan if zoomed in AND not dragging a hold
                                            if imageScale > 1.0 && draggedHoldIndex == nil && !currentClimb.isEstablished {
                                                imageOffset = CGSize(
                                                    width: lastImageOffset.width + value.translation.width,
                                                    height: lastImageOffset.height + value.translation.height
                                                )
                                            } else if imageScale > 1.0 && currentClimb.isEstablished {
                                                // Always allow pan when established (can't mark holds)
                                                imageOffset = CGSize(
                                                    width: lastImageOffset.width + value.translation.width,
                                                    height: lastImageOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { value in
                                            lastImageOffset = imageOffset
                                        }
                                )
                            }
                            .aspectRatio(image.size, contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipped()
                        }
                        
                        // Beta Videos button (below image, left-aligned)
                        HStack {
                            NavigationLink(destination: BetaVideosView(
                                wall: wall,
                                climb: currentClimb,
                                onUpdate: { updatedClimb in
                                    currentClimb = updatedClimb
                                    onUpdate(updatedClimb)
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(systemName: currentClimb.betaVideos.isEmpty ? "video.badge.plus" : "play.circle.fill")
                                        .font(.system(size: currentClimb.betaVideos.isEmpty ? 22 : 24))
                                        .foregroundColor(currentClimb.betaVideos.isEmpty ? .white.opacity(0.9) : .blue)
                                    
                                    Text("Beta Videos")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    if !currentClimb.betaVideos.isEmpty {
                                        Text("(\(currentClimb.betaVideos.count))")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            currentClimb.betaVideos.isEmpty
                                            ? Color.black.opacity(0.6)
                                            : Color.blue.opacity(0.3)
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            currentClimb.betaVideos.isEmpty
                                            ? Color.white.opacity(0.3)
                                            : Color.blue.opacity(0.6),
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Hold size slider (only when not established)
                        if !currentClimb.isEstablished {
                            VStack(spacing: 12) {
                                // Reset zoom button
                                if imageScale != 1.0 || imageOffset != .zero {
                                    Button {
                                        withAnimation(.spring()) {
                                            imageScale = 1.0
                                            imageOffset = .zero
                                            lastImageScale = 1.0
                                            lastImageOffset = .zero
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            Text("Reset Zoom")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.cyan.opacity(0.2))
                                        )
                                    }
                                }
                                
                                VStack(spacing: 8) {
                                Text("Hold Size")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Slider(value: $holdSize, in: 15...120, step: 5)
                                        .tint(.white)
                                        .onChange(of: holdSize) { newSize in
                                            // Update the size of the most recently added hold
                                            if let index = recentlyAddedHoldIndex,
                                               index < currentClimb.holds.count,
                                               let imageSize = recentHoldImageSize,
                                               let containerSize = recentHoldContainerSize {
                                                
                                                let oldHold = currentClimb.holds[index]
                                                let position = oldHold.position(imageSize: imageSize, containerSize: containerSize)
                                                
                                                // Create new hold with updated size
                                                let updatedHold = SavedHold(
                                                    position: position,
                                                    color: oldHold.holdColor,
                                                    size: newSize,
                                                    imageSize: imageSize,
                                                    containerSize: containerSize
                                                )
                                                currentClimb.holds[index] = updatedHold
                                            }
                                        }
                                    
                                    Image(systemName: "circle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .padding(.horizontal)
                        }
                        
                        // Match toggle (always visible, locked when established)
                        VStack(spacing: 8) {
                            if currentClimb.isEstablished {
                                // Display only (locked)
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(currentClimb.matchAllowed ? Color.green : Color.red, lineWidth: 3)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "hands.clap.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(currentClimb.matchAllowed ? .green : .red)
                                        
                                        if !currentClimb.matchAllowed {
                                            Rectangle()
                                                .fill(Color.red)
                                                .frame(width: 60, height: 3)
                                                .rotationEffect(.degrees(-45))
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(currentClimb.matchAllowed ? "Match Allowed" : "No Matching")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Locked")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                            } else {
                                // Toggle button (editable)
                                Button {
                                    currentClimb.matchAllowed.toggle()
                                    onUpdate(currentClimb)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .stroke(currentClimb.matchAllowed ? Color.green : Color.red, lineWidth: 3)
                                                .frame(width: 50, height: 50)
                                            
                                            Image(systemName: "hands.clap.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(currentClimb.matchAllowed ? .green : .red)
                                            
                                            if !currentClimb.matchAllowed {
                                                Rectangle()
                                                    .fill(Color.red)
                                                    .frame(width: 60, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(currentClimb.matchAllowed ? "Match Allowed" : "No Matching")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text("Tap to change")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Action buttons
                        VStack(spacing: 8) {
                            // Save Draft and Establish buttons (only when not established and has holds)
                            if !currentClimb.isEstablished && !currentClimb.holds.isEmpty {
                                    HStack(spacing: 8) {
                                        Button {
                                            onUpdate(currentClimb)
                                            dismiss()
                                        } label: {
                                            Label("Save Draft", systemImage: "square.and.arrow.down")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [.blue, Color.blue.opacity(0.7)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .cornerRadius(12)
                                        }
                                        
                                        Button {
                                            establishName = currentClimb.name
                                            showEstablishNameAlert = true
                                        } label: {
                                            Label("Establish", systemImage: "lock.fill")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [.green, Color.green.opacity(0.7)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(currentClimb.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.square.fill")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showTickSheet) {
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            colors: [Color.black, Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            if currentClimb.isTicked {
                                VStack(spacing: 16) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.green)
                                    
                                    Text("Climb Sent! 🎉")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    // Send count
                                    if currentClimb.sendCount > 1 {
                                        Text("\(currentClimb.sendCount) sends")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text("Grade")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text(currentClimb.difficulty ?? "V0")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    // Star rating display
                                    if let rating = currentClimb.rating {
                                        VStack(spacing: 8) {
                                            Text("Quality")
                                                .font(.headline)
                                                .foregroundColor(.white.opacity(0.6))
                                            
                                            HStack(spacing: 8) {
                                                ForEach(1...4, id: \.self) { star in
                                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                                        .font(.title2)
                                                        .foregroundColor(star <= rating ? .yellow : .white.opacity(0.3))
                                                }
                                            }
                                        }
                                        .padding(.top, 16)
                                    }
                                    
                                    // Repeat send button
                                    Button {
                                        currentClimb.tickDates.append(Date())
                                        onUpdate(currentClimb)
                                        showTickSheet = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Repeat Send")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(Color.green)
                                        .cornerRadius(12)
                                    }
                                    .padding(.top, 20)
                                    
                                    Text("Tap 'Clear All' to reset sends")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.top, 8)
                                }
                                .padding(.top, 40)
                                
                            } else {
                                VStack(spacing: 20) {
                                    Text("Send this climb!")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.top, 20)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Grade")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Picker("Grade", selection: $selectedGrade) {
                                            ForEach(0...15, id: \.self) { grade in
                                                Text("V\(grade)").tag("V\(grade)")
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(height: 150)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                    }
                                    .padding(.horizontal)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Rate Quality")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 20) {
                                            ForEach(1...4, id: \.self) { star in
                                                Button {
                                                    selectedRating = star
                                                } label: {
                                                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                                        .font(.system(size: 32))
                                                        .foregroundColor(star <= selectedRating ? .yellow : .white.opacity(0.3))
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top)
                    }
                    .navigationTitle(currentClimb.isTicked ? "Climb Sent" : "Tick Climb")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showTickSheet = false
                            }
                            .foregroundColor(.white)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if currentClimb.isTicked {
                                Button {
                                    currentClimb.tickDates = []
                                    currentClimb.difficulty = nil
                                    currentClimb.rating = nil
                                    onUpdate(currentClimb)
                                    showTickSheet = false
                                } label: {
                                    Text("Clear All")
                                        .foregroundColor(.red)
                                }
                            } else {
                                Button("Tick") {
                                    currentClimb.tickDates.append(Date())
                                    currentClimb.difficulty = selectedGrade
                                    currentClimb.rating = selectedRating
                                    onUpdate(currentClimb)
                                    showTickSheet = false
                                }
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .alert("Name Your Climb", isPresented: $showEstablishNameAlert) {
            TextField("Climb name", text: $establishName)
            Button("Cancel", role: .cancel) {
                establishName = ""
            }
            Button("Establish") {
                currentClimb.name = establishName.isEmpty ? currentClimb.name : establishName
                currentClimb.isEstablished = true
                onUpdate(currentClimb)
                dismiss()
            }
        } message: {
            Text("Give this climb a name before establishing it")
        }
    }
    
    private func handleTap(at location: CGPoint, imageSize: CGSize, containerSize: CGSize) {
        // Check if tap is near an existing hold
        for (index, hold) in currentClimb.holds.enumerated() {
            let holdPos = hold.position(imageSize: imageSize, containerSize: containerSize)
            let holdSz = hold.size(containerSize: containerSize)
            let tapRadius = holdSz / 2 + 10
            let distance = sqrt(pow(holdPos.x - location.x, 2) + pow(holdPos.y - location.y, 2))
            if distance < tapRadius {
                changeHoldColor(at: index, imageSize: imageSize, containerSize: containerSize)
                return
            }
        }
        
        // If not near existing hold, create new one
        addHold(at: location, imageSize: imageSize, containerSize: containerSize)
    }
    
    private func addHold(at location: CGPoint, imageSize: CGSize, containerSize: CGSize) {
        let newHold = SavedHold(
            position: location,
            color: .red,
            size: holdSize,
            imageSize: imageSize,
            containerSize: containerSize
        )
        currentClimb.holds.append(newHold)
        recentlyAddedHoldIndex = currentClimb.holds.count - 1
        recentHoldImageSize = imageSize
        recentHoldContainerSize = containerSize
    }
    
    private func changeHoldColor(at index: Int, imageSize: CGSize, containerSize: CGSize) {
        // Clear selection when changing colors
        recentlyAddedHoldIndex = nil
        recentHoldImageSize = nil
        recentHoldContainerSize = nil
        
        let oldHold = currentClimb.holds[index]
        let position = oldHold.position(imageSize: imageSize, containerSize: containerSize)
        let size = oldHold.size(containerSize: containerSize)
        
        // Cycle through colors: red -> green -> blue -> purple -> delete
        switch oldHold.holdColor {
        case .red:
            currentClimb.holds[index] = SavedHold(position: position, color: .green, size: size, imageSize: imageSize, containerSize: containerSize)
        case .green:
            currentClimb.holds[index] = SavedHold(position: position, color: .blue, size: size, imageSize: imageSize, containerSize: containerSize)
        case .blue:
            currentClimb.holds[index] = SavedHold(position: position, color: .purple, size: size, imageSize: imageSize, containerSize: containerSize)
        case .purple:
            // Fifth tap - delete the hold
            currentClimb.holds.remove(at: index)
        }
    }
    
    private func colorForHold(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .red
        }
    }
}

// Video Player View with Controls
struct VideoPlayerView: View {
    let videoURL: URL
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerViewModel: VideoPlayerViewModel
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        self._playerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(url: videoURL))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video content
                VideoPlayerLayerView(player: playerViewModel.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50) // Bring video down from top
                    .ignoresSafeArea(edges: .top)
                
                // Controls at bottom
                VStack(spacing: 12) {
                    // Timeline scrubber
                    HStack(spacing: 12) {
                        Text(playerViewModel.currentTimeString)
                            .font(.caption)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(width: 45, alignment: .leading)
                        
                        Slider(
                            value: Binding(
                                get: { playerViewModel.currentTime },
                                set: { newValue in
                                    playerViewModel.currentTime = newValue
                                    if playerViewModel.isScrubbing {
                                        playerViewModel.updatePlaybackTime(newValue)
                                    }
                                }
                            ),
                            in: 0...max(playerViewModel.duration, 1),
                            onEditingChanged: { editing in
                                playerViewModel.isScrubbing = editing
                                if !editing {
                                    playerViewModel.updatePlaybackTime(playerViewModel.currentTime)
                                }
                            }
                        )
                        .tint(.white)
                        
                        Text(playerViewModel.durationString)
                            .font(.caption)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    
                    // Play/Pause button
                    Button {
                        playerViewModel.togglePlayPause()
                    } label: {
                        Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            print("VideoPlayerView appeared for: \(videoURL.path)")
            // Auto-play when video opens
            playerViewModel.togglePlayPause()
        }
        .onDisappear {
            playerViewModel.cleanup()
        }
    }
}

// UIViewRepresentable for AVPlayerLayer
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        
        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        
        // CRITICAL: Set initial frame to ensure layer renders
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// ViewModel for Video Player
class VideoPlayerViewModel: ObservableObject {
    let player: AVPlayer
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isScrubbing = false
    
    private var timeObserver: Any?
    private var playerItemObserver: NSKeyValueObservation?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    init(url: URL) {
        print("VideoPlayerViewModel init with URL: \(url.path)")
        print("Video file exists: \(FileManager.default.fileExists(atPath: url.path))")
        self.player = AVPlayer(url: url)
        setupObservers()
        
        // Add status observer for player item
        if let item = player.currentItem {
            print("Player item status: \(item.status.rawValue)")
        } else {
            print("WARNING: No player item created")
        }
    }
    
    private func setupObservers() {
        // Observe time updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isScrubbing else { return }
            self.currentTime = time.seconds
        }
        
        // Get duration when ready with fallback methods
        Task { [weak self] in
            guard let self = self else { return }
            if let asset = self.player.currentItem?.asset {
                do {
                    // Try modern async API first
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.duration = duration.seconds
                    }
                } catch {
                    print("Failed to load duration with async API: \(error)")
                    
                    // Fallback: Try getting duration from player item directly
                    await MainActor.run {
                        if let playerItem = self.player.currentItem {
                            let itemDuration = playerItem.duration
                            if itemDuration.isValid && !itemDuration.isIndefinite {
                                self.duration = itemDuration.seconds
                                print("Got duration from player item: \(self.duration)")
                            } else {
                                // Final fallback: observe duration changes
                                self.observeDurationChanges()
                            }
                        }
                    }
                }
            }
        }
        
        // Observe play state
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.player.seek(to: .zero)
        }
        
        // Add error observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("Playback error: \(error)")
            }
        }
    }
    
    private func observeDurationChanges() {
        guard let playerItem = player.currentItem else { return }
        
        // Observe status changes to get duration when ready
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            
            if item.status == .readyToPlay {
                let itemDuration = item.duration
                if itemDuration.isValid && !itemDuration.isIndefinite {
                    DispatchQueue.main.async {
                        self.duration = itemDuration.seconds
                        print("Got duration from status observer: \(self.duration)")
                    }
                }
            } else if item.status == .failed {
                print("Player item failed: \(String(describing: item.error))")
            }
        }
    }
    
    func togglePlayPause() {
        print("togglePlayPause called. Current isPlaying: \(isPlaying)")
        print("Player rate before: \(player.rate)")
        print("Player currentItem status: \(player.currentItem?.status.rawValue ?? -1)")
        
        if isPlaying {
            player.pause()
            print("Called pause()")
        } else {
            player.play()
            print("Called play()")
        }
        isPlaying.toggle()
        
        print("Player rate after: \(player.rate)")
        print("New isPlaying: \(isPlaying)")
    }
    
    func updatePlaybackTime(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func cleanup() {
        player.pause()
        
        // Remove time observer safely
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Cancel any KVO observations
        playerItemObserver?.invalidate()
        playerItemObserver = nil
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    deinit {
        cleanup()
    }
}

#Preview {
    ClimbDetailView(
        wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!),
        climb: Climb(name: "Easy Route", holds: []),
        onUpdate: { _ in },
        onDelete: { }
    )
}

import SwiftUI

// Extension to get color based on climb grade
extension Color {
    static func gradeColor(for grade: String) -> Color {
        // Extract numeric value from grade string (e.g., "V0" -> 0, "V10" -> 10)
        let numericString = grade.filter { $0.isNumber }
        guard let gradeNumber = Int(numericString) else {
            return .gray // Default color if grade can't be parsed
        }
        
        // Map V0-V15 to a color gradient from green to red
        let normalizedGrade = min(max(Double(gradeNumber), 0), 15) / 15.0
        
        // Create smooth color transition: green -> yellow -> orange -> red
        if normalizedGrade < 0.33 {
            // Green to Yellow (V0-V5)
            let ratio = normalizedGrade / 0.33
            return Color(
                red: ratio,
                green: 1.0,
                blue: 0
            )
        } else if normalizedGrade < 0.66 {
            // Yellow to Orange (V6-V10)
            let ratio = (normalizedGrade - 0.33) / 0.33
            return Color(
                red: 1.0,
                green: 1.0 - (ratio * 0.5), // Stay somewhat yellow
                blue: 0
            )
        } else {
            // Orange to Red (V11-V15)
            let ratio = (normalizedGrade - 0.66) / 0.34
            return Color(
                red: 1.0,
                green: 0.5 - (ratio * 0.5), // Fade out green component
                blue: 0
            )
        }
    }
}


//
//  ContentView.swift
//  Home Wall
//
//  Created by Ian Church on 10/28/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct DashboardView: View {
    @State private var walls: [ClimbingWall] = []
    @State private var isEditMode = false
    @State private var isWallsExpanded = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showNameAlert = false
    @State private var newWallName = ""
    @State private var showSourceSelection = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showARScanner = false
    
    private let saveKey = "SavedWalls"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if walls.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("No Walls Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Tap \"New Wall\" below to get started")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // New Wall button at bottom for empty state
                    VStack {
                        Spacer()
                        Button {
                            showSourceSelection = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("New Wall")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.6), .cyan.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .cornerRadius(16)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // New Wall Button (at top)
                            Button {
                                showSourceSelection = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("New Wall")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.cyan.opacity(0.6), .cyan.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .cornerRadius(16)
                                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // My Walls widget at top (full width, expandable)
                            MyWallsWidgetView(
                                walls: walls,
                                isEditMode: isEditMode,
                                isExpanded: $isWallsExpanded,
                                onUpdateWall: updateWall,
                                onDeleteWall: deleteWall
                            )
                            .onLongPressGesture(minimumDuration: 0.5) {
                                withAnimation {
                                    isEditMode.toggle()
                                }
                            }
                        }
                        .padding()
                        .overlay(
                            Group {
                                if isEditMode {
                                    VStack {
                                        Spacer()
                                        Button {
                                            withAnimation {
                                                isEditMode = false
                                            }
                                        } label: {
                                            Text("Done")
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 40)
                                                .padding(.vertical, 12)
                                                .background(Color.white)
                                                .cornerRadius(25)
                                                .shadow(radius: 10)
                                        }
                                        .padding(.bottom, 30)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Welcome to Home Wall")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 2, x: 0, y: 2)
                }
            }
            .toolbarBackground(.black.opacity(0.95), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imageSourceType)
            }
            .fullScreenCover(isPresented: $showARScanner) {
                WallScannerView { scannedImage in
                    selectedImage = scannedImage
                    showNameAlert = true
                }
            }
            .confirmationDialog("Add Wall Photo", isPresented: $showSourceSelection) {
                Button("Scan with AR") {
                    showARScanner = true
                }
                Button("Take Photo") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Name Your Wall", isPresented: $showNameAlert) {
                TextField("Wall name", text: $newWallName)
                Button("Cancel", role: .cancel) {
                    selectedImage = nil
                    newWallName = ""
                }
                Button("Create") {
                    createWall()
                }
            } message: {
                Text("Give this climbing wall a name")
            }
            .onChange(of: selectedImage) { newValue in
                if newValue != nil {
                    showNameAlert = true
                }
            }
            .onAppear {
                loadWalls()
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadWalls() {
        let url = getDocumentsDirectory().appendingPathComponent(saveKey)
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([ClimbingWall].self, from: data) {
                walls = decoded
            }
        }
    }
    
    private func saveWalls() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(walls) {
            let url = getDocumentsDirectory().appendingPathComponent(saveKey)
            try? encoded.write(to: url)
        }
    }
    
    private func createWall() {
        guard let image = selectedImage else { return }
        
        let wallName = newWallName.isEmpty ? "Wall \(walls.count + 1)" : newWallName
        let newWall = ClimbingWall(name: wallName, image: image, climbs: [])
        walls.append(newWall)
        saveWalls()
        
        // Reset
        selectedImage = nil
        newWallName = ""
    }
    
    private func deleteWall(at index: Int) {
        walls.remove(at: index)
        saveWalls()
    }
    
    private func updateWall(_ updatedWall: ClimbingWall) {
        if let index = walls.firstIndex(where: { $0.id == updatedWall.id }) {
            walls[index] = updatedWall
            saveWalls()
        }
    }
}

// My Walls Widget (expandable inline)
struct MyWallsWidgetView: View {
    let walls: [ClimbingWall]
    let isEditMode: Bool
    @Binding var isExpanded: Bool
    let onUpdateWall: (ClimbingWall) -> Void
    let onDeleteWall: (Int) -> Void
    
    @State private var swipedWallId: UUID?
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                if !isEditMode {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Walls")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(walls.count) wall\(walls.count == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if walls.count > 0 {
                            let totalClimbs = walls.reduce(0) { $0 + $1.climbs.count }
                            Text("\(totalClimbs) total climbs")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    if isEditMode {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white.opacity(0.3))
                            .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    }
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content (all walls)
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(Array(walls.enumerated()), id: \.element.id) { index, wall in
                        ZStack(alignment: .trailing) {
                            // Delete button (revealed on swipe)
                            Button {
                                withAnimation {
                                    onDeleteWall(index)
                                    swipedWallId = nil
                                }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 60)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            .opacity(swipedWallId == wall.id ? 1 : 0)
                            
                            // Wall content
                            NavigationLink {
                                WallDetailView(wall: wall, onUpdate: onUpdateWall)
                            } label: {
                                HStack(spacing: 12) {
                                    // Thumbnail
                                    if let image = wall.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    
                                    // Wall info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(wall.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        Text("\(wall.climbs.count) climbs")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(x: swipedWallId == wall.id ? -80 : 0)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 20)
                                    .onChanged { value in
                                        if value.translation.width < -20 {
                                            withAnimation(.spring(response: 0.3)) {
                                                swipedWallId = wall.id
                                            }
                                        } else if value.translation.width > 20 {
                                            withAnimation(.spring(response: 0.3)) {
                                                swipedWallId = nil
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.width > 20 {
                                            withAnimation(.spring(response: 0.3)) {
                                                swipedWallId = nil
                                            }
                                        }
                                    }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .scaleEffect(isEditMode ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isEditMode)
        .overlay(
            Group {
                if isEditMode {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .shadow(color: Color.cyan.opacity(0.5), radius: 8)
                }
            }
        )
    }
}

#Preview {
    DashboardView()
}


import SwiftUI

struct HoldMarkingView: View {
    let image: UIImage
    let existingHolds: [SavedHold]
    let onSave: ([SavedHold]) -> Void
    
    @State private var holds: [Hold] = []
    @State private var holdSize: CGFloat = 40
    @State private var activeHoldIndex: Int? = nil
    @State private var draggedHoldIndex: Int? = nil
    @State private var dragStartPosition: CGPoint? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main image area with holds
                GeometryReader { geometry in
                    ZStack {
                        // Display the climbing wall image with holds overlay
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                            
                            // Draw circles for each hold
                            ForEach(holds.indices, id: \.self) { index in
                                Circle()
                                    .stroke(holds[index].color.color, lineWidth: 3)
                                    .frame(width: holds[index].size, height: holds[index].size)
                                    .position(holds[index].position)
                            }
                        }
                        .scaleEffect(scale)
                        .offset(offset)
                        
                        // Tap capture overlay - OUTSIDE the transformed content
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // First time - check if we're on a circle
                                        if dragStartLocation == nil {
                                            dragStartLocation = value.startLocation
                                            
                                            // Transform tap to image coordinates
                                            let centerX = geometry.size.width / 2
                                            let centerY = geometry.size.height / 2
                                            let originalX = ((value.startLocation.x - centerX - offset.width) / scale) + centerX
                                            let originalY = ((value.startLocation.y - centerY - offset.height) / scale) + centerY
                                            let adjustedLocation = CGPoint(x: originalX, y: originalY)
                                            
                                            // Check if on a circle
                                            for (index, hold) in holds.enumerated() {
                                                let tapRadius = hold.size / 2 + 10
                                                let distance = sqrt(pow(hold.position.x - adjustedLocation.x, 2) + pow(hold.position.y - adjustedLocation.y, 2))
                                                if distance < tapRadius {
                                                    draggedHoldIndex = index
                                                    dragStartPosition = hold.position
                                                    break
                                                }
                                            }
                                        }
                                        
                                        // If dragging a hold, update its position
                                        if let holdIndex = draggedHoldIndex, let startPos = dragStartPosition {
                                            let adjustedTranslation = CGSize(
                                                width: value.translation.width / scale,
                                                height: value.translation.height / scale
                                            )
                                            holds[holdIndex].position = CGPoint(
                                                x: startPos.x + adjustedTranslation.width,
                                                y: startPos.y + adjustedTranslation.height
                                            )
                                        }
                                    }
                                    .onEnded { value in
                                        let dragDistance = sqrt(
                                            pow(value.location.x - value.startLocation.x, 2) +
                                            pow(value.location.y - value.startLocation.y, 2)
                                        )
                                        
                                        // If was dragging a hold and moved significantly, it's done
                                        if draggedHoldIndex != nil && dragDistance >= 10 {
                                            // Just finish the drag
                                        }
                                        // If minimal movement, treat as tap
                                        else if dragDistance < 10 {
                                            handleTap(at: value.location, in: geometry.size)
                                        }
                                        
                                        // Reset
                                        dragStartLocation = nil
                                        draggedHoldIndex = nil
                                        dragStartPosition = nil
                                    }
                            )
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale *= delta
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                // Limit zoom range
                                if scale < 1.0 {
                                    scale = 1.0
                                } else if scale > 4.0 {
                                    scale = 4.0
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                // Don't pan if we're dragging a hold
                                if draggedHoldIndex == nil {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                if draggedHoldIndex == nil {
                                    lastOffset = offset
                                }
                            }
                    )
                }
                .frame(height: 500)
                
                // Size slider at the bottom
                VStack(spacing: 8) {
                    Text("Hold Size")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack {
                        Image(systemName: "circle")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Slider(value: $holdSize, in: 20...80, step: 5)
                            .tint(.white)
                            .onChange(of: holdSize) { newValue in
                                if let activeIndex = activeHoldIndex, activeIndex < holds.count {
                                    holds[activeIndex].size = newValue
                                }
                            }
                        
                        Image(systemName: "circle")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.8), Color.gray.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationTitle("Mark Holds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                loadExistingHolds()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Reset zoom button
                        if scale != 1.0 || offset != .zero {
                            Button {
                                withAnimation {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button("Done") {
                            saveHolds()
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        // When zoomed, we need to transform the tap location back to the original coordinate space
        // The transformation order is: original -> scale -> offset
        // So to reverse: tap -> remove offset -> divide by scale
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Convert tap location back to original coordinates
        let originalX = ((location.x - centerX - offset.width) / scale) + centerX
        let originalY = ((location.y - centerY - offset.height) / scale) + centerY
        
        let adjustedLocation = CGPoint(x: originalX, y: originalY)
        
        // Check if tap is near an existing hold
        for (index, hold) in holds.enumerated() {
            let tapRadius = hold.size / 2 + 10
            let distance = sqrt(pow(hold.position.x - adjustedLocation.x, 2) + pow(hold.position.y - adjustedLocation.y, 2))
            if distance < tapRadius {
                changeHoldColor(at: index)
                return
            }
        }
        
        // If not near existing hold, create new one
        addHold(at: adjustedLocation, in: size)
    }
    
    private func getActualImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image is wider - fits to width
            let displayHeight = containerSize.width / imageAspect
            return CGSize(width: containerSize.width, height: displayHeight)
        } else {
            // Image is taller - fits to height
            let displayWidth = containerSize.height * imageAspect
            return CGSize(width: displayWidth, height: containerSize.height)
        }
    }
    
    private func getImageOffset(in containerSize: CGSize) -> CGPoint {
        let actualSize = getActualImageSize(in: containerSize)
        return CGPoint(
            x: (containerSize.width - actualSize.width) / 2,
            y: (containerSize.height - actualSize.height) / 2
        )
    }
    
    private func addHold(at location: CGPoint, in size: CGSize) {
        let newHold = Hold(position: location, color: .red, size: holdSize)
        holds.append(newHold)
        activeHoldIndex = holds.count - 1
    }
    
    private func changeHoldColor(at index: Int) {
        // Cycle through colors: red -> green -> blue -> purple -> delete
        switch holds[index].color {
        case .red:
            holds[index].color = .green
            activeHoldIndex = index
            holdSize = holds[index].size
        case .green:
            holds[index].color = .blue
            activeHoldIndex = index
            holdSize = holds[index].size
        case .blue:
            holds[index].color = .purple
            activeHoldIndex = index
            holdSize = holds[index].size
        case .purple:
            // Fifth tap - delete the hold
            holds.remove(at: index)
            if activeHoldIndex == index {
                activeHoldIndex = nil
            } else if let activeIndex = activeHoldIndex, activeIndex > index {
                // Adjust active index if it was after the deleted hold
                activeHoldIndex = activeIndex - 1
            }
        }
    }
    
    private func loadExistingHolds() {
        // Container size is 500pt height, calculate width based on aspect
        let containerSize = CGSize(width: UIScreen.main.bounds.width, height: 500)
        holds = existingHolds.map { savedHold in
            Hold(position: savedHold.position(imageSize: image.size, containerSize: containerSize),
                 color: savedHold.holdColor,
                 size: savedHold.size(containerSize: containerSize))
        }
    }
    
    private func saveHolds() {
        let containerSize = CGSize(width: UIScreen.main.bounds.width, height: 500)
        let savedHolds = holds.map { hold in
            SavedHold(position: hold.position, color: hold.color, size: hold.size, imageSize: image.size, containerSize: containerSize)
        }
        onSave(savedHolds)
    }
}

// Model for a climbing hold
struct Hold: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: HoldColor
    var size: CGFloat
}

// Available colors for holds
enum HoldColor {
    case red, green, blue, purple
    
    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
    
    mutating func next() {
        switch self {
        case .red: self = .green
        case .green: self = .blue
        case .blue: self = .purple
        case .purple: self = .red // Cycle back to red, delete handled separately
        }
    }
}

#Preview {
    HoldMarkingView(image: UIImage(systemName: "photo")!, existingHolds: [], onSave: { _ in })
}

import SwiftUI

@main
struct Home_wallApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

import SwiftUI

struct HomeView: View {
    @State private var walls: [ClimbingWall] = []
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showNameAlert = false
    @State private var newWallName = ""
    @State private var showSourceSelection = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showARScanner = false
    
    private let saveKey = "SavedWalls"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                
                if walls.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("No Walls Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Add your first climbing wall to get started")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            showSourceSelection = true
                        } label: {
                            Label("Add Wall", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.white, Color.gray.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.top)
                    }
                } else {
                    // List of walls
                    List {
                        ForEach(walls) { wall in
                            NavigationLink(destination: WallDetailView(wall: wall, onUpdate: updateWall)) {
                                WallRowView(wall: wall)
                                    .contentShape(Rectangle())
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = walls.firstIndex(where: { $0.id == wall.id }) {
                                        deleteWall(at: index)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("My Walls")
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSourceSelection = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imageSourceType)
            }
            .fullScreenCover(isPresented: $showARScanner) {
                WallScannerView { scannedImage in
                    selectedImage = scannedImage
                    showNameAlert = true
                }
            }
            .confirmationDialog("Add Wall Photo", isPresented: $showSourceSelection) {
                Button("Scan with AR") {
                    showARScanner = true
                }
                Button("Take Photo") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Name Your Wall", isPresented: $showNameAlert) {
                TextField("Wall name", text: $newWallName)
                Button("Cancel", role: .cancel) {
                    selectedImage = nil
                    newWallName = ""
                }
                Button("Create") {
                    createWall()
                }
            } message: {
                Text("Give this climbing wall a name")
            }
            .onChange(of: selectedImage) { newValue in
                if newValue != nil {
                    showNameAlert = true
                }
            }
            .onAppear {
                loadWalls()
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveWalls() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(walls) {
            let url = getDocumentsDirectory().appendingPathComponent(saveKey)
            try? encoded.write(to: url)
        }
    }
    
    private func loadWalls() {
        let url = getDocumentsDirectory().appendingPathComponent(saveKey)
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([ClimbingWall].self, from: data) {
                walls = decoded
            }
        }
    }
    
    private func createWall() {
        guard let image = selectedImage else { return }
        
        let wallName = newWallName.isEmpty ? "Wall \(walls.count + 1)" : newWallName
        let newWall = ClimbingWall(name: wallName, image: image, climbs: [])
        walls.append(newWall)
        saveWalls()
        
        // Reset
        selectedImage = nil
        newWallName = ""
    }
    
    private func deleteWall(at index: Int) {
        walls.remove(at: index)
        saveWalls()
    }
    
    private func updateWall(_ updatedWall: ClimbingWall) {
        if let index = walls.firstIndex(where: { $0.id == updatedWall.id }) {
            walls[index] = updatedWall
            saveWalls()
        }
    }
}

// Row view for each wall in the list
struct WallRowView: View {
    let wall: ClimbingWall
    
    var body: some View {
        HStack(spacing: 15) {
            thumbnailView
            wallInfoView
            Spacer()
            chevronView
        }
        .padding()
        .background(cardBackground)
        .overlay(cardBorder)
    }
    
    private var thumbnailView: some View {
        ZStack {
            if let image = wall.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(thumbnailGradient, lineWidth: 1)
        )
    }
    
    private var thumbnailGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.3), .white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var wallInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(wall.name)
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(wall.climbs.count) climbs")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            
            Text(wall.createdDate, style: .date)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.white.opacity(0.3))
            .font(.caption)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

#Preview {
    HomeView()
}

import SwiftUI
import PhotosUI

// Image picker wrapper with camera and photo library support
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

import SwiftUI

struct LogbookView: View {
    @State private var walls: [ClimbingWall] = []
    private let saveKey = "SavedWalls"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if tickedClimbs.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("No Sends Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Tick climbs to build your logbook")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // List of ticked climbs
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(tickedClimbs) { entry in
                                NavigationLink {
                                    ClimbDetailView(
                                        wall: entry.wall,
                                        climb: entry.climb,
                                        onUpdate: { updatedClimb in
                                            updateClimb(updatedClimb, in: entry.wall)
                                        },
                                        onDelete: {
                                            deleteClimb(entry.climb, from: entry.wall)
                                        }
                                    )
                                } label: {
                                    LogbookEntryView(entry: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Logbook")
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                loadWalls()
            }
        }
    }
    
    // Computed property to get all ticked climbs
    private var tickedClimbs: [LogbookEntry] {
        var entries: [LogbookEntry] = []
        
        for wall in walls {
            for climb in wall.climbs where climb.isTicked {
                entries.append(LogbookEntry(
                    id: climb.id,
                    climbName: climb.name,
                    wallName: wall.name,
                    grade: climb.difficulty ?? "Unknown",
                    date: climb.createdDate,
                    matchAllowed: climb.matchAllowed,
                    rating: climb.rating,
                    wall: wall,
                    climb: climb
                ))
            }
        }
        
        // Sort by date, most recent first
        return entries.sorted { $0.date > $1.date }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadWalls() {
        let url = getDocumentsDirectory().appendingPathComponent(saveKey)
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([ClimbingWall].self, from: data) {
                walls = decoded
            }
        }
    }
    
    private func saveWalls() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(walls) {
            let url = getDocumentsDirectory().appendingPathComponent(saveKey)
            try? encoded.write(to: url)
        }
    }
    
    private func updateClimb(_ updatedClimb: Climb, in wall: ClimbingWall) {
        if let wallIndex = walls.firstIndex(where: { $0.id == wall.id }),
           let climbIndex = walls[wallIndex].climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
            walls[wallIndex].climbs[climbIndex] = updatedClimb
            saveWalls()
        }
    }
    
    private func deleteClimb(_ climb: Climb, from wall: ClimbingWall) {
        if let wallIndex = walls.firstIndex(where: { $0.id == wall.id }),
           let climbIndex = walls[wallIndex].climbs.firstIndex(where: { $0.id == climb.id }) {
            walls[wallIndex].climbs.remove(at: climbIndex)
            saveWalls()
        }
    }
}

// Model for logbook entry
struct LogbookEntry: Identifiable {
    let id: UUID
    let climbName: String
    let wallName: String
    let grade: String
    let date: Date
    let matchAllowed: Bool
    let rating: Int?
    let wall: ClimbingWall
    let climb: Climb
}

// Row view for each logbook entry
struct LogbookEntryView: View {
    let entry: LogbookEntry
    
    var body: some View {
        HStack(spacing: 15) {
            // Grade circle
            ZStack {
                let gradeColor = Color.gradeColor(for: entry.grade)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [gradeColor.opacity(0.3), gradeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text(entry.grade)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(gradeColor)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.gradeColor(for: entry.grade).opacity(0.5),
                                   Color.gradeColor(for: entry.grade).opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.climbName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Match indicator
                    ZStack {
                        Circle()
                            .stroke(entry.matchAllowed ? Color.green : Color.red, lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "hands.clap.fill")
                            .font(.system(size: 8))
                            .foregroundColor(entry.matchAllowed ? .green : .red)
                        
                        if !entry.matchAllowed {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 22, height: 1.5)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
                
                Text(entry.wallName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                // Star rating
                if let rating = entry.rating {
                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= rating ? .yellow : .white.opacity(0.3))
                        }
                    }
                }
                
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    LogbookView()
}


import SwiftUI

struct MainView: View {
    var body: some View {
        DashboardView()
    }
}

#Preview {
    MainView()
}

import SwiftUI
import PhotosUI
import AVFoundation

// Enhanced video picker with automatic transcoding for compatibility
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 300 // 5 minute limit
        if sourceType == .camera {
            picker.cameraCaptureMode = .video
        }
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                // Validate and potentially transcode video
                processVideo(from: videoURL)
            } else {
                parent.dismiss()
            }
        }
        
        private func processVideo(from sourceURL: URL) {
            print("processVideo called with: \(sourceURL.path)")
            print("Source file exists: \(FileManager.default.fileExists(atPath: sourceURL.path))")
            
            let asset = AVAsset(url: sourceURL)
            
            Task {
                do {
                    // Check if video has tracks using modern async API
                    let videoTracks = try await asset.loadTracks(withMediaType: .video)
                    print("Video has \(videoTracks.count) video tracks")
                    
                    guard !videoTracks.isEmpty else {
                        print("Error: Video has no video tracks")
                        await MainActor.run {
                            self.parent.dismiss()
                        }
                        return
                    }
                    
                    // Check if the video is playable
                    let isPlayable = try await asset.load(.isPlayable)
                    print("Video is playable: \(isPlayable)")
                    
                    if isPlayable {
                        // Video is playable, save it directly
                        print("Taking direct save path")
                        self.saveVideo(from: sourceURL)
                    } else {
                        // Video may have compatibility issues, transcode it
                        print("Video may have compatibility issues, transcoding...")
                        await MainActor.run {
                            self.transcodeVideo(asset: asset, sourceURL: sourceURL)
                        }
                    }
                } catch {
                    print("Error loading video tracks: \(error)")
                    await MainActor.run {
                        self.parent.dismiss()
                    }
                }
            }
        }
        
        private func saveVideo(from sourceURL: URL) {
            print("saveVideo called with: \(sourceURL.path)")
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "\(UUID().uuidString).mov"
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            print("Will save to: \(destinationURL.path)")
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy video file
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                print("File copied successfully")
                
                // Verify file exists
                let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)
                print("File exists after copy: \(fileExists)")
                
                if fileExists {
                    DispatchQueue.main.async {
                        self.parent.videoURL = destinationURL
                        print("Video saved successfully: \(destinationURL.path)")
                        self.parent.dismiss()
                    }
                } else {
                    print("Error: File doesn't exist after copy!")
                    DispatchQueue.main.async {
                        self.parent.dismiss()
                    }
                }
            } catch {
                print("Error saving video: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.parent.dismiss()
                }
            }
        }
        
        private func transcodeVideo(asset: AVAsset, sourceURL: URL) {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "\(UUID().uuidString).mov"
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                print("Failed to create export session")
                saveVideo(from: sourceURL) // Fallback to direct copy
                return
            }
            
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = .mov
            exportSession.shouldOptimizeForNetworkUse = true
            
            exportSession.exportAsynchronously { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        print("Video transcoded successfully to: \(destinationURL.path)")
                        self.parent.videoURL = destinationURL
                        self.parent.dismiss()
                    case .failed:
                        print("Transcoding failed: \(String(describing: exportSession.error))")
                        // Fallback to direct copy
                        self.saveVideo(from: sourceURL)
                    case .cancelled:
                        print("Transcoding cancelled")
                        self.parent.dismiss()
                    default:
                        self.parent.dismiss()
                    }
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

import SwiftUI

// Model for a climbing wall with multiple climbs
struct ClimbingWall: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var imageData: Data
    var climbs: [Climb]
    var createdDate: Date
    
    init(id: UUID = UUID(), name: String, image: UIImage, climbs: [Climb] = []) {
        self.id = id
        self.name = name
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.climbs = climbs
        self.createdDate = Date()
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    // Helper computed property for total holds across all climbs
    var totalHolds: Int {
        climbs.reduce(0) { $0 + $1.holds.count }
    }
}

// Model for a single climb/route on a wall
struct Climb: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var holds: [SavedHold]
    var createdDate: Date
    var difficulty: String? // Optional difficulty rating (set when ticked)
    var notes: String? // Optional notes
    var matchAllowed: Bool // Whether matching (both hands on same hold) is allowed
    var tickDates: [Date] // Array of dates when climb was completed (for repeats)
    var isEstablished: Bool // Whether the climb is established (locked from editing holds)
    var rating: Int? // Star rating 1-4 (set when ticked)
    var betaVideoURL: URL? // DEPRECATED: kept for backwards compatibility, migrate to betaVideos
    var betaVideos: [BetaVideo] // Array of beta videos from multiple users
    
    // Computed property for backwards compatibility
    var isTicked: Bool {
        !tickDates.isEmpty
    }
    
    // Most recent tick date
    var lastTickDate: Date? {
        tickDates.max()
    }
    
    // Number of sends
    var sendCount: Int {
        tickDates.count
    }
    
    init(id: UUID = UUID(), name: String, holds: [SavedHold] = [], difficulty: String? = nil, notes: String? = nil, matchAllowed: Bool = true, tickDates: [Date] = [], isEstablished: Bool = false, rating: Int? = nil, betaVideoURL: URL? = nil, betaVideos: [BetaVideo] = []) {
        self.id = id
        self.name = name
        self.holds = holds
        self.createdDate = Date()
        self.difficulty = difficulty
        self.notes = notes
        self.matchAllowed = matchAllowed
        self.tickDates = tickDates
        self.isEstablished = isEstablished
        self.rating = rating
        self.betaVideoURL = betaVideoURL
        self.betaVideos = betaVideos
        
        // Migration: if betaVideoURL exists but betaVideos is empty, migrate it
        if let legacyURL = betaVideoURL, betaVideos.isEmpty {
            self.betaVideos = [BetaVideo(videoURL: legacyURL, uploaderName: "Legacy User", uploadDate: createdDate)]
        }
    }
}

// Saved hold with position, color, and size
struct SavedHold: Identifiable, Codable, Hashable {
    let id: UUID
    let relativeX: Double // Position as percentage of actual image width
    let relativeY: Double // Position as percentage of actual image height
    let color: String // "red", "green", "blue", or "purple"
    let relativeSize: Double // Size as percentage of container width
    
    init(id: UUID = UUID(), position: CGPoint, color: HoldColor, size: CGFloat, imageSize: CGSize, containerSize: CGSize) {
        self.id = id
        
        // Calculate actual displayed image size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let actualImageSize: CGSize
        let imageOffset: CGPoint
        
        if imageAspect > containerAspect {
            // Image fits to width
            let displayHeight = containerSize.width / imageAspect
            actualImageSize = CGSize(width: containerSize.width, height: displayHeight)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayHeight) / 2)
        } else {
            // Image fits to height
            let displayWidth = containerSize.height * imageAspect
            actualImageSize = CGSize(width: displayWidth, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayWidth) / 2, y: 0)
        }
        
        // Convert position to relative coordinates within actual image
        self.relativeX = Double((position.x - imageOffset.x) / actualImageSize.width)
        self.relativeY = Double((position.y - imageOffset.y) / actualImageSize.height)
        self.relativeSize = Double(size / containerSize.width)
        
        switch color {
        case .red: self.color = "red"
        case .green: self.color = "green"
        case .blue: self.color = "blue"
        case .purple: self.color = "purple"
        }
    }
    
    func position(imageSize: CGSize, containerSize: CGSize) -> CGPoint {
        // Calculate actual displayed image size and offset
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let actualImageSize: CGSize
        let imageOffset: CGPoint
        
        if imageAspect > containerAspect {
            let displayHeight = containerSize.width / imageAspect
            actualImageSize = CGSize(width: containerSize.width, height: displayHeight)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayHeight) / 2)
        } else {
            let displayWidth = containerSize.height * imageAspect
            actualImageSize = CGSize(width: displayWidth, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayWidth) / 2, y: 0)
        }
        
        // Convert relative position back to absolute
        return CGPoint(
            x: imageOffset.x + (relativeX * actualImageSize.width),
            y: imageOffset.y + (relativeY * actualImageSize.height)
        )
    }
    
    func size(containerSize: CGSize) -> CGFloat {
        relativeSize * containerSize.width
    }
    
    var holdColor: HoldColor {
        switch color {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .red
        }
    }
}

// Model for beta videos with user attribution
struct BetaVideo: Identifiable, Codable, Hashable {
    let id: UUID
    var videoURL: URL
    var uploaderName: String
    var uploadDate: Date
    var notes: String? // Optional notes about the beta
    
    init(id: UUID = UUID(), videoURL: URL, uploaderName: String, uploadDate: Date = Date(), notes: String? = nil) {
        self.id = id
        self.videoURL = videoURL
        self.uploaderName = uploaderName
        self.uploadDate = uploadDate
        self.notes = notes
    }
}

import SwiftUI
import UniformTypeIdentifiers

// Playlist model
struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var climbIds: Set<UUID>
    
    init(id: UUID = UUID(), name: String, climbIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.climbIds = climbIds
    }
}

struct WallDetailView: View {
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    
    @State private var currentWall: ClimbingWall
    @State private var showDeleteAlert = false
    @State private var climbToDelete: Climb?
    @State private var navigateToNewClimb: Climb?
    @State private var isNavigatingToNewClimb = false
    @State private var isCreatingNewClimb = false
    @State private var isDraftsExpanded = true
    @State private var isEstablishedExpanded = true
    @State private var isEditMode = false
    @State private var folderOrder: [String] = ["drafts", "established", "playlist", "logbook"]
    @State private var draggedFolder: String?
    @State private var playlists: [Playlist] = []
    @State private var showPlaylistManager = false
    @State private var establishedFilterMinGrade: String? = nil
    @State private var establishedFilterMaxGrade: String? = nil
    @State private var draftFilterMinGrade: String? = nil
    @State private var draftFilterMaxGrade: String? = nil
    @State private var logbookFilterMinGrade: String? = nil
    @State private var logbookFilterMaxGrade: String? = nil
    
    init(wall: ClimbingWall, onUpdate: @escaping (ClimbingWall) -> Void) {
        self.wall = wall
        self.onUpdate = onUpdate
        self._currentWall = State(initialValue: wall)
    }
    
    // Computed properties to separate drafts and established climbs
    private var draftClimbs: [Climb] {
        currentWall.climbs.filter { !$0.isEstablished }
    }
    
    private var establishedClimbs: [Climb] {
        currentWall.climbs.filter { $0.isEstablished }
    }
    
    private var filteredEstablishedClimbs: [Climb] {
        var climbs = establishedClimbs
        
        // Apply grade filters if set
        if let minGrade = establishedFilterMinGrade {
            climbs = climbs.filter { climb in
                guard let difficulty = climb.difficulty else { return false }
                return difficulty >= minGrade
            }
        }
        
        if let maxGrade = establishedFilterMaxGrade {
            climbs = climbs.filter { climb in
                guard let difficulty = climb.difficulty else { return false }
                return difficulty <= maxGrade
            }
        }
        
        return climbs
    }
    
    private var logbookClimbs: [Climb] {
        currentWall.climbs.filter { $0.isTicked }
    }
    
    private var filteredLogbookClimbs: [Climb] {
        var climbs = logbookClimbs
        
        // Apply grade filters if set
        if let minGrade = logbookFilterMinGrade {
            climbs = climbs.filter { climb in
                guard let difficulty = climb.difficulty else { return false }
                return difficulty >= minGrade
            }
        }
        
        if let maxGrade = logbookFilterMaxGrade {
            climbs = climbs.filter { climb in
                guard let difficulty = climb.difficulty else { return false }
                return difficulty <= maxGrade
            }
        }
        
        return climbs
    }
    
    private var totalPlaylistClimbs: Int {
        playlists.reduce(0) { $0 + $1.climbIds.count }
    }
    
    private var newClimbButton: some View {
        Button {
            let climbName = "Climb \(currentWall.climbs.count + 1)"
            let newClimb = Climb(name: climbName, holds: [])
            navigateToNewClimb = newClimb
            isCreatingNewClimb = true
            isNavigatingToNewClimb = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("New Climb")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                Rectangle()
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .cyan.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .cornerRadius(16)
            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Climbs Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Tap \"New Climb\" above to get started")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(folderOrder, id: \.self) { folderId in
                    folderWidgetForId(folderId)
                }
            }
            .padding()
        }
        .overlay(
            Group {
                if isEditMode {
                    VStack {
                        Spacer()
                        Button {
                            withAnimation {
                                isEditMode = false
                            }
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(25)
                                .shadow(radius: 10)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        )
    }
    
    @ViewBuilder
    private func folderWidgetForId(_ folderId: String) -> some View {
        if folderId == "drafts" && !draftClimbs.isEmpty {
            draftsWidget
        } else if folderId == "established" && !establishedClimbs.isEmpty {
            establishedWidget
        } else if folderId == "playlist" {
            playlistWidget
        } else if folderId == "logbook" && !logbookClimbs.isEmpty {
            logbookWidget
        }
    }
    
    private var draftsWidget: some View {
        FolderWidgetView(
            title: "Drafts",
            icon: "pencil.and.outline",
            count: draftClimbs.count,
            isExpanded: $isDraftsExpanded,
            isEditMode: isEditMode,
            accentColor: .orange,
            filterMinGrade: $draftFilterMinGrade,
            filterMaxGrade: $draftFilterMaxGrade
        ) {
            ForEach(draftClimbs) { climb in
                climbNavigationLink(for: climb)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                                currentWall.climbs.remove(at: index)
                                onUpdate(currentWall)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                isEditMode.toggle()
            }
        }
        .opacity(draggedFolder == "drafts" && isEditMode ? 0.5 : 1.0)
    }
    
    private var establishedWidget: some View {
        FolderWidgetView(
            title: "Established",
            icon: "checkmark.seal.fill",
            count: filteredEstablishedClimbs.count,
            isExpanded: $isEstablishedExpanded,
            isEditMode: isEditMode,
            accentColor: .green,
            hasFilter: true,
            filterMinGrade: $establishedFilterMinGrade,
            filterMaxGrade: $establishedFilterMaxGrade,
            allClimbs: establishedClimbs
        ) {
            ForEach(filteredEstablishedClimbs) { climb in
                climbNavigationLink(for: climb)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                                currentWall.climbs.remove(at: index)
                                onUpdate(currentWall)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                isEditMode.toggle()
            }
        }
        .opacity(draggedFolder == "established" && isEditMode ? 0.5 : 1.0)
    }
    
    private var playlistWidget: some View {
        PlaylistWidgetView(
            count: totalPlaylistClimbs,
            playlistCount: playlists.count,
            isEditMode: isEditMode,
            onTap: {
                showPlaylistManager = true
            }
        )
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                isEditMode.toggle()
            }
        }
        .opacity(draggedFolder == "playlist" && isEditMode ? 0.5 : 1.0)
    }
    
    private var logbookWidget: some View {
        LogbookWidgetView(
            count: filteredLogbookClimbs.count,
            isEditMode: isEditMode,
            climbs: filteredLogbookClimbs,
            wall: currentWall,
            onUpdate: onUpdate,
            filterMinGrade: $logbookFilterMinGrade,
            filterMaxGrade: $logbookFilterMaxGrade,
            allClimbs: logbookClimbs
        ) {
            ForEach(filteredLogbookClimbs) { climb in
                climbNavigationLink(for: climb)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                                currentWall.climbs.remove(at: index)
                                onUpdate(currentWall)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                isEditMode.toggle()
            }
        }
        .opacity(draggedFolder == "logbook" && isEditMode ? 0.5 : 1.0)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // New Climb Button (at top)
                newClimbButton
                
                // Widget-style folders
                if currentWall.climbs.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
        }
        .navigationDestination(isPresented: $isNavigatingToNewClimb) {
            if let newClimb = navigateToNewClimb {
                ClimbDetailView(
                    wall: currentWall,
                    climb: newClimb,
                    onUpdate: { updatedClimb in
                        if isCreatingNewClimb {
                            // First save - add the climb to the array
                            currentWall.climbs.append(updatedClimb)
                            isCreatingNewClimb = false
                        } else {
                            // Subsequent updates - update existing climb
                            if let index = currentWall.climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
                                currentWall.climbs[index] = updatedClimb
                            }
                        }
                        onUpdate(currentWall)
                    },
                    onDelete: {
                        if !isCreatingNewClimb {
                            // Only delete if climb was actually added
                            if let index = currentWall.climbs.firstIndex(where: { $0.id == newClimb.id }) {
                                currentWall.climbs.remove(at: index)
                                onUpdate(currentWall)
                            }
                        }
                        // If still creating, just dismiss without doing anything
                    }
                )
            }
        }
        .navigationTitle(currentWall.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete Climb?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                climbToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let climb = climbToDelete,
                   let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                    deleteClimb(at: index)
                }
                climbToDelete = nil
            }
        } message: {
            if let climb = climbToDelete {
                Text("This will permanently delete '\(climb.name)'. This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showPlaylistManager) {
            PlaylistManagerView(
                wall: currentWall,
                playlists: $playlists,
                establishedClimbs: establishedClimbs,
                allClimbs: currentWall.climbs,
                onUpdate: { updatedWall in
                    currentWall = updatedWall
                    onUpdate(updatedWall)
                }
            )
        }
    }
    
    // Helper function to create navigation link for a climb
    private func climbNavigationLink(for climb: Climb) -> some View {
        NavigationLink {
            ClimbDetailView(
                wall: currentWall,
                climb: climb,
                onUpdate: { updatedClimb in
                    if let index = currentWall.climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
                        currentWall.climbs[index] = updatedClimb
                        onUpdate(currentWall)
                    }
                },
                onDelete: {
                    if let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                        currentWall.climbs.remove(at: index)
                        onUpdate(currentWall)
                    }
                }
            )
        } label: {
            ClimbRowView(climb: climb)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                climbToDelete = climb
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func deleteClimb(at index: Int) {
        currentWall.climbs.remove(at: index)
        onUpdate(currentWall)
    }
}

// Widget-style folder view
struct FolderWidgetView<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    @Binding var isExpanded: Bool
    let isEditMode: Bool
    let accentColor: Color
    var hasFilter: Bool = false
    @Binding var filterMinGrade: String?
    @Binding var filterMaxGrade: String?
    var allClimbs: [Climb] = []
    let content: () -> Content
    
    enum SheetType: Identifiable {
        case climbsList
        case filter
        
        var id: Int {
            switch self {
            case .climbsList: return 0
            case .filter: return 1
            }
        }
    }
    
    @State private var activeSheet: SheetType?
    
    var body: some View {
        Button {
            if !isEditMode {
                activeSheet = .climbsList
            }
        } label: {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Title and count
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Edit mode indicator
                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .aspectRatio(1.0, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(0.4), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(isEditMode ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isEditMode)
            .overlay(
                Group {
                    if isEditMode {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .shadow(color: accentColor.opacity(0.5), radius: 8)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(item: $activeSheet) { sheetType in
            NavigationStack {
                switch sheetType {
                case .climbsList:
                    ZStack {
                        LinearGradient(
                            colors: [Color.black, Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        List {
                            content()
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if hasFilter {
                                NavigationLink {
                                    EstablishedFilterView(
                                        minGrade: $filterMinGrade,
                                        maxGrade: $filterMaxGrade
                                    )
                                } label: {
                                    Image(systemName: (filterMinGrade != nil || filterMaxGrade != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .foregroundColor((filterMinGrade != nil || filterMaxGrade != nil) ? .green : .white)
                                }
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                activeSheet = nil
                            }
                            .foregroundColor(.white)
                        }
                    }
                    
                case .filter:
                    EstablishedFilterView(
                        minGrade: $filterMinGrade,
                        maxGrade: $filterMaxGrade
                    )
                }
            }
        }
    }
}

// Playlist Widget
struct PlaylistWidgetView: View {
    let count: Int
    let playlistCount: Int
    let isEditMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            if !isEditMode {
                onTap()
            }
        } label: {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: playlistCount > 0 ? "figure.climbing" : "plus.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.purple)
                }
                
                // Title and count
                VStack(spacing: 4) {
                    Text("Playlists")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if playlistCount > 0 {
                        Text("\(playlistCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("Create")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Edit mode indicator
                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .aspectRatio(1.0, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(isEditMode ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isEditMode)
            .overlay(
                Group {
                    if isEditMode {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .shadow(color: Color.purple.opacity(0.5), radius: 8)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Logbook Widget
struct LogbookWidgetView<Content: View>: View {
    let count: Int
    let isEditMode: Bool
    let climbs: [Climb]
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    @Binding var filterMinGrade: String?
    @Binding var filterMaxGrade: String?
    var allClimbs: [Climb] = []
    let content: () -> Content
    
    enum SheetType: Identifiable {
        case climbsList
        case stats
        case filter
        
        var id: Int {
            switch self {
            case .climbsList: return 0
            case .stats: return 1
            case .filter: return 2
            }
        }
    }
    
    @State private var activeSheet: SheetType?
    
    var body: some View {
        Button {
            if !isEditMode {
                activeSheet = .climbsList
            }
        } label: {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                // Title and count
                VStack(spacing: 4) {
                    Text("Logbook")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Edit mode indicator
                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .aspectRatio(1.0, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.green.opacity(0.4), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(isEditMode ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isEditMode)
            .overlay(
                Group {
                    if isEditMode {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .shadow(color: Color.green.opacity(0.5), radius: 8)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(item: $activeSheet) { sheetType in
            NavigationStack {
                switch sheetType {
                case .climbsList:
                    ZStack {
                        LinearGradient(
                            colors: [Color.black, Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            // Stats button
                            Button {
                                activeSheet = .stats
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                    
                                    Text("View Stats")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.15)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.green.opacity(0.5), .green.opacity(0.2)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            List {
                                content()
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .navigationTitle("Logbook")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            NavigationLink {
                                EstablishedFilterView(
                                    minGrade: $filterMinGrade,
                                    maxGrade: $filterMaxGrade
                                )
                            } label: {
                                Image(systemName: (filterMinGrade != nil || filterMaxGrade != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundColor((filterMinGrade != nil || filterMaxGrade != nil) ? .green : .white)
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                activeSheet = nil
                            }
                            .foregroundColor(.white)
                        }
                    }
                    
                case .stats:
                    LogbookStatsView(climbs: allClimbs, wall: wall, onUpdate: onUpdate)
                    
                case .filter:
                    EstablishedFilterView(
                        minGrade: $filterMinGrade,
                        maxGrade: $filterMaxGrade
                    )
                }
            }
        }
    }
}

// Logbook Stats View
struct LogbookStatsView: View {
    let climbs: [Climb]
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showSessionsDetail = false
    @State private var showMostRepeatedDetail = false
    @State private var showHardestDetail = false
    
    private var gradeDistribution: [(grade: String, count: Int)] {
        let grouped = Dictionary(grouping: climbs) { $0.difficulty ?? "Unknown" }
        return grouped.map { (grade: $0.key, count: $0.value.reduce(0) { $0 + $1.sendCount }) }
            .sorted { $0.grade < $1.grade }
    }
    
    private var totalSends: Int {
        climbs.reduce(0) { $0 + $1.sendCount }
    }
    
    private var mostRepeated: Int {
        climbs.map { $0.sendCount }.max() ?? 0
    }
    
    private var hardestGrade: String {
        climbs.compactMap { $0.difficulty }.max() ?? "N/A"
    }
    
    private var hardestClimbs: [Climb] {
        let maxGrade = hardestGrade
        return climbs.filter { $0.difficulty == maxGrade }
    }
    
    private var sessionCount: Int {
        // Sort climbs by created date
        let sortedClimbs = climbs.sorted { $0.createdDate < $1.createdDate }
        
        guard !sortedClimbs.isEmpty else { return 0 }
        
        var sessions = 1
        for i in 1..<sortedClimbs.count {
            let timeDiff = sortedClimbs[i].createdDate.timeIntervalSince(sortedClimbs[i-1].createdDate)
            // If more than 4 hours (14400 seconds) between climbs, it's a new session
            if timeDiff > 14400 {
                sessions += 1
            }
        }
        return sessions
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Stats
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            StatCardView(
                                title: "Total Sends",
                                value: "\(totalSends)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            Button {
                                showSessionsDetail = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    StatCardView(
                                        title: "Sessions",
                                        value: "\(sessionCount)",
                                        icon: "calendar",
                                        color: .blue
                                    )
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(12)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                showMostRepeatedDetail = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    StatCardView(
                                        title: "Most Repeated",
                                        value: "View",
                                        icon: "arrow.clockwise",
                                        color: .purple,
                                        useSmallValue: true
                                    )
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(12)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button {
                                showHardestDetail = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    StatCardView(
                                        title: "Hardest",
                                        value: hardestGrade,
                                        icon: "flame.fill",
                                        color: .orange
                                    )
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(12)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Grade Distribution
                    if !gradeDistribution.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Grade Distribution")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(gradeDistribution, id: \.grade) { item in
                                    GradeDistributionRow(
                                        grade: item.grade,
                                        count: item.count,
                                        total: totalSends
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Logbook Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showSessionsDetail) {
            NavigationStack {
                SessionsDetailView(climbs: climbs, wall: wall, onUpdate: onUpdate)
            }
        }
        .sheet(isPresented: $showMostRepeatedDetail) {
            NavigationStack {
                MostRepeatedDetailView(climbs: climbs)
            }
        }
        .sheet(isPresented: $showHardestDetail) {
            NavigationStack {
                HardestClimbDetailView(climbs: hardestClimbs, grade: hardestGrade)
            }
        }
    }
}

// Sessions Detail View
struct SessionsDetailView: View {
    let climbs: [Climb]
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedSession: ClimbingSession?
    
    // Group climbs into sessions (4 hour gap = new session)
    private var sessions: [ClimbingSession] {
        let sortedClimbs = climbs.sorted { $0.createdDate < $1.createdDate }
        guard !sortedClimbs.isEmpty else { return [] }
        
        var sessions: [ClimbingSession] = []
        var currentSessionClimbs: [Climb] = [sortedClimbs[0]]
        
        for i in 1..<sortedClimbs.count {
            let timeDiff = sortedClimbs[i].createdDate.timeIntervalSince(sortedClimbs[i-1].createdDate)
            
            if timeDiff > 14400 { // 4 hours
                // Save current session and start new one
                sessions.append(ClimbingSession(
                    date: currentSessionClimbs[0].createdDate,
                    climbs: currentSessionClimbs
                ))
                currentSessionClimbs = [sortedClimbs[i]]
            } else {
                currentSessionClimbs.append(sortedClimbs[i])
            }
        }
        
        // Add final session
        sessions.append(ClimbingSession(
            date: currentSessionClimbs[0].createdDate,
            climbs: currentSessionClimbs
        ))
        
        return sessions.reversed() // Most recent first
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if sessions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No Sessions")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            Button {
                                selectedSession = session
                            } label: {
                                SessionRowView(
                                    session: session,
                                    sessionNumber: sessions.count - index
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                SessionDetailView(session: session, wall: wall, onUpdate: onUpdate)
            }
        }
    }
}

// Session Model
struct ClimbingSession: Identifiable {
    let id = UUID()
    let date: Date
    let climbs: [Climb]
}

// Most Repeated Detail View
struct MostRepeatedDetailView: View {
    let climbs: [Climb]
    @Environment(\.dismiss) var dismiss
    
    // Sort climbs by send count (descending)
    private var sortedClimbs: [Climb] {
        climbs.sorted { $0.sendCount > $1.sendCount }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sortedClimbs) { climb in
                        RepeatedClimbRow(climb: climb)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Most Repeated")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

// Repeated Climb Row View
struct RepeatedClimbRow: View {
    let climb: Climb
    
    var body: some View {
        HStack(spacing: 15) {
            // Send count circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 2) {
                    Text("\(climb.sendCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text(climb.sendCount == 1 ? "send" : "sends")
                        .font(.system(size: 10))
                        .foregroundColor(.purple.opacity(0.7))
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.5), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                Text(climb.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let grade = climb.difficulty {
                    Text(grade)
                        .font(.subheadline)
                        .foregroundColor(Color.gradeColor(for: grade))
                }
                
                // Star rating
                if let rating = climb.rating {
                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= rating ? .yellow : .white.opacity(0.3))
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Hardest Climb Detail View
struct HardestClimbDetailView: View {
    let climbs: [Climb]
    let grade: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    // Header with grade
                    VStack(spacing: 8) {
                        Text(grade)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(Color.gradeColor(for: grade))
                        
                        Text(climbs.count == 1 ? "1 climb at this grade" : "\(climbs.count) climbs at this grade")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    ForEach(climbs) { climb in
                        HardestClimbRow(climb: climb)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Hardest Climbs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

// Hardest Climb Row View
struct HardestClimbRow: View {
    let climb: Climb
    
    var body: some View {
        HStack(spacing: 15) {
            // Grade circle
            ZStack {
                let gradeColor = Color.gradeColor(for: climb.difficulty ?? "V0")
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [gradeColor.opacity(0.3), gradeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundColor(gradeColor)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.gradeColor(for: climb.difficulty ?? "V0").opacity(0.5),
                                   Color.gradeColor(for: climb.difficulty ?? "V0").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                Text(climb.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Send count
                if climb.sendCount > 1 {
                    Text("\(climb.sendCount) sends")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Text("1 send")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                // Star rating
                if let rating = climb.rating {
                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= rating ? .yellow : .white.opacity(0.3))
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Session Row View
struct SessionRowView: View {
    let session: ClimbingSession
    let sessionNumber: Int
    
    var body: some View {
        HStack(spacing: 15) {
            // Session number badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text("#\(sessionNumber)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
            // Session info
            VStack(alignment: .leading, spacing: 6) {
                Text(session.date, style: .date)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(session.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(session.climbs.count) climbs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Session Detail View
struct SessionDetailView: View {
    let session: ClimbingSession
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var currentWall: ClimbingWall
    
    init(session: ClimbingSession, wall: ClimbingWall, onUpdate: @escaping (ClimbingWall) -> Void) {
        self.session = session
        self.wall = wall
        self.onUpdate = onUpdate
        self._currentWall = State(initialValue: wall)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Session summary
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatCardView(
                                title: "Total Climbs",
                                value: "\(session.climbs.count)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            StatCardView(
                                title: "Hardest",
                                value: session.climbs.compactMap { $0.difficulty }.max() ?? "N/A",
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Climbs list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Climbs")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(session.climbs) { climb in
                            NavigationLink {
                                ClimbDetailView(
                                    wall: currentWall,
                                    climb: climb,
                                    onUpdate: { updatedClimb in
                                        if let index = currentWall.climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
                                            currentWall.climbs[index] = updatedClimb
                                            onUpdate(currentWall)
                                        }
                                    },
                                    onDelete: {
                                        if let index = currentWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                                            currentWall.climbs.remove(at: index)
                                            onUpdate(currentWall)
                                        }
                                    }
                                )
                            } label: {
                                SessionClimbRowView(climb: climb)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(session.date.formatted(date: .long, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

// Simplified climb row for sessions (no match indicator)
struct SessionClimbRowView: View {
    let climb: Climb
    
    var body: some View {
        HStack(spacing: 15) {
            // Grade circle
            ZStack {
                let gradeColor = climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!) : Color.white
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                climb.difficulty != nil ? gradeColor.opacity(0.3) : Color.white.opacity(0.2),
                                climb.difficulty != nil ? gradeColor.opacity(0.1) : Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                if let difficulty = climb.difficulty {
                    Text(difficulty)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(gradeColor)
                } else {
                    Image(systemName: "figure.climbing")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!).opacity(0.5) : .white.opacity(0.3),
                                climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!).opacity(0.2) : .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: climb.difficulty != nil ? 2 : 1
                    )
            )
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                Text(climb.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Star rating
                if let rating = climb.rating {
                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= rating ? .yellow : .white.opacity(0.3))
                        }
                    }
                }
                
                Text(climb.createdDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var useSmallValue: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(useSmallValue ? .caption : .title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Grade Distribution Row
struct GradeDistributionRow: View {
    let grade: String
    let count: Int
    let total: Int
    
    private var percentage: Double {
        Double(count) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(grade)
                .font(.headline)
                .foregroundColor(Color.gradeColor(for: grade))
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.gradeColor(for: grade), Color.gradeColor(for: grade).opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 20)
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// Playlist Manager View
struct PlaylistManagerView: View {
    let wall: ClimbingWall
    @Binding var playlists: [Playlist]
    let establishedClimbs: [Climb]
    let allClimbs: [Climb]
    let onUpdate: (ClimbingWall) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var selectedPlaylist: Playlist?
    @State private var showPlaylistDetail = false
    @State private var showNewPlaylistSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if playlists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("No Playlists")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Create your first playlist")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button {
                            showNewPlaylistSheet = true
                        } label: {
                            Label("New Playlist", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    List {
                        ForEach(playlists) { playlist in
                            Button {
                                selectedPlaylist = playlist
                                showPlaylistDetail = true
                            } label: {
                                PlaylistRowView(
                                    playlist: playlist,
                                    climbCount: playlist.climbIds.count
                                )
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                                        playlists.remove(at: index)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewPlaylistSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showNewPlaylistSheet) {
                NewPlaylistSheet(
                    newPlaylistName: $newPlaylistName,
                    onCreate: { name, shouldAddClimbs in
                        let newPlaylist = Playlist(name: name)
                        playlists.append(newPlaylist)
                        if shouldAddClimbs {
                            selectedPlaylist = newPlaylist
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPlaylistDetail = true
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showPlaylistDetail) {
                if let playlist = selectedPlaylist,
                   let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                    PlaylistDetailView(
                        wall: wall,
                        playlist: $playlists[index],
                        establishedClimbs: establishedClimbs,
                        allClimbs: allClimbs,
                        onUpdate: onUpdate
                    )
                }
            }
        }
    }
}

// New Playlist Sheet
struct NewPlaylistSheet: View {
    @Binding var newPlaylistName: String
    let onCreate: (String, Bool) -> Void // Bool indicates if should add climbs
    @Environment(\.dismiss) var dismiss
    @State private var showOptions = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "figure.climbing")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text(showOptions ? "Add Climbs?" : "New Playlist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !showOptions {
                        TextField("Playlist name", text: $newPlaylistName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                            )
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            Button {
                                onCreate(newPlaylistName, true)
                                newPlaylistName = ""
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Climbs Now")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            
                            Button {
                                onCreate(newPlaylistName, false)
                                newPlaylistName = ""
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Done")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(showOptions ? "Back" : "Cancel") {
                        if showOptions {
                            showOptions = false
                        } else {
                            newPlaylistName = ""
                            dismiss()
                        }
                    }
                    .foregroundColor(.white)
                }
                if !showOptions {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Next") {
                            if !newPlaylistName.isEmpty {
                                withAnimation {
                                    showOptions = true
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .disabled(newPlaylistName.isEmpty)
                    }
                }
            }
        }
    }
}

// Playlist Row View
struct PlaylistRowView: View {
    let playlist: Playlist
    let climbCount: Int
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "figure.climbing")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(climbCount) climb\(climbCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Playlist Detail View
struct PlaylistDetailView: View {
    let wall: ClimbingWall
    @Binding var playlist: Playlist
    let establishedClimbs: [Climb]
    let allClimbs: [Climb]
    let onUpdate: (ClimbingWall) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showAddClimbs = false
    @State private var showRenameAlert = false
    @State private var newName = ""
    
    private var playlistClimbs: [Climb] {
        allClimbs.filter { playlist.climbIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if playlistClimbs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Empty Playlist")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Button {
                            showAddClimbs = true
                        } label: {
                            Label("Add Climbs", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    List {
                        ForEach(playlistClimbs) { climb in
                            NavigationLink {
                                ClimbDetailView(
                                    wall: wall,
                                    climb: climb,
                                    onUpdate: { updatedClimb in
                                        // Find and update the climb in the wall
                                        var updatedWall = wall
                                        if let index = updatedWall.climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
                                            updatedWall.climbs[index] = updatedClimb
                                            onUpdate(updatedWall)
                                        }
                                    },
                                    onDelete: {
                                        // Remove from wall and playlist
                                        var updatedWall = wall
                                        if let index = updatedWall.climbs.firstIndex(where: { $0.id == climb.id }) {
                                            updatedWall.climbs.remove(at: index)
                                            playlist.climbIds.remove(climb.id)
                                            onUpdate(updatedWall)
                                        }
                                    }
                                )
                            } label: {
                                ClimbRowView(climb: climb)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    playlist.climbIds.remove(climb.id)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                        }
                        
                        // Add more climbs button
                        Button {
                            showAddClimbs = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                
                                Text("Add More Climbs")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.2), Color.purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.4), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddClimbs = true
                        } label: {
                            Label("Add Climbs", systemImage: "plus.circle")
                        }
                        Button {
                            newName = playlist.name
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddClimbs) {
                PlaylistSelectionView(
                    establishedClimbs: establishedClimbs,
                    selectedClimbIds: $playlist.climbIds
                )
            }
            .alert("Rename Playlist", isPresented: $showRenameAlert) {
                TextField("Playlist name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if !newName.isEmpty {
                        playlist.name = newName
                    }
                }
            }
            .onAppear {
                // Auto-open add climbs if playlist is empty (new playlist)
                if playlist.climbIds.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showAddClimbs = true
                    }
                }
            }
        }
    }
}

// Playlist Selection View (reusing for adding climbs)
struct PlaylistSelectionView: View {
    let establishedClimbs: [Climb]
    @Binding var selectedClimbIds: Set<UUID>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if establishedClimbs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("No Established Climbs")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Publish some climbs first")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(establishedClimbs) { climb in
                                Button {
                                    withAnimation {
                                        if selectedClimbIds.contains(climb.id) {
                                            selectedClimbIds.remove(climb.id)
                                        } else {
                                            selectedClimbIds.insert(climb.id)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        ClimbRowView(climb: climb)
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedClimbIds.contains(climb.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(selectedClimbIds.contains(climb.id) ? .purple : .white.opacity(0.3))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// Row view for each climb
struct ClimbRowView: View {
    let climb: Climb
    
    var body: some View {
        HStack(spacing: 15) {
            // Climb icon with gradient
            ZStack {
                let gradeColor = climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!) : Color.white
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                climb.difficulty != nil ? gradeColor.opacity(0.3) : Color.white.opacity(0.2),
                                climb.difficulty != nil ? gradeColor.opacity(0.1) : Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                if let difficulty = climb.difficulty {
                    Text(difficulty)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(gradeColor)
                } else if climb.isEstablished && !climb.isTicked {
                    Text("OP")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "figure.climbing")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!).opacity(0.5) : .white.opacity(0.3),
                                climb.difficulty != nil ? Color.gradeColor(for: climb.difficulty!).opacity(0.2) : .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: climb.difficulty != nil ? 2 : 1
                    )
            )
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                // Climb name with indicators
                HStack(spacing: 8) {
                    Text(climb.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Draft badge
                    if !climb.isEstablished {
                        Text("DRAFT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    // Published indicator
                    if climb.isEstablished {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Tick indicator
                    if climb.isTicked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                    
                    // Match indicator icon
                    ZStack {
                        Circle()
                            .stroke(climb.matchAllowed ? Color.green : Color.red, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "hands.clap.fill")
                            .font(.system(size: 10))
                            .foregroundColor(climb.matchAllowed ? .green : .red)
                        
                        if !climb.matchAllowed {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 24, height: 2)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
                
                Text(climb.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// Established Filter View
struct EstablishedFilterView: View {
    @Binding var minGrade: String?
    @Binding var maxGrade: String?
    @Environment(\.dismiss) var dismiss
    
    let grades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15"]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Min Grade Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Grade")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if minGrade != nil {
                                Button {
                                    minGrade = nil
                                } label: {
                                    Text("Clear")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 60), spacing: 12)
                        ], spacing: 12) {
                            ForEach(grades, id: \.self) { grade in
                                Button {
                                    minGrade = grade
                                } label: {
                                    Text(grade)
                                        .font(.headline)
                                        .foregroundColor(minGrade == grade ? .white : Color.gradeColor(for: grade))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(minGrade == grade ? Color.gradeColor(for: grade) : Color.white.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gradeColor(for: grade), lineWidth: minGrade == grade ? 2 : 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    
                    // Max Grade Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Maximum Grade")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if maxGrade != nil {
                                Button {
                                    maxGrade = nil
                                } label: {
                                    Text("Clear")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 60), spacing: 12)
                        ], spacing: 12) {
                            ForEach(grades, id: \.self) { grade in
                                Button {
                                    maxGrade = grade
                                } label: {
                                    Text(grade)
                                        .font(.headline)
                                        .foregroundColor(maxGrade == grade ? .white : Color.gradeColor(for: grade))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(maxGrade == grade ? Color.gradeColor(for: grade) : Color.white.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gradeColor(for: grade), lineWidth: maxGrade == grade ? 2 : 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    
                    // Clear All Button
                    if minGrade != nil || maxGrade != nil {
                        Button {
                            minGrade = nil
                            maxGrade = nil
                        } label: {
                            Text("Clear All Filters")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.6), Color.red.opacity(0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Filter Climbs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WallDetailView(
            wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!, climbs: []),
            onUpdate: { _ in }
        )
    }
}


//
//  Home_WallTests.swift
//  Home WallTests
//
//  Created by Ian Church on 10/28/25.
//

import XCTest
@testable import Home_Wall

final class Home_WallTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

//
//  Home_WallUITests.swift
//  Home WallUITests
//
//  Created by Ian Church on 10/28/25.
//

import XCTest

final class Home_WallUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

//
//  Home_WallUITestsLaunchTests.swift
//  Home WallUITests
//
//  Created by Ian Church on 10/28/25.
//

import XCTest

final class Home_WallUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
