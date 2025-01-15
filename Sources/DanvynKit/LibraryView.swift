//
//  LibraryView.swift
//  DanvynKit
//
//  Created by Nevyn Bengtsson on 2025-01-09.
//

import SwiftUI
import RealityKit

/// An item in a library that the user can drag'n'drop or tap to add to the current scene.
public protocol LibraryItem : Equatable, Identifiable, Codable, Transferable
{
    /// Display name to show next to the item
    var name: String { get }
    /// Name of image that should be shown for the asset. Should be a string compatible with Image({}, bundle: .main))
    var iconAsset: String  { get }
}

/// A list of items that the LibraryView contains
public struct Library<VendedType: LibraryItem> : Equatable
{
    public let items: [VendedType]
    public init(items: [VendedType])
    {
        self.items = items
    }
}

/// A Library, to be presented in a Window, which allows the user to drag'n'drop items into a scene (or tap them to have them added to the middle of the scene).
/// Use LibraryWindow in your App's Scene to present it in a uniform manner across platforms.
public struct LibraryView<VendedType: LibraryItem> : View
{
    public var contents: Library<VendedType>
    public var body: some View {
        VStack {
            ForEach(contents.items)
            { template in
                VStack {
                    // Model3D(named: template.iconAsset) only on visionOS
                    Image(template.iconAsset)
                        .resizable()
                        .frame(width: 64, height: 64)
                    Text(template.name)
                }
                .padding()
                .cornerRadius(12)
                .overlay() {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.1), lineWidth: 1)
                }
                
                .frame(width: 128, height: 128)
                .draggable(template)
            }
        }
        .background(Color.black.opacity(0.3))
    }
}

/// Convenience constructor which makes a pretty Library window suitable for the current platform.
public func LibraryWindow<VendedType: LibraryItem>(name: String, id: String, contents: Library<VendedType>) -> some SwiftUI.Scene
{
#if os(macOS)
        Window(name, id: id) {
            LibraryView<VendedType>(contents: contents)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, context in
            return WindowPlacement(.trailing)
        }
#else
        WindowGroup(id: id) {
            LibraryView<VendedType>(contents: contents)
                // TODO: make it nice
        }
#endif
}


extension View
{
    /**
        Make the receiver a drag'n'drop destination for a model vended through a LibraryView.
        
        Sorry about the hack with contentProvider. If i rewrite this using raycasting in the future, this parameter will
        disappear, but then `plane` will have to have a `CollisionComponent`.
        
        Example usage:
        ```
            @State private var isBeingDropped = false
            RealityView { ... }
            .libraryDestination(for: RoomTemplate.self, onto: model.roomRoot, in: { model.content! } )
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
    nonisolated public func libraryDestination<VendedType: LibraryItem>(
        for payloadType: VendedType.Type = VendedType.self,
        onto plane: Entity,
        in contentProvider: @escaping () -> any RealityViewContentProtocol,
        action: @escaping (_ items: [VendedType], _ position: SIMD3<Float>) -> Bool,
        isTargeted: @escaping (Bool) -> Void = { _ in }
    )  -> some View
    {
        // TODO: Wait, is this even library specific? Should this be an extension on RealityView instead, since all it really does is converting coordinate systems to the RealityView scene's space?
        
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
        
        // TODO: Also hook it up somehow so you can TAP the entry in library and have that call `action`.
    }
}

