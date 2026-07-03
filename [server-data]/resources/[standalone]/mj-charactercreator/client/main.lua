MJCC = MJCC or {}

local creatorOpen = false
local creatorBusy = false
local currentGender = nil
local originalState = nil

local function response(cb, handler)
    local ok, result, extra = pcall(handler)

    if ok then
        cb(result or { ok = true })
        return
    end

    MJCC.Debug('callback error', result)
    cb({ ok = false, error = tostring(result or 'unknown error') })
end

local function sendCreatorData(loading, forceScan)
    local ped = PlayerPedId()
    local clothing = nil
    local errorMessage = nil

    if not loading then
        local ok, result = pcall(MJCC.Clothing.ScanForPed, ped, currentGender, forceScan)

        if ok then
            clothing = result
        else
            errorMessage = tostring(result)
            MJCC.Debug('scan failed', errorMessage)
        end
    end

    MJCC.Send('creatorData', {
        loading = loading == true,
        error = errorMessage,
        gender = currentGender,
        appearance = MJCC.DeepCopy(MJCC.CurrentAppearance),
        clothing = clothing,
        cameraViews = MJCC.BuildCameraPayload()
    })

    return clothing, errorMessage
end

local function setCreatorFocus(enabled)
    SetNuiFocus(enabled, enabled)
    SetNuiFocusKeepInput(false)
end

local function applyCreatorCoords(ped)
    if type(Config.CreatorCoords) ~= 'table' then
        return
    end

    local coords = Config.CreatorCoords
    SetEntityCoordsNoOffset(ped, coords.x or coords[1] or 0.0, coords.y or coords[2] or 0.0, coords.z or coords[3] or 0.0, false, false, false)

    if coords.w or coords.heading or coords[4] then
        SetEntityHeading(ped, coords.w or coords.heading or coords[4])
    end
end

local function setCreatorBucket(enabled)
    if Config.UseCreatorBucket then
        TriggerServerEvent('mj-charactercreator:server:setCreatorBucket', enabled == true)
    end
end

local function ensureFreemodePed(gender, creatorMode)
    local ped = PlayerPedId()
    local targetGender = MJCC.IsValidGender(gender) and gender or MJCC.GetGenderFromPed(ped) or Config.DefaultGender
    local modelName = MJCC.GetModelNameForGender(targetGender)
    local modelHash = GetHashKey(modelName)
    local snapshot = MJCC.SnapshotPedState(ped)

    if GetEntityModel(ped) ~= modelHash then
        local loaded, result = MJCC.LoadModel(modelName, Config.ModelLoadTimeout)

        if not loaded then
            return false, result
        end

        SetPlayerModel(PlayerId(), result)
        SetModelAsNoLongerNeeded(result)
        Wait(0)

        ped = PlayerPedId()
        MJCC.ResetPedDefaults(ped)
        MJCC.RestorePedState(ped, snapshot)
    end

    ped = PlayerPedId()
    if creatorMode then
        applyCreatorCoords(ped)
        MJCC.SetCreatorPedSafety(ped, true)

        if Config.FreezePlayerInCreator then
            FreezeEntityPosition(ped, true)
        end
    end

    currentGender = targetGender
    MJCC.Clothing.ReadCurrentAppearance(ped, currentGender, modelName)

    return true, ped, modelName
end

function OpenCreator(gender)
    if creatorBusy then
        return false, 'creator is busy'
    end

    creatorBusy = true

    if gender and gender ~= '' and not MJCC.IsValidGender(gender) then
        creatorBusy = false
        return false, 'invalid gender'
    end

    local startPed = PlayerPedId()

    if not originalState then
        originalState = MJCC.SnapshotPedState(startPed)
    end

    setCreatorBucket(true)

    local ok, result, modelName = ensureFreemodePed(gender, true)

    if not ok then
        setCreatorBucket(false)
        creatorBusy = false
        originalState = nil
        MJCC.SetCreatorPedSafety(PlayerPedId(), false)
        return false, result
    end

    creatorOpen = true
    setCreatorFocus(true)
    StartCreatorCamera(MJCC.GetActiveCameraView() or 'full')

    MJCC.Send('open', {
        loading = true,
        gender = currentGender,
        cameraViews = MJCC.BuildCameraPayload(),
        appearance = MJCC.DeepCopy(MJCC.CurrentAppearance)
    })

    CreateThread(function()
        sendCreatorData(false, false)
        creatorBusy = false
    end)

    MJCC.Debug(('opened model=%s gender=%s'):format(modelName or 'unknown', currentGender or 'unknown'))

    return true
end

function CloseCreator(skipMessage)
    local ped = PlayerPedId()

    creatorBusy = false

    if creatorOpen then
        StopCreatorCamera()
    end

    creatorOpen = false
    setCreatorFocus(false)
    FreezeEntityPosition(ped, false)
    MJCC.SetCreatorPedSafety(ped, false)
    DisplayRadar(true)
    setCreatorBucket(false)

    if originalState and type(Config.CreatorCoords) == 'table' then
        MJCC.RestorePedState(ped, originalState)
    end

    originalState = nil

    if not skipMessage then
        MJCC.Send('close')
    end

    return true
end

function GetCurrentAppearance()
    return MJCC.DeepCopy(MJCC.CurrentAppearance)
end

function ApplyAppearance(appearance)
    if type(appearance) ~= 'table' then
        return false, 'appearance must be a table'
    end

    local gender = appearance.gender

    if not MJCC.IsValidGender(gender) and type(appearance.model) == 'string' then
        if appearance.model == Config.Models.female then
            gender = 'female'
        elseif appearance.model == Config.Models.male then
            gender = 'male'
        end
    end

    gender = MJCC.IsValidGender(gender) and gender or Config.DefaultGender

    local ok, result = ensureFreemodePed(gender, false)

    if not ok then
        return false, result
    end

    local applied, err = MJCC.Clothing.ApplyAppearance(PlayerPedId(), appearance)

    if creatorOpen then
        sendCreatorData(false, false)
    end

    return applied, err
end

local function saveAppearance()
    if not MJCC.CurrentAppearance then
        return false, 'no appearance to save'
    end

    local appearance = MJCC.DeepCopy(MJCC.CurrentAppearance)
    MJCC.SaveAppearanceKvp(appearance)
    TriggerServerEvent('mj-charactercreator:server:saveAppearance', appearance)

    return true, appearance
end

local function switchGender(gender)
    if not MJCC.IsValidGender(gender) then
        return false, 'invalid gender'
    end

    MJCC.Send('loading', { loading = true })

    local ok, err = ensureFreemodePed(gender, true)

    if not ok then
        return false, err
    end

    SetCreatorCameraView(MJCC.GetActiveCameraView() or 'full')
    local clothing, scanErr = sendCreatorData(false, false)

    if scanErr then
        return false, scanErr
    end

    return true, clothing
end

if Config.AllowCommand then
    for _, commandName in ipairs(Config.Commands) do
        RegisterCommand(commandName, function(_, args)
            local arg = args and args[1] and string.lower(args[1]) or nil

            if arg == 'close' then
                CloseCreator()
                return
            end

            local gender = MJCC.IsValidGender(arg) and arg or nil
            local ok, err = OpenCreator(gender)

            if not ok then
                MJCC.Debug('open failed', err)
            end
        end, false)
    end
end

RegisterNUICallback('getCreatorData', function(_, cb)
    response(cb, function()
        if not creatorOpen then
            return { ok = false, error = 'creator is not open' }
        end

        local clothing, err = sendCreatorData(false, false)

        if err then
            return { ok = false, error = err }
        end

        return {
            ok = true,
            gender = currentGender,
            appearance = MJCC.DeepCopy(MJCC.CurrentAppearance),
            clothing = clothing,
            cameraViews = MJCC.BuildCameraPayload()
        }
    end)
end)

RegisterNUICallback('setGender', function(data, cb)
    response(cb, function()
        local ok, result = switchGender(data and data.gender)

        if not ok then
            return { ok = false, error = result }
        end

        return {
            ok = true,
            gender = currentGender,
            appearance = MJCC.DeepCopy(MJCC.CurrentAppearance),
            clothing = result
        }
    end)
end)

RegisterNUICallback('setComponent', function(data, cb)
    response(cb, function()
        local ok, err = MJCC.Clothing.ApplyComponent(PlayerPedId(), data or {})

        if not ok then
            return { ok = false, error = err }
        end

        return { ok = true, appearance = MJCC.DeepCopy(MJCC.CurrentAppearance) }
    end)
end)

RegisterNUICallback('setProp', function(data, cb)
    response(cb, function()
        local ok, err = MJCC.Clothing.ApplyProp(PlayerPedId(), data or {})

        if not ok then
            return { ok = false, error = err }
        end

        return { ok = true, appearance = MJCC.DeepCopy(MJCC.CurrentAppearance) }
    end)
end)

RegisterNUICallback('clearProp', function(data, cb)
    response(cb, function()
        data = data or {}
        data.clear = true
        data.drawable = -1

        local ok, err = MJCC.Clothing.ApplyProp(PlayerPedId(), data)

        if not ok then
            return { ok = false, error = err }
        end

        return { ok = true, appearance = MJCC.DeepCopy(MJCC.CurrentAppearance) }
    end)
end)

RegisterNUICallback('rotatePed', function(data, cb)
    response(cb, function()
        RotateCreatorPed(data and (data.direction or data.delta) or 'right')
        return { ok = true }
    end)
end)

RegisterNUICallback('setCameraView', function(data, cb)
    response(cb, function()
        local ok, err = SetCreatorCameraView(data and data.view)

        if not ok then
            return { ok = false, error = err }
        end

        return { ok = true }
    end)
end)

RegisterNUICallback('zoomCamera', function(data, cb)
    response(cb, function()
        ZoomCreatorCamera(data and data.delta or 0.0)
        return { ok = true }
    end)
end)

RegisterNUICallback('saveCharacter', function(_, cb)
    response(cb, function()
        local ok, result = saveAppearance()

        if not ok then
            return { ok = false, error = result }
        end

        return { ok = true, appearance = result }
    end)
end)

RegisterNUICallback('closeCreator', function(_, cb)
    response(cb, function()
        CloseCreator()
        return { ok = true }
    end)
end)

RegisterNetEvent('mj-charactercreator:client:open', function(gender)
    OpenCreator(gender)
end)

RegisterNetEvent('mj-charactercreator:client:close', function()
    CloseCreator()
end)

RegisterNetEvent('mj-charactercreator:client:applyAppearance', function(appearance)
    ApplyAppearance(appearance)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CloseCreator(true)
end)

CreateThread(function()
    while true do
        if creatorOpen and IsEntityDead(PlayerPedId()) then
            CloseCreator()
        end

        Wait(500)
    end
end)

exports('OpenCreator', OpenCreator)
exports('CloseCreator', CloseCreator)
exports('GetCurrentAppearance', GetCurrentAppearance)
exports('ApplyAppearance', ApplyAppearance)
