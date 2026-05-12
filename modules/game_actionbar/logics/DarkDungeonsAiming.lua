DDAiming = {}

local AIMED_SPELL_OPCODE = 222
local USE_TALKACTION_BRIDGE = true
local PREVIEW_OFFSET_TILES = { x = 2.7, y = 0 }
local currentAim

local rupturaNarrowOffsets = {
    {x = 0, y = -2},
    {x = -1, y = -1}, {x = 0, y = -1}, {x = 1, y = -1},
    {x = -3, y = 0}, {x = -2, y = 0}, {x = -1, y = 0}, {x = 0, y = 0}, {x = 1, y = 0}, {x = 2, y = 0}, {x = 3, y = 0},
    {x = -1, y = 1}, {x = 0, y = 1}, {x = 1, y = 1},
    {x = 0, y = 2}
}

local targetCrossOffsets = {
    {x = 0, y = -1},
    {x = -1, y = 0}, {x = 0, y = 0}, {x = 1, y = 0},
    {x = 0, y = 1}
}

local singleTileOffsets = {
    {x = 0, y = 0}
}

local square3x3Offsets = {
    {x = -1, y = -1}, {x = 0, y = -1}, {x = 1, y = -1},
    {x = -1, y = 0}, {x = 0, y = 0}, {x = 1, y = 0},
    {x = -1, y = 1}, {x = 0, y = 1}, {x = 1, y = 1}
}

local aimedSkills = {
    ["dd ruptura"] = {
        id = "dd_campo_ruptura",
        name = "DD Campo de Ruptura",
        range = 6,
        cooldownMs = 20000,
        offsets = rupturaNarrowOffsets,
        color = "#00e5ff",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd arcano"] = {
        id = "dd_proyectil_arcano",
        name = "DD Proyectil Arcano",
        range = 5,
        cooldownMs = 5000,
        offsets = targetCrossOffsets,
        color = "#6ee7ff",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd ignea"] = {
        id = "dd_marca_ignea",
        name = "DD Marca Ignea",
        range = 5,
        cooldownMs = 13000,
        offsets = targetCrossOffsets,
        color = "#ff8a30",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd blink"] = {
        id = "dd_parpadeo_arcano",
        name = "DD Parpadeo Arcano",
        range = 3,
        cooldownMs = 30000,
        offsets = singleTileOffsets,
        color = "#b084ff",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd rezo"] = {
        id = "dd_rezo_curativo",
        name = "DD Rezo Curativo",
        range = 5,
        cooldownMs = 16000,
        offsets = targetCrossOffsets,
        color = "#66ffcc",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd castigo"] = {
        id = "dd_castigo_sagrado",
        name = "DD Castigo Sagrado",
        range = 5,
        cooldownMs = 5000,
        offsets = targetCrossOffsets,
        color = "#f7e86b",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd disparo"] = {
        id = "dd_disparo_certero",
        name = "DD Disparo Certero",
        range = 7,
        cooldownMs = 5000,
        offsets = targetCrossOffsets,
        color = "#f0f0f0",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd cazador"] = {
        id = "dd_marca_cazador",
        name = "DD Marca del Cazador",
        range = 7,
        cooldownMs = 20000,
        offsets = square3x3Offsets,
        color = "#ffe45c",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    },
    ["dd toxica"] = {
        id = "dd_hoja_toxica",
        name = "DD Hoja Toxica",
        range = 5,
        cooldownMs = 12000,
        offsets = targetCrossOffsets,
        color = "#63ff72",
        invalidColor = "#ff4040",
        cooldownUntil = 0
    }
}

local function normalizeSpellWords(words)
    if not words then
        return ""
    end

    words = words:lower()
    words = words:gsub("^%s+", ""):gsub("%s+$", "")
    return words
end

local function displayStatus(message)
    if modules.game_textmessage then
        modules.game_textmessage.displayStatusMessage(message)
    end
end

local function getTargetPosition(mapWidget, mousePosition)
    if not mapWidget or not mousePosition then
        return nil
    end

    local tile = mapWidget:getTile(mousePosition)
    if not tile then
        return nil
    end

    return tile:getPosition()
end

local function isInRange(position)
    local player = g_game.getLocalPlayer()
    if not player or not position then
        return false
    end

    local playerPosition = player:getPosition()
    if playerPosition.z ~= position.z then
        return false
    end

    local distance = math.max(math.abs(playerPosition.x - position.x), math.abs(playerPosition.y - position.y))
    return distance <= currentAim.skill.range
end

local function getDimensionValue(size, key, fallback)
    if not size then
        return fallback
    end

    local value = size[key]
    if type(value) == "function" then
        return value(size)
    elseif value then
        return value
    end

    return fallback
end

local function samePosition(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function getRectValue(rect, key, fallback)
    if not rect then
        return fallback
    end

    local value = rect[key]
    if type(value) == "function" then
        return value(rect)
    elseif value then
        return value
    end

    return fallback
end

local function getMapTileSize(mapWidget)
    local visibleDimension = mapWidget:getVisibleDimension()
    local visibleWidth = getDimensionValue(visibleDimension, "width", 15)
    local visibleHeight = getDimensionValue(visibleDimension, "height", 11)
    return math.min(mapWidget:getWidth() / visibleWidth, mapWidget:getHeight() / visibleHeight)
end

local function positionToMapRect(mapWidget, position, anchor)
    local cameraPosition = mapWidget:getCameraPosition()
    local visibleDimension = mapWidget:getVisibleDimension()
    local visibleWidth = getDimensionValue(visibleDimension, "width", 15)
    local visibleHeight = getDimensionValue(visibleDimension, "height", 11)
    local tileSize = getMapTileSize(mapWidget)
    local x
    local y

    if anchor then
        tileSize = anchor.rect.width
        x = anchor.rect.x + ((position.x - anchor.position.x) * tileSize)
        y = anchor.rect.y + ((position.y - anchor.position.y) * tileSize)
    else
        local mapLeft = (mapWidget:getWidth() - (visibleWidth * tileSize)) / 2
        local mapTop = (mapWidget:getHeight() - (visibleHeight * tileSize)) / 2
        local tileX = position.x - cameraPosition.x + math.floor(visibleWidth / 2)
        local tileY = position.y - cameraPosition.y + math.floor(visibleHeight / 2)
        x = mapLeft + (tileX * tileSize)
        y = mapTop + (tileY * tileSize)
    end

    return {
        x = math.floor(x),
        y = math.floor(y),
        width = math.ceil(tileSize),
        height = math.ceil(tileSize)
    }
end

local function getMouseTileRect(mapWidget, mousePosition, position)
    local widgetRect = mapWidget:getRect()
    local widgetX = getRectValue(widgetRect, "x", mapWidget:getX())
    local widgetY = getRectValue(widgetRect, "y", mapWidget:getY())
    local widgetRight = widgetX + mapWidget:getWidth() - 1
    local widgetBottom = widgetY + mapWidget:getHeight() - 1
    local left = mousePosition.x
    local right = mousePosition.x
    local top = mousePosition.y
    local bottom = mousePosition.y

    while left > widgetX and samePosition(mapWidget:getPosition({ x = left - 1, y = mousePosition.y }), position) do
        left = left - 1
    end

    while right < widgetRight and samePosition(mapWidget:getPosition({ x = right + 1, y = mousePosition.y }), position) do
        right = right + 1
    end

    while top > widgetY and samePosition(mapWidget:getPosition({ x = mousePosition.x, y = top - 1 }), position) do
        top = top - 1
    end

    while bottom < widgetBottom and samePosition(mapWidget:getPosition({ x = mousePosition.x, y = bottom + 1 }), position) do
        bottom = bottom + 1
    end

    local width = right - left + 1
    local height = bottom - top + 1
    local tileSize = math.min(width, height)

    return {
        x = math.floor(left - widgetX + (tileSize * PREVIEW_OFFSET_TILES.x)),
        y = math.floor(top - widgetY + (tileSize * PREVIEW_OFFSET_TILES.y)),
        width = tileSize,
        height = tileSize
    }
end

local function createPreviewMarker(mapWidget, rect, color, isCenter)
    local marker = g_ui.createWidget("UIWidget", mapWidget)
    marker:setPhantom(true)
    marker:setX(rect.x + 1)
    marker:setY(rect.y + 1)
    marker:setWidth(math.max(4, rect.width - 2))
    marker:setHeight(math.max(4, rect.height - 2))
    marker:setBorderWidth(isCenter and 2 or 1)
    marker:setBorderColor(color)
    return marker
end

function DDAiming.clearPreview()
    if not currentAim or not currentAim.previewWidgets then
        return
    end

    for _, widget in ipairs(currentAim.previewWidgets) do
        widget:destroy()
    end
    currentAim.previewWidgets = {}
end

local function previewAt(mapWidget, position, mousePosition)
    if not currentAim or not position then
        return
    end

    DDAiming.clearPreview()

    local color = isInRange(position) and currentAim.skill.color or currentAim.skill.invalidColor
    local anchor = {
        position = position,
        rect = mousePosition and getMouseTileRect(mapWidget, mousePosition, position) or positionToMapRect(mapWidget, position)
    }

    for _, offset in ipairs(currentAim.skill.offsets) do
        local previewPosition = { x = position.x + offset.x, y = position.y + offset.y, z = position.z }
        local tile = g_map.getTile(previewPosition)
        if tile then
            local rect = positionToMapRect(mapWidget, previewPosition, anchor)
            if rect.x + rect.width > 0 and rect.y + rect.height > 0 and
                rect.x < mapWidget:getWidth() and rect.y < mapWidget:getHeight() then
                local marker = createPreviewMarker(mapWidget, rect, color, offset.x == 0 and offset.y == 0)
                table.insert(currentAim.previewWidgets, marker)
            end
        end
    end
end

function DDAiming.isAimedSpell(words)
    return aimedSkills[normalizeSpellWords(words)] ~= nil
end

function DDAiming.start(words, onConfirm)
    local skill = aimedSkills[normalizeSpellWords(words)]
    if not skill or not g_game.isOnline() then
        return false
    end

    local cooldownUntil = skill.cooldownUntil or 0
    local now = g_clock.millis()
    if cooldownUntil > now then
        displayStatus(skill.name .. " en cooldown: " .. math.ceil((cooldownUntil - now) / 1000) .. "s.")
        return true
    end

    DDAiming.cancel()
    currentAim = {
        words = normalizeSpellWords(words),
        skill = skill,
        onConfirm = onConfirm,
        previewWidgets = {}
    }

    g_mouse.pushCursor("target")
    displayStatus("Selecciona el sqm para " .. skill.name .. ". Click derecho o Escape para cancelar.")
    return true
end

function DDAiming.isActive()
    return currentAim ~= nil
end

function DDAiming.cancel()
    if not currentAim then
        return false
    end

    DDAiming.clearPreview()
    g_mouse.popCursor("target")
    currentAim = nil
    return true
end

function DDAiming.handleMouseMove(mapWidget, mousePosition)
    if not currentAim then
        return false
    end

    local position = getTargetPosition(mapWidget, mousePosition)
    if not position then
        DDAiming.clearPreview()
        return true
    end

    previewAt(mapWidget, position, mousePosition)
    return true
end

function DDAiming.handleMouseRelease(mapWidget, mousePosition, mouseButton)
    if not currentAim then
        return false
    end

    if mouseButton == MouseRightButton then
        DDAiming.cancel()
        return true
    end

    if mouseButton ~= MouseLeftButton then
        return true
    end

    local position = getTargetPosition(mapWidget, mousePosition)
    if not position then
        return true
    end

    if not isInRange(position) then
        displayStatus("Objetivo fuera de rango.")
        previewAt(mapWidget, position, mousePosition)
        return true
    end

    local protocol = g_game.getProtocolGame()
    local payload = string.format("%s;%d;%d;%d", currentAim.skill.id, position.x, position.y, position.z)
    if USE_TALKACTION_BRIDGE then
        g_game.talk("!ddaim " .. payload)
        displayStatus("DD apuntado: comando enviado a " .. position.x .. "," .. position.y .. "," .. position.z .. ".")
    elseif protocol then
        protocol:sendExtendedOpcode(AIMED_SPELL_OPCODE, payload)
        displayStatus("DD apuntado: opcode enviado a " .. position.x .. "," .. position.y .. "," .. position.z .. ".")
    else
        displayStatus("DD apuntado: no hay protocolo activo.")
    end

    if currentAim.skill.cooldownMs then
        local cooldownUntil = g_clock.millis() + currentAim.skill.cooldownMs
        currentAim.skill.cooldownUntil = math.max(currentAim.skill.cooldownUntil or 0, cooldownUntil)
    end

    if currentAim.onConfirm then
        currentAim.onConfirm(currentAim.skill)
    end

    DDAiming.cancel()
    return true
end

function DDAiming.handleEscape()
    return DDAiming.cancel()
end

function onAimedSpellMouseMove(mapWidget, mousePosition)
    return DDAiming.handleMouseMove(mapWidget, mousePosition)
end

function onAimedSpellMouseRelease(mapWidget, mousePosition, mouseButton)
    return DDAiming.handleMouseRelease(mapWidget, mousePosition, mouseButton)
end

function onAimedSpellEscape()
    return DDAiming.handleEscape()
end
