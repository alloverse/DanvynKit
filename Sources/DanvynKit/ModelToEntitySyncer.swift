import SwiftUI
import RealityKit

/// Syncs a list of model objects to a list of entities, taking care to create, update and remove entities as needed
/// to match the given list.
public actor ModelToEntitySyncer<ModelType: Equatable>
{
    private var cachedList: [String: ModelType] = [:]
    private var entities: [String: Entity] = [:]
    private func saveToCache(entity: Entity, at id: String)
    {
        entities[id] = entity
    }
    private let executor = DispatchSerialQueue(label: "syncer")
    nonisolated public var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    public init() {}
    
    /// Sync the given model objects with a set of RealityKit entities.
    ///
    /// When RealityKit entities need to be added or updated, the relevant closures will be called. When an entity
    /// needs to be removed, it'll be removed without any callbacks.
    ///
    /// - Parameters:
    ///   - newList: A dictionary of model objects keyed by each object's unique ID.
    ///   - parent: The parent entity in which to add created model entities.
    ///   - add: The closure to be called when a RealityKit entity needs to be created for a given model object.
    ///          Once returned, it'll be added into the parent entity for you.
    ///   - update: The closure to be called when a given model object has changed since the last time this method
    ///             was called. The RealityKit entity for the model object will be provided for you to apply updates to.
    ///   - forceUpdates: Pass `true` to always call the `update` closure for existing model objects. Useful for when
    ///                   `Equatable` conformance isn't enough, or when using classes for model objects (the cache is noncopying).
    public func sync(
        listOfModels newList: [String: ModelType],
        asChildrenOf parent: Entity,
        add: @escaping @MainActor (ModelType) async -> Entity,
        update: @escaping @MainActor (ModelType, Entity) -> Void,
        forceUpdates: Bool = false
    ) async
    {
        let toAdd = newList.filter { !cachedList.keys.contains($0.key) }
        let toRemove = cachedList.filter { !newList.keys.contains($0.key) }
        let toUpdate = newList.filter {
            let oldModel = cachedList[$0.key]
            return
                !toRemove.keys.contains($0.key) &&
                 (oldModel == nil || (forceUpdates || oldModel! != $0.value))
        }
        
        cachedList = newList
        await withDiscardingTaskGroup
        {
            for (id, model) in toAdd
            {
                $0.addTask
                {
                    let ent = await add(model)
                    await self.saveToCache(entity: ent, at: id)
                    await update(model, ent)
                    await parent.addChild(ent)
                }
            }
        }
        
        for (id, model) in toUpdate
        {
            let ent = entities[id]
            if let ent
            {
                await update(model, ent)
            }
        }
        
        for (id, _) in toRemove
        {
            let ent = entities[id]!
            await ent.removeFromParent()
            entities.removeValue(forKey: id)
        }
    }
}
