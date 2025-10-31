import SwiftUI

@main
struct Home_WallApp: App {
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            if isLoading {
                LoadingView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLoading = false
                        }
                    }
            } else {
                DashboardView()
            }
        }
    }
}
