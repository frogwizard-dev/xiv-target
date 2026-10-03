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
        -- Templates: words level, name, value, max, percent (percent.1 for a decimal).
        left = "Lv level name",
        right = "percent",
    },
    tot = { enabled = true, width = 150, gap = 40, template = "name" },
    clicks = true, -- left-click the bars to target, right-click for the unit menu
    hideTargetFrame = false, -- hide Blizzard's target frame (its combo points stay)
    absorb = true, -- the target's shields drawn on its gauge as a striped fill
    -- Small icons by the name. anchor: "left" of the name, "right" past the bar's end, or
    -- "above" the name; x/y nudge the whole row from there.
    icons = {
        enabled = true, size = 16, anchor = "left", x = 0, y = 0,
        raid = true, leader = true, role = true, pvp = true, quest = true,
    },
    -- offset: how far above the health bar the cast bar floats (its spell name hangs below it).
    cast = { enabled = true, width = 200, height = 3, offset = 44, showTime = true },
    -- Own font: timers sit in a gap one icon wide, too narrow for a wide face like Michroma.
    auras = {
        enabled = true, mode = "all", size = 26, max = 16, spacing = 3, showTimer = true,
        font = "Interface\\AddOns\\XIVTarget\\Fonts\\SourceSans3.ttf",
    },
}

ns.issecret = issecretvalue or function() return false end

function ns.Print(...)
    print("|cfff5dc8fXIVTarget|r:", ...)
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Text templates: "Lv level name" -> ("Lv %s %s", {level, name}). Same scheme as
-- PersonalResourceTweaks, plus the level and name words. Values may be secret, so they're
-- only ever formatted engine-side by SetFormattedText.
local compiled = {}
function ns.Compile(template)
    local c = compiled[template]
    if c then return c end
    local args = {}
    local pattern = template:gsub("%%", "%%%%")
    pattern = pattern:gsub("||", "|")
    pattern = pattern:gsub("|", "||")
    pattern = pattern:gsub("(%a+)(%.?%d*)", function(word, suffix)
        local w = word:lower()
        if w == "name" or w == "level" then
            args[#args + 1] = w
            return "%s" .. suffix
        elseif w == "value" or w == "max" then
            args[#args + 1] = w
            return "%d" .. suffix
        elseif w == "percent" then
            args[#args + 1] = "percent"
            local places = tonumber(suffix:match("^%.(%d)"))
            if places then return "%." .. math.min(places, 3) .. "f%%" end
            return "%d%%" .. suffix
        end
    end)
    c = { pattern = pattern, args = args }
    compiled[template] = c
    return c
end

local function Level(unit)
    local level = UnitLevel(unit)
    if ns.issecret(level) then return level end
    if not level or level < 0 then return "??" end -- skull-level bosses
    return tostring(level)
end

local function HealthPercent(unit)
    if UnitHealthPercent and CurveConstants then
        return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    end
    local h, m = UnitHealth(unit), UnitHealthMax(unit)
    if ns.issecret(h) or ns.issecret(m) or m == 0 then return 0 end
    return h / m * 100
end

-- Fills a FontString from a template for a unit. fake = values for the unlocked preview.
function ns.SetUnitText(fs, template, unit, fake)
    if not template or strtrim(template) == "" then
        fs:Hide()
        return
    end
    fs:Show()
    local vals = fake or {
        name = UnitName(unit), level = Level(unit),
        value = UnitHealth(unit), max = UnitHealthMax(unit), percent = HealthPercent(unit),
    }
    local c = ns.Compile(template)
    local a = c.args
    pcall(fs.SetFormattedText, fs, c.pattern, vals[a[1]], vals[a[2]], vals[a[3]], vals[a[4]], vals[a[5]], vals[a[6]])
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
