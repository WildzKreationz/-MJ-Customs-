MJCC = MJCC or {}
MJCC.Clothing = {}

local scanCache = {}

local function getScanConfig()
    return Config.Scan or {}
end

local function shouldYield(counter)
    local scan = getScanConfig()
    local yieldEvery = tonumber(scan.YieldEvery) or 100

    counter.value = counter.value + 1

    if yieldEvery > 0 and counter.value >= yieldEvery then
        counter.value = 0
        Wait(0)
    end
end

local function isKnownComponent(id)
    for _, item in ipairs(Config.Components) do
        if item.id == id then
            return true
        end
    end

    return false
end

local function isKnownProp(id)
    for _, item in ipairs(Config.Props) do
        if item.id == id then
            return true
        end
    end

    return false
end

local function getCollectionNames(ped)
    local scan = getScanConfig()

    if scan.UseCollectionNatives == false then
        return {}
    end

    local ok, count = MJCC.CallNative('GetPedCollectionsCount', ped)

    if not ok or type(count) ~= 'number' or count <= 0 then
        return {}
    end

    local names = {}
    local seen = {}

    for index = 0, count - 1 do
        local nameOk, name = MJCC.CallNative('GetPedCollectionName', ped, index)

        if nameOk and type(name) == 'string' and name ~= '' and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end

    return names
end

local function addDrawable(drawables, drawable, textures)
    textures = MJCC.RoundInt(textures, 0)

    if textures > 0 then
        drawables[#drawables + 1] = {
            drawable = drawable,
            textures = textures
        }
    end
end

local function scanGlobalComponent(ped, component, counter)
    local ok, drawableCount = MJCC.CallNative('GetNumberOfPedDrawableVariations', ped, component.id)

    if not ok or type(drawableCount) ~= 'number' or drawableCount <= 0 then
        return nil
    end

    local scan = getScanConfig()
    local maxDrawables = math.min(drawableCount, scan.MaxDrawablesPerCollection or 1000)
    local drawables = {}

    for drawable = 0, maxDrawables - 1 do
        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedTextureVariations', ped, component.id, drawable)
        local textures = texOk and textureCount or 0
        textures = math.min(textures, scan.MaxTexturesPerDrawable or 50)
        addDrawable(drawables, drawable, textures)
        shouldYield(counter)
    end

    if #drawables == 0 then
        return nil
    end

    return {
        collection = '',
        label = 'Base Game',
        mode = 'global',
        drawables = drawables
    }
end

local function scanCollectionComponent(ped, component, collection, counter)
    local ok, drawableCount = MJCC.CallNative('GetNumberOfPedCollectionDrawableVariations', ped, component.id, collection)

    if not ok or type(drawableCount) ~= 'number' or drawableCount <= 0 then
        return nil
    end

    local scan = getScanConfig()
    local maxDrawables = math.min(drawableCount, scan.MaxDrawablesPerCollection or 1000)
    local drawables = {}

    for drawable = 0, maxDrawables - 1 do
        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedCollectionTextureVariations', ped, component.id, collection, drawable)
        local textures = texOk and textureCount or 0
        local valid = true

        if textures > 0 and type(_G.IsPedCollectionComponentVariationValid) == 'function' then
            local validOk, isValid = MJCC.CallNative('IsPedCollectionComponentVariationValid', ped, component.id, collection, drawable, 0)
            valid = not validOk or isValid == true
        end

        textures = math.min(textures, scan.MaxTexturesPerDrawable or 50)

        if valid then
            addDrawable(drawables, drawable, textures)
        end

        shouldYield(counter)
    end

    if #drawables == 0 then
        return nil
    end

    return {
        collection = collection,
        label = collection,
        mode = 'collection',
        drawables = drawables
    }
end

local function scanGlobalProp(ped, prop, counter)
    local ok, drawableCount = MJCC.CallNative('GetNumberOfPedPropDrawableVariations', ped, prop.id)

    if not ok or type(drawableCount) ~= 'number' or drawableCount <= 0 then
        return nil
    end

    local scan = getScanConfig()
    local maxDrawables = math.min(drawableCount, scan.MaxDrawablesPerCollection or 1000)
    local drawables = {}

    for drawable = 0, maxDrawables - 1 do
        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedPropTextureVariations', ped, prop.id, drawable)
        local textures = texOk and textureCount or 0
        textures = math.min(textures, scan.MaxTexturesPerDrawable or 50)
        addDrawable(drawables, drawable, textures)
        shouldYield(counter)
    end

    if #drawables == 0 then
        return nil
    end

    return {
        collection = '',
        label = 'Base Game',
        mode = 'global',
        drawables = drawables
    }
end

local function scanCollectionProp(ped, prop, collection, counter)
    local ok, drawableCount = MJCC.CallNative('GetNumberOfPedCollectionPropDrawableVariations', ped, prop.id, collection)

    if not ok or type(drawableCount) ~= 'number' or drawableCount <= 0 then
        return nil
    end

    local scan = getScanConfig()
    local maxDrawables = math.min(drawableCount, scan.MaxDrawablesPerCollection or 1000)
    local drawables = {}

    for drawable = 0, maxDrawables - 1 do
        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedCollectionPropTextureVariations', ped, prop.id, collection, drawable)
        local textures = texOk and textureCount or 0
        textures = math.min(textures, scan.MaxTexturesPerDrawable or 50)
        addDrawable(drawables, drawable, textures)
        shouldYield(counter)
    end

    if #drawables == 0 then
        return nil
    end

    return {
        collection = collection,
        label = collection,
        mode = 'collection',
        drawables = drawables
    }
end

local function buildCategories()
    local categories = {}

    for _, component in ipairs(Config.Components) do
        categories[#categories + 1] = {
            id = component.id,
            name = component.name,
            type = 'component'
        }
    end

    for _, prop in ipairs(Config.Props) do
        categories[#categories + 1] = {
            id = prop.id,
            name = prop.name,
            type = 'prop'
        }
    end

    return categories
end

local function getCacheKey(ped, gender)
    gender = gender or (MJCC.CurrentAppearance and MJCC.CurrentAppearance.gender) or MJCC.GetGenderFromPed(ped) or 'unknown'
    return ('%s:%s'):format(gender, GetEntityModel(ped))
end

local function validateScannedVariation(ped, kind, id, collection, drawable, texture)
    local cacheKey = getCacheKey(ped)
    local data = scanCache[cacheKey]

    if not data then
        data = MJCC.Clothing.ScanForPed(ped, MJCC.GetGenderFromPed(ped), false)
    end

    local bucket = kind == 'prop' and data.props or data.components
    local entry = bucket and bucket[tostring(id)]

    if not entry or type(entry.collections) ~= 'table' then
        return false, 'category has not been scanned'
    end

    for _, collectionEntry in ipairs(entry.collections) do
        if collectionEntry.collection == collection then
            for _, drawableEntry in ipairs(collectionEntry.drawables or {}) do
                if drawableEntry.drawable == drawable then
                    if texture < math.max(drawableEntry.textures or 0, 1) then
                        return true
                    end

                    return false, 'texture out of range'
                end
            end

            return false, 'drawable out of range'
        end
    end

    return false, 'collection is not available for this ped'
end

function MJCC.Clothing.ClearCache()
    scanCache = {}
end

function MJCC.Clothing.ScanForPed(ped, gender, force)
    local model = GetEntityModel(ped)
    local cacheKey = getCacheKey(ped, gender or 'unknown')

    if not force and scanCache[cacheKey] then
        return MJCC.DeepCopy(scanCache[cacheKey])
    end

    local started = GetGameTimer()
    local collections = getCollectionNames(ped)
    local counter = { value = 0 }
    local data = {
        components = {},
        props = {},
        categories = buildCategories(),
        meta = {
            model = model,
            gender = gender,
            collectionMode = #collections > 0,
            collectionCount = #collections
        }
    }

    for _, component in ipairs(Config.Components) do
        local entry = {
            id = component.id,
            name = component.name,
            type = 'component',
            collections = {}
        }

        if Config.Scan.EnableFallbackGlobalScan ~= false then
            local globalCollection = scanGlobalComponent(ped, component, counter)

            if globalCollection then
                entry.collections[#entry.collections + 1] = globalCollection
            end
        end

        for _, collection in ipairs(collections) do
            local collectionEntry = scanCollectionComponent(ped, component, collection, counter)

            if collectionEntry then
                entry.collections[#entry.collections + 1] = collectionEntry
            end
        end

        data.components[tostring(component.id)] = entry
    end

    for _, prop in ipairs(Config.Props) do
        local entry = {
            id = prop.id,
            name = prop.name,
            type = 'prop',
            collections = {}
        }

        if Config.Scan.EnableFallbackGlobalScan ~= false then
            local globalCollection = scanGlobalProp(ped, prop, counter)

            if globalCollection then
                entry.collections[#entry.collections + 1] = globalCollection
            end
        end

        for _, collection in ipairs(collections) do
            local collectionEntry = scanCollectionProp(ped, prop, collection, counter)

            if collectionEntry then
                entry.collections[#entry.collections + 1] = collectionEntry
            end
        end

        data.props[tostring(prop.id)] = entry
    end

    data.meta.scanMs = GetGameTimer() - started
    scanCache[cacheKey] = MJCC.DeepCopy(data)
    MJCC.Debug(('scan complete gender=%s collections=%s ms=%s'):format(gender or 'unknown', #collections, data.meta.scanMs))

    return data
end

function MJCC.Clothing.ReadCurrentAppearance(ped, gender, modelName)
    local appearance = {
        model = modelName,
        gender = gender,
        components = {},
        props = {}
    }

    for _, component in ipairs(Config.Components) do
        local drawable = GetPedDrawableVariation(ped, component.id)
        local texture = GetPedTextureVariation(ped, component.id)
        local palette = 0
        local paletteOk, paletteResult = MJCC.CallNative('GetPedPaletteVariation', ped, component.id)

        if paletteOk and type(paletteResult) == 'number' then
            palette = paletteResult
        end

        appearance.components[tostring(component.id)] = {
            component = component.id,
            collection = '',
            drawable = drawable,
            texture = texture,
            palette = palette
        }
    end

    for _, prop in ipairs(Config.Props) do
        local drawable = GetPedPropIndex(ped, prop.id)
        local texture = GetPedPropTextureIndex(ped, prop.id)

        appearance.props[tostring(prop.id)] = {
            prop = prop.id,
            collection = '',
            drawable = drawable,
            texture = math.max(texture, 0),
            clear = drawable < 0
        }
    end

    MJCC.CurrentAppearance = appearance
    return MJCC.DeepCopy(appearance)
end

function MJCC.Clothing.SetAppearanceIdentity(gender, modelName)
    if not MJCC.CurrentAppearance then
        MJCC.CurrentAppearance = {
            model = modelName,
            gender = gender,
            components = {},
            props = {}
        }
        return
    end

    MJCC.CurrentAppearance.model = modelName
    MJCC.CurrentAppearance.gender = gender
end

function MJCC.Clothing.ApplyComponent(ped, payload)
    local componentId = MJCC.RoundInt(payload.component or payload.id, -1)

    if not isKnownComponent(componentId) then
        return false, 'invalid component'
    end

    local collection = MJCC.SafeString(payload.collection, 96)
    local drawable = MJCC.RoundInt(payload.drawable, -1)
    local texture = MJCC.RoundInt(payload.texture, 0)
    local palette = MJCC.RoundInt(payload.palette, 0)

    if drawable < 0 or texture < 0 then
        return false, 'invalid drawable or texture'
    end

    if collection ~= '' then
        if type(_G.SetPedCollectionComponentVariation) ~= 'function' then
            return false, 'collection component native unavailable'
        end

        local scanned, scanErr = validateScannedVariation(ped, 'component', componentId, collection, drawable, texture)

        if not scanned then
            return false, scanErr
        end

        if type(_G.IsPedCollectionComponentVariationValid) == 'function' then
            local validOk, isValid = MJCC.CallNative('IsPedCollectionComponentVariationValid', ped, componentId, collection, drawable, texture)

            if validOk and not isValid then
                return false, 'component variation is not valid'
            end
        end

        local ok = MJCC.CallNative('SetPedCollectionComponentVariation', ped, componentId, collection, drawable, texture, palette)

        if not ok then
            return false, 'failed to apply collection component'
        end
    else
        local drawOk, drawableCount = MJCC.CallNative('GetNumberOfPedDrawableVariations', ped, componentId)

        if drawOk and type(drawableCount) == 'number' and drawable >= drawableCount then
            return false, 'drawable out of range'
        end

        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedTextureVariations', ped, componentId, drawable)
        local maxTextures = texOk and math.max(textureCount, 1) or 1

        if texture >= maxTextures then
            return false, 'texture out of range'
        end

        SetPedComponentVariation(ped, componentId, drawable, texture, palette)
    end

    MJCC.CurrentAppearance = MJCC.CurrentAppearance or { components = {}, props = {} }
    MJCC.CurrentAppearance.components = MJCC.CurrentAppearance.components or {}
    MJCC.CurrentAppearance.components[tostring(componentId)] = {
        component = componentId,
        collection = collection,
        drawable = drawable,
        texture = texture,
        palette = palette
    }

    return true
end

function MJCC.Clothing.ApplyProp(ped, payload)
    local propId = MJCC.RoundInt(payload.prop or payload.id, -1)

    if not isKnownProp(propId) then
        return false, 'invalid prop'
    end

    local collection = MJCC.SafeString(payload.collection, 96)
    local drawable = MJCC.RoundInt(payload.drawable, -1)
    local texture = MJCC.RoundInt(payload.texture, 0)
    local clear = payload.clear == true or drawable < 0

    if clear then
        ClearPedProp(ped, propId)

        MJCC.CurrentAppearance = MJCC.CurrentAppearance or { components = {}, props = {} }
        MJCC.CurrentAppearance.props = MJCC.CurrentAppearance.props or {}
        MJCC.CurrentAppearance.props[tostring(propId)] = {
            prop = propId,
            collection = '',
            drawable = -1,
            texture = 0,
            clear = true
        }

        return true
    end

    if drawable < 0 or texture < 0 then
        return false, 'invalid drawable or texture'
    end

    if collection ~= '' then
        if type(_G.SetPedCollectionPropIndex) ~= 'function' then
            return false, 'collection prop native unavailable'
        end

        local scanned, scanErr = validateScannedVariation(ped, 'prop', propId, collection, drawable, texture)

        if not scanned then
            return false, scanErr
        end

        local ok = MJCC.CallNative('SetPedCollectionPropIndex', ped, propId, collection, drawable, texture, true)

        if not ok then
            return false, 'failed to apply collection prop'
        end
    else
        local drawOk, drawableCount = MJCC.CallNative('GetNumberOfPedPropDrawableVariations', ped, propId)

        if drawOk and type(drawableCount) == 'number' and drawable >= drawableCount then
            return false, 'drawable out of range'
        end

        local texOk, textureCount = MJCC.CallNative('GetNumberOfPedPropTextureVariations', ped, propId, drawable)
        local maxTextures = texOk and math.max(textureCount, 1) or 1

        if texture >= maxTextures then
            return false, 'texture out of range'
        end

        SetPedPropIndex(ped, propId, drawable, texture, true)
    end

    MJCC.CurrentAppearance = MJCC.CurrentAppearance or { components = {}, props = {} }
    MJCC.CurrentAppearance.props = MJCC.CurrentAppearance.props or {}
    MJCC.CurrentAppearance.props[tostring(propId)] = {
        prop = propId,
        collection = collection,
        drawable = drawable,
        texture = texture,
        clear = false
    }

    return true
end

function MJCC.Clothing.ApplyAppearance(ped, appearance)
    if type(appearance) ~= 'table' then
        return false, 'appearance must be a table'
    end

    local failed = false

    if type(appearance.components) == 'table' then
        for _, component in pairs(appearance.components) do
            if type(component) == 'table' then
                local ok, err = MJCC.Clothing.ApplyComponent(ped, component)

                if not ok then
                    failed = true
                    MJCC.Debug('component apply skipped', err)
                end
            end
        end
    end

    if type(appearance.props) == 'table' then
        for _, prop in pairs(appearance.props) do
            if type(prop) == 'table' then
                local ok, err = MJCC.Clothing.ApplyProp(ped, prop)

                if not ok then
                    failed = true
                    MJCC.Debug('prop apply skipped', err)
                end
            end
        end
    end

    if appearance.model or appearance.gender then
        MJCC.CurrentAppearance = MJCC.CurrentAppearance or { components = {}, props = {} }
        MJCC.CurrentAppearance.model = appearance.model or MJCC.CurrentAppearance.model
        MJCC.CurrentAppearance.gender = appearance.gender or MJCC.CurrentAppearance.gender
    end

    return not failed, failed and 'one or more appearance entries could not be applied' or nil
end
