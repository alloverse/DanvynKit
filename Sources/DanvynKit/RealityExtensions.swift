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

/// RealityView vends different types for `content` on macOS and visionOS. Unify them to avoid `if os(visionOS)` all over the code base.
public extension RealityViewContentProtocol
{
    func project(point: SIMD3<Float>, to space: some CoordinateSpaceProtocol) -> CGPoint?
    {
#if os(visionOS)
        return nil
#else
        let actualSelf = self as! RealityViewCameraContent
        return actualSelf.project(point: point, to: space)
#endif
    }
    
    func unproject(_ point: CGPoint, from space: some CoordinateSpaceProtocol, to realitySpace: some RealityCoordinateSpace, ontoPlane: float4x4) -> SIMD3<Float>?
    {
#if os(visionOS)
        // TODO: Could implement this with a raycast? https://developer.apple.com/documentation/realitykit/scene/raycast(origin:direction:length:query:mask:relativeto:)
        return nil
#else
        let actualSelf = self as! RealityViewCameraContent
        return actualSelf.unproject(point, from: space, to: realitySpace, ontoPlane: ontoPlane)
#endif
    }
}

public extension View
{
    /**
        Like `dropDestination`, except with a 3D location into a Volume if on visionOS.
        Make the receiver a drag'n'drop destination for a transferrable type, with an additional 3D location.
        
        Sorry about the hack with contentProvider. If i rewrite this using raycasting in the future, this parameter will
        disappear, but then `plane` will have to have a `CollisionComponent`.
        
        Example usage:
        ```
        @State private var isBeingDropped = false
        RealityView { ... }
        .dropDestination3D(for: RoomTemplate.self, onto: model.roomRoot, in: { model.content! } )
        { items, roompos in
            guard let template = items.first else { return false }
            state.place.addRoom(from: template, at: SIMD2(roompos.x, roompos.z))
            return true
        } isTargeted: { inDropArea in
            isBeingDropped = inDropArea
        }
        .border(
            isBeingDropped ? Color.accentColor : Color.clear,
            width: isBeingDropped ? 4.0 : 0.0
        )
        ```
    */
    nonisolated func dropDestination3D<VendedType: Transferable>(
        for payloadType: VendedType.Type = VendedType.self,
        onto plane: Entity,
        in contentProvider: @escaping () -> any RealityViewContentProtocol,
        action: @escaping (_ items: [VendedType], _ position: SIMD3<Float>) -> Bool,
        isTargeted: @escaping (Bool) -> Void = { _ in }
    )  -> some View
    {
        // TODO: Use DropDelegate to get continuously updating drop positions, and ask the user of this API to display a 3D proxy icon inside of their drop entity.
        return self.dropDestination(for: payloadType)
        { items, location in
            // TODO: Either figure out how to do this with a raycast here, or implement it in RealityExtensions
            let scenepos = contentProvider().unproject(
                location,
                from: .local,
                to: .scene,
                ontoPlane: plane.transformMatrix(relativeTo: nil)
            ) ?? .zero
            let roompos = plane.convert(position: scenepos, from: nil)
            
            return action(items, roompos)
        } isTargeted: { inDropArea in
            isTargeted(inDropArea)
        }
    }
}

extension Transform {
    /// Creates a Transform that positions an object at `origin` and orients
    /// it so that its -Z axis faces `target`, using `up` as the world up-direction.
    /// Shamelessly "created" with ChatGPT o1
    public static func look(at target: SIMD3<Float>,
                       from origin: SIMD3<Float>,
                       up: SIMD3<Float> = [0, 1, 0]) -> Transform
    {
        // 1. Compute the forward vector from origin to target
        let forward = simd_normalize(target - origin)
        
        // 2. RealityKit typically treats -Z as "forward," so invert:
        let lookForward = -forward
        
        // 3. Compute a right vector by crossing up with forward
        let right = simd_normalize(simd_cross(up, lookForward))
        
        // 4. Compute a real up vector orthonormal to (right, lookForward)
        let realUp = simd_cross(lookForward, right)
        
        // 5. Build a rotation matrix using these axis vectors:
        //    columns = ( right, up, forward ), last col is translation
        var matrix = matrix_identity_float4x4
        matrix.columns.0 = SIMD4<Float>( right,   0)
        matrix.columns.1 = SIMD4<Float>( realUp,  0)
        matrix.columns.2 = SIMD4<Float>( lookForward, 0)
        matrix.columns.3 = SIMD4<Float>( origin,  1)
        
        // 6. Return a Transform from that 4x4 matrix
        return Transform(matrix: matrix)
    }
}
