Config = {}

Config.Commands = { 'creator' }
Config.DefaultGender = 'male'
Config.AllowCommand = true
Config.FreezePlayerInCreator = true
Config.HideHudInCreator = true
Config.CreatorCoords = nil
Config.UseCreatorBucket = false
Config.Debug = false

Config.Models = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01'
}

Config.KvpKey = 'mj_charactercreator_appearance'
Config.ModelLoadTimeout = 7500
Config.ServerMaxAppearanceBytes = 200000

Config.Scan = {
    UseCollectionNatives = true,
    EnableFallbackGlobalScan = true,
    MaxDrawablesPerCollection = 1000,
    MaxTexturesPerDrawable = 50,
    YieldEvery = 100
}

Config.CameraZoom = {
    Min = -0.7,
    Max = 1.2,
    Step = 0.2
}

Config.CameraRotateStep = 15.0

Config.CameraViews = {
    full = { label = 'Full Body', offset = { x = 0.0, y = 2.5, z = 0.7 }, point = { x = 0.0, y = 0.0, z = 0.4 }, fov = 45.0 },
    face = { label = 'Face', offset = { x = 0.0, y = 0.9, z = 0.65 }, point = { x = 0.0, y = 0.0, z = 0.65 }, fov = 35.0 },
    torso = { label = 'Torso', offset = { x = 0.0, y = 1.4, z = 0.35 }, point = { x = 0.0, y = 0.0, z = 0.25 }, fov = 40.0 },
    legs = { label = 'Legs', offset = { x = 0.0, y = 1.8, z = -0.35 }, point = { x = 0.0, y = 0.0, z = -0.35 }, fov = 42.0 },
    feet = { label = 'Feet', offset = { x = 0.0, y = 1.2, z = -0.8 }, point = { x = 0.0, y = 0.0, z = -0.85 }, fov = 38.0 }
}

Config.Components = {
    { id = 0, name = 'Face' },
    { id = 1, name = 'Mask' },
    { id = 2, name = 'Hair' },
    { id = 3, name = 'Arms' },
    { id = 4, name = 'Pants' },
    { id = 5, name = 'Bags' },
    { id = 6, name = 'Shoes' },
    { id = 7, name = 'Accessories' },
    { id = 8, name = 'Undershirt' },
    { id = 9, name = 'Body Armor' },
    { id = 10, name = 'Decals' },
    { id = 11, name = 'Tops' }
}

Config.Props = {
    { id = 0, name = 'Hats' },
    { id = 1, name = 'Glasses' },
    { id = 2, name = 'Ears' },
    { id = 6, name = 'Watches' },
    { id = 7, name = 'Bracelets' }
}
