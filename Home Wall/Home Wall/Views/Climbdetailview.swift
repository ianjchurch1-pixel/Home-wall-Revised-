//
//  ClimbDetailView.swift
//  Home Wall
//
//  Individual climb detail with hold marking, ticking, and beta videos
//

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
            TickSheetView(
                climb: $currentClimb,
                selectedGrade: $selectedGrade,
                selectedRating: $selectedRating,
                onUpdate: onUpdate
            )
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

// Tick Sheet View
struct TickSheetView: View {
    @Binding var climb: Climb
    @Binding var selectedGrade: String
    @Binding var selectedRating: Int
    let onUpdate: (Climb) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if climb.isTicked {
                        tickedView
                    } else {
                        untickedView
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle(climb.isTicked ? "Climb Sent" : "Tick Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if climb.isTicked {
                        Button {
                            climb.tickDates = []
                            climb.difficulty = nil
                            climb.rating = nil
                            onUpdate(climb)
                            dismiss()
                        } label: {
                            Text("Clear All")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button("Tick") {
                            climb.tickDates.append(Date())
                            climb.difficulty = selectedGrade
                            climb.rating = selectedRating
                            onUpdate(climb)
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var tickedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Climb Sent! 🎉")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Send count
            if climb.sendCount > 1 {
                Text("\(climb.sendCount) sends")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            Text("Grade")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            
            Text(climb.difficulty ?? "V0")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            // Star rating display
            if let rating = climb.rating {
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
                climb.tickDates.append(Date())
                onUpdate(climb)
                dismiss()
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
    }
    
    private var untickedView: some View {
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
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            ClimbDetailView(
                wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!),
                climb: Climb(name: "Easy Route", holds: []),
                onUpdate: { _ in },
                onDelete: { }
            )
        }
    } else {
        NavigationView {
            ClimbDetailView(
                wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!),
                climb: Climb(name: "Easy Route", holds: []),
                onUpdate: { _ in },
                onDelete: { }
            )
        }
    }
}
