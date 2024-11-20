/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main app class.
*/

import SwiftUI
import Spatial
import OSLog
import ADCAssets

let logger = Logger(subsystem: "com.apple-samplecode.ADCBuilder", category: "general")

@main
struct ADCBuilderApp: App {
    @Environment(\.dismissWindow) var dismissWindow
    
    /// Pass the app's state object to all SwiftUI views as an environment object.
    @State private var appState = AppState()

    /// The initial 3D dimensions of the volumetric window.
    private var initialVolumeSize: Size3D = Size3D(width: 900, height: 500, depth: 900)
    
    /// The initial 2D dimensions of the content view window.
    private var initialWindowSize: CGSize = CGSize(width: 1166, height: 680)

    var body: some Scene {
        WindowGroup(id: "ADCCreation") {
            ContentView()
                .environment(appState)
                .onAppear {
                    #if os(visionOS)
                    dismissWindow(id: "ADCExploration")
                    #elseif os(macOS)
                    NSWindow.allowsAutomaticWindowTabbing = false
                    #endif
                }
        }
        .defaultSize(initialWindowSize)
        #if os(macOS)
        .commandsRemoved()
        .commands {
            CommandGroup(after: .newItem) {
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text("Quit ADCBuilder", comment: "An action to quit the ADCBuilder app.")
                }
                .keyboardShortcut("Q")
            }
        }
        #endif
        
        #if os(visionOS)
        WindowGroup(id: "ADCExploration") {
            GeometryReader3D { geometry in
                ExplorationView()
                    .volumeBaseplateVisibility(.visible)
                    .environment(appState)
                    .scaleEffect(geometry.size.width / initialVolumeSize.width)
                    .ornament(attachmentAnchor: .scene(.topBack)) {
                        OrnamentView()
                            .environment(appState)
                    }
                    .onAppear {
                        dismissWindow(id: "ADCCreation")
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        guard let robot = appState.adc else { return }
                        robot.speedScale = Float(newSize.width / initialVolumeSize.width)
                    }
            }
        }
        .windowStyle(.volumetric)
        .defaultWorldScaling(.dynamic)
        .defaultSize(initialVolumeSize)
        #endif
    }
    
    init() {
        CancerComponent.registerComponent()
        JointPinComponent.registerComponent()
        JointPinSystem.registerSystem()
    }
}
