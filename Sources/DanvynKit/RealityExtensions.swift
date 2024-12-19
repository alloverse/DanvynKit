//
//  Extensions.swift
//  Koja
//
//  Created by Nevyn Bengtsson on 2024-09-19.
//

import SwiftUI
import RealityKit

public extension SIMD3 where Scalar : FloatingPoint
{
    static var xAxis: SIMD3<Scalar> { get { return SIMD3<Scalar>(1, 0, 0)} }
    static var yAxis: SIMD3<Scalar> { get { return SIMD3<Scalar>(0, 1, 0)} }
    static var zAxis: SIMD3<Scalar> { get { return SIMD3<Scalar>(0, 0, 1)} }
}

public extension SimpleMaterial
{
    /// Create a nice singly-colored material with a random hue. Good for debugging/programmer's-art
    static func random(saturation: CGFloat = 0.8, brightness: CGFloat = 0.8, isMetallic: Bool = false) -> Self
    {
        return SimpleMaterial(color: Color(hue: .random(in: 0...1), saturation: saturation, brightness: brightness, alpha: 1.0), isMetallic: isMetallic)
    }
}

public extension EntityTargetValue<SpatialTapGesture.Value>
{
    ///* Get the 3D location of a `SpatialTapGesture` in the coordinate space of the entity being tapped, or one of its parents,
    /// in a cross-platform safe manner.
    ///
    /// Example:
    /// ```SpatialTapGesture()
    ///    .targetedToEntity(where: .has(FloorComponent.self))
    ///    .onEnded({ value in
    ///        guard let tappedPositionInRoom = value.location(in: roomRoot) ...
    /// ```
    func location(in coordinateSpaceOf: Entity) -> SIMD3<Float>?
    {
#if os(visionOS)
            //let globalPos = SIMD3<Float>(location3D)
            return convert(self.gestureValue.location3D, from: .local, to: coordinateSpaceOf)
#else
            guard let globalPos = unproject(location, from: .local, to: .scene) else { return nil }
            return coordinateSpaceOf.convert(position: globalPos, from: nil)
#endif
    }
}

public extension EntityTargetValue<DragGesture.Value>
{
    /// Get the 3D location of a `DragGesture` in the coordinate space of the entity being dragged on, or one of its parents,
    /// in a cross-platform safe manner. See also `EntityTargetValue<SpatialTapGesture.Value>.location(in:)`
    func location(in coordinateSpaceOf: Entity) -> SIMD3<Float>?
    {
#if os(visionOS)
            //let globalPos = SIMD3<Float>(location3D)
            return convert(self.gestureValue.location3D, from: .local, to: coordinateSpaceOf)
#else
            guard let globalPos = unproject(location, from: .local, to: .scene) else { return nil }
            return coordinateSpaceOf.convert(position: globalPos, from: nil)
#endif
    }
}

public extension Entity
{
    /// Search for a component of type T in the receiver, or in its parent, or any of its ancestors.
    func findAncestorComponent<T: Component>(ofType type: T.Type) -> T?
    {
        return components[type] ?? self.parent?.findAncestorComponent(ofType: type)
    }
}
