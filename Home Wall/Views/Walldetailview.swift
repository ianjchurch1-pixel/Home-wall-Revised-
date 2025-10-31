//
//  WallDetailView.swift
//  Home Wall
//
//  Wall detail view showing all climbs on a wall
//

import SwiftUI
import UniformTypeIdentifiers

struct WallDetailView: View {
    let wall: ClimbingWall
    let onUpdate: (ClimbingWall) -> Void
    
    @State private var currentWall: ClimbingWall
    @State private var showDeleteAlert = false
    @State private var climbToDelete: Climb?
    @State private var showNewClimbAlert = false
    @State private var newClimbName = ""
    @Environment(\.dismiss) var dismiss
    
    init(wall: ClimbingWall, onUpdate: @escaping (ClimbingWall) -> Void) {
        self.wall = wall
        self.onUpdate = onUpdate
        self._currentWall = State(initialValue: wall)
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
            
            if currentWall.climbs.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "figure.climbing")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("No Climbs Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Add your first climb to this wall")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        showNewClimbAlert = true
                    } label: {
                        Label("Add Climb", systemImage: "plus.circle.fill")
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
                // List of climbs
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(currentWall.climbs) { climb in
                            NavigationLink {
                                ClimbDetailView(
                                    wall: currentWall,
                                    climb: climb,
                                    onUpdate: { updatedClimb in
                                        updateClimb(updatedClimb)
                                    },
                                    onDelete: {
                                        climbToDelete = climb
                                        showDeleteAlert = true
                                    }
                                )
                            } label: {
                                ClimbRowView(climb: climb)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(currentWall.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewClimbAlert = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        .alert("New Climb", isPresented: $showNewClimbAlert) {
            TextField("Climb name", text: $newClimbName)
            Button("Cancel", role: .cancel) {
                newClimbName = ""
            }
            Button("Create") {
                createClimb()
            }
        } message: {
            Text("Give this climb a name")
        }
        .alert("Delete Climb", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let climb = climbToDelete {
                    deleteClimb(climb)
                }
            }
        } message: {
            Text("Are you sure you want to delete this climb? This action cannot be undone.")
        }
    }
    
    private func createClimb() {
        let climbName = newClimbName.isEmpty ? "Climb \(currentWall.climbs.count + 1)" : newClimbName
        let newClimb = Climb(name: climbName)
        currentWall.climbs.append(newClimb)
        
        // Save the updated wall
        onUpdate(currentWall)
        
        // Reset
        newClimbName = ""
    }
    
    private func updateClimb(_ updatedClimb: Climb) {
        if let index = currentWall.climbs.firstIndex(where: { $0.id == updatedClimb.id }) {
            currentWall.climbs[index] = updatedClimb
            
            // Save the updated wall
            onUpdate(currentWall)
        }
    }
    
    private func deleteClimb(_ climb: Climb) {
        currentWall.climbs.removeAll { $0.id == climb.id }
        
        // Save the updated wall
        onUpdate(currentWall)
        
        climbToDelete = nil
    }
}

// Row view for each climb
struct ClimbRowView: View {
    let climb: Climb
    
    var body: some View {
        HStack(spacing: 15) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
            
            // Climb info
            VStack(alignment: .leading, spacing: 6) {
                Text(climb.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    // Hold count
                    if !climb.holds.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                            Text("\(climb.holds.count) holds")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Grade (if ticked)
                    if let grade = climb.difficulty {
                        Text(grade)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.gradeColor(for: grade))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gradeColor(for: grade).opacity(0.2))
                            )
                    }
                    
                    // Match indicator
                    if climb.isEstablished {
                        HStack(spacing: 2) {
                            Image(systemName: "hands.clap.fill")
                                .font(.system(size: 8))
                            if !climb.matchAllowed {
                                Image(systemName: "slash.circle.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(climb.matchAllowed ? .green : .red)
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
    
    private var statusColor: Color {
        if climb.isTicked {
            return .green
        } else if climb.isEstablished {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var statusIcon: String {
        if climb.isTicked {
            return "checkmark.circle.fill"
        } else if climb.isEstablished {
            return "flag.fill"
        } else {
            return "pencil.circle.fill"
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            WallDetailView(
                wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!),
                onUpdate: { _ in }
            )
        }
    } else {
        NavigationView {
            WallDetailView(
                wall: ClimbingWall(name: "Test Wall", image: UIImage(systemName: "photo")!),
                onUpdate: { _ in }
            )
        }
    }
}
