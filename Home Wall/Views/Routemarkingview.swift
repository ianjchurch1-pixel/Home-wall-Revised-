//
//  Routemarkingview.swift
//  Home Wall
//
//  Hold marking view for marking climbing holds on wall images
//

import SwiftUI

struct RouteMarkingView: View {
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
        NavigationView {
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
            Hold(
                position: savedHold.position(imageSize: image.size, containerSize: containerSize),
                color: savedHold.holdColor,
                size: savedHold.size(containerSize: containerSize)
            )
        }
    }
    
    private func saveHolds() {
        let containerSize = CGSize(width: UIScreen.main.bounds.width, height: 500)
        
        let savedHolds = holds.map { hold in
            SavedHold(
                position: hold.position,
                color: hold.color,
                size: hold.size,
                imageSize: image.size,
                containerSize: containerSize
            )
        }
        
        onSave(savedHolds)
    }
}

#Preview {
    RouteMarkingView(
        image: UIImage(systemName: "photo")!,
        existingHolds: [],
        onSave: { _ in }
    )
}

// Backward compatibility alias
typealias HoldMarkingView = RouteMarkingView
