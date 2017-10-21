// Copyright(c) 2017 POLYGONTEK
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http ://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

/*
-------------------------------------------------------------------------------

    Entity

-------------------------------------------------------------------------------
*/

#include "Containers/HashTable.h"
#include "Core/Object.h"
#include "Render/SceneView.h"
#include "Components/Component.h"

BE_NAMESPACE_BEGIN

class Component;
class ComTransform;
class GameWorld;
class Prefab;
class Entity;

using EntityPtr                 = Entity*;
using EntityPtrArray            = Array<EntityPtr>;

class Entity : public Object {
    friend class GameWorld;
    friend class GameEdit;
    friend class Prefab;
    friend class Component;

public:
    enum WorldPosEnum {
        Pivot,
        Center,
        Minimum,
        Maximum
    };

    OBJECT_PROTOTYPE(Entity);
    
    Entity();
    virtual ~Entity();

    virtual Str                 ToString() const override { return GetName(); }
    
    Str                         GetName() const { return name; }
    void                        SetName(const Str &name);

    Str                         GetTag() const { return tag; }
    void                        SetTag(const Str &tag);

    int                         GetLayer() const { return layer; }
    void                        SetLayer(int layer);

                                // frozen entity is not selectable in editor
    bool                        IsFrozen() const { return frozen; }
    void                        SetFrozen(bool frozen);

    bool                        IsPrefabSource() const { return prefab; }

    Guid                        GetPrefabSource() const;
    void                        SetPrefabSource(const Guid &prefabSourceGuid);

    ObjectRef                   GetPrefabSourceRef() const;
    void                        SetPrefabSourceRef(const ObjectRef &prefabSourceRef);

    GameWorld *                 GetGameWorld() const { return gameWorld; }

    int                         GetEntityNum() const { return entityNum; }

    int                         GetSpawnId() const;

                                /// Returns hierarchy node
    const Hierarchy<Entity> &   GetNode() const { return node; }

                                /// Returns root entity
    Entity *                    GetRoot() const;

                                /// Is root entity ?
    bool                        IsRoot() const { return GetRoot() == this; }

    Entity *                    GetParent() const;
    void                        SetParent(Entity *parentEntity);

    Guid                        GetParentGuid() const;
    void                        SetParentGuid(const Guid &parentGuid);

    ObjectRef                   GetParentRef() const;
    void                        SetParentRef(const ObjectRef &parentRef);

                                /// Get the children by depth first order
    void                        GetChildren(EntityPtrArray &children) const;
    
                                /// Find a child by name
    Entity *                    FindChild(const char *name) const;
    
                                /// Number of components
    int                         NumComponents() const { return components.Count(); }

                                /// Checks if component exist by the given meta object
    bool                        HasComponent(const MetaObject &type) const;

                                /// Returns a component pointer that is conflicting with other components
    Component *                 GetConflictingComponent(const MetaObject &type) const;

                                /// Returns index of the component pointer
    int                         GetComponentIndex(const Component *component) const;

                                /// Returns a component pointer by the given comopnent index
    Component *                 GetComponent(int index) const { return components[index]; }

                                /// Returns a component pointer by the given meta object
    Component *                 GetComponent(const MetaObject &type) const;

                                /// Returns a component pointer by the given type T
    template <typename T> T *   GetComponent() const;

                                /// Returns a component pointer array by the given meta object
    ComponentPtrArray           GetComponents(const MetaObject &type) const;

                                /// Returns a transform component
    ComTransform *              GetTransform() const;

                                /// Adds a component to the entity
    void                        AddComponent(Component *component);

                                /// Inserts a component after the index to the entity
    void                        InsertComponent(Component *component, int index);

    bool                        HasRenderEntity(int renderEntityHandle) const;

    void                        Purge();

                                // entity 초기화 함수, 언제나 부모 entity 초기화가 먼저 실행된다.
    void                        Init();

                                /// Initialize components
    void                        InitComponents();

    void                        Awake();

                                // game 이 시작되어 update loop 에 들어가면 처음 한번만 실행된다. 
                                // game 중이라면 spawn 된 후 바로 실행한다.
    void                        Start();

    void                        Update();

    void                        LateUpdate();
    
    void                        OnApplicationTerminate();
    void                        OnApplicationPause(bool pause);

                                /// Serializes entity to JSON value
    void                        Serialize(Json::Value &data) const;

    bool                        IsActiveSelf() const;
    void                        SetActive(bool active);

    virtual const AABB          GetAABB() const;
    const AABB                  GetWorldAABB() const;
    const Vec3                  GetWorldPosition(WorldPosEnum pos = Pivot) const;

    virtual void                DrawGizmos(const SceneView::Parms &sceneView, bool selected);

    virtual bool                RayIntersection(const Vec3 &start, const Vec3 &dir, bool backFaceCull, float &lastScale) const;

                                // Create an entity by JSON text.
                                // Just initialize properties of an entity and it's components.
                                // Later this have to be initialized by it's properties.
    static Entity *             CreateEntity(Json::Value &data);

                                // Make copy of a entity's JSON value and replace the GUID of entity/components to new one
    static Json::Value          CloneEntityValue(const Json::Value &entityValue, HashTable<Guid, Guid> &oldToNewGuidMap);

    static void                 RemapGuids(EntityPtrArray &entities, const HashTable<Guid, Guid> &guidMap);

    static void                 DestroyInstance(Entity *entity);

    static const SignalDef      SIG_ComponentInserted;
    static const SignalDef      SIG_ComponentRemoved;
    static const SignalDef      SIG_LayerChanged;
        
protected:
    virtual void                Event_ImmediateDestroy() override;

    void                        PropertyChanged(const char *classname, const char *propName);

    Str                         name;           // Name of entity
    int                         nameHash;       // Hash key for gameWorld->entityHash
    Str                         tag;            // Tag name
    int                         tagHash;        // Hash key for gameWorld->entityTagHash
    int                         entityNum;      // Index for gameWorld->entities
    int                         layer;
    Hierarchy<Entity>           node;
    Guid                        prefabSourceGuid;

    bool                        initialized;
    bool                        prefab;
    bool                        frozen;

    GameWorld *                 gameWorld;

    ComponentPtrArray           components;     ///< 0'th component is always transform component
};

template <typename T>
BE_INLINE T *Entity::GetComponent() const {
    Component *component = GetComponent(T::metaObject);
    if (component) {
        return component->Cast<T>();
    }

    return nullptr;
}

BE_INLINE bool Entity::HasComponent(const MetaObject &type) const {
    if (GetComponent(type)) {
        return true;
    }
    return false;
}

BE_INLINE int Entity::GetComponentIndex(const Component *component) const {
    return components.FindIndex(const_cast<Component *>(component));
}

BE_INLINE Component *Entity::GetComponent(const MetaObject &type) const {
    for (int i = 0; i < components.Count(); i++) {
        Component *component = components[i];
        if (component->GetMetaObject()->IsTypeOf(type)) {
            return component;
        }
    }

    return nullptr;
}

BE_INLINE ComponentPtrArray Entity::GetComponents(const MetaObject &type) const {
    ComponentPtrArray subComponents;

    for (int i = 0; i < components.Count(); i++) {
        Component *component = components[i];

        if (component->GetMetaObject()->IsTypeOf(type)) {
            subComponents.Append(component);
        }
    }

    return subComponents;
}

BE_INLINE Component *Entity::GetConflictingComponent(const MetaObject &type) const {
    for (int i = 0; i < components.Count(); i++) {
        Component *component = components[i];
        if (component->IsConflictComponent(type)) {
            return component;
        }
    }

    return nullptr;
}

BE_INLINE void Entity::AddComponent(Component *component) {
    InsertComponent(component, components.Count());
}

BE_INLINE Entity *Entity::GetRoot() const {
    const Entity *ent = this;
    while (ent->GetParent()) {
        ent = ent->GetParent();
    }
    return const_cast<Entity *>(ent);
}

BE_INLINE Entity *Entity::GetParent() const {
    return node.GetParent();
}

BE_NAMESPACE_END
