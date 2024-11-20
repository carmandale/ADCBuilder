/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The global app state.
*/

import Foundation
import RealityKit
import ADCAssets
import SwiftUI
import Spatial

/// An enumeration that tracks the current phase of the app.
public enum AppPhase: CaseIterable, Codable, Identifiable, Sendable {
    case waitingToStart // Waiting to start the game
    case loadingAssets // Loading assets from the Reality Composer Pro project
    case playing // Creating the robot.
    case exploration // Exploring the volume.
    
    public var id: Self { self }
}

/// An object that maintains app-wide state.
@Observable
@MainActor
public class AppState {
    
    /// The root entity for the reality view in which robot creation happens.
    var creationRoot = Entity()
    /// The root entity for the exploration `RealityView`.
    var explorationRoot = Entity()
    
    /// The parent entity for the exploration environment.
    var explorationEnvironment: Entity? = nil
    
    var selectedBodyIndex: Int = 1
        
    var adcData: ADCData!
    
    /// A Boolean value that indicates whether the robot is celebrating after propagating every plant.
    var celebrating: Bool = false
    
    let materialColorParameterName = "mat_switch"
    let materialLightsParameterName = "light_switch"
    let materialFaceParameterName = "face_switch"
    
    /// The finished and built robot. Intialized after creation phase.
    var adc: ADC? = nil
    
    /// The current phase of the app.
    var phase = AppPhase.waitingToStart
    
    /// The orientation of the robot model in the creation screen.
    var adcCreationOrientation: Rotation3D = Rotation3D()
    
    var isRotating = false
    
    /// The camera establishing the rendering perspective for the creation screen `RealityView` for platforms other than visionOS.
    let adcCamera = PerspectiveCamera()
    /// The camera establishing the rendering perspective for the exploration screen `RealityView` for platforms other than visionOS.
    var explorationCamera = PerspectiveCamera()
        
    var totalCancerCells: Int = 3
    
    init() {
        // Warm up the provider and load the assets
        let provider = ADCProvider.shared
        _ = CancerCellAnimationProvider.shared
       
        phase = .loadingAssets
        provider.listenForLoadComplete() { provider in
            self.phase = .playing
            self.adcData = ADCData()
            
            #if os(macOS) || os(iOS)
            self.creationRoot.scale = SIMD3<Float>(repeating: 0.027)
            self.creationRoot.position = SIMD3<Float>(x: -0, y: -0.022, z: -0.05)
            #else
            self.creationRoot.scale = SIMD3<Float>(repeating: 0.23)
            self.creationRoot.position = SIMD3<Float>(x: -0.02, y: -0.175, z: -0.05)
            #endif

            ADCPart.allCases.forEach { part in
                if let mesh = self.adcData.meshes[part] {
                    if part == .payload {
                        self.setMesh(part: part, index: 0)
                    } else {
                        self.setMesh(part: part, index: 1)
                    }
                    self.setMaterial(part: part, material: .plastic)
                    self.creationRoot.addChild(mesh)
                }
            }
            self.setFace(face: .circle)
            self.updateADCAppearance()
        }
    }

    /// Starts the game.
    ///
    /// Call this to setup the robot model after the app's intial setup finishes.
    public func startGame() {
        updateADCAppearance()
        adcCamera.transform.translation = SIMD3(x: 0, y: 0.1, z: 0.5)
    }
    
    /// Returns the entity for the provided robot part.
    public func getSelectedMesh(_ part: ADCPart) -> Entity? {
        guard let mesh = adcData.meshes[part] else { fatalError("Unexpectedly missing mesh.") }
        return mesh
    }
    
    /// Modifies the backpack entity so that the correct strap is shown based on the current body model.
    private func showCorrectStrap() {
        if let backpack = adcData.meshes[.payload],
           let body = adcData.meshes[.linker] {
            if let strapNum = body.name.last {
                backpack.findEntity(named: "strap_B1")?.isEnabled = false
                backpack.findEntity(named: "strap_B2")?.isEnabled = false
                backpack.findEntity(named: "strap_B3")?.isEnabled = false
                backpack.findEntity(named: "strap_B\(strapNum)")?.isEnabled = true
            }
        }
    }
    
    /// Sets the mesh for the given robot part based on index.
    public func setMesh(part: ADCPart, index: Int) {
        if part == .linker {
            selectedBodyIndex = index
        }
        let mesh = ADCProvider.shared.getMesh(forPart: part, index: index)
        adcData.meshes[part]?.removeFromParent()
        adcData.meshes[part] = mesh
        creationRoot.addChild(mesh)
        
        updateADCAppearance()
    }
    
    /// Sets the mesh for the given robot part based on name.
    public func setMesh(part: ADCPart, name: String) {
        let mesh = ADCProvider.shared.getMesh(forPart: part, name: name)
        adcData.meshes[part]?.removeFromParent()
        adcData.meshes[part] = mesh
        creationRoot.addChild(mesh)
        
        updateADCAppearance()
    }
    
    /// Sets the given robot part to the given material.
    public func setMaterial(part: ADCPart, material: ADCMaterial) {
        guard let shape = adcData.shapeIndices[part] else { fatalError("Failed to find expected shape.") }
        let shader = ADCProvider.shared.getMaterial(forPart: part, material: material, index: shape   )
        let mesh = getSelectedMesh(part)

        mesh?.forEachDescendant(withComponent: ModelComponent.self) {entity, component in
            var modelComponent = component
            modelComponent.materials = modelComponent.materials.map {
                guard let material = $0 as? ShaderGraphMaterial else { return $0 }
                if material.name!.contains("_\(part.suffix)") {
                    return shader
                } else {
                    return material
                }
            }
            entity.components.set(modelComponent)
        }
        
        adcData.materials[part] = material
        updateADCAppearance()
    }
    
    /// Sets the color of the material of the given robot part.
    public func setColorIndex(part: ADCPart, colorIndex: Int) {
        adcData.materialColorIndex[part] = colorIndex
        updateADCAppearance()
    }
    
    /// Sets the robot's face.
    public func setFace(face: RobotFace) {
        adcData.face = face
        updateADCAppearance()
    }
    
    /// Sets the light color of the given robot part.
    public func setLightColor(part: ADCPart, lightColor: ADCLightColor) {
        adcData.lightColor[part] = lightColor
        updateADCAppearance()
    }
   
    /// Updates the robot's appearance based on current robot data.
    private func updateADCAppearance() {
        for part in ADCPart.allCases {
            // Make sure the right mesh is in the RealityKit Scene
            guard let mesh = adcData.meshes[part] else { fatalError("Failed to find robot mesh.") }
            
            mesh.forEachDescendant(withComponent: ModelComponent.self) {entity, component in
                var modelComponent = component
                do {
                    modelComponent.materials = try modelComponent.materials.map {
                        
                        // Update the part colors
                        guard var material = $0 as? ShaderGraphMaterial else { return $0 }
                        
                        // Change material color
                        if material.parameterNames.contains(materialColorParameterName) {
                            guard let colorIndex = adcData.materialColorIndex[part] else { fatalError("Unexpected nil color index.") }
                            try material.setParameter(name: materialColorParameterName,
                                                      value: MaterialParameters.Value.int(Int32(colorIndex)))
                        }
                        // Update the lights
                        if material.parameterNames.contains(materialLightsParameterName) {
                            guard let colorIndex = adcData.lightColor[part]?.index else { fatalError("Unexpected nil color index.") }
                            try material.setParameter(name: materialLightsParameterName,
                                                      value: MaterialParameters.Value.int(Int32(colorIndex)))
                        }
                        // Update the face plate
                        if part == .antibody {
                            if material.parameterNames.contains(materialFaceParameterName) {
                                try material.setParameter(name: materialFaceParameterName,
                                                          value: MaterialParameters.Value.int(Int32(adcData.face.index)))
                            }
                        }
                        return material
                    }
                    entity.components.set(modelComponent)
                } catch {
                    fatalError("Unable to update robot appearance.")
                }
            }
            showCorrectStrap()
        }
    }
    
    /// Randomizes the mesh, material, material color, and light color for each robot part.
    public func randomizeSelectedRobot() {
        ADCPart.allCases.forEach { part in
            if self.adcData.meshes[part] != nil {
                let upperPartIndex = ADCPart.numberOfParts - 1
                setMesh(part: part, index: Int.random(in: 0...upperPartIndex))
                setMaterial(part: part, material: ADCMaterial.randomMaterial)
                adcData.materialColorIndex[part] = Int.random(in: 0...upperPartIndex)
                adcData.lightColor[part] = .red
                updateADCAppearance()
            }
        }
    }
    
    /// Restores the robot in the creator when exiting exploration and re-opening the character creator window.
    public func restoreRobotInCreator() {
        guard let head = adcData.meshes[.antibody],
              let body = adcData.meshes[.linker],
              let backpack = adcData.meshes[.payload] else { fatalError("Failed to find robot mesh.") }
        
        setMesh(part: .antibody, name: head.name)
        setMesh(part: .linker, name: body.name)
        setMesh(part: .payload, name: backpack.name)
        updateADCAppearance()
    }
    
    /// Resets the robot to the base style.
    public func resetSelectedRobot() {
        ADCPart.allCases.forEach { part in
            if part == .payload {
                setMesh(part: part, index: 0)
            } else {
                setMesh(part: part, index: 1)
            }
            
            setMaterial(part: part, material: .plastic)
            adcData.lightColor[part] = .white
            adcData.materialColorIndex[part] = 0
            adcData.face = .circle
            updateADCAppearance()
        }
    }
    
    /// Starts the celebration after the robot finishes propagating all the plants.
    public func startCelebration() {
        celebrating = true
        explorationEnvironment?.forEachDescendant(withComponent: CancerComponent.self) { plantEntity, plantComponent in
            plantEntity.forEachDescendant(withComponent: BlendShapeWeightsComponent.self) { blendEntity, blendComponent in
                if let celebrateAnim = CancerCellAnimationProvider.shared.celebrateAnimations[plantComponent.plantType] {
                    blendEntity.playAnimation(celebrateAnim.repeat())
                }
            }
        }
    }
}
