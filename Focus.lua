local ADDON, ns = ...
local Focus = {}
ns.Focus = Focus

-- A smaller bar for your focus, in the target bar's look (its texture, font, colouring and text
-- tint): a thin gauge with a text over each end, the focus's raid mark before the name, and its
-- cast as a thinner line underneath, the spell's name hanging below its right end and the time
-- left below its left. Its own place (drag it while unlocked; a sample shows with no focus),
-- scale and width; click it to target your focus, right-click for its menu.

local issecret = FrogLib.issecret
local Cast, Icons = FrogLib.Cast, FrogLib.Icons

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

local function Cfg() return ns.db.focus end

local function Text(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Focus:Init()
    local f = CreateFrame("Frame", "XIVTargetFocusFrame", UIParent)
    f:SetHeight(20)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    FrogLib.Mover.Make(f, { save = function(point) Cfg().point = point end, tint = 4 })
    self.frame = f

    local g = FrogLib.Gauge.New(f)
    g.bar:SetPoint("BOTTOMLEFT")
    g.bar:SetPoint("BOTTOMRIGHT")
    self.gauge = g
    self.left = Text(f, "LEFT")
    self.left:SetPoint("BOTTOMLEFT", g.bar, "TOPLEFT", 1, 2)
    self.right = Text(f, "RIGHT")
    self.right:SetPoint("BOTTOMRIGHT", g.bar, "TOPRIGHT", -1, 2)
    self.mark = Text(f, "RIGHT") -- a FontString: which mark it is can be secret
    self.mark:SetPoint("RIGHT", self.left, "LEFT", -3, 0)
    self:BuildCast()

    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(f.RegisterEvent, f, "PLAYER_FOCUS_CHANGED")
    pcall(f.RegisterEvent, f, "RAID_TARGET_UPDATE")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
        "UNIT_FACTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        pcall(f.RegisterUnitEvent, f, event, "focus")
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, "focus")
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_FOCUS_CHANGED" then
            self:Update(true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event)
        else
            self:Update(false)
        end
    end)
    self:Apply()
end

-- The cast: a thinner line under the gauge, as long as it, the spell's name under its right end
-- and the time left under its left (the duration can be secret: it only goes into
-- SetFormattedText).
function Focus:BuildCast()
    local g = FrogLib.Gauge.New(self.frame)
    local c = g.bar
    c.gauge = g
    c.label = Text(c, "RIGHT")
    c.label:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", -1, -3)
    c.time = Text(c, "LEFT")
    c.time:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 1, -3)
    c.driver = Cast.NewDriver({
        show = function(info)
            Cast.Fill(c, info)
            c.label:SetText(info.text)
            if Cast.Locked(info) then
                g:SetColor(0.6, 0.6, 0.6)
            else
                g:SetColor(1, 0.72, 0.3)
            end
            c:Show()
        end,
        hold = function(event)
            c:SetMinMaxValues(0, 1)
            c:SetValue(1)
            g:SetColor(0.85, 0.2, 0.15)
            c.label:SetText(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        end,
        sample = function()
            c:SetMinMaxValues(0, 1)
            c:SetValue(0.4)
            g:SetColor(1, 0.72, 0.3)
            c.label:SetText("Spell name")
            c.time:SetText(Cfg().cast.showTime and "2.1" or "")
            c:Show()
        end,
        hide = function() c:Hide() end,
        refresh = function() self:UpdateCast() end,
    })
    c:SetScript("OnUpdate", function(bar)
        local d = bar.driver
        if d.sample then return end
        if not Cfg().cast.showTime or d.holdUntil then
            bar.time:SetText("")
            return
        end
        Cast.ShowTime(bar, bar.time)
    end)
    c:Hide()
    self.cast = c
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
    local db, cfg = ns.db, Cfg()
    if not self.click then
        self.click = FrogLib.Secure.UnitButton("XIVTargetFocusClick", "focus", { tooltip = true })
    end
    local b = self.click
    b:SetScale(cfg.scale)
    b:ClearAllPoints()
    b:SetPoint(cfg.point[1], UIParent, cfg.point[3], cfg.point[4], cfg.point[5])
    b:SetSize(cfg.width, self.frame:GetHeight())
    b:SetHitRectInsets(-2, -2, -2, -6)
    if cfg.enabled and db.clicks and db.locked then
        RegisterUnitWatch(b)
    else
        UnregisterUnitWatch(b)
        b:Hide()
    end
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

function Focus:Apply()
    local f = self.frame
    if not f then return end
    local db, cfg, t = ns.db, Cfg(), ns.db.text
    f:SetScale(cfg.scale)
    f:SetWidth(cfg.width)
    f:SetHeight(cfg.textSize + 6 + cfg.height)
    f:ClearAllPoints()
    f:SetPoint(cfg.point[1], UIParent, cfg.point[3], cfg.point[4], cfg.point[5])
    f:EnableMouse(not db.locked)
    f.unlockTint:SetShown(not db.locked)
    FrogLib.Hider.Set(ADDON, "FocusFrame", cfg.enabled and cfg.hideBlizzard)

    self.gauge:SetHeight(cfg.height)
    self.gauge:SetTexture(db.texture)
    for _, fs in ipairs({ self.left, self.right, self.mark }) do
        ns.Media:SetFont(fs, t.font, cfg.textSize, t.outline)
    end
    self.left:SetWidth(cfg.width * 0.72) -- long names truncate before reaching the right text

    local c, cc = self.cast, cfg.cast
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -cc.gap)
    c:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, -cc.gap)
    c.gauge:SetHeight(cc.height)
    c.gauge:SetTexture(db.texture)
    for _, fs in ipairs({ c.label, c.time }) do
        ns.Media:SetFont(fs, t.font, math.max(8, cfg.textSize - 1), t.outline)
        fs:SetTextColor(1, 0.95, 0.85)
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
    local f = self.frame
    if not f then return end
    local db, cfg = ns.db, Cfg()
    local exists = cfg.enabled and UnitExists("focus")
    local preview = cfg.enabled and not exists and not db.locked
    f:SetShown((exists or preview) and true or false)
    if not (exists or preview) then
        self.cast.driver:Update(nil)
        return
    end

    local unit = exists and "focus" or nil
    local g = self.gauge
    if preview then
        g:SetValues(FAKE.value, FAKE.max, true)
    else
        g:SetValues(UnitHealth("focus"), UnitHealthMax("focus"), instant)
    end
    local r, gr, b = ns.BarColor(unit)
    g:SetColor(r, gr, b)
    ns.SetUnitText(self.left, cfg.left, unit, preview and FAKE)
    ns.SetUnitText(self.right, cfg.right, unit, preview and FAKE)
    ns.TintText(self.left, r, gr, b)
    ns.TintText(self.right, r, gr, b)

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

function Focus:UpdateCast(event)
    local c, cfg = self.cast, Cfg()
    if not (cfg.enabled and cfg.cast.enabled) then
        c:Hide()
        return
    end
    local exists = UnitExists("focus")
    c.driver:Update((issecret(exists) or exists) and "focus" or nil, event, not ns.db.locked)
end

------------------------------------------------------------------------------
-- Its page in the settings (UI: the window's kit, from Config.lua)
------------------------------------------------------------------------------

function Focus.BuildPage(p, UI)
    local cfg = Cfg()
    local place = UI.Placer()
    place(UI.Checkbox(p, "A bar for my focus", function() return cfg.enabled end,
        function(v) cfg.enabled = v end), 28)
    place(UI.Checkbox(p, "Hide Blizzard's focus frame while it's on", function() return cfg.hideBlizzard end,
        function(v) cfg.hideBlizzard = v end), 34)
    place(UI.Stepper(p, "Scale", 0.5, 2, 0.05, function() return cfg.scale end, function(v) cfg.scale = v end, "%.2f"), 26)
    place(UI.Stepper(p, "Width", 80, 600, 10, function() return cfg.width end, function(v) cfg.width = v end), 26)
    place(UI.Stepper(p, "Bar height", 2, 20, 1, function() return cfg.height end, function(v) cfg.height = v end), 26)
    place(UI.Stepper(p, "Text size", 7, 24, 1, function() return cfg.textSize end,
        function(v) cfg.textSize = v end), 32)
    place(UI.TextBox(p, "Above bar, left", function() return cfg.left end, function(v) cfg.left = v end), 28)
    place(UI.TextBox(p, "Above bar, right", function() return cfg.right end, function(v) cfg.right = v end), 32)
    place(UI.Checkbox(p, "Its raid mark before the name", function() return cfg.raidMark end,
        function(v) cfg.raidMark = v end), 34)
    place(UI.Label(p, "Cast bar"), 22)
    place(UI.Checkbox(p, "Show the focus's casts (a line under the bar)", function() return cfg.cast.enabled end,
        function(v) cfg.cast.enabled = v end), 28)
    place(UI.Stepper(p, "Cast bar height", 1, 12, 1, function() return cfg.cast.height end,
        function(v) cfg.cast.height = v end), 26)
    place(UI.Stepper(p, "Gap under the bar", 0, 30, 1, function() return cfg.cast.gap end,
        function(v) cfg.cast.gap = v end), 26)
    place(UI.Checkbox(p, "Show remaining cast time", function() return cfg.cast.showTime end,
        function(v) cfg.cast.showTime = v end), 30)
    place(UI.Help(p, "The texts take the same words as the target bar's (Text page). Texture, font, "
        .. "colouring and clicks are the target bar's too. Unlock (Bar page) to drag it: a sample shows "
        .. "with no focus.", 420), 44, 4)
end
