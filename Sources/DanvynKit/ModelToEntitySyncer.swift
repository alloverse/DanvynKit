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
    
    public func sync(
        listOfModels newList: [String: ModelType],
        asChildrenOf parent: Entity,
        add: @escaping (ModelType) async -> Entity,
        update: @escaping (ModelType, Entity) -> Void
    ) async
    {
        let toAdd = newList.filter { !cachedList.keys.contains($0.key) }
        let toRemove = cachedList.filter { !newList.keys.contains($0.key) }
        let toUpdate = newList.filter {
            let oldModel = cachedList[$0.key]
            return
                !toRemove.keys.contains($0.key) &&
                (oldModel == nil || oldModel! != $0.value)
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
                    update(model, ent)
                    await parent.addChild(ent)
                }
            }
        }
        
        for (id, model) in toUpdate
        {
            let ent = entities[id]
            if let ent
            {
                update(model, ent)
            }
        }
        
        for (id, model) in toRemove
        {
            let ent = entities[id]!
            await ent.removeFromParent()
            entities.removeValue(forKey: id)
        }
    }
}
