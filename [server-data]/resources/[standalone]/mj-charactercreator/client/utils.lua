MJCC = MJCC or {}

MJCC.Resource = GetCurrentResourceName()
MJCC.CurrentAppearance = nil

function MJCC.Debug(...)
    if Config.Debug then
        print(('[%s]'):format(MJCC.Resource), ...)
    end
end

function MJCC.CallNative(name, ...)
    local native = _G[name]

    if type(native) ~= 'function' then
        return false, nil
    end

    local ok, result = pcall(native, ...)

    if not ok then
        MJCC.Debug(('native failed: %s'):format(name), result)
        return false, nil
    end

    return true, result
end

function MJCC.Clamp(value, min, max)
    value = tonumber(value) or min

    if value < min then return min end
    if value > max then return max end

    return value
end

function MJCC.RoundInt(value, fallback)
    value = tonumber(value)

    if not value then
        return fallback or 0
    end

    return math.floor(value + 0.5)
end

function MJCC.SafeString(value, maxLength)
    if type(value) ~= 'string' then
        return ''
    end

    maxLength = maxLength or 64

    if #value > maxLength then
        return value:sub(1, maxLength)
    end

    return value
end

function MJCC.DeepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[MJCC.DeepCopy(key)] = MJCC.DeepCopy(child)
    end

    return copy
end

function MJCC.TableCount(value, limit)
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

function MJCC.Send(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

function MJCC.GetModelNameForGender(gender)
    if gender == 'female' then
        return Config.Models.female
    end

    return Config.Models.male
end

function MJCC.IsValidGender(gender)
    return gender == 'male' or gender == 'female'
end

function MJCC.GetGenderFromModel(model)
    if model == GetHashKey(Config.Models.male) then
        return 'male'
    end

    if model == GetHashKey(Config.Models.female) then
        return 'female'
    end

    return nil
end

function MJCC.GetGenderFromPed(ped)
    return MJCC.GetGenderFromModel(GetEntityModel(ped))
end

function MJCC.IsFreemodePed(ped)
    return MJCC.GetGenderFromPed(ped) ~= nil
end

function MJCC.LoadModel(modelName, timeout)
    local hash = GetHashKey(modelName)

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return false, ('invalid model: %s'):format(modelName)
    end

    RequestModel(hash)

    local expires = GetGameTimer() + (timeout or Config.ModelLoadTimeout)

    while not HasModelLoaded(hash) do
        Wait(0)

        if GetGameTimer() > expires then
            return false, ('model load timed out: %s'):format(modelName)
        end
    end

    return true, hash
end

function MJCC.SnapshotPedState(ped)
    local coords = GetEntityCoords(ped)

    return {
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = GetEntityHeading(ped),
        health = GetEntityHealth(ped),
        armor = GetPedArmour(ped)
    }
end

function MJCC.RestorePedState(ped, state)
    if not state then return end

    if state.coords then
        SetEntityCoordsNoOffset(ped, state.coords.x, state.coords.y, state.coords.z, false, false, false)
    end

    if state.heading then
        SetEntityHeading(ped, state.heading)
    end

    if state.health and state.health > 0 then
        SetEntityHealth(ped, state.health)
    end

    if state.armor then
        SetPedArmour(ped, state.armor)
    end
end

function MJCC.ResetPedDefaults(ped)
    SetPedDefaultComponentVariation(ped)

    for _, prop in ipairs(Config.Props) do
        ClearPedProp(ped, prop.id)
    end
end

function MJCC.SetCreatorPedSafety(ped, enabled)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, enabled == true)
    SetPedCanRagdoll(ped, enabled ~= true)
end

function MJCC.BuildCameraPayload()
    local views = {}

    for name, view in pairs(Config.CameraViews) do
        views[#views + 1] = {
            name = name,
            label = view.label
        }
    end

    table.sort(views, function(a, b)
        local order = { full = 1, face = 2, torso = 3, legs = 4, feet = 5 }
        return (order[a.name] or 99) < (order[b.name] or 99)
    end)

    return views
end

function MJCC.SaveAppearanceKvp(appearance)
    local encoded = json.encode(appearance)

    if type(SetResourceKvpNoSync) == 'function' then
        local ok = pcall(SetResourceKvpNoSync, Config.KvpKey, encoded)

        if ok then
            return true
        end
    end

    SetResourceKvp(Config.KvpKey, encoded)
    return true
end

function MJCC.LoadAppearanceKvp()
    local encoded = GetResourceKvpString(Config.KvpKey)

    if not encoded or encoded == '' then
        return nil
    end

    local ok, decoded = pcall(json.decode, encoded)

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return nil
end
