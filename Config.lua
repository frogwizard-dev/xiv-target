local _, ns = ...
local Config = {}
ns.Config = Config

local W, H = 440, 560

-- The controls are FrogLib's (UI.lua); every change calls ns.Refresh().
local UI = FrogLib.UI.Kit({ refresh = function() ns.Refresh() end })
local Label, Button, Checkbox, Stepper, Dropdown, Options, ColorSwatch, TextBox, Placer =
    UI.Label, UI.Button, UI.Checkbox, UI.Stepper, UI.Dropdown, UI.Options, UI.ColorSwatch, UI.TextBox, UI.Placer

local OUTLINES = Options("", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick outline")
local AURA_MODES = Options("mine", "Only my debuffs", "all", "My debuffs, others' debuffs, buffs")
local ICON_ANCHORS = Options("left", "Left of the name", "right", "Past the end of the bar", "above", "Above the name")
local COLOR_MODES = Options("xiv", "FFXIV (engaged / passive / friendly)",
    "reaction", "Hostile / neutral / friendly", "fixed", "Always the bar colour")
local POWER_ALIGN = Options("left", "Under the left end", "center", "Centred", "right", "Under the right end")

-- The template words, in the help under each text box.
local function W_(word) return "|cffffd100" .. word .. "|r" end

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

function Config:BuildBar(p)
    local db = ns.db
    local place = Placer()
    place(Checkbox(p, "Unlock to move (drag the bar; shows a preview)",
        function() return not db.locked end, function(v) db.locked = not v end), 28)
    place(Checkbox(p, "Click to target, right-click for the menu",
        function() return db.clicks end, function(v) db.clicks = v end), 28)
    place(Checkbox(p, "Hide Blizzard's target frame",
        function() return db.hideTargetFrame end, function(v) db.hideTargetFrame = v end), 34)
    place(Stepper(p, "Scale", 0.5, 2, 0.05, function() return db.scale end, function(v) db.scale = v end, "%.2f"), 26)
    place(Stepper(p, "Width", 150, 900, 10, function() return db.width end, function(v) db.width = v end), 26)
    place(Stepper(p, "Bar height", 2, 20, 1, function() return db.height end, function(v) db.height = v end), 32)
    place(Dropdown(p, "Bar texture", function() return ns.Media:List("statusbar") end,
        function() return db.texture end, function(v) db.texture = v end), 30)
    place(Dropdown(p, "Colouring", COLOR_MODES, function() return db.colorMode end,
        function(v) db.colorMode = v end), 30)
    place(ColorSwatch(p, "Bar colour (fixed mode)", function() return db.color end,
        function(r, g, b) db.color = { r = r, g = g, b = b } end), 30)
    place(Checkbox(p, "Show the target's shields (absorbs)",
        function() return db.absorb end, function(v) db.absorb = v end), 34)

    place(Label(p, "Cast bar"), 22)
    place(Checkbox(p, "Show the target's casts",
        function() return db.cast.enabled end, function(v) db.cast.enabled = v end), 28)
    place(Stepper(p, "Cast bar width", 60, 400, 10, function() return db.cast.width end, function(v) db.cast.width = v end), 26)
    place(Stepper(p, "Cast bar height", 2, 12, 1, function() return db.cast.height end, function(v) db.cast.height = v end), 26)
    place(Stepper(p, "Cast bar raised by", 20, 100, 2, function() return db.cast.offset end, function(v) db.cast.offset = v end), 26)
    place(Checkbox(p, "Show remaining cast time",
        function() return db.cast.showTime end, function(v) db.cast.showTime = v end), 28)
end

function Config:BuildText(p)
    local t = ns.db.text
    local place = Placer()
    place(TextBox(p, "Above bar, left", function() return t.left end, function(v) t.left = v end), 28)
    place(TextBox(p, "Above bar, right", function() return t.right end, function(v) t.right = v end), 30)
    local help = Label(p, "Words: " .. W_("level") .. ", " .. W_("name") .. ", " .. W_("class") .. ", "
        .. W_("value") .. ", " .. W_("max") .. ", " .. W_("percent") .. " (" .. W_("percent.1")
        .. " for a decimal); for mana, rage or energy: " .. W_("power") .. ", " .. W_("powermax") .. ", "
        .. W_("powerpercent") .. ", " .. W_("powertype") .. " (its name). "
        .. W_("class") .. " is a player's class, or a creature's type (Beast, Undead...). "
        .. "Leave empty to hide.", "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 62, 4)
    place(Dropdown(p, "Font", function() return ns.Media:List("font") end,
        function() return t.font end, function(v) t.font = v end), 30)
    place(Dropdown(p, "Font outline", OUTLINES, function() return t.outline end, function(v) t.outline = v end), 30)
    place(Stepper(p, "Text size", 8, 24, 1, function() return t.size end, function(v) t.size = v end), 28)
    place(Checkbox(p, "Tint text to match the bar, like FFXIV",
        function() return t.tinted end, function(v) t.tinted = v end), 28)
    place(Checkbox(p, "Show a player's class in its class colour",
        function() return t.classColor end, function(v) t.classColor = v end), 28)
end

function Config:BuildPower(p)
    local cfg = ns.db.power
    local place = Placer()
    place(Checkbox(p, "Show the target's power (mana, rage, energy) under the bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 28)
    place(Checkbox(p, "Hide it while it's empty (an enemy that hasn't built any rage)",
        function() return cfg.hideEmpty end, function(v) cfg.hideEmpty = v end), 34)
    place(Stepper(p, "Height", 1, 12, 1, function() return cfg.height end, function(v) cfg.height = v end), 26)
    place(Stepper(p, "Length (% of the bar)", 10, 100, 5, function() return cfg.width end,
        function(v) cfg.width = v end, "%d%%"), 26)
    place(Dropdown(p, "Lined up", POWER_ALIGN, function() return cfg.align end, function(v) cfg.align = v end), 30)
    place(Stepper(p, "Gap below the bar", 0, 40, 1, function() return cfg.gap end, function(v) cfg.gap = v end), 26)
    place(Stepper(p, "Move left / right", -300, 300, 2, function() return cfg.x end, function(v) cfg.x = v end), 26)
    local help = Label(p, "Shift-click + or - for ten steps at once. Unlock the bar (Bar page) to see a sample.",
        "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 32, 4)
    place(TextBox(p, "Text under it", function() return cfg.text end, function(v) cfg.text = v end), 30)
    local words = Label(p, "Words: " .. W_("value") .. ", " .. W_("max") .. ", " .. W_("percent")
        .. " (the power's here), " .. W_("powertype") .. ", " .. W_("name") .. ", " .. W_("level") .. ", "
        .. W_("class") .. ". Leave empty to hide.", "GameFontDisableSmall")
    words:SetWidth(W - 40)
    words:SetJustifyH("LEFT")
    place(words, 34, 4)
    place(Stepper(p, "Text size", 6, 20, 1, function() return cfg.textSize end, function(v) cfg.textSize = v end), 28)

    -- Combo points (rogues, druids in cat form), under the power.
    local combo = ns.db.combo
    place(Label(p, "Combo points"), 22)
    place(Checkbox(p, "Show your combo points under the bar (rogues, druids in cat form)",
        function() return combo.enabled end, function(v) combo.enabled = v end), 26)
    place(Checkbox(p, "Hidden until you have one", function() return combo.hideEmpty end,
        function(v) combo.hideEmpty = v end), 26, 16)
    place(Stepper(p, "Height", 1, 12, 1, function() return combo.height end, function(v) combo.height = v end), 26)
    place(Stepper(p, "Gap between them", 0, 20, 1, function() return combo.spacing end,
        function(v) combo.spacing = v end), 26)
    place(Stepper(p, "Gap below the bar", 0, 40, 1, function() return combo.gap end, function(v) combo.gap = v end), 26)
    place(ColorSwatch(p, "Colour", function() return combo.color end,
        function(r, g, b) combo.color = { r = r, g = g, b = b } end), 28)
end

function Config:BuildToT(p)
    local cfg = ns.db.tot
    local place = Placer()
    place(Checkbox(p, "Show your target's target beside the bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 34)
    place(Stepper(p, "Width", 60, 400, 10, function() return cfg.width end, function(v) cfg.width = v end), 26)
    place(Stepper(p, "Gap from target bar", 0, 80, 2, function() return cfg.gap end, function(v) cfg.gap = v end), 32)
    place(TextBox(p, "Text", function() return cfg.template end, function(v) cfg.template = v end), 28)
    local help = Label(p, "The same words as on the Text page. Its class icon is on the Icons page.",
        "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 24, 4)
end

function Config:BuildAuras(p)
    local cfg = ns.db.auras
    local place = Placer()
    place(Checkbox(p, "Show status effects under the bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 28)
    place(Checkbox(p, "Show timers under the icons",
        function() return cfg.showTimer end, function(v) cfg.showTimer = v end), 34)
    place(Dropdown(p, "Show", AURA_MODES, function() return cfg.mode end, function(v) cfg.mode = v end), 32)
    place(Stepper(p, "Icon size", 14, 48, 2, function() return cfg.size end, function(v) cfg.size = v end), 26)
    place(Stepper(p, "Max per group", 1, 40, 1, function() return cfg.max end, function(v) cfg.max = v end), 26)
    place(Stepper(p, "Spacing", 0, 12, 1, function() return cfg.spacing end, function(v) cfg.spacing = v end), 32)
    place(Dropdown(p, "Timer & stack font", function() return ns.Media:List("font") end,
        function() return cfg.font end, function(v) cfg.font = v end), 30)
end

function Config:BuildIcons(p)
    local cfg = ns.db.icons
    local place = Placer()
    place(Checkbox(p, "Show icons beside the name",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 34)
    place(Stepper(p, "Icon size", 10, 64, 2, function() return cfg.size end, function(v) cfg.size = v end), 26)
    place(Dropdown(p, "Position", ICON_ANCHORS, function() return cfg.anchor end, function(v) cfg.anchor = v end), 30)
    place(Stepper(p, "Move left / right", -300, 300, 2, function() return cfg.x end, function(v) cfg.x = v end), 26)
    place(Stepper(p, "Move up / down", -100, 100, 2, function() return cfg.y end, function(v) cfg.y = v end), 34)
    local help = Label(p, "Unlock the bar (Bar page) to see sample icons while you place them.", "GameFontDisableSmall")
    place(help, 24, 4)
    for _, def in ipairs({
        { "class", "Class (players)" },
        { "raid", "Raid marker" },
        { "leader", "Group leader / assistant" },
        { "role", "Group role (tank, healer, damage)" },
        { "pvp", "PvP flag (players)" },
        { "quest", "Quest target" },
    }) do
        local key = def[1]
        place(Checkbox(p, def[2], function() return cfg[key] end, function(v) cfg[key] = v end), 28, 16)
    end
    place(Label(p, "Class icon"), 22)
    place(Checkbox(p, "Also before your target's target's name",
        function() return cfg.classToT end, function(v) cfg.classToT = v end), 28, 16)
    place(Stepper(p, "Class icon size", 10, 40, 2, function() return cfg.classSize end,
        function(v) cfg.classSize = v end), 26, 16)
end

function Config:Build()
    self.frame = UI.Window("XIVTargetConfig", "XIVTarget", W, H, {
        { "bar", "Bar", function(p) self:BuildBar(p) end },
        { "text", "Text", function(p) self:BuildText(p) end },
        { "power", "Power", function(p) self:BuildPower(p) end },
        { "tot", "ToT", function(p) self:BuildToT(p) end },
        { "auras", "Status", function(p) self:BuildAuras(p) end },
        { "icons", "Icons", function(p) self:BuildIcons(p) end },
    }, { tabWidth = 66, tabGap = 3 })
end

function Config:Toggle()
    if not self.frame then
        self:Build()
        self.frame:Show()
        return
    end
    self.frame:SetShown(not self.frame:IsShown())
end

-- Its entry in the game's Options > AddOns list (Options.lua).
FrogLib.Options.Add("XIVTarget", ns, {
    open = function()
        if not (Config.frame and Config.frame:IsShown()) then Config:Toggle() end
    end,
    commands = { { "/xiv", "open or close the settings" } },
})
