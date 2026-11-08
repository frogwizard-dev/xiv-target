local ADDON, ns = ...

-- Optionally fades out your target's nameplate (Blizzard's or any nameplate addon's, since they
-- sit on the same plate), so the target bar is the only bar showing for it. It changes the plate's
-- alpha rather than hiding it, which the game still allows in combat. Plates get reused for other
-- units, so a faded one goes back to full as soon as it changes hands.
local hidden -- the plate we faded

local function Restore()
    if hidden then hidden:SetAlpha(1) end
    hidden = nil
end

local function Update()
    Restore()
    if not (ns.db and ns.db.hideTargetPlate) then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if plate then
        plate:SetAlpha(0)
        hidden = plate
    end
end
ns.UpdateTargetPlate = Update

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate == hidden then Restore() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if UnitIsUnit(unit, "target") then Update() end
    else
        Update()
    end
end)
