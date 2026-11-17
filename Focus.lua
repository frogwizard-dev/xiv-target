local ADDON, ns = ...
local Focus = {}
ns.Focus = Focus

-- A smaller bar for your focus in the target bar's look: a thin gauge with a text over each end, its raid
-- mark before the name, and its cast as a thinner line underneath (spell name under the right end, time
-- left under the left). Its own place (drag it while unlocked; a sample shows with no focus), scale and
-- width; click it to target your focus, right-click for its menu.

local issecret = FrogLib.issecret
local Cast, Icons = FrogLib.Cast, FrogLib.Icons
local Text = ns.Text

ns.defaults.focus = {
    enabled = true,
    hideBlizzard = true, -- Blizzard's focus frame, while this one is on
    point = { "TOP", "UIParent", "TOP", 0, -230 },
    scale = 1,
    width = 220,
    height = 3,
    textSize = 11,
    -- Templates: the target bar's words (level, name, class, value, max, percent, power...).
    left = "Lv level name",
    right = "percent",
    raidMark = true,
    cast = { enabled = true, height = 2, gap = 6, showTime = true },
}

local MANA_NAME = type(MANA) == "string" and MANA or "Mana"
local FAKE = {
    name = "Focus Dummy", level = "70", value = 54, max = 100, percent = 54,
    class = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.MAGE or "Mage", classFile = "MAGE",
    power = 80, powermax = 100, powerpercent = 80, powertype = MANA_NAME,
}

local function Settings() return ns.db.focus end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Focus:Init()
    local frame = CreateFrame("Frame", "XIVTargetFocusFrame", UIParent)
    frame:SetHeight(20)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    FrogLib.Mover.Make(frame, { save = function(point) Settings().point = point end, tint = 4 })
    self.frame = frame

    local gauge = FrogLib.Gauge.New(frame)
    gauge.bar:SetPoint("BOTTOMLEFT")
    gauge.bar:SetPoint("BOTTOMRIGHT")
    self.gauge = gauge
    self.left = Text(frame, "LEFT")
    self.left:SetPoint("BOTTOMLEFT", gauge.bar, "TOPLEFT", 1, 2)
    self.right = Text(frame, "RIGHT")
    self.right:SetPoint("BOTTOMRIGHT", gauge.bar, "TOPRIGHT", -1, 2)
    self.mark = Text(frame, "RIGHT") -- a FontString: which mark it is can be secret
    self.mark:SetPoint("RIGHT", self.left, "LEFT", -3, 0)
    self:BuildCast()

    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(frame.RegisterEvent, frame, "PLAYER_FOCUS_CHANGED")
    pcall(frame.RegisterEvent, frame, "RAID_TARGET_UPDATE")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
        "UNIT_FACTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        pcall(frame.RegisterUnitEvent, frame, event, "focus")
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(frame.RegisterUnitEvent, frame, event, "focus")
    end
    frame:SetScript("OnEvent", function(_, event, _, _, _, interruptedBy)
        if event == "PLAYER_FOCUS_CHANGED" then
            self:Update(true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event, interruptedBy)
        else
            self:Update(false)
        end
    end)
    self:Apply()
end

-- The cast: a thinner line under the gauge, as long as it, the spell's name under its right end
-- and the time left under its left (the duration can be secret: it only goes into SetFormattedText).
function Focus:BuildCast()
    local gauge = FrogLib.Gauge.New(self.frame)
    local cast = gauge.bar
    cast.gauge = gauge
    cast.label = Text(cast, "RIGHT")
    cast.label:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", -1, -3)
    cast.time = Text(cast, "LEFT")
    cast.time:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 1, -3)
    cast.driver = Cast.NewLine({
        bar = cast, gauge = gauge, label = cast.label, time = cast.time,
        showTime = function() return Settings().cast.showTime end,
        refresh = function() self:UpdateCast() end,
        sample = { label = "Spell name", value = 0.4, time = "2.1" },
    })
    cast:Hide()
    self.cast = cast
end

------------------------------------------------------------------------------
-- Clicks: a secure button laid over the bar (placed its way, not anchored to it, so the bar can
-- still be shown and hidden in combat), shown by the game while you have a focus.
------------------------------------------------------------------------------

function Focus:SetupClicks()
    if InCombatLockdown() then
        self.clicksPending = true
        return
    end
    self.clicksPending = nil
    local db, cfg = ns.db, Settings()
    if not self.click then
        self.click = FrogLib.Secure.UnitButton("XIVTargetFocusClick", "focus", { tooltip = true })
    end
    local click = self.click
    click:SetScale(cfg.scale)
    click:ClearAllPoints()
    click:SetPoint(cfg.point[1], UIParent, cfg.point[3], cfg.point[4], cfg.point[5])
    click:SetSize(cfg.width, self.frame:GetHeight())
    click:SetHitRectInsets(-2, -2, -2, -6)
    FrogLib.Secure.Watch(click, cfg.enabled and db.clicks and db.locked)
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

function Focus:Apply()
    local frame = self.frame
    if not frame then return end
    local db, cfg, text = ns.db, Settings(), ns.db.text
    frame:SetScale(cfg.scale)
    frame:SetWidth(cfg.width)
    frame:SetHeight(cfg.textSize + 6 + cfg.height)
    frame:ClearAllPoints()
    frame:SetPoint(cfg.point[1], UIParent, cfg.point[3], cfg.point[4], cfg.point[5])
    frame:EnableMouse(not db.locked)
    frame.unlockTint:SetShown(not db.locked)
    FrogLib.Hider.Set(ADDON, "FocusFrame", cfg.enabled and cfg.hideBlizzard)

    self.gauge:SetHeight(cfg.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetNameFont(self.left, text.font, cfg.textSize, text.outline) -- the name: other scripts draw too
    for _, fontString in ipairs({ self.right, self.mark }) do
        ns.Media:SetFont(fontString, text.font, cfg.textSize, text.outline)
    end
    self.left:SetWidth(cfg.width * 0.72) -- long names truncate before reaching the right text

    local cast, castCfg = self.cast, cfg.cast
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -castCfg.gap)
    cast:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, -castCfg.gap)
    cast.gauge:SetHeight(castCfg.height)
    cast.gauge:SetTexture(db.texture)
    for _, fontString in ipairs({ cast.label, cast.time }) do
        ns.Media:SetFont(fontString, text.font, math.max(8, cfg.textSize - 1), text.outline)
        fontString:SetTextColor(1, 0.95, 0.85)
    end

    self:SetupClicks()
    self:Update(true)
    -- A font file is loaded on first use, and text set in that same moment can render blank.
    C_Timer.After(0.1, function() self:Update(true) end)
end

------------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------------

function Focus:Update(instant)
    local frame = self.frame
    if not frame then return end
    local db, cfg = ns.db, Settings()
    local exists = cfg.enabled and UnitExists("focus")
    local preview = cfg.enabled and not exists and not db.locked
    frame:SetShown((exists or preview) and true or false)
    if not (exists or preview) then
        self.cast.driver:Update(nil)
        return
    end

    local unit = exists and "focus" or nil
    local gauge = self.gauge
    if preview then
        gauge:SetValues(FAKE.value, FAKE.max, true)
    else
        gauge:SetValues(UnitHealth("focus"), UnitHealthMax("focus"), instant)
    end
    local r, g, b = ns.BarColor(unit)
    gauge:SetColor(r, g, b)
    ns.SetUnitText(self.left, cfg.left, unit, preview and FAKE)
    ns.SetUnitText(self.right, cfg.right, unit, preview and FAKE)
    ns.TintText(self.left, r, g, b)
    ns.TintText(self.right, r, g, b)

    local marked = false
    if cfg.raidMark then
        if unit then
            marked = Icons.SHOW.raid(self.mark, unit, cfg.textSize + 3)
        elseif Icons.PREVIEW.raid then
            marked = Icons.PREVIEW.raid(self.mark, cfg.textSize + 3)
        end
    end
    self.mark:SetShown(marked and true or false)

    if instant then self:UpdateCast() end
end

function Focus:UpdateCast(event, interruptedBy)
    local cast, cfg = self.cast, Settings()
    if not (cfg.enabled and cfg.cast.enabled) then
        cast:Hide()
        return
    end
    local exists = UnitExists("focus")
    cast.driver:Update((issecret(exists) or exists) and "focus" or nil, event, not ns.db.locked, interruptedBy)
end

------------------------------------------------------------------------------
-- Its page in the settings (UI: the window's kit, from Config.lua)
------------------------------------------------------------------------------

function Focus.BuildPage(page, UI)
    local settings = Settings()
    local cast = settings.cast
    local place = UI.Placer()
    place(UI.Checkbox(page, "A bar for my focus", settings, "enabled"), 28)
    place(UI.Checkbox(page, "Hide Blizzard's focus frame while it's on", settings, "hideBlizzard"), 34)
    place(UI.Stepper(page, "Scale", 0.5, 2, 0.05, settings, "scale", "%.2f"), 26)
    place(UI.Stepper(page, "Width", 80, 600, 10, settings, "width"), 26)
    place(UI.Stepper(page, "Bar height", 2, 20, 1, settings, "height"), 26)
    place(UI.Stepper(page, "Text size", 7, 24, 1, settings, "textSize"), 32)
    place(UI.TextBox(page, "Above bar, left", settings, "left"), 28)
    place(UI.TextBox(page, "Above bar, right", settings, "right"), 32)
    place(UI.Checkbox(page, "Its raid mark before the name", settings, "raidMark"), 34)
    place(UI.Label(page, "Cast bar"), 22)
    place(UI.Checkbox(page, "Show the focus's casts (a line under the bar)", cast, "enabled"), 28)
    place(UI.Stepper(page, "Cast bar height", 1, 12, 1, cast, "height"), 26)
    place(UI.Stepper(page, "Gap under the bar", 0, 30, 1, cast, "gap"), 26)
    place(UI.Checkbox(page, "Show remaining cast time", cast, "showTime"), 30)
    place(UI.Help(page, "The texts take the same words as the target bar's (Text page). Texture, font, "
        .. "colouring and clicks are the target bar's too. Unlock (Bar page) to drag it: a sample shows "
        .. "with no focus.", 420), 44, 4)
end
