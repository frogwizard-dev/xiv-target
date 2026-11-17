local _, ns = ...

-- Optionally fades out your target's nameplate (Blizzard's or any nameplate addon's, since they
-- sit on the same plate), so the target bar is the only bar showing for it. It changes the plate's
-- alpha rather than hiding it, which the game still allows in combat. Plates get reused for other
-- units, so a faded one goes back to full as soon as it changes hands. Nothing listens while it's off.
local hidden -- the plate we faded
local events = CreateFrame("Frame")
local listening = false

local function Restore()
    if hidden then hidden:SetAlpha(1) end
    hidden = nil
end

local function Fade()
    Restore()
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        plate:SetAlpha(0)
        hidden = plate
    end
end

local EVENTS = { "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD" }

local function Update()
    local on = ns.db and ns.db.hideTargetPlate and true or false
    if on ~= listening then
        listening = on
        for _, event in ipairs(EVENTS) do
            if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
        end
    end
    if on then Fade() else Restore() end
end
ns.UpdateTargetPlate = Update

events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate == hidden then Restore() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        -- Your target's plate come into view: the plate frames compared (whether two units are the same can be
        -- secret, and is never tested).
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate == C_NamePlate.GetNamePlateForUnit("target") then Fade() end
    else
        Fade()
    end
end)
