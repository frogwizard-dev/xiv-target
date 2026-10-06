local ADDON, ns = ...

ns.defaults = {
    locked = true,
    point = { "TOP", "UIParent", "TOP", 0, -140 },
    scale = 1,
    width = 420,
    height = 3,
    texture = "Interface\\Buttons\\WHITE8X8",
    -- "xiv": FFXIV's rules (red engaged, yellow passive, blue friendly); "reaction": plain
    -- hostile/neutral/friendly; "fixed": always `color`.
    colorMode = "xiv",
    color = { r = 0.96, g = 0.86, b = 0.56 },
    text = {
        -- Expressway from EllesmereUI; without EllesmereUI, Media:SetFont falls back to the
        -- bundled Fonts\XIV.ttf (M PLUS 1p).
        font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
        outline = "OUTLINE",
        size = 12,
        tinted = true, -- text takes a light version of the bar's colour, like FFXIV
        classColor = true, -- the `class` word in the class's colour (players)
        -- Templates: words level, name, class, value, max, percent (percent.1 for a decimal),
        -- power, powermax, powerpercent, powertype.
        left = "Lv level name",
        right = "percent",
    },
    tot = { enabled = true, width = 150, gap = 40, template = "name" },
    -- The target's power (mana, rage, energy) on a slimmer gauge under the health gauge: `width`
    -- per cent as long, lined up by `align` ("left", "center", "right"), `gap` pixels below it
    -- and nudged x pixels sideways. text: a template whose value, max and percent are the
    -- power's, printed under the gauge's right end; empty hides it.
    power = {
        enabled = false, height = 2, width = 100, align = "left", gap = 6, x = 0,
        hideEmpty = true, text = "value", textSize = 10,
    },
    -- Your combo points on the target (rogues; druids in cat form): a row of small gauges under
    -- the bar (and its power gauge). gap: from what's above; spacing: between the pips.
    combo = { enabled = true, hideEmpty = true, height = 3, spacing = 5, gap = 6, color = { r = 1, g = 0.82, b = 0.3 } },
    clicks = true, -- left-click the bars to target, right-click for the unit menu
    hideTargetFrame = false, -- hide Blizzard's target frame (its combo points stay)
    absorb = true, -- the target's shields drawn on its gauge as a striped fill
    -- Small icons by the name. anchor: "left" of the name, "right" past the bar's end, or
    -- "above" the name; x/y nudge the whole row from there.
    icons = {
        enabled = true, size = 16, anchor = "left", x = 0, y = 0,
        raid = true, leader = true, role = true, pvp = true, quest = true,
        -- A player's class icon: first in the row, and (classToT) before your target's
        -- target's name. classSize: its own size, for both.
        class = false, classToT = true, classSize = 16,
    },
    -- offset: how far above the health bar the cast bar floats (its spell name hangs below it).
    cast = { enabled = true, width = 200, height = 3, offset = 44, showTime = true },
    -- Own font: timers sit in a gap one icon wide, too narrow for a wide face like Michroma.
    auras = {
        enabled = true, mode = "all", size = 26, max = 16, spacing = 3, showTimer = true,
        font = "Interface\\AddOns\\XIVTarget\\Fonts\\SourceSans3.ttf",
    },
}

ns.issecret = FrogLib.issecret

ns.Print = FrogLib.Util.Printer("XIVTarget", "f5dc8f")

local CopyDefaults = FrogLib.Util.CopyDefaults

-- Text templates and their words (level, name, class, value, max, percent, power, powermax,
-- powerpercent, powertype): FrogLib.Text and FrogLib.Unit, shared with FrogTarget and FrogFrames.
-- Values may be secret, so they're only ever formatted engine-side by SetFormattedText.
-- Fills a FontString from a template for a unit. fake = values for the unlocked preview (its
-- class word: class plus classFile, coloured); power = value, max and percent are the unit's
-- power rather than its health (the power gauge's text).
local textOpts = {}
function ns.SetUnitText(fs, template, unit, fake, power)
    textOpts.fake, textOpts.power = fake or nil, power
    textOpts.classColor = ns.db.text.classColor -- the class word in the class's colour (players)
    FrogLib.Unit.SetText(fs, template, unit, textOpts)
end

function ns.Refresh()
    if ns.Target then ns.Target:Apply() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        XIVTargetDB = XIVTargetDB or {}
        local db = XIVTargetDB
        -- 0.1 -> 0.2: thinner FFXIV defaults (only where the old default was never changed),
        -- and the reaction toggle became a colour mode.
        if not db.version then
            if db.height == 5 then db.height = nil end
            if db.cast and db.cast.height == 4 then db.cast.height = nil end
            if db.cast and db.cast.width == 180 then db.cast.width = nil end
            if db.text and db.text.size == 13 then db.text.size = nil end
            if db.reactionColor then db.colorMode = "reaction" end
            db.reactionColor = nil
            db.version = 2
        end
        -- 0.2 -> 0.3: bundled FFXIV-style font as default, and room for ">>>" beside the round caps.
        if db.version < 3 then
            if db.text and db.text.font == "Fonts\\FRIZQT__.TTF" then db.text.font = nil end
            if db.tot and db.tot.gap == 24 then db.tot.gap = nil end
            db.version = 3
        end
        -- 0.3 -> 0.4: Expressway as the default font.
        if db.version < 4 then
            if db.text and db.text.font == "Interface\\AddOns\\XIVTarget\\Fonts\\XIV.ttf" then db.text.font = nil end
            db.version = 4
        end
        -- Krona One was bundled briefly and then removed; move anyone using it to Michroma.
        if db.text and type(db.text.font) == "string" and db.text.font:find("KronaOne", 1, true) then
            db.text.font = "Interface\\AddOns\\XIVTarget\\Fonts\\Michroma.ttf"
        end
        CopyDefaults(ns.defaults, db)
        ns.db = db
    elseif event == "PLAYER_LOGIN" then
        ns.Target:Init()
    end
end)

SLASH_XIVTARGET1 = "/xiv"
SlashCmdList.XIVTARGET = function() ns.Config:Toggle() end

function XIVTarget_OnCompartmentClick()
    ns.Config:Toggle()
end
