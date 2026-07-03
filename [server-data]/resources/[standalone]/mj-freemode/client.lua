local hasForcedPed = false

local function GetModelFromGender(gender)
    gender = string.lower(gender or Config.DefaultGender or 'male')

    if gender == 'female' or gender == 'f' then
        return `mp_f_freemode_01`, 'female'
    end

    return `mp_m_freemode_01`, 'male'
end

local function IsFreemodePed(ped)
    local model = GetEntityModel(ped)
    return model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
end

local function LoadModel(model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print('[MJ Freemode] Invalid model.')
        return false
    end

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(50)
    end

    return true
end

local function SetFreemodePed(gender)
    local model, selectedGender = GetModelFromGender(gender)

    if not LoadModel(model) then return end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    Wait(500)

    local ped = PlayerPedId()

    -- Prevent invisible / broken default freemode clothing
    SetPedDefaultComponentVariation(ped)

    -- Clean ped for clothing testing
    ClearPedBloodDamage(ped)
    ClearPedDecorations(ped)
    ClearPedWetness(ped)

    print(('[MJ Freemode] Player set to %s freemode ped.'):format(selectedGender))
end

AddEventHandler('playerSpawned', function()
    Wait(1500)

    local ped = PlayerPedId()

    if Config.ForceEverySpawn then
        SetFreemodePed(Config.DefaultGender)
        return
    end

    if not hasForcedPed and not IsFreemodePed(ped) then
        SetFreemodePed(Config.DefaultGender)
        hasForcedPed = true
    end
end)

RegisterCommand(Config.Command, function(source, args)
    local gender = args[1]

    if not gender then
        SetFreemodePed(Config.DefaultGender)
        return
    end

    gender = string.lower(gender)

    if gender ~= 'male' and gender ~= 'm' and gender ~= 'female' and gender ~= 'f' then
        print('[MJ Freemode] Usage: /freemode male or /freemode female')
        return
    end

    SetFreemodePed(gender)
end, false)

RegisterCommand('male', function()
    SetFreemodePed('male')
end, false)

RegisterCommand('female', function()
    SetFreemodePed('female')
end, false)