/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Loads and provides access to robot parts and materials.
*/

import Foundation
import RealityKit
import ADCAssets

/// A class that loads and provides the robot entities and materials.
@MainActor
final public class ADCProvider: Sendable {
    
    static let shared = ADCProvider()
    
    private var loadCompleteListeners = [(ADCProvider) -> Void]()
    
    var materials = [ADCPart: [ADCMaterial: [ShaderGraphMaterial]]]()
    var robotParts = [ADCPart: [Entity]]()

    var robotsLoaded = false
    
    init() {
        Task { [self] in
            // Load models and meshes concurrently
            await withTaskGroup(of: ADCPartLoadResult.self) { taskGroup in
                await loadRobotParts(taskGroup: &taskGroup)
                
                for await result in taskGroup {
                    Task { @MainActor in
                        var parts = robotParts[result.type] ?? [Entity]()
                        parts.append(result.entity)
                        parts.sort { left, right in
                            return left.name.compare(right.name) == ComparisonResult.orderedAscending
                        }
                        robotParts[result.type] = parts
                    }
                }
            }

            await withTaskGroup(of: RobotMaterialResult.self) { taskGroup in
                await loadRobotMaterials(taskGroup: &taskGroup)
                
                for await result in taskGroup {
                    for partKey in result.materials.keys {
                        if self.materials[partKey] == nil {
                            self.materials[partKey] = [ADCMaterial: [ShaderGraphMaterial]]()
                        }
                        if let shaders = result.materials[partKey] {
                            if self.materials[partKey]?[result.material] == nil {
                                self.materials[partKey]?[result.material] = [ShaderGraphMaterial]()
                            }
                            self.materials[partKey]?[result.material]?.append(contentsOf: shaders)
                        }
                    }
                    
                }

                robotsLoaded = true
                for listener in loadCompleteListeners {
                    listener(self)
                }
            }
        }
    }

    public func listenForLoadComplete(completion: @escaping (ADCProvider) -> Void) {
        loadCompleteListeners.append(completion)
        if robotsLoaded {
            completion(self)
        }
    }
    
    /// Returns the mesh entity corresponding to the provided robot part and index.
    func getMesh(forPart part: ADCPart, index: Int) -> Entity {
        guard let parts = robotParts[part] else { fatalError("Failed to find expected robot part.") }
        let entity = parts[index]
        entity.components.set(InputTargetComponent())
        return entity
    }
    
    /// Returns the mesh entity corresponding to the provided robot part and name.
    func getMesh(forPart part: ADCPart, name: String) -> Entity {
        guard let parts = robotParts[part] else { fatalError("Failed to find expected robot part.") }
        guard let entity = parts.first(where: { $0.name == name }) else { fatalError() }
        entity.components.set(InputTargetComponent())
        return entity
    }
    
    /// Returns the shader graph material corresponding to the provided robot part, material type, and index.
    func getMaterial(forPart part: ADCPart, material: ADCMaterial, index: Int) -> ShaderGraphMaterial {
        guard let materials = materials[part]?[material] else { fatalError("Failed ot find expected shader graph material.") }
        return materials[index]
    }
}