local ADDON, ns = ...
local Target = {}
ns.Target = Target

local issecret, Safe = FrogLib.issecret, FrogLib.Safe
-- Casts and when the cast bar shows (FrogLib.Cast), the curve an empty power gauge fades by (FrogLib.Curve),
-- the colours and the icons by the name are shared with Frog Wizard's other bars.
local Cast, Curve, Color, Icons = FrogLib.Cast, FrogLib.Curve, FrogLib.Color, FrogLib.Icons
local Text = ns.Text

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
ns.BarColor = BarColor -- the focus bar's too (Focus.lua)

-- Text in a light version of the bar's colour, with a dark outline so it lifts off the world.
local function TintText(text, r, g, b)
    if ns.db.text.tinted then
        text:SetTextColor(Color.Lighten(r, g, b, 0.55))
    else
        text:SetTextColor(1, 1, 1)
    end
end
ns.TintText = TintText

------------------------------------------------------------------------------
-- Icons beside the name, each FrogLib.Icons' (SHOW for a unit, PREVIEW for the unlocked sample); the
-- raid marker is a FontString, as which mark it is can be secret.
------------------------------------------------------------------------------

local ICON_ORDER = { "class", "raid", "leader", "role", "pvp", "quest" } -- nearest the name first

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Target:Init()
    local frame = CreateFrame("Frame", "XIVTargetFrame", UIParent)
    frame:SetHeight(26)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    -- Dragged while unlocked; the tint, shown only then, marks it (FrogLib's Mover.lua).
    FrogLib.Mover.Make(frame, { save = function(point) ns.db.point = point end, tint = 4 })
    self.frame = frame

    local gauge = FrogLib.Gauge.New(frame)
    gauge.bar:SetPoint("BOTTOMLEFT")
    gauge.bar:SetPoint("BOTTOMRIGHT")
    gauge:EnableAbsorb()
    self.gauge = gauge

    self.left = Text(frame, "LEFT")
    self.left:SetPoint("BOTTOMLEFT", gauge.bar, "TOPLEFT", 1, 2)
    self.right = Text(frame)
    self.right:SetPoint("BOTTOMRIGHT", gauge.bar, "TOPRIGHT", -1, 2)
    self.right:SetJustifyH("RIGHT")

    self:BuildPower()
    self:BuildCombo()
    self:BuildCast()
    self:BuildToT()
    self.icons = {}
    for _, key in ipairs(ICON_ORDER) do
        self.icons[key] = key == "raid" and Text(frame) or frame:CreateTexture(nil, "OVERLAY")
    end

    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    pcall(frame.RegisterUnitEvent, frame, "UNIT_CLASSIFICATION_CHANGED", "target")
    frame:RegisterUnitEvent("UNIT_HEALTH", "target")
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
    frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target")
    frame:RegisterUnitEvent("UNIT_LEVEL", "target")
    frame:RegisterUnitEvent("UNIT_FACTION", "target")
    frame:RegisterUnitEvent("UNIT_FLAGS", "target") -- entering/leaving combat recolours the bar
    for event in pairs(POWER_EVENTS) do
        pcall(frame.RegisterUnitEvent, frame, event, "target")
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(frame.RegisterUnitEvent, frame, event, "target")
    end
    frame:SetScript("OnEvent", function(_, event, _, _, _, interruptedBy)
        if event == "PLAYER_TARGET_CHANGED" then
            self:Update(true)
            ns.Auras:TargetChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event, interruptedBy)
        elseif POWER_EVENTS[event] then
            self:UpdatePower(false)
            self:UpdatePowerWords()
        else
            self:Update(false)
        end
    end)

    -- Target of target has no events of its own, so poll it a few times a second: a new one (or one that can't be told
    -- apart, its GUID secret) drawn in full, and the same one in full once a second, only its health between.
    local elapsed, lastGUID, lastFull = 0, nil, 0
    frame:SetScript("OnUpdate", function(_, sinceLast)
        elapsed = elapsed + sinceLast
        if elapsed <= 0.2 then return end
        elapsed = 0
        local guid, now = UnitGUID("targettarget"), GetTime()
        if issecret(guid) or guid == nil or guid ~= lastGUID or now - lastFull >= 1 or not self.tot:IsShown() then
            lastGUID, lastFull = not issecret(guid) and guid or nil, now
            self:UpdateToT()
        else
            self.tot.gauge:SetValues(UnitHealth("targettarget"), UnitHealthMax("targettarget"))
        end
    end)

    self:Apply()
end

-- The power gauge: a slimmer line under the health gauge, its number under its right end (as FFXIV
-- prints a party member's MP). The text is on the gauge, so it fades out with it (power.hideEmpty).
function Target:BuildPower()
    local gauge = FrogLib.Gauge.New(self.frame)
    gauge.text = Text(gauge.bar)
    gauge.text:SetJustifyH("RIGHT")
    gauge.bar:Hide()
    self.power = gauge
end

-- Your combo points: a row of small gauges, from FrogLib's Combo.lua (only for a character that
-- has them).
function Target:BuildCombo()
    if not FrogLib.Combo.Has() then return end
    self.combo = FrogLib.Combo.NewRow(self.frame, function(_, holder)
        local gauge = FrogLib.Gauge.New(holder)
        return gauge, gauge.bar
    end)
    FrogLib.Combo.Watch(function() self:UpdateCombo() end, function() self:ApplyCombo() end)
end

-- FFXIV shows an enemy's cast as a glowing white-gold line floating over the right half of
-- the bar, with the spell name hanging underneath it.
function Target:BuildCast()
    local gauge = FrogLib.Gauge.New(self.frame)
    gauge:SetColor(1, 0.72, 0.30)
    local cast = gauge.bar
    cast.gauge = gauge
    cast.label = Text(cast)
    cast.label:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", 0, -3)
    cast.label:SetJustifyH("RIGHT")
    -- Remaining time, to the left of the cast line. The duration can be secret, so it only
    -- goes straight into SetFormattedText.
    cast.time = Text(cast)
    cast.time:SetPoint("RIGHT", cast, "LEFT", -8, 0)
    cast.time:SetJustifyH("RIGHT")
    -- What's on it, as FrogLib's cast line decides; unlocked, a sample cast so its place can be judged.
    cast.driver = Cast.NewLine({
        bar = cast, gauge = gauge, label = cast.label, time = cast.time,
        showTime = function() return ns.db.cast.showTime end,
        refresh = function() self:UpdateCast() end,
        sample = { label = "Spell name", value = 0.6, time = "1.4" },
    })
    cast:Hide()
    self.cast = cast
end

function Target:BuildToT()
    -- ">>>" between the bars, as FFXIV links a target to its target.
    self.chevrons = Text(self.frame)
    self.chevrons:SetText(">>>")
    self.chevrons:SetTextColor(0.96, 0.86, 0.56, 0.8)

    local tot = CreateFrame("Frame", nil, self.frame)
    tot.gauge = FrogLib.Gauge.New(tot)
    tot.name = Text(tot, "LEFT")
    tot.name:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 1, 4)
    tot.classIcon = tot:CreateTexture(nil, "OVERLAY") -- before the name (icons.classToT)
    tot.classIcon:Hide()
    tot:Hide()
    self.tot = tot
end

------------------------------------------------------------------------------
-- Clicks: left-click targets, right-click opens the unit menu
------------------------------------------------------------------------------

-- The bars are plain frames, so clicks go to secure buttons over them (FrogLib.Secure's). They copy the
-- bar's place: a frame a secure one anchors to turns protected, and couldn't then hide in combat.
local Secure = FrogLib.Secure

local function ClickButton(name, unit)
    return (Secure.UnitButton(name, unit, { tooltip = true }))
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

    -- Same place, scale and size as the bar frame; the hit rect reaches a little past its
    -- edges so the thin gauge is easy to hit.
    local click = self.click
    click:SetScale(db.scale)
    click:ClearAllPoints()
    click:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    click:SetSize(db.width, self.frame:GetHeight())
    click:SetHitRectInsets(-2, -2, -2, -(6 + self:PowerDrop())) -- down over a power gauge too
    Secure.Watch(click, on)

    -- Target's target: its gauge starts `gap` past the end of the target bar. Anchoring one
    -- secure button to the other is fine.
    local totClick = self.totClick
    totClick:SetScale(db.scale)
    totClick:ClearAllPoints()
    totClick:SetPoint("BOTTOMLEFT", click, "BOTTOMRIGHT", db.tot.gap, 0)
    totClick:SetSize(db.tot.width, self.frame:GetHeight())
    totClick:SetHitRectInsets(-2, -2, -2, -6)
    Secure.Watch(totClick, on and db.tot.enabled)
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

-- How far the power gauge and its text reach below the health gauge, so the status effects clear
-- them. From the settings alone, not the target's power, so nothing jumps between targets.
function Target:PowerDrop()
    local cfg = ns.db.power
    if not cfg.enabled then return 0 end
    local drop = cfg.gap + cfg.height
    if cfg.text and strtrim(cfg.text) ~= "" then drop = drop + cfg.textSize + 3 end
    return drop
end

-- How far the combo points reach below what's over them (nothing for a character without them;
-- kept out of cat form too, so the status effects don't jump with every shift).
function Target:ComboDrop()
    local cfg = ns.db.combo
    if not (self.combo and cfg.enabled) then return 0 end
    return cfg.gap + cfg.height
end

function Target:ApplyCombo()
    local row, db = self.combo, ns.db
    if not row then return end
    local cfg = db.combo
    if not (cfg.enabled and row:Refresh(not db.locked)) then
        row.holder:Hide()
        return
    end
    local color = cfg.color
    row:Layout(db.width, cfg.height, cfg.spacing, function(gauge, width, height)
        gauge:SetHeight(height)
        gauge:SetTexture(db.texture)
        gauge.bar:SetWidth(width)
        gauge:SetColor(color.r, color.g, color.b)
    end)
    row.holder:ClearAllPoints()
    -- Right under the bar (first), or under its power gauge (which keeps its room whether the
    -- target has power or not, so nothing jumps between targets).
    local down = cfg.first and cfg.gap or (self:PowerDrop() + cfg.gap)
    row.holder:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -down)
    self:UpdateCombo()
end

-- The count (a sample while unlocked); it may be secret, so it only goes into the gauges.
function Target:UpdateCombo()
    if self.combo then self.combo:Update(not ns.db.locked, ns.db.combo.hideEmpty) end
end

function Target:ApplyPower()
    local db, cfg, gauge = ns.db, ns.db.power, self.power
    gauge:SetHeight(cfg.height)
    gauge:SetTexture(db.texture)
    gauge.bar:ClearAllPoints()
    gauge.bar:SetWidth(math.max(10, db.width * cfg.width / 100))
    local health = self.gauge.bar
    -- Under the combo points when they come first (combo.first).
    local down = cfg.gap + (db.combo.first and self:ComboDrop() or 0)
    if cfg.align == "right" then
        gauge.bar:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", cfg.x, -down)
    elseif cfg.align == "center" then
        gauge.bar:SetPoint("TOP", health, "BOTTOM", cfg.x, -down)
    else
        gauge.bar:SetPoint("TOPLEFT", health, "BOTTOMLEFT", cfg.x, -down)
    end
    ns.Media:SetFont(gauge.text, db.text.font, cfg.textSize, db.text.outline)
    gauge.text:ClearAllPoints()
    gauge.text:SetPoint("TOPRIGHT", gauge.bar, "BOTTOMRIGHT", -1, -2)
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
    local db, text = ns.db, ns.db.text
    local frame = self.frame
    frame:SetScale(db.scale)
    frame:SetWidth(db.width)
    frame:ClearAllPoints()
    frame:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    frame:EnableMouse(not db.locked)
    frame.unlockTint:SetShown(not db.locked)
    -- Blizzard's combo points (drawn on its target frame) stay, unless ours are on: then they'd
    -- be shown twice (and another addon hiding them couldn't).
    local ownCombo = self.combo and db.combo.enabled
    FrogLib.Hider.Set(ADDON, "TargetFrame", db.hideTargetFrame, { keep = ownCombo and {} or { "ComboFrame" } })

    self.gauge:SetHeight(db.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetNameFont(self.left, text.font, text.size, text.outline) -- the name: other scripts draw too
    ns.Media:SetFont(self.right, text.font, text.size, text.outline)
    self.left:SetWidth(db.width * 0.72) -- long names truncate before reaching the right text

    self:ApplyPower()

    local cast = self.cast
    cast:ClearAllPoints()
    cast:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", 0, db.cast.offset)
    cast:SetWidth(db.cast.width)
    ns.Media:SetFont(cast.time, text.font, text.size, text.outline)
    cast.time:SetTextColor(1, 0.95, 0.85)
    cast.gauge:SetHeight(db.cast.height)
    cast.gauge:SetTexture(db.texture)
    ns.Media:SetFont(cast.label, text.font, text.size + 2, text.outline)
    cast.label:SetTextColor(1, 0.95, 0.85)

    local tot = self.tot
    tot.gauge:SetHeight(db.height)
    tot.gauge:SetTexture(db.texture)
    tot.gauge.bar:ClearAllPoints()
    tot.gauge.bar:SetPoint("BOTTOMLEFT", self.gauge.bar, "BOTTOMRIGHT", db.tot.gap, 0)
    tot.gauge.bar:SetWidth(db.tot.width)
    self:PlaceToTName()
    ns.Media:SetNameFont(tot.name, text.font, text.size - 1, text.outline)
    ns.Media:SetFont(self.chevrons, text.font, math.max(8, text.size - 3), text.outline)
    self.chevrons:ClearAllPoints()
    self.chevrons:SetPoint("CENTER", self.gauge.bar, "RIGHT", db.tot.gap / 2, 0)

    self:ApplyCombo()
    ns.Auras:Apply(frame, self.gauge.bar, 6 + self:PowerDrop() + self:ComboDrop())
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
    local gauge = self.gauge
    if preview then
        gauge:SetValues(FAKE.value, FAKE.max, true)
        gauge:SetAbsorb(FAKE.shield, FAKE.max)
    else
        local max = UnitHealthMax("target")
        gauge:SetValues(UnitHealth("target"), max, instant)
        -- The shield total can be secret; it only ever goes into the gauge's status bars.
        gauge:SetAbsorb((UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("target")) or 0, max)
    end
    gauge:ShowAbsorb(db.absorb)
    local r, g, b = BarColor(unit)
    gauge:SetColor(r, g, b)
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

-- An empty power gauge fades (power.hideEmpty): a new target at 0 at once, one dropping to 0 after
-- EMPTY_WAIT seconds (rage ebbing between swings). Secret power (combat): a curve over its percent instead.
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
    local alpha = Curve.Power(unit, Curve.Empty())
    if issecret(alpha) or alpha ~= nil then return alpha end
    return 1
end

-- Values may be secret: they only go into the gauge and SetFormattedText. A unit with no power
-- at all (a critter) shows none, when that much can be told. Unlocked with no target: a sample.
function Target:UpdatePower(instant)
    local gauge, cfg = self.power, ns.db.power
    local unit = UnitExists("target") and "target" or nil
    local show = cfg.enabled and (unit ~= nil or not ns.db.locked)
    if show and unit then
        local max = UnitPowerMax(unit)
        if Safe(max) == 0 then
            show = false
        else
            gauge:SetValues(UnitPower(unit), max, instant)
        end
    elseif show then
        gauge:SetValues(FAKE.power, FAKE.powermax, true)
    end
    gauge.bar:SetShown(show)
    if not show then return end
    gauge.bar:SetAlpha(self:EmptyAlpha(unit, instant))
    local r, g, b = Color.Power(unit)
    gauge:SetColor(r, g, b)
    ns.SetUnitText(gauge.text, cfg.text, unit, not unit and FAKE or nil, true)
    TintText(gauge.text, r, g, b)
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
    local anchor = ICON_ANCHORS[cfg.anchor] or ICON_ANCHORS.left
    local relative = anchor[2] == "bar" and self.gauge.bar or self.left
    local previous
    for _, key in ipairs(ICON_ORDER) do
        local icon = self.icons[key]
        local size = key == "class" and cfg.classSize or cfg.size
        local shown = false
        if cfg.enabled and cfg[key] then
            if unit then
                shown = Icons.SHOW[key](icon, unit, size)
            elseif Icons.PREVIEW[key] then
                shown = Icons.PREVIEW[key](icon, size)
            end
        end
        icon:SetShown(shown)
        if shown then
            if icon:GetObjectType() == "Texture" then icon:SetSize(size, size) end
            icon:ClearAllPoints()
            if previous then
                if anchor[6] < 0 then
                    icon:SetPoint("RIGHT", previous, "LEFT", -2, 0)
                else
                    icon:SetPoint("LEFT", previous, "RIGHT", 2, 0)
                end
            else
                icon:SetPoint(anchor[1], relative, anchor[3], anchor[4] + cfg.x, anchor[5] + cfg.y)
            end
            previous = icon
        end
    end
end

function Target:UpdateCast(event, interruptedBy)
    local cast = self.cast
    if not ns.db.cast.enabled then
        cast:Hide()
        return
    end
    local exists = UnitExists("target")
    cast.driver:Update((issecret(exists) or exists) and "target" or nil, event, not ns.db.locked, interruptedBy)
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
                local friend = Color.XIV.friend
                r, g, b = friend.r, friend.g, friend.b
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
