import SwiftUI

struct WallSetupView: View {
    let wallImage: UIImage
    @Binding var isPresented: Bool
    
    @State private var wallName: String = ""
    @State private var showNameAlert: Bool = false
    @State private var showRouteMarking: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Wall Image Preview
                    Image(uiImage: wallImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .padding()
                    
                    // Setup Form
                    VStack(spacing: 24) {
                        // Wall Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wall Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("e.g., Home Spray Wall", text: $wallName)
                                .font(.system(size: 16))
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Next, you'll be able to mark holds and create routes on this wall")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Continue Button
                        Button(action: {
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            
                            print("Create Wall button pressed. Wall name: '\(wallName)'")
                            
                            if wallName.isEmpty {
                                showNameAlert = true
                            } else {
                                print("Navigating to RouteMarkingView")
                                showRouteMarking = true
                            }
                        }) {
                            Text("Create Wall")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        
                        // Cancel Button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Setup Wall")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .alert("Wall Name Required", isPresented: $showNameAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a name for your wall")
            }
            .fullScreenCover(isPresented: $showRouteMarking) {
                RouteMarkingView(
                    image: wallImage,
                    existingHolds: [],
                    onSave: { savedHolds in
                        // Holds are saved, dismiss the view
                        showRouteMarking = false
                    }
                )
            }

        }
    }
}

// Preview
struct WallSetupView_Previews: PreviewProvider {
    static var previews: some View {
        WallSetupView(
            wallImage: UIImage(systemName: "photo")!,
            isPresented: .constant(true)
        )
    }
}
