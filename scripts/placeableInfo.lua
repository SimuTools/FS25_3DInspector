Inspector3DPlaceableInfo = Inspector3DPlaceableInfo or {}

Inspector3DPlaceableInfo.DEBUG = false
Inspector3DPlaceableInfo.MAX_RESULTS = 500
Inspector3DPlaceableInfo.MAX_RECURSION_DEPTH = 15


local function tr(key, deText, enText, ...)
    if Inspector3D ~= nil and Inspector3D.getText ~= nil then
        return Inspector3D:getText(key, ...)
    end

    local text = isGermanLanguage() and deText or enText
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok and formatted ~= nil then
            text = formatted
        end
    end
    return text
end

local function makeLine(icon, text, iconPath, shortText)
    if Inspector3D ~= nil and Inspector3D.makeLine ~= nil then
        return Inspector3D.makeLine(icon, text, iconPath, shortText)
    end

    return {
        icon = tostring(icon or ""),
        text = tostring(text or ""),
        iconPath = iconPath ~= nil and tostring(iconPath) or nil,
        shortText = shortText ~= nil and tostring(shortText) or nil
    }
end

local function dbg(fmt, ...)
    if not Inspector3DPlaceableInfo.DEBUG then
        return
    end

    local ok, msg = pcall(string.format, "[Inspector3DPlaceableInfo] " .. tostring(fmt), ...)
    if ok then
        print(msg)
    else
        print("[Inspector3DPlaceableInfo] " .. tostring(fmt))
    end
end

local function isTable(v)
    return type(v) == "table"
end

local function isValidNode(v)
    return type(v) == "number" and v ~= 0
end

local function safeMethod(obj, methodName, ...)
    if obj == nil then
        return nil
    end

    local fn = obj[methodName]
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e = pcall(fn, obj, ...)
    if ok then
        return a, b, c, d, e
    end

    return nil
end

local function normalizeMaxDistanceSq(v)
    v = tonumber(v) or 80
    if v > 1000 then
        return v
    end
    return v * v
end

local function tryGetWorldTranslation(node)
    if not isValidNode(node) then
        return nil, nil, nil
    end

    local ok, x, y, z = pcall(getWorldTranslation, node)
    if ok then
        return x, y, z
    end

    return nil, nil, nil
end

local function getResolvedFillTypeIndex(value, fallbackFillTypeIndex)
    if not isTable(value) then
        return tonumber(fallbackFillTypeIndex)
    end

    local candidates = {
        value.fillTypeIndex,
        value.fillType,
        value.defaultFillType,
        value.inputFillType,
        value.outputFillType,
        safeMethod(value, "getFillTypeIndex"),
        safeMethod(value, "getFillType"),
        fallbackFillTypeIndex
    }

    for _, candidate in ipairs(candidates) do
        local index = tonumber(candidate)
        if index ~= nil and index > 0 then
            return index
        end
    end

    return nil
end

local function getDistanceSq(ax, ay, az, bx, by, bz)
    if ax == nil or ay == nil or az == nil or bx == nil or by == nil or bz == nil then
        return math.huge
    end

    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return dx * dx + dy * dy + dz * dz
end

local function getDistanceSqNodeToCamera(node, cameraNode)
    local ax, ay, az = tryGetWorldTranslation(node)
    local bx, by, bz = tryGetWorldTranslation(cameraNode)
    return getDistanceSq(ax, ay, az, bx, by, bz)
end

local function getFillTypeTitle(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 or (FillType ~= nil and fillTypeIndex == FillType.UNKNOWN) then
        return nil
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            return fillType.title or fillType.name or tostring(fillTypeIndex)
        end
    end

    return tostring(fillTypeIndex)
end

local function getFillTypeIconPath(fillTypeIndex)
    if Inspector3D ~= nil and Inspector3D.getFillTypeIconPath ~= nil then
        return Inspector3D.getFillTypeIconPath(fillTypeIndex)
    end

    if fillTypeIndex == nil or fillTypeIndex == 0 or (FillType ~= nil and fillTypeIndex == FillType.UNKNOWN) then
        return nil
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            local iconPath = tostring(fillType.hudOverlayFilename or fillType.hudOverlay or "")
            if iconPath ~= "" then
                return iconPath
            end
        end
    end

    return nil
end

local function getGrassFallbackIconPath()
    local candidates = {"GRASS", "GRASS_WINDROW", "DRYGRASS"}

    if g_fillTypeManager == nil then
        return nil
    end

    for _, name in ipairs(candidates) do
        local fillType = g_fillTypeManager.nameToFillType ~= nil and g_fillTypeManager.nameToFillType[name] or nil
        if fillType == nil and g_fillTypeManager.nameToIndex ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
            local index = g_fillTypeManager.nameToIndex[name]
            if index ~= nil then
                fillType = g_fillTypeManager:getFillTypeByIndex(index)
            end
        end

        if fillType ~= nil then
            local iconPath = tostring(fillType.hudOverlayFilename or fillType.hudOverlay or "")
            if iconPath ~= "" then
                return iconPath
            end
        end
    end

    return nil
end

local function isMeadowText(text)
    text = string.upper(tostring(text or ""))
    return text == "MEADOW" or string.find(text, "MEADOW", 1, true) ~= nil
end

local function resolveFillTypeIndexByName(name)
    name = string.upper(tostring(name or ""))
    if name == "" or g_fillTypeManager == nil then
        return nil
    end

    if g_fillTypeManager.getFillTypeIndexByName ~= nil then
        local ok, index = pcall(g_fillTypeManager.getFillTypeIndexByName, g_fillTypeManager, name)
        if ok and index ~= nil and index ~= 0 then
            return index
        end
    end

    local tables = {
        g_fillTypeManager.indexToFillType,
        g_fillTypeManager.fillTypes,
        g_fillTypeManager.nameToFillType
    }

    for _, tbl in ipairs(tables) do
        if isTable(tbl) then
            for key, fillType in pairs(tbl) do
                if isTable(fillType) then
                    local fillName = string.upper(tostring(fillType.name or ""))
                    local fillTitle = string.upper(tostring(fillType.title or ""))
                    if fillName == name or fillTitle == name then
                        return tonumber(fillType.index) or tonumber(key)
                    end
                end
            end
        end
    end

    return nil
end

local function resolveFirstFillTypeIconPath(fillTypes, fallbackTitle)
    if isTable(fillTypes) then
        for key, value in pairs(fillTypes) do
            local fillTypeIndex = tonumber(key)

            if fillTypeIndex == nil and type(key) == "string" then
                fillTypeIndex = resolveFillTypeIndexByName(key)
            end

            if fillTypeIndex == nil and type(value) == "number" then
                fillTypeIndex = tonumber(value)
            end

            if isTable(value) and fillTypeIndex == nil then
                fillTypeIndex =
                    tonumber(value.fillTypeIndex or value.fillType or value.index) or
                    resolveFillTypeIndexByName(value.name or value.title or value.fillTypeName)
            end

            if fillTypeIndex ~= nil and fillTypeIndex > 0 then
                local iconPath = getFillTypeIconPath(fillTypeIndex)
                if iconPath ~= nil and iconPath ~= "" then
                    return iconPath
                end
            end
        end
    end

    if isMeadowText(fallbackTitle) then
        return getGrassFallbackIconPath()
    end

    return nil
end

local function getAnimalSystemTypeByIndex(animalTypeIndex)
    if animalTypeIndex == nil then
        return nil
    end

    local systems = {
        g_currentMission and g_currentMission.animalSystem or nil,
        g_currentMission and g_currentMission.animalManager or nil,
        g_animalSystem
    }

    for _, system in ipairs(systems) do
        if isTable(system) then
            local animalType = safeMethod(system, "getTypeByIndex", animalTypeIndex)
            if isTable(animalType) then
                return animalType
            end

            animalType = safeMethod(system, "getAnimalTypeByIndex", animalTypeIndex)
            if isTable(animalType) then
                return animalType
            end

            if isTable(system.types) and isTable(system.types[animalTypeIndex]) then
                return system.types[animalTypeIndex]
            end

            if isTable(system.typeIndexToType) and isTable(system.typeIndexToType[animalTypeIndex]) then
                return system.typeIndexToType[animalTypeIndex]
            end
        end
    end

    return nil
end

local getDisplayObject

local ANIMAL_ICON_DEFAULT_FILLTYPES = {
    COW = "COW_HOLSTEIN",
    SHEEP = "SHEEP_LANDRACE",
    PIG = "PIG_LANDRACE",
    CHICKEN = "CHICKEN",
    ROOSTER = "CHICKEN_ROOSTER",
    HEN = "CHICKEN",
    GOAT = "GOAT",
    HORSE = "HORSE_BAY",
    BUFFALO = "COW_WATERBUFFALO",
    WATERBUFFALO = "COW_WATERBUFFALO",
    WATER_BUFFALO = "COW_WATERBUFFALO"
}

local function addAnimalCandidateIndex(candidates, seen, value)
    local index = tonumber(value)
    if index ~= nil and index > 0 and not seen[index] then
        seen[index] = true
        candidates[#candidates + 1] = index
    end
end

local function addAnimalCandidateName(candidates, seen, name)
    if name == nil or name == "" then
        return
    end

    addAnimalCandidateIndex(candidates, seen, resolveFillTypeIndexByName(name))
end

local function collectAnimalSourceTexts(source, out)
    if not isTable(source) then
        return
    end

    local values = {
        source.animalTypeName,
        source.typeName,
        source.name,
        source.title,
        source.subTypeName,
        source.breedName,
        source.categoryName,
        source.configFileName,
        source.xmlFilename,
        source.filename,
        source.customEnvironment,
        source.storeItemName,
        source.placeableTypeName,
        source.husbandryType,
        source.animalType,
        source.animalSubType,
        safeMethod(source, "getName"),
        safeMethod(source, "getFullName")
    }

    for _, value in ipairs(values) do
        if value ~= nil and value ~= "" then
            out[#out + 1] = tostring(value)
        end
    end
end

local function appendAnimalCandidatesFromText(candidates, seen, text)
    text = tostring(text or "")
    if text == "" then
        return
    end

    addAnimalCandidateName(candidates, seen, text)

    local upperRaw = string.upper(text)
    local upper = string.gsub(upperRaw, "[^%w]+", " ")

    local function contains(token)
        return string.find(upper, token, 1, true) ~= nil or string.find(upperRaw, token, 1, true) ~= nil
    end

    if contains("WATER BUFFALO") or contains("WATERBUFFALO") then
        addAnimalCandidateName(candidates, seen, "COW_WATERBUFFALO")
    end

    if contains("HIGHLAND") then
        addAnimalCandidateName(candidates, seen, "COW_HIGHLAND_CATTLE")
    end

    if contains("HOLSTEIN") then
        addAnimalCandidateName(candidates, seen, "COW_HOLSTEIN")
    end

    if contains("LIMOUSIN") then
        addAnimalCandidateName(candidates, seen, "COW_LIMOUSIN")
    end

    if contains("ANGUS") then
        addAnimalCandidateName(candidates, seen, "COW_ANGUS")
    end

    if contains("SWISS BROWN") or contains("BROWN SWISS") then
        addAnimalCandidateName(candidates, seen, "COW_SWISS_BROWN")
    end

    if contains("LANDRACE OF BENTHEIM") then
        addAnimalCandidateName(candidates, seen, "SHEEP_LANDRACE")
    end

    if contains("SWISS BLACK BROWN MOUNTAIN") or contains("SWISS MOUNTAIN") then
        addAnimalCandidateName(candidates, seen, "SHEEP_SWISS_MOUNTAIN")
    end

    if contains("STEINSCHAF") then
        addAnimalCandidateName(candidates, seen, "SHEEP_STEINSCHAF")
    end

    if contains("BLACK WELSH") then
        addAnimalCandidateName(candidates, seen, "SHEEP_BLACK_WELSH")
    end

    if contains("BENTHEIM BLACK PIED") or contains("BLACK PIED") then
        addAnimalCandidateName(candidates, seen, "PIG_BLACK_PIED")
    end

    if contains("BERKSHIRE") then
        addAnimalCandidateName(candidates, seen, "PIG_BERKSHIRE")
    end

    if contains("LANDRACE") and contains("PIG") then
        addAnimalCandidateName(candidates, seen, "PIG_LANDRACE")
    end

    if contains("ROOSTER") then
        addAnimalCandidateName(candidates, seen, "CHICKEN_ROOSTER")
    end

    if contains("CHICKEN") or contains("HEN") then
        addAnimalCandidateName(candidates, seen, "CHICKEN")
    end

    if contains("GOAT") then
        addAnimalCandidateName(candidates, seen, "GOAT")
    end

    if contains("PALOMINO") then
        addAnimalCandidateName(candidates, seen, "HORSE_PALOMINO")
    end

    if contains("SEAL BROWN") then
        addAnimalCandidateName(candidates, seen, "HORSE_SEAL_BROWN")
    end

    if contains("CHESTNUT") then
        addAnimalCandidateName(candidates, seen, "HORSE_CHESTNUT")
    end

    if contains("PINTO") then
        addAnimalCandidateName(candidates, seen, "HORSE_PINTO")
    end

    if contains("GRAY") or contains("GREY") then
        addAnimalCandidateName(candidates, seen, "HORSE_GRAY")
    end

    if contains("BAY") then
        addAnimalCandidateName(candidates, seen, "HORSE_BAY")
    end

    if contains("DUN") then
        addAnimalCandidateName(candidates, seen, "HORSE_DUN")
    end

    if contains("BLACK") and contains("HORSE") then
        addAnimalCandidateName(candidates, seen, "HORSE_BLACK")
    end

    if contains("HORSE") then
        addAnimalCandidateName(candidates, seen, ANIMAL_ICON_DEFAULT_FILLTYPES.HORSE)
    end

    if contains("BUFFALO") then
        addAnimalCandidateName(candidates, seen, ANIMAL_ICON_DEFAULT_FILLTYPES.BUFFALO)
    end

    if contains("COW") or contains("CATTLE") then
        addAnimalCandidateName(candidates, seen, ANIMAL_ICON_DEFAULT_FILLTYPES.COW)
    end

    if contains("SHEEP") then
        addAnimalCandidateName(candidates, seen, ANIMAL_ICON_DEFAULT_FILLTYPES.SHEEP)
    end

    if contains("PIG") or contains("SWINE") or contains("HOG") then
        addAnimalCandidateName(candidates, seen, ANIMAL_ICON_DEFAULT_FILLTYPES.PIG)
    end
end

local function getAnimalIconPathFromSource(source)
    if not isTable(source) then
        return nil
    end

    local displayObj = getDisplayObject(source)
    local animalTypeIndex =
        source.animalTypeIndex or
        (isTable(source.spec_husbandryAnimals) and source.spec_husbandryAnimals.animalTypeIndex) or
        (isTable(source.spec_husbandryFood) and source.spec_husbandryFood.animalTypeIndex) or
        (isTable(displayObj) and displayObj.animalTypeIndex) or
        (isTable(displayObj) and isTable(displayObj.spec_husbandryAnimals) and displayObj.spec_husbandryAnimals.animalTypeIndex) or
        (isTable(displayObj) and isTable(displayObj.spec_husbandryFood) and displayObj.spec_husbandryFood.animalTypeIndex)

    local candidates = {}
    local seen = {}

    if animalTypeIndex ~= nil then
        local animalType = getAnimalSystemTypeByIndex(animalTypeIndex)
        if isTable(animalType) then
            addAnimalCandidateIndex(candidates, seen, animalType.fillTypeIndex)
            addAnimalCandidateIndex(candidates, seen, animalType.fillType)
            addAnimalCandidateIndex(candidates, seen, animalType.storeFillTypeIndex)
            addAnimalCandidateIndex(candidates, seen, animalType.outputFillTypeIndex)

            local animalTypeTexts = {
                animalType.name,
                animalType.title,
                animalType.typeName,
                animalType.storeName,
                animalType.fillTypeName,
                animalType.subTypeName,
                animalType.breedName
            }

            for _, value in ipairs(animalTypeTexts) do
                appendAnimalCandidatesFromText(candidates, seen, value)
            end
        end
    end

    local sourceTexts = {}
    collectAnimalSourceTexts(source, sourceTexts)
    collectAnimalSourceTexts(isTable(source.spec_husbandryAnimals) and source.spec_husbandryAnimals or nil, sourceTexts)
    collectAnimalSourceTexts(isTable(source.spec_husbandryFood) and source.spec_husbandryFood or nil, sourceTexts)
    collectAnimalSourceTexts(displayObj, sourceTexts)
    collectAnimalSourceTexts(isTable(displayObj) and displayObj.spec_husbandryAnimals or nil, sourceTexts)
    collectAnimalSourceTexts(isTable(displayObj) and displayObj.spec_husbandryFood or nil, sourceTexts)

    local title = nil
    if isTable(displayObj) then
        title = safeMethod(displayObj, "getName") or safeMethod(displayObj, "getFullName") or displayObj.name or displayObj.title or displayObj.typeName or displayObj.configFileName
    end
    if title ~= nil and title ~= "" then
        sourceTexts[#sourceTexts + 1] = tostring(title)
    end

    for _, value in ipairs(sourceTexts) do
        appendAnimalCandidatesFromText(candidates, seen, value)
    end

    for _, fillTypeIndex in ipairs(candidates) do
        local iconPath = getFillTypeIconPath(fillTypeIndex)
        if iconPath ~= nil and iconPath ~= "" then
            return iconPath
        end
    end

    return nil
end

getDisplayObject = function(obj)
    if not isTable(obj) then
        return obj
    end

    local candidates = {
        obj.placeable,
        obj.owner,
        obj.object,
        obj.parent,
        obj.placeableObject,
        obj.owningPlaceable,
        obj.productionPoint
    }

    if isTable(obj.spec_husbandryAnimals) then
        candidates[#candidates + 1] = obj.spec_husbandryAnimals.placeable
        candidates[#candidates + 1] = obj.spec_husbandryAnimals.owner
        candidates[#candidates + 1] = obj.spec_husbandryAnimals.object
        candidates[#candidates + 1] = obj.spec_husbandryAnimals.parent
    end

    for _, candidate in ipairs(candidates) do
        if isTable(candidate) then
            return candidate
        end
    end

    return obj
end

local function hasAnyHusbandrySpec(source)
    if not isTable(source) then
        return false
    end

    return source.spec_husbandryAnimals ~= nil
        or source.spec_husbandryFood ~= nil
        or source.spec_husbandryWater ~= nil
        or source.spec_husbandryStraw ~= nil
        or source.spec_husbandryMilk ~= nil
        or source.spec_husbandryManure ~= nil
        or source.spec_husbandryLiquidManure ~= nil
        or source.spec_husbandryPallets ~= nil
end

local function getObjectTitle(obj)
    if not isTable(obj) then
        return tr("placeable_fallback", "Objekt", "Placeable")
    end

    local displayObj = getDisplayObject(obj)
    if isTable(displayObj) and displayObj ~= obj then
        obj = displayObj
    end

    local name = safeMethod(obj, "getName")
    if name ~= nil and name ~= "" then
        return tostring(name)
    end

    name = safeMethod(obj, "getFullName")
    if name ~= nil and name ~= "" then
        return tostring(name)
    end

    if obj.name ~= nil and obj.name ~= "" then
        return tostring(obj.name)
    end

    if obj.title ~= nil and obj.title ~= "" then
        return tostring(obj.title)
    end

    if obj.typeName ~= nil and obj.typeName ~= "" then
        return tostring(obj.typeName)
    end

    if obj.configFileName ~= nil and obj.configFileName ~= "" then
        return tostring(obj.configFileName)
    end

    return tr("placeable_fallback", "Objekt", "Placeable")
end

local function appendUniqueLine(lines, seen, text, icon, iconPath, shortText)
    if text == nil then
        return
    end

    text = tostring(text)
    if text == "" then
        return
    end

    icon = tostring(icon or "")
    iconPath = iconPath ~= nil and tostring(iconPath) or ""
    shortText = shortText ~= nil and tostring(shortText) or nil

    local visibleText = shortText ~= nil and shortText or text
    local existingIndex = seen[visibleText]

    if existingIndex ~= nil then
        local existing = lines[existingIndex]
        if type(existing) == "table" then
            local existingIconPath = tostring(existing.iconPath or "")
            local newHasIcon = iconPath ~= ""
            local oldHasIcon = existingIconPath ~= ""

            if not oldHasIcon and newHasIcon then
                lines[existingIndex] = makeLine(icon, text, iconPath, shortText)
            end
        end
        return
    end

    lines[#lines + 1] = makeLine(icon, text, iconPath ~= "" and iconPath or nil, shortText)
    seen[visibleText] = #lines
end

local function addUniqueNode(nodes, seen, node)
    if not isValidNode(node) then
        return
    end

    if seen[node] then
        return
    end

    seen[node] = true
    nodes[#nodes + 1] = node
end

local function collectNodesFromValue(value, nodes, seen)
    if isValidNode(value) then
        addUniqueNode(nodes, seen, value)
    end
end

local function collectNodesFromTable(tbl, keys, nodes, seen)
    if not isTable(tbl) then
        return
    end

    for _, key in ipairs(keys) do
        collectNodesFromValue(tbl[key], nodes, seen)
    end
end

local function scanCandidateNodesFromObject(scanObj, nodes, seen)
    if not isTable(scanObj) then
        return
    end

    local directKeys = {
        "rootNode",
        "node",
        "nodeId",
        "exactFillRootNode",
        "fillRootNode",
        "infoTriggerNode",
        "interactionTriggerNode",
        "unloadTriggerNode",
        "loadTriggerNode",
        "loadingTriggerNode",
        "unloadingTriggerNode",
        "triggerNode"
    }

    collectNodesFromTable(scanObj, directKeys, nodes, seen)

    if isTable(scanObj.components) and isTable(scanObj.components[1]) then
        collectNodesFromValue(scanObj.components[1].node, nodes, seen)
    end

    if isTable(scanObj.i3dMappings) then
        local mappingKeys = {
            "exactFillRootNode",
            "fillRootNode",
            "unloadTrigger",
            "loadTrigger",
            "loadingTrigger",
            "unloadingTrigger",
            "infoTrigger",
            "interactionTrigger",
            "root",
            "food",
            "water",
            "straw",
            "milk",
            "manure",
            "liquidManure"
        }

        collectNodesFromTable(scanObj.i3dMappings, mappingKeys, nodes, seen)

        for _, node in pairs(scanObj.i3dMappings) do
            collectNodesFromValue(node, nodes, seen)
        end
    end

    local specsToScan = {
        scanObj.spec_husbandryAnimals,
        scanObj.spec_husbandryFood,
        scanObj.spec_husbandryWater,
        scanObj.spec_husbandryStraw,
        scanObj.spec_husbandryMilk,
        scanObj.spec_husbandryManure,
        scanObj.spec_husbandryLiquidManure,
        scanObj.spec_husbandryPallets,
        scanObj.spec_silo,
        scanObj.spec_farmSilo,
        scanObj.spec_bunkerSilo,
        scanObj.spec_manureHeap,
        scanObj.spec_buyingStation,
        scanObj.spec_sellingStation,
        scanObj.spec_loadingStation,
        scanObj.spec_unloadingStation,
        scanObj.spec_productionPoint
    }

    for _, spec in ipairs(specsToScan) do
        if isTable(spec) then
            collectNodesFromTable(spec, directKeys, nodes, seen)

            if isTable(spec.i3dMappings) then
                for _, node in pairs(spec.i3dMappings) do
                    collectNodesFromValue(node, nodes, seen)
                end
            end

            if isTable(spec.loadingStation) then
                collectNodesFromTable(spec.loadingStation, directKeys, nodes, seen)
            end

            if isTable(spec.unloadingStation) then
                collectNodesFromTable(spec.unloadingStation, directKeys, nodes, seen)
            end

            if isTable(spec.storage) then
                collectNodesFromTable(spec.storage, directKeys, nodes, seen)
            end

            if isTable(spec.storages) then
                for _, storage in pairs(spec.storages) do
                    if isTable(storage) then
                        collectNodesFromTable(storage, directKeys, nodes, seen)
                    end
                end
            end

            if isTable(spec.storagePerFarm) then
                for _, storage in pairs(spec.storagePerFarm) do
                    if isTable(storage) then
                        collectNodesFromTable(storage, directKeys, nodes, seen)
                    end
                end
            end

            if isTable(spec.exactFillRootNodeToStorage) then
                for key, storage in pairs(spec.exactFillRootNodeToStorage) do
                    collectNodesFromValue(key, nodes, seen)
                    if isTable(storage) then
                        collectNodesFromTable(storage, directKeys, nodes, seen)
                    end
                end
            end
        end
    end
end

local function getAllCandidateNodesFromObject(obj)
    if not isTable(obj) then
        return {}
    end

    local nodes = {}
    local seen = {}

    scanCandidateNodesFromObject(obj, nodes, seen)

    local displayObj = getDisplayObject(obj)
    if isTable(displayObj) and displayObj ~= obj then
        scanCandidateNodesFromObject(displayObj, nodes, seen)
    end

    return nodes
end

local function getBestNodeFromObject(obj, cameraNode)
    local candidates = getAllCandidateNodesFromObject(obj)

    if #candidates == 0 then
        return nil
    end

    if not isValidNode(cameraNode) then
        return candidates[1]
    end

    local bestNode = nil
    local bestDistSq = math.huge

    for _, node in ipairs(candidates) do
        local distSq = getDistanceSqNodeToCamera(node, cameraNode)
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestNode = node
        end
    end

    return bestNode or candidates[1]
end

local function makeFillDedupKey(fillTypeIndex, amount)
    return "__fill__|" .. tostring(fillTypeIndex or 0) .. "|" .. tostring(math.floor((tonumber(amount) or 0) + 0.5))
end

local function getFillLineScore(amount, capacity)
    amount = math.floor((tonumber(amount) or 0) + 0.5)
    capacity = math.floor((tonumber(capacity) or 0) + 0.5)

    if capacity > 0 then
        if capacity >= amount then
            return (capacity - amount)
        end

        return 1000000000 + (amount - capacity)
    end

    return 2000000000
end

local function upsertFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
    amount = tonumber(amount) or 0
    capacity = tonumber(capacity) or 0

    if amount <= 0.001 then
        return
    end

    local title = getFillTypeTitle(fillTypeIndex) or tr("fill_fallback", "Füllstand", "Fill")
    local iconPath = getFillTypeIconPath(fillTypeIndex)

    if iconPath == nil and isMeadowText(title) then
        iconPath = getGrassFallbackIconPath()
    end

    local roundedAmount = math.floor(amount + 0.5)
    local roundedCapacity = math.floor(capacity + 0.5)

    local text
    local shortText

    if capacity > 0 then
        local percent = math.floor((amount / capacity) * 100 + 0.5)
        text = string.format("%s: %d / %d L (%d%%)", title, roundedAmount, roundedCapacity, percent)
        shortText = string.format("%d / %d L (%d%%)", roundedAmount, roundedCapacity, percent)
    else
        text = string.format("%s: %d L", title, roundedAmount)
        shortText = string.format("%d L", roundedAmount)
    end

    local fillKey = makeFillDedupKey(fillTypeIndex, amount)
    local newScore = getFillLineScore(amount, capacity)
    local existingIndex = seen[fillKey]

    if existingIndex ~= nil and outLines[existingIndex] ~= nil then
        local existing = outLines[existingIndex]
        local oldScore = tonumber(existing.__fillScore) or 9999999999

        if newScore < oldScore then
            local newLine = makeLine("fill", text, iconPath, shortText)
            newLine.__fillScore = newScore
            outLines[existingIndex] = newLine
        end

        return
    end

    local newLine = makeLine("fill", text, iconPath, shortText)
    newLine.__fillScore = newScore

    outLines[#outLines + 1] = newLine
    seen[fillKey] = #outLines
end

local function appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
    amount = tonumber(amount) or 0
    capacity = tonumber(capacity) or 0

    if amount <= 0.001 then
        return
    end

    if fillTypeIndex ~= nil and tonumber(fillTypeIndex) ~= nil and tonumber(fillTypeIndex) > 0 then
        upsertFillLevelLine(tonumber(fillTypeIndex), amount, capacity, outLines, seen)
        return
    end

    local title = getFillTypeTitle(fillTypeIndex) or tr("fill_fallback", "Füllstand", "Fill")
    local iconPath = getFillTypeIconPath(fillTypeIndex)

    if iconPath == nil and isMeadowText(title) then
        iconPath = getGrassFallbackIconPath()
    end

    if capacity > 0 then
        local percent = math.floor((amount / capacity) * 100 + 0.5)
        appendUniqueLine(
            outLines,
            seen,
            string.format("%s: %d / %d L (%d%%)", title, math.floor(amount + 0.5), math.floor(capacity + 0.5), percent),
            "fill",
            iconPath,
            string.format("%d / %d L (%d%%)", math.floor(amount + 0.5), math.floor(capacity + 0.5), percent)
        )
    else
        appendUniqueLine(
            outLines,
            seen,
            string.format("%s: %d L", title, math.floor(amount + 0.5)),
            "fill",
            iconPath,
            string.format("%d L", math.floor(amount + 0.5))
        )
    end
end

local function collectStorageLinesFromFillLevels(storage, outLines, seen)
    if not isTable(storage) then
        return
    end

    local fillLevels = storage.fillLevels
        or storage.storageFillLevels
        or storage.fillLevelByFillType
        or storage.fillTypeToAmount
        or storage.amounts
        or storage.levels
        or storage.inputFillLevels
        or storage.outputFillLevels

    if not isTable(fillLevels) then
        return
    end

    local capacity = tonumber(storage.capacity or storage.maxCapacity or storage.totalCapacity or storage.storageCapacity) or 0

    for fillTypeKey, level in pairs(fillLevels) do
        local resolvedFillTypeIndex = tonumber(fillTypeKey)

        if resolvedFillTypeIndex == nil and type(fillTypeKey) == "string" then
            resolvedFillTypeIndex = resolveFillTypeIndexByName(fillTypeKey)
        end

        if resolvedFillTypeIndex == nil and isTable(level) then
            resolvedFillTypeIndex =
                tonumber(level.fillTypeIndex or level.fillType or level.index) or
                resolveFillTypeIndexByName(level.name or level.title or level.fillTypeName)

            level = level.fillLevel or level.level or level.amount or level.quantity or level.value
        end

        local amount = tonumber(level) or 0
        if resolvedFillTypeIndex ~= nil and resolvedFillTypeIndex > 0 and amount > 0.001 then
            appendFillLevelLine(resolvedFillTypeIndex, amount, capacity, outLines, seen)
        end
    end
end

local function collectStorageLinesFromFillTypes(storage, outLines, seen)
    if not isTable(storage) then
        return
    end

    local fillTypes = storage.fillTypes
        or storage.supportedFillTypesData
        or storage.storageByFillType
        or storage.fillTypeStorages

    if not isTable(fillTypes) then
        return
    end

    for fillTypeKey, entry in pairs(fillTypes) do
        local resolvedFillTypeIndex = tonumber(fillTypeKey)

        if resolvedFillTypeIndex == nil and type(fillTypeKey) == "string" then
            resolvedFillTypeIndex = resolveFillTypeIndexByName(fillTypeKey)
        end

        local amount = nil
        local capacity = tonumber(storage.capacity or storage.maxCapacity or storage.totalCapacity or storage.storageCapacity) or 0

        if isTable(entry) then
            resolvedFillTypeIndex =
                tonumber(entry.fillTypeIndex or entry.fillType or entry.index) or
                resolvedFillTypeIndex or
                resolveFillTypeIndexByName(entry.name or entry.title or entry.fillTypeName)

            amount = tonumber(entry.fillLevel or entry.level or entry.amount or entry.quantity or entry.value)
            capacity = tonumber(entry.capacity or entry.maxCapacity or entry.totalCapacity or entry.storageCapacity) or capacity
        elseif entry == true then
            if resolvedFillTypeIndex ~= nil and resolvedFillTypeIndex > 0 then
                amount =
                    tonumber(safeMethod(storage, "getFillLevel", resolvedFillTypeIndex)) or
                    tonumber(safeMethod(storage, "getLevel", resolvedFillTypeIndex))
            end
        end

        if resolvedFillTypeIndex ~= nil and resolvedFillTypeIndex > 0 and (tonumber(amount) or 0) > 0.001 then
            appendFillLevelLine(resolvedFillTypeIndex, amount, capacity, outLines, seen)
        end
    end
end

local function collectFillUnitLines(obj, outLines, seen)
    local specFillUnit = obj.spec_fillUnit
    if specFillUnit == nil or not isTable(specFillUnit.fillUnits) then
        return
    end

    if type(obj.getFillUnitCapacity) ~= "function" or type(obj.getFillUnitFillLevel) ~= "function" then
        return
    end

    for _, fillUnit in pairs(specFillUnit.fillUnits) do
        local idx = fillUnit.fillUnitIndex
        if idx ~= nil then
            local cap = tonumber(safeMethod(obj, "getFillUnitCapacity", idx)) or 0
            local lvl = tonumber(safeMethod(obj, "getFillUnitFillLevel", idx)) or 0

            if cap > 0 and lvl > 0.001 then
                local ft = nil
                if type(obj.getFillUnitFillType) == "function" then
                    ft = safeMethod(obj, "getFillUnitFillType", idx)
                else
                    ft = fillUnit.fillType
                end

                appendFillLevelLine(ft, lvl, cap, outLines, seen)
            end
        end
    end
end

local collectGenericStorageData

local function collectTableChildrenAsStorageData(tbl, outLines, seen, visited, depth)
    if not isTable(tbl) then
        return
    end

    for _, value in pairs(tbl) do
        if isTable(value) then
            collectGenericStorageData(value, outLines, seen, visited, depth + 1)
        end
    end
end

collectGenericStorageData = function(value, outLines, seen, visited, depth)
    if not isTable(value) then
        return
    end

    if visited[value] then
        return
    end
    visited[value] = true

    if depth > Inspector3DPlaceableInfo.MAX_RECURSION_DEPTH then
        return
    end

    collectStorageLinesFromFillLevels(value, outLines, seen)
    collectStorageLinesFromFillTypes(value, outLines, seen)

    local directFillTypeIndex = getResolvedFillTypeIndex(value, nil)
    local directAmount =
        tonumber(value.fillLevel) or
        tonumber(value.level) or
        tonumber(value.amount) or
        tonumber(value.quantity) or
        tonumber(value.value)

    local directCapacity =
        tonumber(value.capacity) or
        tonumber(value.maxCapacity) or
        tonumber(value.totalCapacity) or
        tonumber(value.storageCapacity)

    if directFillTypeIndex ~= nil and directFillTypeIndex > 0 and (directAmount or 0) > 0.001 then
        appendFillLevelLine(directFillTypeIndex, directAmount, directCapacity, outLines, seen)
    end

    local nestedKeys = {
        "storage",
        "storages",
        "inputStorage",
        "outputStorage",
        "sourceStorage",
        "targetStorage",
        "sourceStorages",
        "targetStorages",
        "sharedStorage",
        "extensions",
        "buffers",
        "fillStorages",
        "food",
        "water",
        "straw",
        "milk",
        "manure",
        "liquidManure",
        "palletFillLevel",
        "loadingStation",
        "unloadingStation",
        "storagePerFarm",
        "exactFillRootNodeToStorage",
        "pallets",
        "inputs",
        "outputs",
        "inputFillTypes",
        "outputFillTypes",
        "inputFillTypeStorages",
        "outputFillTypeStorages",
        "storageByFillType",
        "fillTypeStorages",
        "fillTypeStorage",
        "inputStorages",
        "outputStorages",
        "inputMaterials",
        "outputMaterials",
        "inputFillLevels",
        "outputFillLevels"
    }

    for _, key in ipairs(nestedKeys) do
        local child = value[key]
        if isTable(child) then
            collectGenericStorageData(child, outLines, seen, visited, depth + 1)
            collectTableChildrenAsStorageData(child, outLines, seen, visited, depth + 1)
        end
    end
end

local function collectDirectHusbandryStorageLines(value, outLines, seen, visited, depth, fallbackFillTypeIndex)
    if not isTable(value) then
        return
    end

    if visited[value] then
        return
    end
    visited[value] = true

    if depth > Inspector3DPlaceableInfo.MAX_RECURSION_DEPTH then
        return
    end

    local function tryAppendDirectLine(storage, fillTypeIndex)
        fillTypeIndex = getResolvedFillTypeIndex(storage, fillTypeIndex)
        if fillTypeIndex == nil or fillTypeIndex <= 0 then
            return false
        end

        local amount =
            tonumber(storage.fillLevel) or
            tonumber(storage.level) or
            tonumber(storage.amount) or
            tonumber(storage.quantity) or
            tonumber(safeMethod(storage, "getFillLevel", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getFillLevel")) or
            tonumber(safeMethod(storage, "getLevel", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getLevel"))

        local capacity =
            tonumber(storage.capacity) or
            tonumber(storage.maxCapacity) or
            tonumber(storage.totalCapacity) or
            tonumber(safeMethod(storage, "getCapacity", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getCapacity"))

        if (tonumber(amount) or 0) > 0.001 then
            appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
            return true
        end

        return false
    end

    local function tryStorageForFillType(storage, fillTypeIndex)
        fillTypeIndex = getResolvedFillTypeIndex(storage, fillTypeIndex)
        if fillTypeIndex == nil or fillTypeIndex <= 0 then
            return
        end

        local amount =
            tonumber(safeMethod(storage, "getFillLevel", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getLevel", fillTypeIndex)) or
            tonumber(storage.fillLevel) or
            tonumber(storage.level) or
            tonumber(storage.amount)

        local capacity =
            tonumber(safeMethod(storage, "getCapacity", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getCapacity")) or
            tonumber(storage.capacity) or
            tonumber(storage.maxCapacity) or
            tonumber(storage.totalCapacity)

        appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
    end

    tryAppendDirectLine(value, fallbackFillTypeIndex)

    if value.fillType ~= nil or value.fillTypeIndex ~= nil then
        tryStorageForFillType(value, fallbackFillTypeIndex)
    end

    if isTable(value.supportedFillTypes) then
        for fillTypeIndex, allowed in pairs(value.supportedFillTypes) do
            if allowed then
                tryStorageForFillType(value, fillTypeIndex)
            end
        end
    end

    if isTable(value.fillTypes) then
        for fillTypeIndex, entry in pairs(value.fillTypes) do
            if isTable(entry) then
                local amount =
                    tonumber(entry.fillLevel) or
                    tonumber(entry.level) or
                    tonumber(entry.amount) or
                    tonumber(safeMethod(value, "getFillLevel", fillTypeIndex))

                local capacity =
                    tonumber(entry.capacity) or
                    tonumber(safeMethod(value, "getCapacity", fillTypeIndex)) or
                    tonumber(safeMethod(value, "getCapacity")) or
                    tonumber(value.capacity) or
                    tonumber(value.maxCapacity) or
                    tonumber(value.totalCapacity)

                appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
            elseif entry == true then
                tryStorageForFillType(value, fillTypeIndex)
            end
        end
    end

    local supported = safeMethod(value, "getSupportedFillTypes")
    if isTable(supported) then
        for fillTypeIndex, allowed in pairs(supported) do
            if allowed then
                tryStorageForFillType(value, fillTypeIndex)
            end
        end
    end

    local nestedKeys = {
        "storage",
        "storages",
        "inputStorage",
        "outputStorage",
        "sourceStorage",
        "targetStorage",
        "sourceStorages",
        "targetStorages",
        "sharedStorage",
        "extensions",
        "buffers",
        "fillStorages",
        "food",
        "water",
        "straw",
        "milk",
        "manure",
        "liquidManure",
        "pallets",
        "production",
        "clusterSystem",
        "feedingTrough",
        "wateringTrough"
    }

    for _, key in ipairs(nestedKeys) do
        local child = value[key]
        if isTable(child) then
            collectDirectHusbandryStorageLines(child, outLines, seen, visited, depth + 1, fallbackFillTypeIndex)

            for _, sub in pairs(child) do
                if isTable(sub) then
                    collectDirectHusbandryStorageLines(sub, outLines, seen, visited, depth + 1, fallbackFillTypeIndex)
                end
            end
        end
    end
end

local function isProductionPointLike(obj)
    if not isTable(obj) then
        return false
    end

    if obj.spec_productionPoint ~= nil then
        return true
    end

    if obj.productions ~= nil and obj.storage ~= nil then
        return true
    end

    if obj.inputFillLevels ~= nil and (obj.loadingStation ~= nil or obj.unloadingStation ~= nil or obj.storage ~= nil) then
        return true
    end

    return false
end

local function collectStorageByKnownFillTypes(storage, fillTypeTable, outLines, seen, capacityFallback)
    if not isTable(storage) or not isTable(fillTypeTable) then
        return
    end

    local done = {}

    local function tryFillType(fillTypeIndex)
        fillTypeIndex = tonumber(fillTypeIndex)
        if fillTypeIndex == nil or fillTypeIndex <= 0 or done[fillTypeIndex] then
            return
        end
        done[fillTypeIndex] = true

        local amount =
            tonumber(safeMethod(storage, "getFillLevel", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getLevel", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getFillTypeAmount", fillTypeIndex)) or
            0

        local capacity =
            tonumber(safeMethod(storage, "getCapacity", fillTypeIndex)) or
            tonumber(safeMethod(storage, "getCapacity")) or
            tonumber(capacityFallback) or
            tonumber(storage.capacity) or
            tonumber(storage.maxCapacity) or
            tonumber(storage.totalCapacity) or
            0

        if amount > 0.001 then
            appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
        end
    end

    for key, value in pairs(fillTypeTable) do
        if type(key) == "number" and value == true then
            tryFillType(key)
        elseif type(key) == "string" and value == true then
            tryFillType(resolveFillTypeIndexByName(key))
        elseif type(value) == "number" then
            tryFillType(value)
        elseif isTable(value) then
            tryFillType(value.fillTypeIndex or value.fillType or value.index or resolveFillTypeIndexByName(value.name or value.title or value.fillTypeName))
        end
    end
end

local function collectProductionInputFillLevels(root, outLines, seen)
    if not isTable(root) or not isTable(root.inputFillLevels) then
        return
    end

    local storage = root.storage
    local fallbackCapacity =
        tonumber(isTable(storage) and (storage.capacity or storage.maxCapacity or storage.totalCapacity) or nil) or
        0

    for fillTypeKey, amount in pairs(root.inputFillLevels) do
        local fillTypeIndex = tonumber(fillTypeKey)

        if fillTypeIndex == nil and type(fillTypeKey) == "string" then
            fillTypeIndex = resolveFillTypeIndexByName(fillTypeKey)
        end

        amount = tonumber(amount) or 0
        if fillTypeIndex ~= nil and fillTypeIndex > 0 and amount > 0.001 then
            local capacity =
                tonumber(isTable(storage) and safeMethod(storage, "getCapacity", fillTypeIndex) or nil) or
                tonumber(isTable(storage) and safeMethod(storage, "getCapacity") or nil) or
                fallbackCapacity

            appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
        end
    end
end

local function collectProductionLines(obj, outLines, seen)
    local root = nil

    if isTable(obj) and isTable(obj.spec_productionPoint) then
        root = obj.spec_productionPoint
    elseif isProductionPointLike(obj) then
        root = obj
    end

    if not isTable(root) then
        return
    end

    local visited = {}

    collectGenericStorageData(root, outLines, seen, visited, 0)
    collectProductionInputFillLevels(root, outLines, seen)

    local extraTables = {
        root.storage,
        root.loadingStation,
        root.unloadingStation,
        root.palletSpawner,
        root.infoTables,
        root.inputs,
        root.outputs,
        root.inputFillLevels,
        root.outputFillLevels,
        root.inputFillTypeStorages,
        root.outputFillTypeStorages,
        root.fillTypeStorages,
        root.storageByFillType
    }

    for _, tbl in ipairs(extraTables) do
        if isTable(tbl) then
            collectGenericStorageData(tbl, outLines, seen, visited, 1)
            collectTableChildrenAsStorageData(tbl, outLines, seen, visited, 1)
        end
    end

    collectStorageByKnownFillTypes(root.storage, root.inputFillTypeIds, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.inputFillTypeIdsArray, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.outputFillTypeIds, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.outputFillTypeIdsArray, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.outputFillTypeIdsAutoDeliver, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.outputFillTypeIdsDirectSell, outLines, seen)
    collectStorageByKnownFillTypes(root.storage, root.outputFillTypeIdsToPallets, outLines, seen)

    if isTable(root.productions) then
        for _, production in pairs(root.productions) do
            if isTable(production) then
                collectGenericStorageData(production, outLines, seen, visited, 1)
                collectTableChildrenAsStorageData(production, outLines, seen, visited, 1)
            end
        end
    end
end

local function getAnimalCountFromSource(source)
    if not isTable(source) then
        return 0
    end

    local count = tonumber(safeMethod(source, "getNumOfAnimals")) or tonumber(safeMethod(source, "getNumAnimals")) or 0

    if count > 0 then
        return count
    end

    local specAnimals = source.spec_husbandryAnimals
    if isTable(specAnimals) then
        if isTable(specAnimals.clusterSystem) and type(specAnimals.clusterSystem.getNumAnimals) == "function" then
            count = tonumber(safeMethod(specAnimals.clusterSystem, "getNumAnimals")) or 0
        elseif isTable(specAnimals.animals) then
            count = 0
            for _ in pairs(specAnimals.animals) do
                count = count + 1
            end
        end
    end

    return tonumber(count) or 0
end

local function getAnimalCountFromObject(obj)
    local count = getAnimalCountFromSource(obj)
    if count > 0 then
        return count
    end

    local displayObj = getDisplayObject(obj)
    if isTable(displayObj) and displayObj ~= obj then
        count = getAnimalCountFromSource(displayObj)
    end

    return tonumber(count) or 0
end

local function collectHusbandryFoodLinesFromSource(source, outLines, seen)
    if not isTable(source) then
        return false
    end

    local infos = safeMethod(source, "getFoodInfos")
    if isTable(infos) and #infos > 0 then
        local addedAny = false

        for _, info in ipairs(infos) do
            if isTable(info) then
                local value = tonumber(info.value) or 0
                local capacity = tonumber(info.capacity) or 0
                local title = tostring(info.title or tr("food_fallback", "Futter", "Food"))

                local iconPath =
                    getFillTypeIconPath(info.fillType or info.fillTypeIndex) or
                    resolveFirstFillTypeIconPath(info.fillTypes, title)

                if iconPath == nil and isMeadowText(info.title) then
                    iconPath = getGrassFallbackIconPath()
                end

                if value > 0.001 then
                    addedAny = true

                    if capacity > 0 then
                        local percent = math.floor((value / capacity) * 100 + 0.5)
                        appendUniqueLine(
                            outLines,
                            seen,
                            string.format("%s: %d / %d L (%d%%)", title, math.floor(value + 0.5), math.floor(capacity + 0.5), percent),
                            "fill",
                            iconPath,
                            string.format("%d / %d L (%d%%)", math.floor(value + 0.5), math.floor(capacity + 0.5), percent)
                        )
                    else
                        appendUniqueLine(
                            outLines,
                            seen,
                            string.format("%s: %d L", title, math.floor(value + 0.5)),
                            "fill",
                            iconPath,
                            string.format("%d L", math.floor(value + 0.5))
                        )
                    end
                end
            end
        end

        if addedAny then
            return true
        end
    end

    local spec = source.spec_husbandryFood
    if not isTable(spec) or not isTable(spec.fillLevels) then
        return false
    end

    local capacity = tonumber(spec.capacity) or 0
    local grouped = false

    if g_currentMission ~= nil and g_currentMission.animalFoodSystem ~= nil and spec.animalTypeIndex ~= nil then
        local animalFood = safeMethod(g_currentMission.animalFoodSystem, "getAnimalFood", spec.animalTypeIndex)

        if isTable(animalFood) and isTable(animalFood.groups) then
            for _, foodGroup in pairs(animalFood.groups) do
                if isTable(foodGroup) and isTable(foodGroup.fillTypes) then
                    local fillLevel = 0

                    for _, fillTypeIndex in pairs(foodGroup.fillTypes) do
                        fillLevel = fillLevel + (tonumber(spec.fillLevels[fillTypeIndex]) or 0)
                    end

                    if fillLevel > 0.001 then
                        local title = tostring(foodGroup.title or tr("food_fallback", "Futter", "Food"))
                        local iconPath = resolveFirstFillTypeIconPath(foodGroup.fillTypes, title)
                        local weight = tonumber(foodGroup.productionWeight)

                        if weight ~= nil then
                            title = string.format("%s (%d%%)", title, math.floor(weight * 100 + 0.5))
                        end

                        if capacity > 0 then
                            local percent = math.floor((fillLevel / capacity) * 100 + 0.5)
                            appendUniqueLine(
                                outLines,
                                seen,
                                string.format("%s: %d / %d L (%d%%)", title, math.floor(fillLevel + 0.5), math.floor(capacity + 0.5), percent),
                                "fill",
                                iconPath,
                                string.format("%d / %d L (%d%%)", math.floor(fillLevel + 0.5), math.floor(capacity + 0.5), percent)
                            )
                        else
                            appendUniqueLine(
                                outLines,
                                seen,
                                string.format("%s: %d L", title, math.floor(fillLevel + 0.5)),
                                "fill",
                                iconPath,
                                string.format("%d L", math.floor(fillLevel + 0.5))
                            )
                        end

                        grouped = true
                    end
                end
            end
        end
    end

    if grouped then
        return true
    end

    local addedAny = false

    for fillTypeIndex, level in pairs(spec.fillLevels) do
        local amount = tonumber(level) or 0
        if amount > 0.001 then
            appendFillLevelLine(fillTypeIndex, amount, capacity, outLines, seen)
            addedAny = true
        end
    end

    return addedAny
end

local function collectHusbandryLines(obj, outLines, seen)
    local displayObj = getDisplayObject(obj)

    local hasHusbandry =
        hasAnyHusbandrySpec(obj) or
        hasAnyHusbandrySpec(displayObj)

    if not hasHusbandry then
        return
    end

    local count = getAnimalCountFromObject(obj)
    if count > 0 then
        local animalIconPath = getAnimalIconPathFromSource(obj) or getAnimalIconPathFromSource(displayObj)
        appendUniqueLine(outLines, seen, tostring(count), animalIconPath ~= nil and "animals" or "", animalIconPath)
    end

    local scannedSources = {}
    local visitedDirect = {}
    local visitedGeneric = {}

    local function scanHusbandrySource(source)
        if not isTable(source) then
            return
        end

        if scannedSources[source] then
            return
        end
        scannedSources[source] = true

        collectHusbandryFoodLinesFromSource(source, outLines, seen)

        local specsToScan = {
            {spec = source.spec_husbandryWater,        fallbackName = "WATER"},
            {spec = source.spec_husbandryStraw,        fallbackName = "STRAW"},
            {spec = source.spec_husbandryMilk,         fallbackName = "MILK"},
            {spec = source.spec_husbandryManure,       fallbackName = "MANURE"},
            {spec = source.spec_husbandryLiquidManure, fallbackName = "LIQUIDMANURE"},
            {spec = source.spec_husbandryPallets,      fallbackName = nil}
        }

        for _, entry in ipairs(specsToScan) do
            local spec = entry.spec
            if isTable(spec) then
                local fallbackFillTypeIndex = entry.fallbackName ~= nil and resolveFillTypeIndexByName(entry.fallbackName) or nil

                collectDirectHusbandryStorageLines(spec, outLines, seen, visitedDirect, 0, fallbackFillTypeIndex)
                collectGenericStorageData(spec, outLines, seen, visitedGeneric, 0)
                collectTableChildrenAsStorageData(spec, outLines, seen, visitedGeneric, 0)
            end
        end
    end

    scanHusbandrySource(obj)

    if displayObj ~= obj then
        scanHusbandrySource(displayObj)
    end
end

local function collectSiloLines(obj, outLines, seen)
    local visited = {}

    local specsToScan = {
        obj.spec_silo,
        obj.spec_farmSilo,
        obj.spec_bunkerSilo,
        obj.spec_manureHeap,
        obj.spec_buyingStation,
        obj.spec_sellingStation,
        obj.spec_loadingStation,
        obj.spec_unloadingStation
    }

    for _, spec in ipairs(specsToScan) do
        if isTable(spec) then
            collectGenericStorageData(spec, outLines, seen, visited, 0)

            if isTable(spec.storagePerFarm) then
                collectTableChildrenAsStorageData(spec.storagePerFarm, outLines, seen, visited, 0)
            end

            if isTable(spec.exactFillRootNodeToStorage) then
                collectTableChildrenAsStorageData(spec.exactFillRootNodeToStorage, outLines, seen, visited, 0)
            end

            if isTable(spec.storages) then
                collectTableChildrenAsStorageData(spec.storages, outLines, seen, visited, 0)
            end
        end
    end
end

local function buildLinesForObject(obj)
    if not isTable(obj) then
        return nil
    end

    local lines = {}
    local seen = {}

    collectFillUnitLines(obj, lines, seen)
    collectProductionLines(obj, lines, seen)
    collectHusbandryLines(obj, lines, seen)
    collectSiloLines(obj, lines, seen)

    local displayObj = getDisplayObject(obj)
    if isTable(displayObj) and displayObj ~= obj then
        collectFillUnitLines(displayObj, lines, seen)
        collectProductionLines(displayObj, lines, seen)
        collectSiloLines(displayObj, lines, seen)
    end

    if #lines == 0 then
        return nil
    end

    return lines
end

local function makeEntry(obj, node, lines, distanceSq)
    return {
        object = obj,
        node = node,
        title = getObjectTitle(obj),
        lines = lines,
        distanceSq = distanceSq or math.huge
    }
end

local function getEntryKey(obj, node)
    local displayObj = getDisplayObject(obj)
    if displayObj ~= nil then
        return tostring(displayObj) .. "::" .. tostring(node or 0)
    end

    if obj ~= nil then
        return tostring(obj) .. "::" .. tostring(node or 0)
    end

    return tostring(node)
end

local function maybeAddObject(result, seen, obj, cameraNode, maxDistanceSq)
    if not isTable(obj) then
        return false
    end

    local node = getBestNodeFromObject(obj, cameraNode)
    if not isValidNode(node) then
        return false
    end

    local distSq = getDistanceSqNodeToCamera(node, cameraNode)
    if distSq > maxDistanceSq then
        return false
    end

    local lines = buildLinesForObject(obj)
    if lines == nil or #lines == 0 then
        return false
    end

    local key = getEntryKey(obj, node)
    if seen[key] then
        return false
    end
    seen[key] = true

    result[#result + 1] = makeEntry(obj, node, lines, distSq)
    dbg("added placeable=%s lines=%d", getObjectTitle(obj), #lines)
    return true
end

local function collectFromArray(result, seen, arr, cameraNode, maxDistanceSq)
    if not isTable(arr) then
        return
    end

    for _, obj in pairs(arr) do
        maybeAddObject(result, seen, obj, cameraNode, maxDistanceSq)
    end
end

function Inspector3DPlaceableInfo.getLines(entryOrObj)
    if isTable(entryOrObj) and isTable(entryOrObj.lines) then
        return entryOrObj.lines
    end

    return buildLinesForObject(entryOrObj)
end

function Inspector3DPlaceableInfo.getAnchor(entryOrObj)
    local cameraNode = nil
    if g_currentMission ~= nil and g_currentMission.camera ~= nil then
        cameraNode = g_currentMission.camera.node
    end

    local node = nil

    if isTable(entryOrObj) and isValidNode(entryOrObj.node) then
        node = entryOrObj.node
    else
        node = getBestNodeFromObject(entryOrObj, cameraNode)
    end

    if not isValidNode(node) then
        return nil, nil, nil
    end

    return tryGetWorldTranslation(node)
end

function Inspector3DPlaceableInfo.getDebugName(entryOrObj)
    if isTable(entryOrObj) and entryOrObj.title ~= nil then
        return tostring(entryOrObj.title)
    end

    return getObjectTitle(entryOrObj)
end

function Inspector3DPlaceableInfo.collectRelevantPlaceables(mission, cameraNode, maxDistanceOrSq)
    local result = {}
    local seen = {}

    if not isValidNode(cameraNode) then
        return result
    end

    local activeMission = mission or g_currentMission
    if activeMission == nil then
        return result
    end

    local maxDistanceSq = normalizeMaxDistanceSq(maxDistanceOrSq)

    if isTable(activeMission.placeableSystem) then
        collectFromArray(result, seen, activeMission.placeableSystem.placeables, cameraNode, maxDistanceSq)
        collectFromArray(result, seen, activeMission.placeableSystem.placeableById, cameraNode, maxDistanceSq)
    end

    if isTable(activeMission.placeables) then
        collectFromArray(result, seen, activeMission.placeables, cameraNode, maxDistanceSq)
    end

    if isTable(activeMission.husbandrySystem) then
        collectFromArray(result, seen, activeMission.husbandrySystem.husbandries, cameraNode, maxDistanceSq)
        collectFromArray(result, seen, activeMission.husbandrySystem.husbandryById, cameraNode, maxDistanceSq)
    end

    if isTable(activeMission.productionChainManager) then
        collectFromArray(result, seen, activeMission.productionChainManager.productionPoints, cameraNode, maxDistanceSq)
        collectFromArray(result, seen, activeMission.productionChainManager.placeables, cameraNode, maxDistanceSq)
    end

    table.sort(result, function(a, b)
        return (a.distanceSq or math.huge) < (b.distanceSq or math.huge)
    end)

    if #result > Inspector3DPlaceableInfo.MAX_RESULTS then
        for i = #result, Inspector3DPlaceableInfo.MAX_RESULTS + 1, -1 do
            table.remove(result, i)
        end
    end

    dbg("collectRelevantPlaceables result=%d", #result)
    return result
end