/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Loads and provides access to plant animations.
*/

import Foundation
import RealityKit
import ADCAssets
import SwiftUI
import Spatial

/// An object that loads and provides all the necessary animations for each plant model.
@MainActor
class CancerCellAnimationProvider: Sendable {
    static var shared = CancerCellAnimationProvider()
    
    /// A dictionary of the grow animations for each type of plant.
    public var growAnimations = [CancerComponent.CancerTypeKey: AnimationResource]()
    /// A dictionary of the celebration animations for each type of plant.
    public var celebrateAnimations = [CancerComponent.CancerTypeKey: AnimationResource]()
    /// A dictionary of the current animation controllers for each type of plant.
    public var currentGrowAnimations = [CancerComponent.CancerTypeKey: AnimationPlaybackController]()
    
    init() {
        Task { @MainActor in
            await withTaskGroup(of: CancerAnimationResult.self) { taskGroup in
                for cancerType in CancerComponent.CancerTypeKey.allCases {
                    taskGroup.addTask {
                        let growAnim = await self.generateGrowAnimationResource(for: cancerType)
                        let celeAnim = await self.generateCelebrateAnimationResource(for: cancerType)
                        return CancerAnimationResult(growAnim: growAnim, celebrateAnim: celeAnim, cancerType: cancerType)
                    }
                }
                for await result in taskGroup {
                    growAnimations[result.cancerType] = result.growAnim
                    celebrateAnimations[result.cancerType] = result.celebrateAnim
                }
            }
        }
    }
    
    /// Loads the grow animation for the given plant type.
    private func generateGrowAnimationResource(for cancerType: CancerComponent.CancerTypeKey) async -> AnimationResource {
        let sceneName = "Assets/plants/animations/\(cancerType.rawValue)_grow_anim"
        var ret: AnimationResource? = nil
        do {
            let rootEntity = try await Entity(named: sceneName, in: ADCAssetsBundle)
            rootEntity.forEachDescendant(withComponent: BlendShapeWeightsComponent.self) { entity, component in
                if let index = entity.animationLibraryComponent?.animations.startIndex {
                    ret = entity.animationLibraryComponent?.animations[index].value
                }
            }
            guard let ret else { fatalError("Animation resource unexpectedly nil.") }
            return ret
        } catch {
            fatalError("Error: \(error.localizedDescription)")
        }
    }
    
    /// Loads the celebration animation for the given plant type.
    private func generateCelebrateAnimationResource(for cancerType: CancerComponent.CancerTypeKey) async -> AnimationResource {
        let sceneName = "Assets/plants/animations/\(cancerType.rawValue)_celebrate_anim"
        var ret: AnimationResource? = nil
        do {
            let rootEntity = try await Entity(named: sceneName, in: ADCAssetsBundle)
             rootEntity.forEachDescendant(withComponent: BlendShapeWeightsComponent.self) { entity, component in
                 ret = entity.animationLibraryComponent?.defaultAnimation
             }
            guard let ret else { fatalError("Animation resource unexpectedly nil.") }
            return ret
        } catch {
            fatalError("Error: \(error.localizedDescription)")
        }
    }
}

@MainActor
public struct CancerAnimationResult: Sendable {
    var growAnim: AnimationResource
    var celebrateAnim: AnimationResource
    var cancerType: CancerComponent.CancerTypeKey
}
