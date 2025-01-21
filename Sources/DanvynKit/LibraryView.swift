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

/**
    You can use either dropDestination() or this library's dropDestination3D to receive a model vended through a LibraryView.
 */

// TODO: Also hook dropDestination3D() up somehow so you can TAP the entry in library and have that call `action`? Or actually do have a libraryDestination that does both?



