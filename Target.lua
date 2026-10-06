local ADDON, ns = ...
local Target = {}
ns.Target = Target

local issecret, Safe = FrogLib.issecret, FrogLib.Safe
-- Reading casts and when the cast bar shows (FrogLib.Cast), the curve an empty power gauge fades
-- by (FrogLib.Curve), the colours (FrogLib.Color), the icons by the name (FrogLib.Icons) and the
-- click buttons (FrogLib.Secure) are shared with Frog Wizard's other bars.
local Cast, Curve, Color, Icons = FrogLib.Cast, FrogLib.Curve, FrogLib.Color, FrogLib.Icons

-- Shown while unlocked with nothing targeted, so there's something to drag and style.
local MANA_NAME = type(MANA) == "string" and MANA or "Mana"
local FAKE = {
    name = "Striking Dummy", level = "70", value = 76, max = 100, percent = 76, shield = 12,
    class = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.PALADIN or "Paladin", classFile = "PALADIN",
    power = 62, powermax = 100, powerpercent = 62, powertype = MANA_NAME,
}
-- Its class is filled in from yours when shown.
local FAKE_TOT = {
    name = "You", level = "70", value = 100, max = 100, percent = 100,
    power = 100, powermax = 100, powerpercent = 100, powertype = MANA_NAME,
}

local POWER_EVENTS = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }

-- "xiv": FFXIV's (FrogLib.Color.XIV). "reaction": tapped grey, players in their class colour,
-- then hostile red / neutral yellow / friendly green; `color` when the game won't say.
local REACTION = {
    tapped = { r = 0.55, g = 0.55, b = 0.55 }, class = true,
    hostile = { r = 0.90, g = 0.32, b = 0.25 }, neutral = { r = 0.95, g = 0.85, b = 0.35 },
    friendly = { r = 0.45, g = 0.85, b = 0.40 },
}

local function BarColor(unit)
    local db = ns.db
    if unit and db.colorMode == "xiv" then return Color.XIVUnit(unit) end
    if unit and db.colorMode == "reaction" then
        local r, g, b = Color.Unit(unit, REACTION)
        if r then return r, g, b end
    end
    return db.color.r, db.color.g, db.color.b
end

-- Text in a light version of the bar's colour, with a dark outline so it lifts off the world.
local function TintText(fs, r, g, b)
    if ns.db.text.tinted then
        fs:SetTextColor(Color.Lighten(r, g, b, 0.55))
    else
        fs:SetTextColor(1, 1, 1)
    end
end

------------------------------------------------------------------------------
-- Icons beside the name: class, raid marker, leader/assistant, group role, PvP, quest mob. Each
-- is FrogLib.Icons' (SHOW for a unit, PREVIEW for the unlocked sample); the raid marker is a
-- FontString, as which mark it is can be secret.
------------------------------------------------------------------------------

local ICON_ORDER = { "class", "raid", "leader", "role", "pvp", "quest" } -- nearest the name first

local function Text(parent)
    -- A default font up front: SetText errors on a FontString with none, and the configured
    -- font is only applied later in Apply.
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    return fs
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Target:Init()
    local f = CreateFrame("Frame", "XIVTargetFrame", UIParent)
    f:SetHeight(26)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local p, _, rp, x, y = frame:GetPoint()
        ns.db.point = { p, "UIParent", rp, x, y }
    end)
    -- Tint shown only while unlocked, marking the draggable area.
    f.unlockTint = f:CreateTexture(nil, "BACKGROUND")
    f.unlockTint:SetPoint("TOPLEFT", -4, 4)
    f.unlockTint:SetPoint("BOTTOMRIGHT", 4, -4)
    f.unlockTint:SetColorTexture(0.3, 0.6, 1, 0.2)
    self.frame = f

    local g = ns.CreateGauge(f)
    g.bar:SetPoint("BOTTOMLEFT")
    g.bar:SetPoint("BOTTOMRIGHT")
    g:EnableAbsorb()
    self.gauge = g

    self.left = Text(f)
    self.left:SetPoint("BOTTOMLEFT", g.bar, "TOPLEFT", 1, 2)
    self.left:SetJustifyH("LEFT")
    self.right = Text(f)
    self.right:SetPoint("BOTTOMRIGHT", g.bar, "TOPRIGHT", -1, 2)
    self.right:SetJustifyH("RIGHT")
    self.left:SetWordWrap(false)

    self:BuildPower()
    self:BuildCast()
    self:BuildToT()
    self.icons = {}
    for _, key in ipairs(ICON_ORDER) do
        self.icons[key] = key == "raid" and Text(f) or f:CreateTexture(nil, "OVERLAY")
    end

    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_CLASSIFICATION_CHANGED", "target")
    f:RegisterUnitEvent("UNIT_HEALTH", "target")
    f:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
    f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", "target")
    f:RegisterUnitEvent("UNIT_LEVEL", "target")
    f:RegisterUnitEvent("UNIT_FACTION", "target")
    f:RegisterUnitEvent("UNIT_FLAGS", "target") -- entering/leaving combat recolours the bar
    for event in pairs(POWER_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, "target")
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, "target")
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" then
            self:Update(true)
            ns.Auras:TargetChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event)
        elseif POWER_EVENTS[event] then
            self:UpdatePower(false)
            self:UpdatePowerWords()
        else
            self:Update(false)
        end
    end)

    -- Target of target has no events of its own, so poll it a few times a second.
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 0.2 then
            elapsed = 0
            self:UpdateToT()
        end
    end)

    self:Apply()
end

-- The power gauge: a slimmer line of the same kind under the health gauge, its number hanging
-- under its right end (as FFXIV prints a party member's MP). The text is on the gauge, so it
-- fades out with it (power.hideEmpty).
function Target:BuildPower()
    local p = ns.CreateGauge(self.frame)
    p.text = Text(p.bar)
    p.text:SetJustifyH("RIGHT")
    p.bar:Hide()
    self.power = p
end

-- FFXIV shows an enemy's cast as a glowing white-gold line floating over the right half of
-- the bar, with the spell name hanging underneath it.
function Target:BuildCast()
    local g = ns.CreateGauge(self.frame)
    g:SetColor(1, 0.72, 0.30)
    local c = g.bar
    c.gauge = g
    c.label = Text(c)
    c.label:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", 0, -3)
    c.label:SetJustifyH("RIGHT")
    -- Remaining time, to the left of the cast line. The duration can be secret, so it only
    -- goes straight into SetFormattedText.
    c.time = Text(c)
    c.time:SetPoint("RIGHT", c, "LEFT", -8, 0)
    c.time:SetJustifyH("RIGHT")
    -- What's on it, as FrogLib's driver decides.
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
        -- Held briefly so an interrupt is visible, as FFXIV does.
        hold = function(event)
            c:SetMinMaxValues(0, 1)
            c:SetValue(1)
            g:SetColor(0.85, 0.2, 0.15)
            c.label:SetText(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        end,
        -- Unlocked: a sample cast so its position can be judged, unless there's a real one.
        sample = function()
            c:SetMinMaxValues(0, 1)
            c:SetValue(0.6)
            g:SetColor(1, 0.72, 0.3)
            c.label:SetText("Spell name")
            c.time:SetText(ns.db.cast.showTime and "1.4" or "")
            c:Show()
        end,
        hide = function() c:Hide() end,
        refresh = function() self:UpdateCast() end,
    })
    c:SetScript("OnUpdate", function(bar)
        local d = bar.driver
        if d.sample then return end
        if not ns.db.cast.showTime or d.holdUntil then
            bar.time:SetText("")
            return
        end
        Cast.ShowTime(bar, bar.time)
    end)
    c:Hide()
    self.cast = c
end

function Target:BuildToT()
    -- ">>>" between the bars, as FFXIV links a target to its target.
    self.chevrons = Text(self.frame)
    self.chevrons:SetText(">>>")
    self.chevrons:SetTextColor(0.96, 0.86, 0.56, 0.8)

    local t = CreateFrame("Frame", nil, self.frame)
    t.gauge = ns.CreateGauge(t)
    t.name = Text(t)
    t.name:SetPoint("BOTTOMLEFT", t.gauge.bar, "TOPLEFT", 1, 4)
    t.name:SetJustifyH("LEFT")
    t.name:SetWordWrap(false)
    t.classIcon = t:CreateTexture(nil, "OVERLAY") -- before the name (icons.classToT)
    t.classIcon:Hide()
    t:Hide()
    self.tot = t
end

------------------------------------------------------------------------------
-- Clicks: left-click targets, right-click opens the unit menu
------------------------------------------------------------------------------

-- The bars themselves are plain frames, so clicks go to secure buttons laid over them and
-- shown by RegisterUnitWatch (FrogLib.Secure's: right-click opens the unit menu). The buttons copy
-- the bar's position rather than anchoring to it: anything a secure frame is anchored to becomes
-- protected too, and the bar couldn't then be shown or hidden in combat (ADDON_ACTION_BLOCKED on
-- XIVTargetFrame:SetShown).
local function ClickButton(name, unit)
    return (FrogLib.Secure.UnitButton(name, unit, { tooltip = true }))
end

-- Secure frames can only be placed and shown out of combat; changes made in combat wait.
function Target:SetupClicks()
    if InCombatLockdown() then
        self.clicksPending = true
        return
    end
    self.clicksPending = nil
    local db = ns.db
    if not self.click then
        self.click = ClickButton("XIVTargetClick", "target")
        self.totClick = ClickButton("XIVTargetToTClick", "targettarget")
    end
    -- Off while unlocked, so the bar can be dragged.
    local on = db.clicks and db.locked
    local function watch(b, active)
        if active then
            RegisterUnitWatch(b)
        else
            UnregisterUnitWatch(b)
            b:Hide()
        end
    end

    -- Same place, scale and size as the bar frame; the hit rect reaches a little past its
    -- edges so the thin gauge is easy to hit.
    local c = self.click
    c:SetScale(db.scale)
    c:ClearAllPoints()
    c:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    c:SetSize(db.width, self.frame:GetHeight())
    c:SetHitRectInsets(-2, -2, -2, -(6 + self:PowerDrop())) -- down over a power gauge too
    watch(c, on)

    -- Target's target: its gauge starts `gap` past the end of the target bar. Anchoring one
    -- secure button to the other is fine.
    local t = self.totClick
    t:SetScale(db.scale)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", db.tot.gap, 0)
    t:SetSize(db.tot.width, self.frame:GetHeight())
    t:SetHitRectInsets(-2, -2, -2, -6)
    watch(t, on and db.tot.enabled)
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

-- How far the power gauge and its text reach below the health gauge, so the status effects
-- clear them. From the settings alone, not from whether the target has power, so nothing
-- jumps about from one target to the next.
function Target:PowerDrop()
    local cfg = ns.db.power
    if not cfg.enabled then return 0 end
    local drop = cfg.gap + cfg.height
    if cfg.text and strtrim(cfg.text) ~= "" then drop = drop + cfg.textSize + 3 end
    return drop
end

function Target:ApplyPower()
    local db, cfg, p = ns.db, ns.db.power, self.power
    p:SetHeight(cfg.height)
    p:SetTexture(db.texture)
    p.bar:ClearAllPoints()
    p.bar:SetWidth(math.max(10, db.width * cfg.width / 100))
    local hp = self.gauge.bar
    if cfg.align == "right" then
        p.bar:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", cfg.x, -cfg.gap)
    elseif cfg.align == "center" then
        p.bar:SetPoint("TOP", hp, "BOTTOM", cfg.x, -cfg.gap)
    else
        p.bar:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", cfg.x, -cfg.gap)
    end
    ns.Media:SetFont(p.text, db.text.font, cfg.textSize, db.text.outline)
    p.text:ClearAllPoints()
    p.text:SetPoint("TOPRIGHT", p.bar, "BOTTOMRIGHT", -1, -2)
end

-- The name of your target's target, after its class icon when that's shown.
function Target:PlaceToTName()
    local tot, db = self.tot, ns.db
    local icon = tot.classIcon
    tot.name:ClearAllPoints()
    if tot.iconShown then
        local size = db.icons.classSize
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 0, 3)
        tot.name:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        tot.name:SetWidth(math.max(20, db.tot.width - size - 3))
    else
        tot.name:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 1, 4)
        tot.name:SetWidth(db.tot.width)
    end
end

function Target:Apply()
    local db, t = ns.db, ns.db.text
    local f = self.frame
    f:SetScale(db.scale)
    f:SetWidth(db.width)
    f:ClearAllPoints()
    f:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    f:EnableMouse(not db.locked)
    f.unlockTint:SetShown(not db.locked)
    -- Combo points are drawn on Blizzard's target frame, so they stay.
    FrogLib.Hider.Set(ADDON, "TargetFrame", db.hideTargetFrame, { keep = { "ComboFrame" } })

    self.gauge:SetHeight(db.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetFont(self.left, t.font, t.size, t.outline)
    ns.Media:SetFont(self.right, t.font, t.size, t.outline)
    self.left:SetWidth(db.width * 0.72) -- long names truncate before reaching the right text

    self:ApplyPower()

    local c = self.cast
    c:ClearAllPoints()
    c:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", 0, db.cast.offset)
    c:SetWidth(db.cast.width)
    ns.Media:SetFont(c.time, t.font, t.size, t.outline)
    c.time:SetTextColor(1, 0.95, 0.85)
    c.gauge:SetHeight(db.cast.height)
    c.gauge:SetTexture(db.texture)
    ns.Media:SetFont(c.label, t.font, t.size + 2, t.outline)
    c.label:SetTextColor(1, 0.95, 0.85)

    local tot = self.tot
    tot.gauge:SetHeight(db.height)
    tot.gauge:SetTexture(db.texture)
    tot.gauge.bar:ClearAllPoints()
    tot.gauge.bar:SetPoint("BOTTOMLEFT", self.gauge.bar, "BOTTOMRIGHT", db.tot.gap, 0)
    tot.gauge.bar:SetWidth(db.tot.width)
    self:PlaceToTName()
    ns.Media:SetFont(tot.name, t.font, t.size - 1, t.outline)
    ns.Media:SetFont(self.chevrons, t.font, math.max(8, t.size - 3), t.outline)
    self.chevrons:ClearAllPoints()
    self.chevrons:SetPoint("CENTER", self.gauge.bar, "RIGHT", db.tot.gap / 2, 0)

    ns.Auras:Apply(f, self.gauge.bar, 6 + self:PowerDrop())
    self:SetupClicks()
    self:Update(true)
    -- A font file is loaded on first use, and text set in that same moment can render blank;
    -- write the text again once it's in.
    C_Timer.After(0.1, function() self:Update(true) end)
    C_Timer.After(1, function() self:Update(true) end)
end

------------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------------

function Target:Update(instant)
    local db = ns.db
    local exists = UnitExists("target")
    local preview = not exists and not db.locked
    self.frame:SetShown(exists or preview)
    if not exists and not preview then return end

    local unit = exists and "target" or nil
    local g = self.gauge
    if preview then
        g:SetValues(FAKE.value, FAKE.max, true)
        g:SetAbsorb(FAKE.shield, FAKE.max)
    else
        local max = UnitHealthMax("target")
        g:SetValues(UnitHealth("target"), max, instant)
        -- The shield total can be secret; it only ever goes into the gauge's status bars.
        g:SetAbsorb((UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("target")) or 0, max)
    end
    g:ShowAbsorb(db.absorb)
    local r, g, b = BarColor(unit)
    self.gauge:SetColor(r, g, b)
    ns.SetUnitText(self.left, db.text.left, unit, preview and FAKE)
    ns.SetUnitText(self.right, db.text.right, unit, preview and FAKE)
    TintText(self.left, r, g, b)
    TintText(self.right, r, g, b)
    self:UpdateIcons(unit)
    self:UpdatePower(instant)

    if instant then
        self:UpdateCast()
        self:UpdateToT()
    end
end

-- The texts above the bar again when the power changes, if they show any of it.
function Target:UpdatePowerWords()
    if not UnitExists("target") then return end
    for _, key in ipairs({ "left", "right" }) do
        local template = ns.db.text[key]
        if FrogLib.Unit.UsesPower(template) then
            ns.SetUnitText(self[key], template, "target")
        end
    end
end

-- An empty power gauge fades out (power.hideEmpty): a unit that's generated nothing and spent
-- nothing has no use for it. When the power can be read, a new target at 0 has it gone at
-- once, and one that drops to 0 keeps it for EMPTY_WAIT seconds first (rage ebbing between
-- swings). In combat the power can be secret, so a curve over its percent becomes the gauge's
-- opacity instead, engine-side: 0 when empty, 1 otherwise.
local EMPTY_WAIT = 3

function Target:EmptyAlpha(unit, instant)
    if not (unit and ns.db.power.hideEmpty) then return 1 end
    local power = UnitPower(unit)
    if not issecret(power) then
        if power > 0 then
            self.emptySince = nil
            return 1
        end
        local now = GetTime()
        if instant then self.emptySince = now - EMPTY_WAIT end
        self.emptySince = self.emptySince or now
        local left = EMPTY_WAIT - (now - self.emptySince)
        if left <= 0 then return 0 end
        if not self.emptyTimer then
            self.emptyTimer = true
            C_Timer.After(left + 0.05, function()
                self.emptyTimer = nil
                self:UpdatePower(false)
            end)
        end
        return 1
    end
    local a = Curve.Power(unit, Curve.Empty())
    if issecret(a) or a ~= nil then return a end
    return 1
end

-- Values may be secret: they only go into the gauge and SetFormattedText. A unit with no power
-- at all (a critter) shows none, when that much can be told. Unlocked with no target: a sample.
function Target:UpdatePower(instant)
    local p, cfg = self.power, ns.db.power
    local unit = UnitExists("target") and "target" or nil
    local show = cfg.enabled and (unit ~= nil or not ns.db.locked)
    if show and unit then
        local max = UnitPowerMax(unit)
        if Safe(max) == 0 then
            show = false
        else
            p:SetValues(UnitPower(unit), max, instant)
        end
    elseif show then
        p:SetValues(FAKE.power, FAKE.powermax, true)
    end
    p.bar:SetShown(show)
    if not show then return end
    p.bar:SetAlpha(self:EmptyAlpha(unit, instant))
    local r, g, b = Color.Power(unit)
    p:SetColor(r, g, b)
    ns.SetUnitText(p.text, cfg.text, unit, not unit and FAKE or nil, true)
    TintText(p.text, r, g, b)
end

-- Where the icon row starts, and which way it grows:
-- { point on first icon, relative-to key, its point, base x, base y, step direction }.
local ICON_ANCHORS = {
    left = { "RIGHT", "left", "LEFT", -4, 0, -1 },       -- beside the name, growing left
    right = { "LEFT", "bar", "RIGHT", 6, 0, 1 },         -- past the end of the bar, growing right
    above = { "BOTTOMLEFT", "left", "TOPLEFT", 0, 4, 1 }, -- above the name, growing right
}

-- Shown icons line up from the chosen anchor, offset by the x/y setting. unit nil = preview.
function Target:UpdateIcons(unit)
    local cfg = ns.db.icons
    local a = ICON_ANCHORS[cfg.anchor] or ICON_ANCHORS.left
    local relative = a[2] == "bar" and self.gauge.bar or self.left
    local prev
    for _, key in ipairs(ICON_ORDER) do
        local tex = self.icons[key]
        local size = key == "class" and cfg.classSize or cfg.size
        local shown = false
        if cfg.enabled and cfg[key] then
            if unit then
                shown = Icons.SHOW[key](tex, unit, size)
            elseif Icons.PREVIEW[key] then
                shown = Icons.PREVIEW[key](tex, size)
            end
        end
        tex:SetShown(shown)
        if shown then
            if tex:GetObjectType() == "Texture" then tex:SetSize(size, size) end
            tex:ClearAllPoints()
            if prev then
                if a[6] < 0 then
                    tex:SetPoint("RIGHT", prev, "LEFT", -2, 0)
                else
                    tex:SetPoint("LEFT", prev, "RIGHT", 2, 0)
                end
            else
                tex:SetPoint(a[1], relative, a[3], a[4] + cfg.x, a[5] + cfg.y)
            end
            prev = tex
        end
    end
end

function Target:UpdateCast(event)
    local c = self.cast
    if not ns.db.cast.enabled then
        c:Hide()
        return
    end
    local exists = UnitExists("target")
    c.driver:Update((issecret(exists) or exists) and "target" or nil, event, not ns.db.locked)
end

function Target:UpdateToT()
    local tot, cfg = self.tot, ns.db.tot
    local show, r, g, b
    if not cfg.enabled then
        show = false
    elseif not UnitExists("target") then
        show = not ns.db.locked
        if show then
            -- The sample stands for you: your class.
            FAKE_TOT.class, FAKE_TOT.classFile = UnitClass("player")
            tot.gauge:SetValues(FAKE_TOT.value, FAKE_TOT.max, true)
            if ns.db.colorMode == "xiv" then
                local c = Color.XIV.friend
                r, g, b = c.r, c.g, c.b
            else
                r, g, b = BarColor(nil)
            end
            ns.SetUnitText(tot.name, cfg.template, nil, FAKE_TOT)
        end
    elseif UnitExists("targettarget") then
        show = true
        tot.gauge:SetValues(UnitHealth("targettarget"), UnitHealthMax("targettarget"))
        r, g, b = BarColor("targettarget")
        ns.SetUnitText(tot.name, cfg.template, "targettarget")
    end
    if show then
        tot.gauge:SetColor(r, g, b)
        TintText(tot.name, r, g, b)
    end

    -- Its class icon, before the name; the name moves over for it.
    local icons, iconShown = ns.db.icons, false
    if show and icons.enabled and icons.class and icons.classToT then
        if UnitExists("target") then
            iconShown = Icons.SHOW.class(tot.classIcon, "targettarget")
        else
            iconShown = Icons.SetClass(tot.classIcon, FAKE_TOT.classFile)
        end
    end
    tot.classIcon:SetShown(iconShown)
    if iconShown ~= (tot.iconShown or false) then
        tot.iconShown = iconShown
        self:PlaceToTName()
    end

    tot:SetShown(show)
    self.chevrons:SetShown(show)
end
