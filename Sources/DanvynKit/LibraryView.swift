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
    public let title: String // TODO: LocalizedStringKey or similar
    public let systemImageName: String
    public let sections: [Section]

    public struct Section: Equatable, Identifiable {
        public init(id: String = UUID().uuidString, title: String, items: [VendedType]) {
            self.title = title
            self.items = items
            self.id = id
        }

        public let id: String
        public let title: String
        public let items: [VendedType]
    }

    public init(title: String = "Library", systemImageName: String, items: [VendedType])
    {
        self.title = title
        self.sections = [Section(title: title, items: items)]
        self.systemImageName = systemImageName
    }

    public init(title: String = "Library", systemImageName: String, sections: [Section]) {
        self.title = title
        self.sections = sections
        self.systemImageName = systemImageName
    }
}

/// A view for displaying a single library of items, which can be dragged out to a destination window.
struct LibraryView<VendedType: LibraryItem>: View {

    public var library: Library<VendedType>

    public var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.flexible(minimum: 80.0)), GridItem(.flexible(minimum: 80.0))],
                      alignment: .center, spacing: 20.0) {
                ForEach(library.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            VStack(alignment: .center) {
                                Image(item.iconAsset)
                                    .resizable()
                                    .frame(width: 64, height: 64)
                                Text(item.name)
                                    .lineLimit(1, reservesSpace: true)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            #if os(visionOS)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20.0))
                            #endif
                            .padding(.horizontal, 8.0)
                            .draggable(item)
                        }
                    } header: {
                        HStack {
                            #if os(visionOS)
                            Spacer(minLength: 0.0)
                            #endif
                            Text(section.title)
                                .font(.system(size: 13.0, weight: .bold))
                                .padding(.vertical, 4.0)
                            Spacer(minLength: 0.0)
                        }
                        #if !os(visionOS)
                        .background(.windowBackground.opacity(0.95))
                        #endif
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 220.0, maxWidth: 400.0)
    }
}

/// A view for displaying one or more libraries. If more than one library is given, the libraries will be displayed
/// inside a tab view. Otherwise, the library will be displayed directly.
struct LibrariesView<VendedType: LibraryItem>: View {

    let libraries: [Library<VendedType>]

    var body: some View {
        if libraries.count == 1 {
            LibraryView(library: libraries[0])
        } else {
            TabView {
                ForEach(libraries, id: \.title) { library in
                    Tab(library.title, systemImage: library.systemImageName) {
                        LibraryView(library: library)
                    }
                }
            }
            .frame(minWidth: 220.0, maxWidth: 400.0)
        }
    }
}

/// Convenience constructor which makes a pretty Library window suitable for the current platform.
public func LibraryWindow<VendedType: LibraryItem>(name: String, id: String, contents: Library<VendedType>) -> some SwiftUI.Scene {
    LibraryWindow(name: name, id: id, contents: [contents])
}

public func LibraryWindow<VendedType: LibraryItem>(name: String, id: String, contents: [Library<VendedType>]) -> some SwiftUI.Scene
{
#if os(macOS)
    Window(name, id: id) {
        LibrariesView(libraries: contents)
    }
    .windowResizability(.contentSize)
    .restorationBehavior(.disabled)
    .defaultWindowPlacement { content, context in
        return WindowPlacement(.trailing)
    }
#else
    WindowGroup(id: id) {
        LibrariesView(libraries: contents)
    }
#endif
}

/**
    You can use either dropDestination() or this library's dropDestination3D to receive a model vended through a LibraryView.
 */

// TODO: Also hook dropDestination3D() up somehow so you can TAP the entry in library and have that call `action`? Or actually do have a libraryDestination that does both?



