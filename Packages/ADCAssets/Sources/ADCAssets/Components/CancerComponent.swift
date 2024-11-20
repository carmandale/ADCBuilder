/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A component that marks an entity as a plant.
*/

import Foundation
import RealityKit

public struct CancerComponent: Component, Codable {
    public enum CancerTypeKey: String, CaseIterable, Identifiable, Codable, Sendable {
        case coffeeBerry
        case poppy
        case yucca
        
        public var id: Self { self }
    }
    
    public var interactedWith: Bool = false
    
    public var plantType: CancerTypeKey = .coffeeBerry
    
    public init() {
        
    }
}
