MJCC = MJCC or {}

local creatorCam = nil
local activeView = 'full'
local cameraActive = false
local zoomOffset = 0.0

local function getOffset(value)
    value = value or {}

    return {
        x = value.x or 0.0,
        y = value.y or 0.0,
        z = value.z or 0.0
    }
end

local function updateCreatorCamera()
    if not creatorCam or not DoesCamExist(creatorCam) then
        return
    end

    local ped = PlayerPedId()
    local view = Config.CameraViews[activeView] or Config.CameraViews.full
    local offset = getOffset(view.offset)
    local point = getOffset(view.point)
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, offset.x, offset.y + zoomOffset, offset.z)
    local lookAt = GetOffsetFromEntityInWorldCoords(ped, point.x, point.y, point.z)

    SetCamCoord(creatorCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(creatorCam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(creatorCam, view.fov or 45.0)
    SetFocusPosAndVel(lookAt.x, lookAt.y, lookAt.z, 0.0, 0.0, 0.0)
end

local function startControlThread()
    CreateThread(function()
        while cameraActive do
            if Config.HideHudInCreator then
                HideHudAndRadarThisFrame()
                HideHudComponentThisFrame(19)
                HideHudComponentThisFrame(20)
            end

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            Wait(0)
        end
    end)
end

function StartCreatorCamera(viewName)
    activeView = Config.CameraViews[viewName] and viewName or 'full'
    zoomOffset = 0.0

    if creatorCam and DoesCamExist(creatorCam) then
        DestroyCam(creatorCam, false)
    end

    creatorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCreatorCamera()
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, 500, true, true)

    if not cameraActive then
        cameraActive = true
        startControlThread()
    end
end

function StopCreatorCamera()
    cameraActive = false

    if creatorCam and DoesCamExist(creatorCam) then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(creatorCam, false)
    else
        RenderScriptCams(false, true, 500, true, true)
    end

    creatorCam = nil
    ClearFocus()
    DisplayRadar(true)
end

function SetCreatorCameraView(viewName)
    if not Config.CameraViews[viewName] then
        return false, 'invalid camera view'
    end

    activeView = viewName
    updateCreatorCamera()

    return true
end

function ZoomCreatorCamera(delta)
    local zoom = Config.CameraZoom or {}
    zoomOffset = MJCC.Clamp(zoomOffset + (tonumber(delta) or 0.0), zoom.Min or -0.7, zoom.Max or 1.2)
    updateCreatorCamera()

    return true
end

function RotateCreatorPed(direction)
    local ped = PlayerPedId()
    local step = Config.CameraRotateStep or 15.0
    local amount = tonumber(direction)

    if not amount then
        amount = direction == 'left' and step or -step
    end

    SetEntityHeading(ped, GetEntityHeading(ped) + amount)
    updateCreatorCamera()

    return true
end

function MJCC.GetActiveCameraView()
    return activeView
end
