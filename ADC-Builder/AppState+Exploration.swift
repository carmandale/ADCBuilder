/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions to global app state with animation-related functions.
*/

import Foundation
import RealityKit
import ADCAssets
import SwiftUI
import Spatial

extension AppState {
    
    /// Prepares the app to transition from the creation phase to the exploration phase.
    public func prepareForExploration() {
        do {
            
            // Load the environment entity and set the blendshape weight mapping for each entity with a BlendShapeWeightsComponent.
            let map = try Entity.load(named: "scenes/volume", in: ADCAssetsBundle)
            self.explorationEnvironment = map
            self.explorationRoot.addChild(map)
            explorationEnvironment!.forEachDescendant(withComponent: BlendShapeWeightsComponent.self) { entity, component in
                guard let modelComponent = entity.modelComponent else { fatalError("Entity must be model entity. No ModelComponent found.") }
                let meshResource = modelComponent.mesh
                let blendShapeWeightsMapping = BlendShapeWeightsMapping(meshResource: meshResource)
                var blendComponent = BlendShapeWeightsComponent(weightsMapping: blendShapeWeightsMapping)
                blendComponent.weightSet[0].weights = BlendShapeWeights([0, 1, 0, 0, 0, 0, 0])
                entity.components.set(blendComponent)
            }
        } catch {
            fatalError("Error loading map: \(error.localizedDescription)")
        }
        
        // Remove each robot body part in the creation view from its parent, then reparent it to the environment.
        for mesh in adcData.meshes.values {
            mesh.removeFromParent()
        }
        
        guard let head = adcData.meshes[.antibody],
              let body = adcData.meshes[.linker],
              let backpack = adcData.meshes[.payload],
        let explorationEnvironment = explorationEnvironment else { fatalError("Error retrieving exploration environment.") }
        
        let robot = ADC(head: head, body: body, backpack: backpack, appState: self)
        self.adc = robot
        explorationCamera = PerspectiveCamera()
        explorationCamera.transform.translation = SIMD3(x: 0, y: 0.2, z: 0.4)
        let cameraTilt = -0.5
        let rotationAngle = Angle2D(radians: cameraTilt)
        let rotation = Rotation3D(angle: rotationAngle, axis: RotationAxis3D.x)
        let startOrientation = Rotation3D()
        let newOrientation = startOrientation.rotated(by: rotation)
        explorationCamera.setOrientation(.init(newOrientation), relativeTo: nil)
        
        explorationRoot.addChild(robot.characterParent)
        explorationRoot.addChild(explorationEnvironment)
        explorationRoot.scale = SIMD3<Float>(repeating: 0.7)
    }
    
    /// Resets the environment so that no plants have been collected and the robot is back in the intial position.
    public func resetExploration() {
        adc?.cancerCellsFound = 0
        adc?.animationState.transition(to: .idle)
        celebrating = false
        explorationRoot.forEachDescendant(withComponent: CancerComponent.self) { entity, component in
            var cancerCellComponent = component
            cancerCellComponent.interactedWith = false
            entity.components.set(cancerCellComponent)
            entity.stopAllAnimations(recursive: true)
        }
        explorationEnvironment!.forEachDescendant(withComponent: BlendShapeWeightsComponent.self) { entity, component in
            Task { @MainActor [entity] in
                entity.components[BlendShapeWeightsComponent.self]!.weightSet[0].weights = BlendShapeWeights([0, 1, 0, 0, 0, 0, 0])
            }
        }
        adc?.characterParent.teleportCharacter(to: [0, 0.065, 0], relativeTo: explorationEnvironment)
    }
    
    /// Exits the exploration phase of the app and return to the creation view.
    public func exitExploration() {
        if let bodies = ADCProvider.shared.robotParts[.linker] {
            for body in bodies {
                body.stopAllAnimations()
            }
        }

        adc?.animationState = .idle
        adc?.antibody.removeFromParent()
        adc?.linker.removeFromParent()
        adc?.payload.removeFromParent()
        
        adc?.antibody.transform.translation = .zero
        adc?.antibody.transform.rotation = simd_quatf()
        adc?.linker.transform.translation = .zero
        adc?.linker.transform.rotation = simd_quatf()
        adc?.payload.transform.translation = .zero
        adc?.payload.transform.rotation = simd_quatf()
       
        if let skeleton = adc?.linker.findEntity(named: "rig_grp") {
            skeleton.jointPinComponent = nil
        }
        
        let children = explorationRoot.children
        for child in children {
            child.removeFromParent()
        }
        
        explorationEnvironment = nil
    
        restoreRobotInCreator()
        phase = .playing
    }
}
