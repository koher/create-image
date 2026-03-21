import SwiftUI

@main
struct CreateImageRunner: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("Generating image...")
                .padding(24)
                .frame(minWidth: 300, minHeight: 100)
        }
    }
}
