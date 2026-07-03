local RESOURCE = GetCurrentResourceName()
local creatorBuckets = {}

local function debugPrint(...)
    if Config.Debug then
        print(('[%s]'):format(RESOURCE), ...)
    end
end

local function tableCount(value, limit)
    if type(value) ~= 'table' then
        return 0
    end

    local count = 0

    for _ in pairs(value) do
        count = count + 1

        if limit and count > limit then
            return count
        end
    end

    return count
end

local function validCollection(value)
    return type(value) == 'string' and #value <= 96
end

local function isKnownComponent(id)
    for _, component in ipairs(Config.Components) do
        if component.id == id then
            return true
        end
    end

    return false
end

local function isKnownProp(id)
    for _, prop in ipairs(Config.Props) do
        if prop.id == id then
            return true
        end
    end

    return false
end

local function validSlot(slot, keyName)
    if type(slot) ~= 'table' then
        return false
    end

    local id = tonumber(slot[keyName])
    local drawable = tonumber(slot.drawable)
    local texture = tonumber(slot.texture)

    if not id then
        return false
    end

    if keyName == 'component' and not isKnownComponent(id) then
        return false
    end

    if keyName == 'prop' and not isKnownProp(id) then
        return false
    end

    if not drawable or drawable < -1 or drawable > (Config.Scan.MaxDrawablesPerCollection or 1000) then
        return false
    end

    if not texture or texture < 0 or texture > (Config.Scan.MaxTexturesPerDrawable or 50) then
        return false
    end

    if not validCollection(slot.collection or '') then
        return false
    end

    return true
end

local function isValidAppearance(appearance)
    if type(appearance) ~= 'table' then
        return false
    end

    local ok, encoded = pcall(json.encode, appearance)

    if not ok or type(encoded) ~= 'string' or #encoded > (Config.ServerMaxAppearanceBytes or 200000) then
        return false
    end

    if appearance.gender ~= 'male' and appearance.gender ~= 'female' then
        return false
    end

    if appearance.model ~= Config.Models.male and appearance.model ~= Config.Models.female then
        return false
    end

    if type(appearance.components) ~= 'table' or tableCount(appearance.components, 12) > 12 then
        return false
    end

    if type(appearance.props) ~= 'table' or tableCount(appearance.props, 5) > 5 then
        return false
    end

    for _, slot in pairs(appearance.components) do
        if not validSlot(slot, 'component') then
            return false
        end
    end

    for _, slot in pairs(appearance.props) do
        if not validSlot(slot, 'prop') then
            return false
        end
    end

    return true
end

RegisterNetEvent('mj-charactercreator:server:saveAppearance', function(appearance)
    local src = source

    if not isValidAppearance(appearance) then
        print(('[%s] rejected invalid appearance from %s'):format(RESOURCE, src))
        return
    end

    debugPrint(('appearance received from %s'):format(src))
    TriggerEvent('mj-charactercreator:server:appearanceSaved', src, appearance)
end)

RegisterNetEvent('mj-charactercreator:server:setCreatorBucket', function(enabled)
    local src = source

    if not Config.UseCreatorBucket then
        return
    end

    if enabled == true then
        local bucket = 50000 + src
        creatorBuckets[src] = bucket
        SetPlayerRoutingBucket(src, bucket)
        return
    end

    creatorBuckets[src] = nil
    SetPlayerRoutingBucket(src, 0)
end)

AddEventHandler('playerDropped', function()
    creatorBuckets[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    for src in pairs(creatorBuckets) do
        if GetPlayerName(src) then
            SetPlayerRoutingBucket(src, 0)
        end
    end
end)
