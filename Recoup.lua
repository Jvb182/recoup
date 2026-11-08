local addon, ns = ...
local frame, buttons, pending, queued = nil, {}, false, false
local requested, retries = {}, 0
local moveHandle
local function message(text) DEFAULT_CHAT_FRAME:AddMessage("|cff78d6aeRecoup:|r " .. text) end
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then message("Error: " .. tostring(err)) end
    end
end
local function text(parent, font, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    return label
end
local function panel(f, r, g, b)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(r, g, b, 0.94)
    f:SetBackdropBorderColor(0.28, 0.36, 0.40, 1)
end

local function stopMoving()
    if InCombatLockdown() then return end
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    RecoupDB.position = { point = point, relPoint = relPoint, x = x, y = y }
end

local function moveMode(enabled)
    if InCombatLockdown() then return end
    stopMoving()
    RecoupDB.locked = not enabled
    if enabled then RecoupDB.hidden = false; frame:Show() end
    moveHandle:SetShown(enabled)
end

function ns.Scan()
    local items, byID, missing = {}, {}, false
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local id = info.itemID
                local name, link, _, _, level, _, _, _, _, icon, _, class, subclass = C_Item.GetItemInfo(id)
                if not name then
                    if not requested[id] then requested[id] = true; C_Item.RequestLoadItemDataByID(id) end
                    missing = true
                elseif class == 0 and (subclass == 5 or subclass == 7) and (level or 0) <= UnitLevel("player") then
                    local usable = C_Item.IsUsableItem(id)
                    if usable then
                        local tooltip = C_TooltipInfo.GetBagItem(bag, slot)
                        local lines = {}
                        for _, line in ipairs(tooltip and tooltip.lines or {}) do
                            if type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
                        end
                        local hp, mp = ns.Recovery(lines, UnitHealthMax("player"), UnitPowerMax("player", 0))
                        if #lines == 0 then missing = true end
                        if hp > 0 or mp > 0 then
                            if byID[id] then byID[id].count = byID[id].count + (info.stackCount or 1)
                            else
                                local item = { id = id, name = name, link = link, icon = icon or info.iconFileID,
                                    count = info.stackCount or 1, health = subclass == 5 and hp or 0, mana = subclass == 5 and mp or 0, bandage = subclass == 7 and hp or 0 }
                                items[#items + 1] = item; byID[id] = item
                            end
                        end
                    end
                end
            end
        end
    end
    return items, missing
end

function ns.Refresh()
    queued = false
    if not frame then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    local items, missing = ns.Scan()
    for kind, button in pairs(buttons) do
        local item = ns.Best(items, kind)
        button.item = item
        -- Item ID instead of bag slot: moving items cannot turn this into a
        -- different consumable while combat prevents secure attribute changes.
        button:SetAttribute("item", item and ("item:" .. item.id) or nil)
        button.icon:SetTexture(item and item.icon or (kind == "health" and "Interface\\Icons\\INV_Misc_Food_15" or (kind == "mana" and "Interface\\Icons\\INV_Drink_07" or "Interface\\Icons\\INV_Misc_Bandage_12")))
        button.count:SetText(item and tostring(item.count) or "")
        button.icon:SetDesaturated(not item)
    end
    if missing and retries < 5 then
        retries = retries + 1
        C_Timer.After(0.5, safe(ns.Refresh))
    end
end

local function schedule()
    if not frame or queued then return end
    queued = true
    C_Timer.After(0.15, safe(ns.Refresh))
end

local function createButton(kind, label, x)
    local button = CreateFrame("Button", kind == "health" and "SnackBarEat" or (kind == "mana" and "SnackBarDrink" or "RecoupBandage"), frame, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(36, 36)
    button:SetPoint("TOPLEFT", x, 0)
    panel(button, 0.07, 0.09, 0.11)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "item")
    button:SetAttribute("unit", "player")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32); button.icon:SetPoint("TOPLEFT", 2, -2)
    button.count = text(button, "NumberFontNormalSmall", 0, 0)
    button.count:ClearAllPoints()
    button.count:SetPoint("BOTTOMRIGHT", -3, 3)
    button:RegisterForDrag("RightButton")
    button:SetScript("OnDragStart", function()
        if not InCombatLockdown() and not RecoupDB.locked then frame:StartMoving() end
    end)
    button:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint(1)
        RecoupDB.position = { point = point, x = x, y = y }
    end)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", safe(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.item then
            GameTooltip:SetHyperlink(self.item.link or ("item:" .. self.item.id))
            GameTooltip:AddLine("Recoup: highest recovery in your bags.", 0.5, 0.9, 0.7, true)
        else GameTooltip:SetText(label); GameTooltip:AddLine("No usable item with a recognized recovery amount.", 1, 1, 1, true) end
        GameTooltip:AddLine("/recoup move opens a left-drag handle.", 0.65, 0.65, 0.65, true)
        GameTooltip:Show()
    end))
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:HookScript("PostClick", function() schedule() end)
    buttons[kind] = button
end

function ns.Create()
    if frame or InCombatLockdown() then pending = true; return end
    if RecoupDB == nil and type(SnackBarDB) == "table" then
        RecoupDB = { hidden = SnackBarDB.hidden, locked = SnackBarDB.locked }
        if type(SnackBarDB.position) == "table" then
            RecoupDB.position = {}
            for k,v in pairs(SnackBarDB.position) do RecoupDB.position[k] = v end
        end
    end
    RecoupDB = type(RecoupDB) == "table" and RecoupDB or {}
    frame = CreateFrame("Frame", "SnackBarFrame", UIParent, "BackdropTemplate")
    frame:SetSize(116, 36); frame:SetClampedToScreen(true); frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("MEDIUM")
    local pos = RecoupDB.position
    if type(pos) == "table" and type(pos.point) == "string" and type(pos.x) == "number" and type(pos.y) == "number" then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
    createButton("health", "Eat", 0)
    createButton("mana", "Drink", 40)
    createButton("bandage", "Bandage", 80)
    moveHandle = CreateFrame("Frame", "SnackBarMoveHandle", frame, "BackdropTemplate")
    moveHandle:SetSize(126, 24)
    moveHandle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    moveHandle:EnableMouse(true)
    panel(moveHandle, 0.08, 0.18, 0.22)
    text(moveHandle, "GameFontNormalSmall", 6, -6):SetText("Drag here")
    moveHandle:SetScript("OnMouseDown", safe(function(_, mouse)
        if mouse == "LeftButton" and not InCombatLockdown() then frame:StartMoving() end
    end))
    moveHandle:SetScript("OnMouseUp", safe(stopMoving))
    local done = CreateFrame("Button", nil, moveHandle, "BackdropTemplate")
    done:SetSize(40, 22); done:SetPoint("RIGHT", -1, 0)
    panel(done, 0.1, 0.25, 0.16)
    text(done, "GameFontNormalSmall", 5, -5):SetText("Done")
    done:SetScript("OnClick", safe(function() moveMode(false) end))
    moveHandle:Hide()
    if RecoupDB.hidden then frame:Hide() end
    ns.Refresh()
end

BINDING_HEADER_SNACKBAR = "Recoup"
_G["BINDING_NAME_CLICK SnackBarEat:LeftButton"] = "Eat best food"
_G["BINDING_NAME_CLICK SnackBarDrink:LeftButton"] = "Drink best drink"
_G["BINDING_NAME_CLICK RecoupBandage:LeftButton"] = "Bandage yourself"
SLASH_SNACKBAR1 = "/recoup"
SLASH_SNACKBAR2 = "/snack"
SlashCmdList.SNACKBAR = safe(function(command)
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "help" then
        message("Click Eat, Drink or Bandage to use the strongest usable item. /recoup move opens a left-drag handle; click Done when positioned. /recoup toggles; /recoup lock, unlock, reset, refresh. Bind keys under AddOns > Recoup.")
        return
    end
    if InCombatLockdown() then message("Consumable updates and layout changes resume after combat."); return end
    ns.Create()
    if command == "refresh" then retries = 0; requested = {}; ns.Refresh()
    elseif command == "move" or command == "unlock" then moveMode(true); message("Left-drag the Drag here handle, then click Done.")
    elseif command == "lock" then moveMode(false); message("Position locked.")
    elseif command == "reset" then
        RecoupDB.position = nil; RecoupDB.hidden = false
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180); frame:Show()
    elseif command == "" then RecoupDB.hidden = not RecoupDB.hidden; frame:SetShown(not RecoupDB.hidden)
    else message("Use /recoup help for commands.") end
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "UNIT_MAXHEALTH", "UNIT_MAXPOWER" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", safe(function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then ns.Create(); ns.Refresh()
    elseif event == "UNIT_MAXHEALTH" or event == "UNIT_MAXPOWER" then if unit == "player" then schedule() end
    else
        if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LEVEL_UP" then retries = 0 end
        schedule()
    end
end))
function ns.Internals() return frame, buttons, events end
