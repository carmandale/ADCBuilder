/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that shows the score in explore mode and provides buttons to end or start over.
*/

import SwiftUI
import ADCAssets

/// A view that shows the score in explore mode and provides buttons to end or start over.
///
/// In visionOS this view appears as an ornament that's attached to the volumetric window.
/// For all other platforms this view appears as an overlay on top of the window during explore mode.
struct OrnamentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) var openWindow
    
    #if os(visionOS)
    let topFontStyle: Font = .title
    let bottomFontStyle: Font = .body
    #else
    let topFontStyle: Font = .subheadline
    let bottomFontStyle: Font = .caption
    #endif
    
    var body: some View {
        #if os(visionOS)
        HStack(spacing: 25) {
            scoreGauge
            scoreReport
        }
        .padding(20)
        .frame(minWidth: 425)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
        #else
        HStack(spacing: 20) {
            scoreGauge
            scoreReport
        }
        .padding()
        .frame(maxHeight: 100)
        #endif
    }
    
    var scoreGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.ringBlue, lineWidth: 8)
                .opacity(0.25)
            Circle()
                .trim(from: 0, to: CGFloat(appState.adc?.cancerCellsFound ?? 0) / CGFloat(appState.totalCancerCells))
                .stroke(Color.ringBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(appState.adc?.cancerCellsFound ?? 0)",
                 comment: "The number of cancer cells destroyed so far.")
                .foregroundStyle(Color.ringBlue)
                .font(.title)
                .padding()
        }
        .animation(.spring(response: 0.6, dampingFraction: 1.0, blendDuration: 1.0), value: UUID())
    }
    
    var scoreReport: some View {
        VStack(alignment: .leading) {
            if appState.adc?.cancerCellsFound ?? 0 == appState.totalCancerCells {
                Text("Awesome job!",
                     comment: "Congratulating the player for killing all of the cancer cells.")
                    .font(topFontStyle)
                    .foregroundStyle(.white)
                Text("You destroyed \(appState.totalCancerCells) cancer cells",
                     comment: "Telling the player how many cancer cells they destroyed.")
                    .foregroundStyle(.white)
                    .opacity(0.5)
                    .font(bottomFontStyle)
            } else {
                Text("Greenhouse score",
                     comment: "Label for the score board.")
                .font(topFontStyle)
                    .foregroundStyle(.white)
                Text("Propagate plants to earn points",
                     comment: "Instructions for the user telling them to plant flowers to earn points.")
                    .lineLimit(2)
                    .foregroundStyle(.white)
                    .opacity(0.5)
                    .font(bottomFontStyle)
            }
           
            HStack {
                Button {
                    appState.resetExploration()
                } label: {
                    Text("Replay",
                         comment: "The label for the button that starts the game over.")
                }
                Button {
                    appState.exitExploration()
                    #if os(visionOS)
                    openWindow(id: "ADCCreation")
                    #endif
                } label: {
                    Text("Exit Game",
                         comment: "The label for the button that goes back to the robot customization screen.")
                }
            }
            .controlSize(.small)
        }
    }
}

#Preview(traits: .sampleAppState) {
    OrnamentView()
}
