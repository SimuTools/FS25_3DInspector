Inspector3D = {}

Inspector3D.DEBUG = false
Inspector3D.MAX_DISTANCE = 80
Inspector3D.TEXT_SIZE = 0.0153
Inspector3D.LINE_OFFSET = 0.018
Inspector3D.SCREEN_BORDER = 0.01
Inspector3D.CAMERA_DOT_MIN = 0.10
Inspector3D.FALLBACK_WORLD_OFFSET = 2.4
Inspector3D.BACKGROUND_PADDING_X = 0.004
Inspector3D.BACKGROUND_PADDING_Y = 0.0025
Inspector3D.PANEL_PADDING_X = 0.0050
Inspector3D.PANEL_PADDING_Y = 0.0035
Inspector3D.PANEL_ROW_GAP = 0.0026
Inspector3D.PANEL_TEXT_GAP = 0.0012
Inspector3D.PANEL_ACCENT_WIDTH = 0.0016
Inspector3D.DEFAULT_SCAN_INTERVAL_MS = 250

Inspector3D.isLoaded = false
Inspector3D.isAltDown = false
Inspector3D.lastAltState = false
Inspector3D.lastDrawFrame = -1
Inspector3D.lastMissionRef = nil
Inspector3D.lastScanTime = -1
Inspector3D.scanCache = nil
Inspector3D.backgroundOverlay = nil
Inspector3D.iconOverlays = {}

Inspector3D.settings = {
    showNearbyVehicles = true,
    showPlaceables = true,
    scanIntervalMs = Inspector3D.DEFAULT_SCAN_INTERVAL_MS,
    showBackground = true,
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 },
    accentColor = { r = 0.22, g = 0.67, b = 0.94, a = 0.95 },
    showText = false
}

local MOD_NAME = g_currentModName or "FS25_3DInspector"
local MOD_DIR = g_currentModDirectory or ""

local function getCurrentLanguageShort()
    local lang = tostring(g_languageShort or "")

    if lang == "" and g_i18n ~= nil then
        if g_i18n.getCurrentLanguage ~= nil then
            local ok, current = pcall(g_i18n.getCurrentLanguage, g_i18n)
            if ok and current ~= nil then
                if type(current) == "table" then
                    lang = tostring(current.shortName or current.languageCode or "")
                else
                    lang = tostring(current)
                end
            end
        end

        if lang == "" and g_i18n.getLanguage ~= nil then
            local ok, current = pcall(g_i18n.getLanguage, g_i18n)
            if ok and current ~= nil then
                if type(current) == "table" then
                    lang = tostring(current.shortName or current.languageCode or "")
                else
                    lang = tostring(current)
                end
            end
        end
    end

    return string.lower(tostring(lang or ""))
end

local function isGermanLanguage()
    return string.sub(getCurrentLanguageShort(), 1, 2) == "de"
end

Inspector3D.L10N_DEFAULTS = {
    unknown = { de = "Unbekannt", en = "Unknown" },
    vehicle_fallback = { de = "Fahrzeug", en = "Vehicle" },
    placeable_fallback = { de = "Objekt", en = "Placeable" },
    fill_fallback = { de = "Füllstand", en = "Fill" },
    food_fallback = { de = "Futter", en = "Food" },
    speed_unit = { de = "km/h", en = "mph" },
}

function Inspector3D:getText(key, ...)
    local fullKey = "inspector3d_" .. tostring(key or "")
    local text = nil

    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, value = pcall(g_i18n.getText, g_i18n, fullKey)
        if ok and value ~= nil and value ~= "" and value ~= fullKey then
            text = tostring(value)
        end
    end

    if text == nil then
        local defaults = self.L10N_DEFAULTS[key]
        if defaults ~= nil then
            text = isGermanLanguage() and tostring(defaults.de or key) or tostring(defaults.en or key)
        else
            text = tostring(key or "")
        end
    end

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok and formatted ~= nil then
            text = formatted
        end
    end

    return text
end

function Inspector3D.makeLine(icon, text, iconPath, shortText)
    return {
        icon = tostring(icon or ""),
        text = tostring(text or ""),
        iconPath = iconPath ~= nil and tostring(iconPath) or nil,
        shortText = shortText ~= nil and tostring(shortText) or nil
    }
end

function Inspector3D.getFillTypeIconPath(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 or (FillType ~= nil and fillTypeIndex == FillType.UNKNOWN) then
        return nil
    end

    local function getOverlayPath(fillType)
        if fillType == nil then
            return nil
        end

        local iconPath = tostring(fillType.hudOverlayFilename or fillType.hudOverlay or "")
        if iconPath ~= "" then
            return iconPath
        end

        return nil
    end

    local function getNamedFillType(name)
        if g_fillTypeManager == nil then
            return nil
        end

        if g_fillTypeManager.nameToFillType ~= nil then
            local fillType = g_fillTypeManager.nameToFillType[name]
            if fillType ~= nil then
                return fillType
            end
        end

        local index = nil
        if g_fillTypeManager.nameToIndex ~= nil then
            index = g_fillTypeManager.nameToIndex[name]
        end

        if index == nil and g_fillTypeManager.getFillTypeIndexByName ~= nil then
            local ok, resolvedIndex = pcall(g_fillTypeManager.getFillTypeIndexByName, g_fillTypeManager, name)
            if ok then
                index = resolvedIndex
            end
        end

        if index ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
            return g_fillTypeManager:getFillTypeByIndex(index)
        end

        return nil
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            local iconPath = getOverlayPath(fillType)
            if iconPath ~= nil then
                return iconPath
            end

            local fillTypeName = string.upper(tostring(fillType.name or ""))
            local fillTypeTitle = string.upper(tostring(fillType.title or ""))
            local meadowIndex = g_fillTypeManager.nameToIndex ~= nil and g_fillTypeManager.nameToIndex.MEADOW or nil

            if fillTypeIndex == meadowIndex or fillTypeName == "MEADOW" or fillTypeTitle == "MEADOW" then
                local grassIconPath = getOverlayPath(getNamedFillType("GRASS"))
                if grassIconPath ~= nil then
                    return grassIconPath
                end

                local grassWindrowIconPath = getOverlayPath(getNamedFillType("GRASS_WINDROW"))
                if grassWindrowIconPath ~= nil then
                    return grassWindrowIconPath
                end

                local dryGrassIconPath = getOverlayPath(getNamedFillType("DRYGRASS"))
                if dryGrassIconPath ~= nil then
                    return dryGrassIconPath
                end
            end
        end
    end

    return nil
end

local function dbg(fmt, ...)
    if not Inspector3D.DEBUG then
        return
    end

    local ok, msg = pcall(string.format, "[3DInspector] " .. tostring(fmt), ...)
    if ok then
        print(msg)
    else
        print("[3DInspector] " .. tostring(fmt))
    end
end

local function nowMs()
    return g_time or 0
end

local function getFrameId()
    if g_currentMission ~= nil and g_currentMission.time ~= nil then
        return g_currentMission.time
    end

    return nowMs()
end

local function ensureFolder(path)
    if path ~= nil and path ~= "" and not fileExists(path) then
        createFolder(path)
    end
end

local function clamp(v, minValue, maxValue)
    if v < minValue then
        return minValue
    end
    if v > maxValue then
        return maxValue
    end
    return v
end

local function parseColorString(value, fallback)
    local color = {
        r = fallback.r,
        g = fallback.g,
        b = fallback.b,
        a = fallback.a
    }

    if type(value) ~= "string" or value == "" then
        return color
    end

    local parts = {}
    for token in string.gmatch(value, "[^%s,;]+") do
        parts[#parts + 1] = tonumber(token)
    end

    if #parts >= 3 then
        color.r = clamp(parts[1] or color.r, 0, 1)
        color.g = clamp(parts[2] or color.g, 0, 1)
        color.b = clamp(parts[3] or color.b, 0, 1)
        color.a = clamp(parts[4] or color.a, 0, 1)
    end

    return color
end

local function colorToString(color)
    return string.format("%.3f %.3f %.3f %.3f", color.r or 0, color.g or 0, color.b or 0, color.a or 0.55)
end

local function isAltPressed()
    local leftPressed = false
    local rightPressed = false

    if Input ~= nil and Input.isKeyPressed ~= nil then
        if Input.KEY_lalt ~= nil then
            leftPressed = Input.isKeyPressed(Input.KEY_lalt) == true
        end

        if Input.KEY_ralt ~= nil then
            rightPressed = Input.isKeyPressed(Input.KEY_ralt) == true
        end
    end

    return leftPressed or rightPressed, leftPressed, rightPressed
end

local function getCameraNode()
    if g_currentMission ~= nil and g_currentMission.camera ~= nil and g_currentMission.camera.node ~= nil then
        return g_currentMission.camera.node
    end

    if getCamera ~= nil then
        return getCamera()
    end

    return nil
end

local function drawText2D(x, y, text, size, alignCenter)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)

    if alignCenter then
        setTextAlignment(RenderText.ALIGN_CENTER)
    else
        setTextAlignment(RenderText.ALIGN_LEFT)
    end

    renderText(x, y, size, tostring(text))
    setTextAlignment(RenderText.ALIGN_LEFT)
end

local function drawBackgroundRect(x, y, width, height, color)
    if not Inspector3D.settings.showBackground or Inspector3D.backgroundOverlay == nil then
        return
    end

    setOverlayColor(Inspector3D.backgroundOverlay, color.r or 0, color.g or 0, color.b or 0, color.a or 0.55)
    renderOverlay(Inspector3D.backgroundOverlay, x, y, width, height)
end

local function drawTextWithBackground(x, y, text, size, alignCenter)
    local paddingX = Inspector3D.BACKGROUND_PADDING_X
    local paddingY = Inspector3D.BACKGROUND_PADDING_Y
    local textValue = tostring(text)

    if Inspector3D.settings.showBackground then
        local width = getTextWidth(size, textValue)
        local height = size + (paddingY * 2)
        local bx = x - paddingX

        if alignCenter then
            bx = x - (width * 0.5) - paddingX
        end

        drawBackgroundRect(
            bx,
            y - paddingY,
            width + (paddingX * 2),
            height,
            Inspector3D.settings.backgroundColor
        )
    end

    drawText2D(x, y, textValue, size, alignCenter)
end

local function normalizeLineEntry(line)
    if type(line) == "table" then
        return tostring(line.text or ""), line.shortText ~= nil and tostring(line.shortText) or nil, tostring(line.icon or ""), line.iconPath ~= nil and tostring(line.iconPath) or nil
    end

    return tostring(line or ""), nil, "", nil
end

local function getLineIconOverlay(icon, iconPath)
    if iconPath ~= nil and iconPath ~= "" and createImageOverlay ~= nil then
        local overlay = Inspector3D.iconOverlays[iconPath]
        if overlay == nil then
            local ok, created = pcall(createImageOverlay, iconPath)
            if ok and created ~= nil then
                Inspector3D.iconOverlays[iconPath] = created
                overlay = created
            end
        end

        if overlay ~= nil then
            return overlay
        end
    end

    if icon == nil or icon == "" then
        return nil
    end

    return Inspector3D.iconOverlays[icon]
end

local function drawPanelText(x, y, text, size, bold)
    setTextBold(bold == true)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x, y, size, tostring(text or ""))
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
end

local function getPanelLineLayout(line, baseSize)
    local fullText, shortText, icon, iconPath = normalizeLineEntry(line)
    local iconOverlay = getLineIconOverlay(icon, iconPath)
    local showLabels = Inspector3D.settings.showText == true

    local primaryText = shortText ~= nil and shortText or fullText
    local secondaryText = nil

    if showLabels then
        local colonPos = string.find(fullText, ":", 1, true)
        if colonPos ~= nil then
            secondaryText = string.sub(fullText, 1, colonPos - 1)
        elseif shortText ~= nil and shortText ~= "" and fullText ~= shortText then
            secondaryText = fullText
        end
    end

    primaryText = tostring(primaryText or "")
    secondaryText = secondaryText ~= nil and tostring(secondaryText) or nil

    local primarySize = showLabels and (baseSize * 0.96) or baseSize
    local secondarySize = baseSize * 0.72
    local iconSize = iconOverlay ~= nil and (baseSize * (showLabels and 1.55 or 1.10)) or 0
    local primaryWidth = primaryText ~= "" and getTextWidth(primarySize, primaryText) or 0
    local secondaryWidth = secondaryText ~= nil and secondaryText ~= "" and getTextWidth(secondarySize, secondaryText) or 0
    local textWidth = math.max(primaryWidth, secondaryWidth)
    local textHeight = primarySize

    if secondaryText ~= nil and secondaryText ~= "" then
        textHeight = primarySize + Inspector3D.PANEL_TEXT_GAP + secondarySize
    end

    local rowHeight = math.max(iconSize, textHeight)

    return {
        fullText = fullText,
        shortText = shortText,
        primaryText = primaryText,
        secondaryText = secondaryText,
        iconOverlay = iconOverlay,
        iconSize = iconSize,
        primarySize = primarySize,
        secondarySize = secondarySize,
        textWidth = textWidth,
        rowHeight = rowHeight
    }
end

local function drawLinesPanel(centerX, topY, lines, baseSize)
    local layouts = {}
    local maxTextWidth = 0
    local maxIconSize = 0
    local rowGap = Inspector3D.PANEL_ROW_GAP
    local paddingX = Inspector3D.PANEL_PADDING_X
    local paddingY = Inspector3D.PANEL_PADDING_Y
    local accentWidth = Inspector3D.PANEL_ACCENT_WIDTH

    for i = 1, #lines do
        local layout = getPanelLineLayout(lines[i], baseSize)
        layouts[#layouts + 1] = layout
        if layout.textWidth > maxTextWidth then
            maxTextWidth = layout.textWidth
        end
        if layout.iconSize > maxIconSize then
            maxIconSize = layout.iconSize
        end
    end

    if #layouts == 0 then
        return
    end

    local iconColumnWidth = maxIconSize > 0 and (maxIconSize + (baseSize * 0.40)) or 0
    local contentHeight = 0
    for i = 1, #layouts do
        contentHeight = contentHeight + layouts[i].rowHeight
        if i < #layouts then
            contentHeight = contentHeight + rowGap
        end
    end

    local panelWidth = accentWidth + (paddingX * 2) + iconColumnWidth + maxTextWidth
    local panelHeight = (paddingY * 2) + contentHeight
    local panelLeft = centerX - (panelWidth * 0.5)
    local panelBottom = topY - panelHeight + (baseSize * 0.18)

    if Inspector3D.settings.showBackground then
        drawBackgroundRect(panelLeft, panelBottom, panelWidth, panelHeight, Inspector3D.settings.backgroundColor)
        if Inspector3D.backgroundOverlay ~= nil then
            local accentColor = Inspector3D.settings.accentColor or { r = 0.22, g = 0.67, b = 0.94, a = 0.95 }
            setOverlayColor(
                Inspector3D.backgroundOverlay,
                accentColor.r or 0.22,
                accentColor.g or 0.67,
                accentColor.b or 0.94,
                accentColor.a or 0.95
            )
            renderOverlay(
                Inspector3D.backgroundOverlay,
                panelLeft,
                panelBottom,
                accentWidth,
                panelHeight
            )
        end
    end

    local textLeft = panelLeft + accentWidth + paddingX + iconColumnWidth
    local iconLeft = panelLeft + accentWidth + paddingX
    local cursorTop = panelBottom + panelHeight - paddingY

    for i = 1, #layouts do
        local layout = layouts[i]
        local rowTop = cursorTop
        local rowBottom = rowTop - layout.rowHeight

        if layout.iconOverlay ~= nil then
            local iconX = iconLeft + math.max(0, (iconColumnWidth - layout.iconSize) * 0.5)
            local iconY = rowBottom + math.max(0, (layout.rowHeight - layout.iconSize) * 0.5)
            renderOverlay(layout.iconOverlay, iconX, iconY, layout.iconSize, layout.iconSize)
        end

        if layout.secondaryText ~= nil and layout.secondaryText ~= "" then
            local primaryY = rowTop - layout.primarySize
            local secondaryY = primaryY - Inspector3D.PANEL_TEXT_GAP - layout.secondarySize
            drawPanelText(textLeft, primaryY, layout.primaryText, layout.primarySize, true)
            drawPanelText(textLeft, secondaryY, layout.secondaryText, layout.secondarySize, false)
        else
            local primaryY = rowBottom + math.max(0, (layout.rowHeight - layout.primarySize) * 0.5)
            drawPanelText(textLeft, primaryY, layout.primaryText, layout.primarySize, true)
        end

        cursorTop = rowBottom - rowGap
    end
end

local function getDistanceSqFromWorld(ax, ay, az, bx, by, bz)
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return dx * dx + dy * dy + dz * dz
end

local function getDistanceSq(nodeA, nodeB)
    if nodeA == nil or nodeB == nil or nodeA == 0 or nodeB == 0 then
        return math.huge
    end

    local ax, ay, az = getWorldTranslation(nodeA)
    local bx, by, bz = getWorldTranslation(nodeB)
    return getDistanceSqFromWorld(ax, ay, az, bx, by, bz)
end

local function tryNoArgMethod(obj, methodName)
    if obj == nil then
        return nil
    end

    local fn = obj[methodName]
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn, obj)
    if ok then
        return result
    end

    return nil
end

local function getFillTypeTitle(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 or (FillType ~= nil and fillTypeIndex == FillType.UNKNOWN) then
        return Inspector3D:getText("unknown")
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            return fillType.title or fillType.name or Inspector3D:getText("unknown")
        end
    end

    return Inspector3D:getText("unknown")
end

local function isValidVehicle(vehicle)
    return vehicle ~= nil
        and type(vehicle) == "table"
        and vehicle.components ~= nil
        and vehicle.components[1] ~= nil
        and vehicle.components[1].node ~= nil
end

local function getVehicleDebugName(vehicle)
    if vehicle == nil then
        return "nil"
    end

    if vehicle.getFullName ~= nil then
        local ok, result = pcall(vehicle.getFullName, vehicle)
        if ok and result ~= nil and result ~= "" then
            return tostring(result)
        end
    end

    if vehicle.getName ~= nil then
        local ok, result = pcall(vehicle.getName, vehicle)
        if ok and result ~= nil and result ~= "" then
            return tostring(result)
        end
    end

    return tostring(vehicle.configFileName or vehicle.typeName or Inspector3D:getText("vehicle_fallback"))
end

local function getVehicleRootNode(vehicle)
    if vehicle == nil then
        return nil
    end

    if vehicle.rootNode ~= nil and vehicle.rootNode ~= 0 then
        return vehicle.rootNode
    end

    if vehicle.components ~= nil and vehicle.components[1] ~= nil then
        return vehicle.components[1].node
    end

    return nil
end

local function getVehicleRoot(vehicle)
    if vehicle == nil then
        return nil
    end

    if vehicle.getRootVehicle ~= nil then
        local ok, rootVehicle = pcall(vehicle.getRootVehicle, vehicle)
        if ok and isValidVehicle(rootVehicle) then
            return rootVehicle
        end
    end

    return vehicle
end

local function getSelectedSeedLine(vehicle)
    local sowingMachine = vehicle.spec_sowingMachine
    if sowingMachine == nil or sowingMachine.seeds == nil or sowingMachine.currentSeed == nil then
        return nil
    end

    local selectedSeedFruitType = sowingMachine.seeds[sowingMachine.currentSeed]
    if selectedSeedFruitType == nil then
        return nil
    end

    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFillTypeIndexByFruitTypeIndex ~= nil then
        local fillTypeIndex = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(selectedSeedFruitType)
        if fillTypeIndex ~= nil then
            return Inspector3D.makeLine("crop", getFillTypeTitle(fillTypeIndex), Inspector3D.getFillTypeIconPath(fillTypeIndex))
        end
    end

    return nil
end

local function isAirFillType(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 then
        return false
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            local name = tostring(fillType.name or "")
            local title = tostring(fillType.title or "")
            if string.upper(name) == "AIR" or string.upper(title) == "AIR" then
                return true
            end
        end
    end

    return false
end

local function getSpeedUnitText()
    return Inspector3D:getText("speed_unit")
end

local function getVehicleSpeedDisplay(vehicle)
    if vehicle == nil then
        return nil
    end

    local rawSpeed = nil

    if vehicle.getLastSpeed ~= nil then
        rawSpeed = tryNoArgMethod(vehicle, "getLastSpeed")
    end

    if rawSpeed == nil then
        rawSpeed = vehicle.lastSpeed
    end

    if rawSpeed == nil and vehicle.spec_motorized ~= nil then
        rawSpeed = vehicle.spec_motorized.lastSpeed
    end

    rawSpeed = tonumber(rawSpeed)
    if rawSpeed == nil then
        return nil
    end

    rawSpeed = math.max(0, rawSpeed)

    -- getLastSpeed() returns km/h already, no m/s conversion needed
    local displaySpeed = nil
    if isGermanLanguage() then
        displaySpeed = rawSpeed
    else
        displaySpeed = rawSpeed * 0.621371192
    end

    return math.floor((tonumber(displaySpeed) or 0) + 0.5), getSpeedUnitText()
end

local function hasAttacherVehicle(vehicle)
    if vehicle == nil then
        return false
    end

    if isValidVehicle(vehicle.attacherVehicle) then
        return true
    end

    local attacherVehicle = tryNoArgMethod(vehicle, "getAttacherVehicle")
    if isValidVehicle(attacherVehicle) then
        return true
    end

    if vehicle.spec_attachable ~= nil then
        local specAttachable = vehicle.spec_attachable

        if isValidVehicle(specAttachable.attacherVehicle) then
            return true
        end

        if specAttachable.attacherVehicleJointDescIndex ~= nil then
            return true
        end
    end

    return false
end

local function isSelfPropelledVehicle(vehicle)
    if vehicle == nil then
        return false
    end

    if hasAttacherVehicle(vehicle) then
        return false
    end

    return vehicle.spec_motorized ~= nil
        or vehicle.spec_drivable ~= nil
        or vehicle.spec_enterable ~= nil
end

local function isVehicleSpeedRelevant(vehicle, isControlledVehicle)
    if vehicle == nil or isControlledVehicle then
        return false
    end

    if not isSelfPropelledVehicle(vehicle) then
        return false
    end

    if tryNoArgMethod(vehicle, "getIsAIActive") == true then
        return true
    end

    if tryNoArgMethod(vehicle, "getIsEntered") == true then
        return true
    end

    if tryNoArgMethod(vehicle, "getIsControlled") == true then
        return true
    end

    local specAI = vehicle.spec_aiVehicle
    if specAI ~= nil then
        if specAI.isActive == true or specAI.isAIActive == true or specAI.startedDriving == true then
            return true
        end
    end

    local specEnterable = vehicle.spec_enterable
    if specEnterable ~= nil then
        if specEnterable.isEntered == true or specEnterable.controller ~= nil or specEnterable.currentPlayer ~= nil then
            return true
        end
    end

    local speedValue = getVehicleSpeedDisplay(vehicle)
    if speedValue ~= nil and speedValue > 0 then
        return true
    end

    return false
end

local function getVehicleLines(vehicle, isControlledVehicle)
    local lines = {}
    local selectedSeedLine = getSelectedSeedLine(vehicle)
    local insertedSeedLine = false

    if vehicle ~= nil and vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil
        and vehicle.getFillUnitCapacity ~= nil and vehicle.getFillUnitFillLevel ~= nil and vehicle.getFillUnitFillType ~= nil then
        for _, fillUnit in ipairs(vehicle.spec_fillUnit.fillUnits) do
            local index = fillUnit.fillUnitIndex
            if index ~= nil then
                local capacity = vehicle:getFillUnitCapacity(index) or 0
                local fillLevel = vehicle:getFillUnitFillLevel(index) or 0

                if capacity > 0 and fillLevel > 0.001 then
                    local fillTypeIndex = vehicle:getFillUnitFillType(index)

                    if not isAirFillType(fillTypeIndex) then
                        local percent = math.floor((fillLevel / capacity) * 100 + 0.5)

                        table.insert(
                            lines,
                            Inspector3D.makeLine(
                                "fill",
                                string.format(
                                    "%s: %d / %d L (%d%%)",
                                    getFillTypeTitle(fillTypeIndex),
                                    math.floor(fillLevel + 0.5),
                                    math.floor(capacity + 0.5),
                                    percent
                                ),
                                Inspector3D.getFillTypeIconPath(fillTypeIndex),
                                string.format(
                                    "%d / %d L (%d%%)",
                                    math.floor(fillLevel + 0.5),
                                    math.floor(capacity + 0.5),
                                    percent
                                )
                            )
                        )

                        if selectedSeedLine ~= nil and not insertedSeedLine then
                            table.insert(lines, selectedSeedLine)
                            insertedSeedLine = true
                        end
                    end
                end
            end
        end
    end

    if isVehicleSpeedRelevant(vehicle, isControlledVehicle) then
        local speedValue, speedUnit = getVehicleSpeedDisplay(vehicle)
        if speedValue ~= nil then
            table.insert(lines, Inspector3D.makeLine("speed", string.format("%d %s", speedValue, speedUnit or getSpeedUnitText())))
        end
    end

    if #lines == 0 then
        return nil
    end

    return lines
end

local function tryNodeBoundingBox(node)
    if node == nil or node == 0 then
        return nil
    end

    if type(getNodeBoundingBox) == "function" then
        local ok, minX, minY, minZ, maxX, maxY, maxZ = pcall(getNodeBoundingBox, node)
        if ok and minX ~= nil then
            return minX, minY, minZ, maxX, maxY, maxZ
        end
    end

    if type(getBoundingBox) == "function" then
        local ok, minX, minY, minZ, maxX, maxY, maxZ = pcall(getBoundingBox, node)
        if ok and minX ~= nil then
            return minX, minY, minZ, maxX, maxY, maxZ
        end
    end

    return nil
end

local function getVehicleAnchor(vehicle)
    local rootNode = getVehicleRootNode(vehicle)
    if rootNode == nil or rootNode == 0 then
        return nil, nil, nil
    end

    local minX, minY, minZ, maxX, maxY, maxZ = tryNodeBoundingBox(rootNode)
    if minX ~= nil then
        return localToWorld(rootNode, (minX + maxX) * 0.5, maxY + 0.25, (minZ + maxZ) * 0.5)
    end

    local highestY = nil
    local sumX = 0
    local sumZ = 0
    local count = 0

    for _, comp in ipairs(vehicle.components) do
        local wx, wy, wz = getWorldTranslation(comp.node)
        sumX = sumX + wx
        sumZ = sumZ + wz
        count = count + 1

        if highestY == nil or wy > highestY then
            highestY = wy
        end
    end

    if count > 0 then
        return sumX / count, (highestY or 0) + Inspector3D.FALLBACK_WORLD_OFFSET, sumZ / count
    end

    local x, y, z = getWorldTranslation(rootNode)
    return x, y + Inspector3D.FALLBACK_WORLD_OFFSET, z
end

local function isPointInFrontOfCamera(worldX, worldY, worldZ, cameraNode)
    if cameraNode == nil or cameraNode == 0 then
        return false
    end

    local cx, cy, cz = getWorldTranslation(cameraNode)
    local fx, fy, fz = localDirectionToWorld(cameraNode, 0, 0, -1)

    local dx = worldX - cx
    local dy = worldY - cy
    local dz = worldZ - cz
    local dot = dx * fx + dy * fy + dz * fz

    return dot > Inspector3D.CAMERA_DOT_MIN
end

local function projectVisiblePoint(worldX, worldY, worldZ, cameraNode)
    if not isPointInFrontOfCamera(worldX, worldY, worldZ, cameraNode) then
        return nil, nil, nil
    end

    local sx, sy, sz = project(worldX, worldY, worldZ)
    if sx == nil or sy == nil or sz == nil or sz <= 0 then
        return nil, nil, nil
    end

    local b = Inspector3D.SCREEN_BORDER
    if sx < b or sx > 1 - b or sy < b or sy > 1 - b then
        return nil, nil, nil
    end

    return sx, sy, sz
end

local function addUniqueVehicle(outList, seen, vehicle)
    if not isValidVehicle(vehicle) or seen[vehicle] then
        return false
    end

    seen[vehicle] = true
    table.insert(outList, vehicle)
    return true
end

local function collectAttachedImplements(vehicle, outList, seen, depth)
    if vehicle == nil then
        return
    end

    depth = depth or 0
    if depth > 12 then
        return
    end

    if vehicle.getAttachedImplements ~= nil then
        local ok, implements = pcall(vehicle.getAttachedImplements, vehicle)
        if ok and implements ~= nil then
            for _, impl in pairs(implements) do
                if impl.object ~= nil then
                    if addUniqueVehicle(outList, seen, impl.object) then
                        collectAttachedImplements(impl.object, outList, seen, depth + 1)
                    end
                end
            end
        end
    end
end

local function getControlledVehicle(mission)
    local activeMission = mission or g_currentMission
    local player = activeMission ~= nil and activeMission.player or g_localPlayer

    if activeMission ~= nil and isValidVehicle(activeMission.controlledVehicle) then
        return activeMission.controlledVehicle
    end

    if player ~= nil then
        if player.baseInformation ~= nil and isValidVehicle(player.baseInformation.currentVehicle) then
            return player.baseInformation.currentVehicle
        end

        local currentVehicle = tryNoArgMethod(player, "getCurrentVehicle")
        if isValidVehicle(currentVehicle) then
            return currentVehicle
        end

        local enteredVehicle = tryNoArgMethod(player, "getEnteredVehicle")
        if isValidVehicle(enteredVehicle) then
            return enteredVehicle
        end
    end

    return nil
end

local function buildExcludedVehicleSet(controlledVehicle)
    local excluded = {}

    controlledVehicle = getVehicleRoot(controlledVehicle)
    if controlledVehicle ~= nil then
        excluded[controlledVehicle] = true
        collectAttachedImplements(controlledVehicle, {}, excluded, 0)
    end

    return excluded
end

local function getMissionVehicleList(mission)
    local result = {}

    if mission ~= nil and mission.vehicleSystem ~= nil and mission.vehicleSystem.vehicles ~= nil then
        for _, vehicle in pairs(mission.vehicleSystem.vehicles) do
            table.insert(result, vehicle)
        end
        return result
    end

    if mission ~= nil and mission.vehicles ~= nil then
        for _, vehicle in pairs(mission.vehicles) do
            table.insert(result, vehicle)
        end
        return result
    end

    if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles ~= nil then
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            table.insert(result, vehicle)
        end
        return result
    end

    if g_currentMission ~= nil and g_currentMission.vehicles ~= nil then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            table.insert(result, vehicle)
        end
    end

    return result
end

local function getRelevantVehicles(mission, cameraNode)
    local result = {}
    local seen = {}
    local controlledVehicle = getVehicleRoot(getControlledVehicle(mission))
    local excludedVehicles = buildExcludedVehicleSet(controlledVehicle)
    local maxDistanceSq = Inspector3D.MAX_DISTANCE * Inspector3D.MAX_DISTANCE

    if Inspector3D.settings.showNearbyVehicles and cameraNode ~= nil and cameraNode ~= 0 then
        local allVehicles = getMissionVehicleList(mission)

        for _, vehicle in ipairs(allVehicles) do
            vehicle = getVehicleRoot(vehicle)

            if isValidVehicle(vehicle) and not excludedVehicles[vehicle] then
                local rootNode = getVehicleRootNode(vehicle)
                local distSq = getDistanceSq(rootNode, cameraNode)

                if distSq <= maxDistanceSq then
                    if addUniqueVehicle(result, seen, vehicle) then
                        collectAttachedImplements(vehicle, result, seen, 0)
                    end
                end
            end
        end
    end

    return result, controlledVehicle
end

function Inspector3D:getSettingsPath()
    return getUserProfileAppPath() .. "modSettings/" .. MOD_NAME .. "/settings.xml"
end

function Inspector3D:createDefaultSettingsFile(path)
    local xml = createXMLFile("Inspector3DSettings", path, "settings")
    setXMLBool(xml, "settings#showNearbyVehicles", true)
    setXMLBool(xml, "settings#showPlaceables", true)
    setXMLString(xml, "settings#scanIntervalMs", tostring(self.DEFAULT_SCAN_INTERVAL_MS))
    setXMLBool(xml, "settings#showBackground", true)
    setXMLString(xml, "settings#backgroundColor", "0 0 0 0.55")
    setXMLString(xml, "settings#accentColor", "0.22 0.67 0.94 0.95")
    setXMLBool(xml, "settings#showText", false)
    saveXMLFile(xml)
    delete(xml)
end

function Inspector3D:loadSettings()
    local dir = getUserProfileAppPath() .. "modSettings/" .. MOD_NAME .. "/"
    local path = self:getSettingsPath()

    ensureFolder(getUserProfileAppPath() .. "modSettings/")
    ensureFolder(dir)

    if not fileExists(path) then
        self:createDefaultSettingsFile(path)
    end

    local xml = loadXMLFile("Inspector3DSettings", path)
    if xml ~= nil then
        local showNearbyVehicles = getXMLBool(xml, "settings#showNearbyVehicles")
        local showPlaceables = getXMLBool(xml, "settings#showPlaceables")
        local scanIntervalMs = tonumber(getXMLString(xml, "settings#scanIntervalMs")) or self.DEFAULT_SCAN_INTERVAL_MS
        local showBackground = getXMLBool(xml, "settings#showBackground")
        local backgroundColor = getXMLString(xml, "settings#backgroundColor")
        local accentColor = getXMLString(xml, "settings#accentColor")
        local showText = getXMLBool(xml, "settings#showText")

        self.settings.showNearbyVehicles = showNearbyVehicles ~= false
        self.settings.showPlaceables = showPlaceables ~= false
        self.settings.scanIntervalMs = math.max(0, math.floor(scanIntervalMs + 0.5))
        self.settings.showBackground = showBackground ~= false
        self.settings.backgroundColor = parseColorString(backgroundColor, self.settings.backgroundColor)
        self.settings.accentColor = parseColorString(accentColor, self.settings.accentColor)
        self.settings.showText = showText == true

        setXMLBool(xml, "settings#showNearbyVehicles", self.settings.showNearbyVehicles)
        setXMLBool(xml, "settings#showPlaceables", self.settings.showPlaceables)
        setXMLString(xml, "settings#scanIntervalMs", tostring(self.settings.scanIntervalMs))
        setXMLBool(xml, "settings#showBackground", self.settings.showBackground)
        setXMLString(xml, "settings#backgroundColor", colorToString(self.settings.backgroundColor))
        setXMLString(xml, "settings#accentColor", colorToString(self.settings.accentColor))
        setXMLBool(xml, "settings#showText", self.settings.showText)
        saveXMLFile(xml)
        delete(xml)
    end

    dbg(
        "settings loaded nearby=%s placeables=%s scanIntervalMs=%s background=%s labels=%s color=%s accent=%s",
        tostring(self.settings.showNearbyVehicles),
        tostring(self.settings.showPlaceables),
        tostring(self.settings.scanIntervalMs),
        tostring(self.settings.showBackground),
        tostring(self.settings.showText),
        colorToString(self.settings.backgroundColor),
        colorToString(self.settings.accentColor)
    )
end

function Inspector3D:ensureBackgroundOverlay()
    local function firstExistingPath(paths)
        for _, path in ipairs(paths) do
            if fileExists(path) then
                return path
            end
        end
        return nil
    end

    if self.backgroundOverlay == nil then
        local whitePath = firstExistingPath({
            MOD_DIR .. "textures/white.dds"
        })

        if whitePath ~= nil and createImageOverlay ~= nil then
            self.backgroundOverlay = createImageOverlay(whitePath)
        end
    end

    local iconFiles = {
        speed = {
            MOD_DIR .. "textures/icon_speed.dds"
        }
    }

    for key, candidates in pairs(iconFiles) do
        if self.iconOverlays[key] == nil then
            local path = firstExistingPath(candidates)
            if path ~= nil and createImageOverlay ~= nil then
                self.iconOverlays[key] = createImageOverlay(path)
            end
        end
    end
end

function Inspector3D:deleteBackgroundOverlay()
    if self.backgroundOverlay ~= nil then
        delete(self.backgroundOverlay)
        self.backgroundOverlay = nil
    end

    for key, overlay in pairs(self.iconOverlays) do
        if overlay ~= nil then
            delete(overlay)
        end
        self.iconOverlays[key] = nil
    end
end

function Inspector3D:clearScanCache()
    self.scanCache = nil
    self.lastScanTime = -1
end

function Inspector3D:loadMap(mapNode)
    self.isLoaded = true
    self.lastDrawFrame = -1
    self.lastMissionRef = nil
    self:clearScanCache()
    self:loadSettings()
    self:ensureBackgroundOverlay()

    if Inspector3DPlaceableInfo ~= nil then
        Inspector3DPlaceableInfo.DEBUG = self.DEBUG
    end

    dbg("loadMap called mapNode=%s", tostring(mapNode))
end

function Inspector3D:deleteMap()
    self.isLoaded = false
    self:clearScanCache()
    self:deleteBackgroundOverlay()
    dbg("deleteMap called")
end

function Inspector3D:update(_)
    local pressed = isAltPressed()
    self.isAltDown = pressed == true

    if self.lastAltState ~= self.isAltDown then
        self.lastAltState = self.isAltDown
        if not self.isAltDown then
            self:clearScanCache()
        end
    end
end

function Inspector3D:performScan(activeMission, cameraNode)
    local relevantVehicles, controlledVehicle = getRelevantVehicles(activeMission, cameraNode)
    local relevantPlaceables = {}

    if self.settings.showPlaceables and Inspector3DPlaceableInfo ~= nil and Inspector3DPlaceableInfo.collectRelevantPlaceables ~= nil then
        relevantPlaceables = Inspector3DPlaceableInfo.collectRelevantPlaceables(activeMission, cameraNode, self.MAX_DISTANCE * self.MAX_DISTANCE)
    end

    local cache = {
        source = "scan",
        controlledVehicle = controlledVehicle,
        relevantVehicles = #relevantVehicles,
        relevantPlaceables = #relevantPlaceables,
        scanned = 0,
        fillable = 0,
        drawn = 0,
        firstName = nil,
        entries = {}
    }

    for _, vehicle in ipairs(relevantVehicles) do
        cache.scanned = cache.scanned + 1

        local isControlledVehicle = controlledVehicle ~= nil and vehicle == controlledVehicle
        local lines = getVehicleLines(vehicle, isControlledVehicle)
        if lines ~= nil and #lines > 0 then
            cache.fillable = cache.fillable + 1
            if cache.firstName == nil then
                cache.firstName = getVehicleDebugName(vehicle)
            end

            cache.entries[#cache.entries + 1] = {
                kind = "vehicle",
                object = vehicle,
                lines = lines
            }
        end
    end

    for _, placeable in ipairs(relevantPlaceables) do
        cache.scanned = cache.scanned + 1

        local lines = Inspector3DPlaceableInfo.getLines(placeable)
        if lines ~= nil and #lines > 0 then
            cache.fillable = cache.fillable + 1
            if cache.firstName == nil then
                cache.firstName = Inspector3DPlaceableInfo.getDebugName(placeable)
            end

            cache.entries[#cache.entries + 1] = {
                kind = "placeable",
                object = placeable,
                lines = lines
            }
        end
    end

    self.scanCache = cache
    self.lastScanTime = nowMs()

    dbg(
        "scan built scanned=%d fillable=%d entries=%d first=%s",
        cache.scanned,
        cache.fillable,
        #cache.entries,
        tostring(cache.firstName)
    )
end

function Inspector3D:refreshScanIfNeeded(activeMission, cameraNode)
    if not self.isAltDown then
        return
    end

    local t = nowMs()
    local intervalMs = math.max(0, tonumber(self.settings.scanIntervalMs) or self.DEFAULT_SCAN_INTERVAL_MS)

    if self.scanCache == nil or intervalMs == 0 or self.lastScanTime < 0 or (t - self.lastScanTime) >= intervalMs then
        self:performScan(activeMission, cameraNode)
    end
end

function Inspector3D:drawWorldLines(lines, worldX, worldY, worldZ, cameraNode)
    local sx, sy = projectVisiblePoint(worldX, worldY, worldZ, cameraNode)
    if sx == nil or sy == nil then
        return false
    end

    drawLinesPanel(
        sx,
        sy,
        lines,
        getCorrectTextSize(self.TEXT_SIZE)
    )

    return true
end

function Inspector3D:drawDebugHud(sourceName)
    if not self.DEBUG then
        return
    end

    local cache = self.scanCache or {}
    local hudLines = {
        "3DInspector ACTIVE",
        string.format("Source: %s", tostring(sourceName)),
        "ALT: " .. tostring(self.isAltDown),
        string.format("Scanned: %d", tonumber(cache.scanned or 0)),
        string.format("Detected: %d", tonumber(cache.fillable or 0)),
        string.format("Drawn: %d", tonumber(cache.drawn or 0)),
        string.format("First: %s", tostring(cache.firstName or "-"))
    }

    local startX = 0.02
    local startY = 0.95
    local stepY = 0.018
    local hudTextSize = getCorrectTextSize(0.014)

    for i = 1, #hudLines do
        drawTextWithBackground(startX, startY - ((i - 1) * stepY), hudLines[i], hudTextSize, false)
    end
end

function Inspector3D:drawInternal(sourceName, mission)
    if not self.isLoaded then
        return
    end

    local frameId = getFrameId()
    if self.lastDrawFrame == frameId then
        return
    end
    self.lastDrawFrame = frameId

    self.lastMissionRef = mission or self.lastMissionRef

    if not self.isAltDown then
        if self.DEBUG then
            self:drawDebugHud(sourceName)
        end
        return
    end

    local activeMission = mission or self.lastMissionRef or g_currentMission
    local cameraNode = getCameraNode()
    if activeMission == nil or cameraNode == nil or cameraNode == 0 then
        return
    end

    self:refreshScanIfNeeded(activeMission, cameraNode)

    local cache = self.scanCache
    if cache == nil or cache.entries == nil then
        return
    end

    cache.drawn = 0

    for _, entry in ipairs(cache.entries) do
        local wx, wy, wz = nil, nil, nil

        if entry.kind == "vehicle" then
            wx, wy, wz = getVehicleAnchor(entry.object)
        elseif Inspector3DPlaceableInfo ~= nil then
            wx, wy, wz = Inspector3DPlaceableInfo.getAnchor(entry.object)
        end

        if wx ~= nil and self:drawWorldLines(entry.lines, wx, wy, wz, cameraNode) then
            cache.drawn = cache.drawn + 1
        end
    end

    self:drawDebugHud(sourceName)
end

function Inspector3D:drawFromFSBaseMission(mission)
    self:drawInternal("FSBaseMission.draw", mission)
end

function Inspector3D:drawFromBaseMission(mission)
    self:drawInternal("BaseMission.draw", mission)
end

function Inspector3D:drawFromMission00(mission)
    self:drawInternal("Mission00.draw", mission)
end

FSBaseMission.loadMap = Utils.appendedFunction(FSBaseMission.loadMap, function(mission, mapNode, ...)
    if Inspector3D ~= nil and Inspector3D.loadMap ~= nil then
        Inspector3D:loadMap(mapNode)
    end
end)

FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, function(mission)
    if Inspector3D ~= nil and Inspector3D.deleteMap ~= nil then
        Inspector3D:deleteMap()
    end
end)

FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
    if Inspector3D ~= nil and Inspector3D.update ~= nil then
        Inspector3D:update(dt)
    end
end)

if FSBaseMission ~= nil and FSBaseMission.draw ~= nil then
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function(mission, ...)
        if Inspector3D ~= nil and Inspector3D.drawFromFSBaseMission ~= nil then
            Inspector3D:drawFromFSBaseMission(mission)
        end
    end)
end

if BaseMission ~= nil and BaseMission.draw ~= nil then
    BaseMission.draw = Utils.appendedFunction(BaseMission.draw, function(mission, ...)
        if Inspector3D ~= nil and Inspector3D.drawFromBaseMission ~= nil then
            Inspector3D:drawFromBaseMission(mission)
        end
    end)
end

if Mission00 ~= nil and Mission00.draw ~= nil then
    Mission00.draw = Utils.appendedFunction(Mission00.draw, function(mission, ...)
        if Inspector3D ~= nil and Inspector3D.drawFromMission00 ~= nil then
            Inspector3D:drawFromMission00(mission)
        end
    end)
end

print("[3DInspector] draw hooks installed for FSBaseMission/BaseMission/Mission00")
