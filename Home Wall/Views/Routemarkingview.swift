import SwiftUI

struct RouteMarkingView: View {
    let wallImage: UIImage
    let wallName: String
    @Binding var isPresented: Bool
    
    @State private var holds: [Hold] = []
    @State private var boulderName: String = "" // For the popup after save
    @State private var currentColorIndex: Int = 2 // Start with blue (hands and feet)
    @State private var currentHoldSize: CGFloat = 36 // Default hold size
    @State private var selectedHoldId: UUID? = nil // Currently selected hold for editing
    @State private var showNamePopup = false
    @State private var showNameAlert = false
    @State private var imageSize: CGSize = .zero
    
    // 4 specific colors with meanings
    let holdColors: [(color: Color, name: String, hex: String)] = [
        (.green, "Start Holds", "00FF00"),
        (.blue, "Hands & Feet", "007AFF"),
        (.purple, "Feet Only", "AF52DE"),
        (.red, "Finish Holds", "FF3B30")
    ]
    
    var currentColor: Color {
        holdColors[currentColorIndex].color
    }
    
    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Mark Route")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        if holds.isEmpty {
                            showNameAlert = true
                        } else {
                            showNamePopup = true
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(hex: "16213e"))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Wall Image with Holds
                        ZStack {
                            GeometryReader { geometry in
                                Image(uiImage: wallImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onAppear {
                                                imageSize = geo.size
                                            }
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onEnded { value in
                                                addHold(at: value.location)
                                            }
                                    )
                                    .overlay(
                                        ForEach(holds) { hold in
                                            HoldMarker(
                                                hold: hold,
                                                isSelected: selectedHoldId == hold.id,
                                                onTap: {
                                                    selectHold(hold)
                                                },
                                                onDelete: {
                                                    removeHold(hold)
                                                }
                                            )
                                        }
                                    )
                            }
                            .aspectRatio(wallImage.size.width / wallImage.size.height, contentMode: .fit)
                        }
                        .background(Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Instructions
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundColor(.blue)
                                Text("Tap wall to add holds, tap holds to select")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Adjust color & size of selected hold")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Hold Color Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text(selectedHoldId != nil ? "Selected Hold Color" : "New Hold Color")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                ForEach(0..<holdColors.count, id: \.self) { index in
                                    Button(action: {
                                        if selectedHoldId != nil {
                                            // Update selected hold color
                                            updateSelectedHoldColor(colorIndex: index)
                                        } else {
                                            // Set color for new holds
                                            currentColorIndex = index
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(holdColors[index].color)
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                            
                                            Text(holdColors[index].name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if currentColorIndex == index {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(holdColors[index].color)
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            currentColorIndex == index ?
                                            holdColors[index].color.opacity(0.2) : Color.white.opacity(0.05)
                                        )
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Hold Size Adjuster
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(selectedHoldId != nil ? "Selected Hold Size" : "New Hold Size")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(Int(currentHoldSize))pt")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Slider(value: $currentHoldSize, in: 20...80, step: 2)
                                    .accentColor(.blue)
                                    .onChange(of: currentHoldSize) { newSize in
                                        if selectedHoldId != nil {
                                            updateSelectedHoldSize(newSize: newSize)
                                        }
                                    }
                                
                                Image(systemName: "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Hold Count
                        HStack {
                            Image(systemName: "circle.grid.3x3.fill")
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(holds.count) holds")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            if !holds.isEmpty {
                                Button(action: {
                                    holds.removeAll()
                                    selectedHoldId = nil
                                }) {
                                    Text("Clear All")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
        }
        .alert("Add Holds First", isPresented: $showNameAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please add at least one hold to your route")
        }
        .alert("Name Your Boulder", isPresented: $showNamePopup) {
            TextField("e.g., Crimpy V4", text: $boulderName)
            Button("Cancel", role: .cancel) {
                boulderName = ""
            }
            Button("Save") {
                saveRoute()
            }
        } message: {
            Text("Give your boulder a name")
        }
    }
    
    private func addHold(at location: CGPoint) {
        // Deselect current hold when adding new one
        selectedHoldId = nil
        
        let hold = Hold(position: location, colorHex: holdColors[currentColorIndex].hex, size: currentHoldSize)
        holds.append(hold)
    }
    
    private func selectHold(_ hold: Hold) {
        // If already selected, deselect
        if selectedHoldId == hold.id {
            selectedHoldId = nil
        } else {
            // Select hold and update UI controls to match hold's properties
            selectedHoldId = hold.id
            currentHoldSize = hold.size
            
            // Update color index to match hold's color
            if let colorIndex = holdColors.firstIndex(where: { $0.hex == hold.colorHex }) {
                currentColorIndex = colorIndex
            }
        }
    }
    
    private func updateSelectedHoldColor(colorIndex: Int) {
        if let index = holds.firstIndex(where: { $0.id == selectedHoldId }) {
            holds[index].colorHex = holdColors[colorIndex].hex
            currentColorIndex = colorIndex
        }
    }
    
    private func updateSelectedHoldSize(newSize: CGFloat) {
        if let index = holds.firstIndex(where: { $0.id == selectedHoldId }) {
            holds[index].size = newSize
        }
    }
    
    private func removeHold(_ hold: Hold) {
        holds.removeAll { $0.id == hold.id }
        if selectedHoldId == hold.id {
            selectedHoldId = nil
        }
    }
    
    private func saveRoute() {
        // TODO: Save route to wall data
        print("Route saved: \(boulderName) with \(holds.count) holds")
        boulderName = "" // Reset for next time
        isPresented = false
    }
}

// MARK: - Hold Marker View
struct HoldMarker: View {
    let hold: Hold
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var holdColor: Color {
        Color(hex: hold.colorHex)
    }
    
    var body: some View {
        ZStack {
            // Selection indicator (outer ring)
            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: hold.size + 12, height: hold.size + 12)
            }
            
            // Hold circle
            Circle()
                .stroke(holdColor, lineWidth: 4)
                .frame(width: hold.size, height: hold.size)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
        .position(hold.position)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onDelete()
        }
    }
}

// Preview
struct RouteMarkingView_Previews: PreviewProvider {
    static var previews: some View {
        RouteMarkingView(
            wallImage: UIImage(systemName: "photo")!,
            wallName: "My Wall",
            isPresented: .constant(true)
        )
    }
}
