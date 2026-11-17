local _, ns = ...
local Config = {}
ns.Config = Config

local WIDTH, HEIGHT = 480, 560

-- The controls are FrogLib's (UI.lua); every change calls ns.Refresh().
local UI = FrogLib.UI.Kit({ refresh = function() ns.Refresh() end })
local Label, Checkbox, Stepper, Dropdown, Options, ColorSwatch, TextBox, Placer, Help =
    UI.Label, UI.Checkbox, UI.Stepper, UI.Dropdown, UI.Options, UI.ColorSwatch, UI.TextBox, UI.Placer, UI.Help

local AURA_MODES = Options("mine", "Only my debuffs", "all", "My debuffs, others' debuffs, buffs")
local ICON_ANCHORS = Options("left", "Left of the name", "right", "Past the end of the bar", "above", "Above the name")
local COLOR_MODES = Options("xiv", "FFXIV (engaged / passive / friendly)",
    "reaction", "Hostile / neutral / friendly", "fixed", "Always the bar colour")
local POWER_ALIGN = Options("left", "Under the left end", "center", "Centred", "right", "Under the right end")
local HELP_WIDTH = WIDTH - 40

-- The template words, in the help under each text box.
local function Word(word) return "|cffffd100" .. word .. "|r" end

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

function Config:BuildBar(page)
    local db = ns.db
    local place = Placer()
    place(Checkbox(page, "Unlock to move (drag the bar; shows a preview)",
        function() return not db.locked end, function(value) db.locked = not value end), 28)
    place(Checkbox(page, "Click to target, right-click for the menu", db, "clicks"), 28)
    place(Checkbox(page, "Hide Blizzard's target frame", db, "hideTargetFrame"), 28)
    place(Checkbox(page, "Hide your target's nameplate (only the bar shows for it)", db, "hideTargetPlate"), 34)
    place(Stepper(page, "Scale", 0.5, 2, 0.05, db, "scale", "%.2f"), 26)
    place(Stepper(page, "Width", 150, 900, 10, db, "width"), 26)
    place(Stepper(page, "Bar height", 2, 20, 1, db, "height"), 32)
    place(Dropdown(page, "Bar texture", function() return ns.Media:List("statusbar") end, db, "texture"), 30)
    place(Dropdown(page, "Colouring", COLOR_MODES, db, "colorMode"), 30)
    place(ColorSwatch(page, "Bar colour (fixed mode)", db, "color"), 30)
    place(Checkbox(page, "Show the target's shields (absorbs)", db, "absorb"), 34)

    local cast = db.cast
    place(Label(page, "Cast bar"), 22)
    place(Checkbox(page, "Show the target's casts", cast, "enabled"), 28)
    place(Stepper(page, "Cast bar width", 60, 400, 10, cast, "width"), 26)
    place(Stepper(page, "Cast bar height", 2, 12, 1, cast, "height"), 26)
    place(Stepper(page, "Cast bar raised by", 20, 100, 2, cast, "offset"), 26)
    place(Checkbox(page, "Show remaining cast time", cast, "showTime"), 28)
end

function Config:BuildText(page)
    local text = ns.db.text
    local place = Placer()
    place(TextBox(page, "Above bar, left", text, "left"), 28)
    place(TextBox(page, "Above bar, right", text, "right"), 30)
    place(Help(page, "Words: " .. Word("level") .. ", " .. Word("name") .. ", " .. Word("class") .. ", "
        .. Word("value") .. ", " .. Word("max") .. ", " .. Word("percent") .. " (" .. Word("percent.1")
        .. " for a decimal); for mana, rage or energy: " .. Word("power") .. ", " .. Word("powermax") .. ", "
        .. Word("powerpercent") .. ", " .. Word("powertype") .. " (its name). "
        .. Word("class") .. " is a player's class, or a creature's type (Beast, Undead...). "
        .. "Leave empty to hide.", HELP_WIDTH), 62, 4)
    place(Dropdown(page, "Font", function() return ns.Media:List("font") end, text, "font"), 30)
    place(Dropdown(page, "Font outline", UI.OUTLINES, text, "outline"), 30)
    place(Stepper(page, "Text size", 8, 24, 1, text, "size"), 28)
    place(Checkbox(page, "Tint text to match the bar, like FFXIV", text, "tinted"), 28)
    place(Checkbox(page, "Show a player's class in its class colour", text, "classColor"), 28)
end

function Config:BuildPower(page)
    local power = ns.db.power
    local place = Placer()
    place(Checkbox(page, "Show the target's power (mana, rage, energy) under the bar", power, "enabled"), 28)
    place(Checkbox(page, "Hide it while it's empty (an enemy that hasn't built any rage)", power, "hideEmpty"), 34)
    place(Stepper(page, "Height", 1, 12, 1, power, "height"), 26)
    place(Stepper(page, "Length (% of the bar)", 10, 100, 5, power, "width", "%d%%"), 26)
    place(Dropdown(page, "Lined up", POWER_ALIGN, power, "align"), 30)
    place(Stepper(page, "Gap below the bar", 0, 40, 1, power, "gap"), 26)
    place(Stepper(page, "Move left / right", -300, 300, 2, power, "x"), 26)
    place(Help(page, "Shift-click + or - for ten steps at once. Unlock the bar (Bar page) to see a sample.",
        HELP_WIDTH), 32, 4)
    place(TextBox(page, "Text under it", power, "text"), 30)
    place(Help(page, "Words: " .. Word("value") .. ", " .. Word("max") .. ", " .. Word("percent")
        .. " (the power's here), " .. Word("powertype") .. ", " .. Word("name") .. ", " .. Word("level") .. ", "
        .. Word("class") .. ". Leave empty to hide.", HELP_WIDTH), 34, 4)
    place(Stepper(page, "Text size", 6, 20, 1, power, "textSize"), 28)

    -- Combo points (rogues, druids in cat form), under the power.
    local combo = ns.db.combo
    place(Label(page, "Combo points"), 22)
    place(Checkbox(page, "Show your combo points under the bar (rogues, druids in cat form)", combo, "enabled"), 26)
    place(Checkbox(page, "Hidden until you have one", combo, "hideEmpty"), 26, 16)
    place(Stepper(page, "Height", 1, 12, 1, combo, "height"), 26)
    place(Stepper(page, "Gap between them", 0, 20, 1, combo, "spacing"), 26)
    place(Checkbox(page, "Right under the bar (the power gauge under them)", combo, "first"), 26)
    place(Stepper(page, "Gap below the bar", 0, 40, 1, combo, "gap"), 26)
    place(ColorSwatch(page, "Colour", combo, "color"), 28)
end

function Config:BuildToT(page)
    local tot = ns.db.tot
    local place = Placer()
    place(Checkbox(page, "Show your target's target beside the bar", tot, "enabled"), 34)
    place(Stepper(page, "Width", 60, 400, 10, tot, "width"), 26)
    place(Stepper(page, "Gap from target bar", 0, 80, 2, tot, "gap"), 32)
    place(TextBox(page, "Text", tot, "template"), 28)
    place(Help(page, "The same words as on the Text page. Its class icon is on the Icons page.", HELP_WIDTH), 24, 4)
end

function Config:BuildAuras(page)
    local auras = ns.db.auras
    local place = Placer()
    place(Checkbox(page, "Show status effects under the bar", auras, "enabled"), 28)
    place(Checkbox(page, "Show timers under the icons", auras, "showTimer"), 34)
    place(Dropdown(page, "Show", AURA_MODES, auras, "mode"), 32)
    place(Stepper(page, "Icon size", 14, 48, 2, auras, "size"), 26)
    place(Stepper(page, "Max per group", 1, 40, 1, auras, "max"), 26)
    place(Stepper(page, "Spacing", 0, 12, 1, auras, "spacing"), 32)
    place(Dropdown(page, "Timer & stack font", function() return ns.Media:List("font") end, auras, "font"), 30)
end

function Config:BuildIcons(page)
    local icons = ns.db.icons
    local place = Placer()
    place(Checkbox(page, "Show icons beside the name", icons, "enabled"), 34)
    place(Stepper(page, "Icon size", 10, 64, 2, icons, "size"), 26)
    place(Dropdown(page, "Position", ICON_ANCHORS, icons, "anchor"), 30)
    place(Stepper(page, "Move left / right", -300, 300, 2, icons, "x"), 26)
    place(Stepper(page, "Move up / down", -100, 100, 2, icons, "y"), 34)
    place(Label(page, "Unlock the bar (Bar page) to see sample icons while you place them.", "GameFontDisableSmall"), 24, 4)
    for _, icon in ipairs({
        { "class", "Class (players)" },
        { "raid", "Raid marker" },
        { "leader", "Group leader / assistant" },
        { "role", "Group role (tank, healer, damage)" },
        { "pvp", "PvP flag (players)" },
        { "quest", "Quest target" },
    }) do
        place(Checkbox(page, icon[2], icons, icon[1]), 28, 16)
    end
    place(Label(page, "Class icon"), 22)
    place(Checkbox(page, "Also before your target's target's name", icons, "classToT"), 28, 16)
    place(Stepper(page, "Class icon size", 10, 40, 2, icons, "classSize"), 26, 16)
end

function Config:Build()
    self.frame = UI.Window("XIVTargetConfig", "XIVTarget", WIDTH, HEIGHT, {
        { "bar", "Bar", function(page) self:BuildBar(page) end },
        { "text", "Text", function(page) self:BuildText(page) end },
        { "power", "Power", function(page) self:BuildPower(page) end },
        { "tot", "ToT", function(page) self:BuildToT(page) end },
        { "auras", "Status", function(page) self:BuildAuras(page) end },
        { "icons", "Icons", function(page) self:BuildIcons(page) end },
        { "focus", "Focus", function(page) ns.Focus.BuildPage(page, UI) end },
    }, { tabWidth = 66, tabGap = 3, fitTabs = true })
end

function Config:Toggle()
    if not self.frame then
        self:Build()
        self.frame:Show()
        return
    end
    self.frame:SetShown(not self.frame:IsShown())
end

-- Its entry in the game's Options > AddOns list (FrogLib's Options.lua).
FrogLib.Options.Add("XIVTarget", ns, {
    open = function()
        if not (Config.frame and Config.frame:IsShown()) then Config:Toggle() end
    end,
    commands = { { "/xiv", "open or close the settings" } },
})
