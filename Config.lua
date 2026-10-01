local _, ns = ...
local Config = {}
ns.Config = Config

local W, H = 440, 560

-- Same control set as PersonalResourceTweaks' settings window.

local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function Checkbox(parent, text, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    Label(cb, text, "GameFontHighlight"):SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb:SetChecked(get())
    cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked())
        ns.Refresh()
    end)
    return cb
end

local function Stepper(parent, text, min, max, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(300, 24)
    Label(f, text, "GameFontHighlight"):SetPoint("LEFT", 4, 0)
    local minus = Button(f, "-", 24)
    minus:SetPoint("LEFT", 150, 0)
    local val = Label(f, "", "GameFontHighlight")
    val:SetWidth(44)
    val:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local plus = Button(f, "+", 24)
    plus:SetPoint("LEFT", val, "RIGHT", 4, 0)
    local function refresh() val:SetText(fmt and string.format(fmt, get()) or get()) end
    local function change(d)
        local v = math.max(min, math.min(max, get() + d))
        set(math.floor(v / step + 0.5) * step)
        refresh()
        ns.Refresh()
    end
    minus:SetScript("OnClick", function() change(-step) end)
    plus:SetScript("OnClick", function() change(step) end)
    f:SetScript("OnShow", refresh)
    refresh()
    return f
end

local function Dropdown(parent, text, groups, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(380, 26)
    Label(f, text, "GameFontHighlight"):SetPoint("LEFT", 4, 0)
    local dd = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    dd:SetWidth(210)
    dd:SetPoint("LEFT", 150, 0)
    dd:SetupMenu(function(_, root)
        local all, count = groups(), 0
        for _, group in ipairs(all) do count = count + #group.items end
        if count > 20 then root:SetScrollMode(20 * 20) end
        for _, group in ipairs(all) do
            if group.title then root:CreateTitle(group.title) end
            for _, item in ipairs(group.items) do
                root:CreateRadio(item.name, function() return get() == item.path end, function()
                    set(item.path)
                    ns.Refresh()
                end)
            end
        end
    end)
    return f
end

local function Options(...)
    local items = {}
    for i = 1, select("#", ...), 2 do
        local path, name = select(i, ...)
        items[#items + 1] = { path = path, name = name }
    end
    local groups = { { items = items } }
    return function() return groups end
end

local OUTLINES = Options("", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick outline")
local AURA_MODES = Options("mine", "Only my debuffs", "all", "My debuffs, others' debuffs, buffs")
local ICON_ANCHORS = Options("left", "Left of the name", "right", "Past the end of the bar", "above", "Above the name")
local COLOR_MODES = Options("xiv", "FFXIV (engaged / passive / friendly)",
    "reaction", "Hostile / neutral / friendly", "fixed", "Always the bar colour")

local function ColorSwatch(parent, text, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(300, 24)
    Label(f, text, "GameFontHighlight"):SetPoint("LEFT", 4, 0)
    local sw = CreateFrame("Button", nil, f, "BackdropTemplate")
    sw:SetSize(40, 18)
    sw:SetPoint("LEFT", 150, 0)
    sw:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sw:SetBackdropBorderColor(1, 1, 1, 0.6)
    local function refresh()
        local c = get()
        sw:SetBackdropColor(c.r, c.g, c.b, 1)
    end
    local function apply(r, g, b)
        set(r, g, b)
        refresh()
        ns.Refresh()
    end
    sw:SetScript("OnClick", function()
        local c = get()
        local r0, g0, b0 = c.r, c.g, c.b
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r0, g = g0, b = b0,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() apply(r0, g0, b0) end,
        })
    end)
    refresh()
    return f
end

local function TextBox(parent, text, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(380, 26)
    Label(f, text, "GameFontHighlight"):SetPoint("LEFT", 4, 0)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(200, 20)
    eb:SetPoint("LEFT", 156, 0)
    eb:SetAutoFocus(false)
    eb:SetText(get())
    eb:SetScript("OnShow", function(self) self:SetText(get()) end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        set(self:GetText())
        ns.Refresh()
    end)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    return f
end

local function Placer()
    local y = 0
    return function(w, h, x)
        w:SetPoint("TOPLEFT", x or 0, y)
        y = y - h
    end
end

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

function Config:BuildBar(p)
    local db = ns.db
    local place = Placer()
    place(Checkbox(p, "Unlock to move (drag the bar; shows a preview)",
        function() return not db.locked end, function(v) db.locked = not v end), 28)
    place(Checkbox(p, "Click to target, right-click for the menu",
        function() return db.clicks end, function(v) db.clicks = v end), 34)
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
    local help = Label(p, "Words: |cffffd100level|r, |cffffd100name|r, |cffffd100value|r, |cffffd100max|r, "
        .. "|cffffd100percent|r (|cffffd100percent.1|r for a decimal). Leave empty to hide.", "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 36, 4)
    place(Dropdown(p, "Font", function() return ns.Media:List("font") end,
        function() return t.font end, function(v) t.font = v end), 30)
    place(Dropdown(p, "Font outline", OUTLINES, function() return t.outline end, function(v) t.outline = v end), 30)
    place(Stepper(p, "Text size", 8, 24, 1, function() return t.size end, function(v) t.size = v end), 28)
    place(Checkbox(p, "Tint text to match the bar, like FFXIV",
        function() return t.tinted end, function(v) t.tinted = v end), 28)
end

function Config:BuildToT(p)
    local cfg = ns.db.tot
    local place = Placer()
    place(Checkbox(p, "Show your target's target beside the bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 34)
    place(Stepper(p, "Width", 60, 400, 10, function() return cfg.width end, function(v) cfg.width = v end), 26)
    place(Stepper(p, "Gap from target bar", 0, 80, 2, function() return cfg.gap end, function(v) cfg.gap = v end), 32)
    place(TextBox(p, "Text", function() return cfg.template end, function(v) cfg.template = v end), 28)
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
        { "raid", "Raid marker" },
        { "leader", "Group leader / assistant" },
        { "role", "Group role (tank, healer, damage)" },
        { "pvp", "PvP flag (players)" },
        { "quest", "Quest target" },
    }) do
        local key = def[1]
        place(Checkbox(p, def[2], function() return cfg[key] end, function(v) cfg[key] = v end), 28, 16)
    end
end

function Config:Build()
    local f = CreateFrame("Frame", "XIVTargetConfig", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    Label(f, "XIVTarget"):SetPoint("TOP", 0, -5)
    tinsert(UISpecialFrames, "XIVTargetConfig")
    self.frame = f

    local pages, tabs = {}, {}
    local function select(key)
        for k, page in pairs(pages) do page:SetShown(k == key) end
        for k, tab in pairs(tabs) do
            if k == key then tab:LockHighlight() else tab:UnlockHighlight() end
        end
    end
    for i, def in ipairs({ { "bar", "Bar" }, { "text", "Text" }, { "tot", "ToT" }, { "auras", "Status" }, { "icons", "Icons" } }) do
        local key = def[1]
        local tab = Button(f, def[2], 80)
        tab:SetPoint("TOPLEFT", 14 + (i - 1) * 83, -30)
        tab:SetScript("OnClick", function() select(key) end)
        tabs[key] = tab
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 16, -62)
        page:SetPoint("BOTTOMRIGHT", -16, 12)
        pages[key] = page
    end
    self:BuildBar(pages.bar)
    self:BuildText(pages.text)
    self:BuildToT(pages.tot)
    self:BuildAuras(pages.auras)
    self:BuildIcons(pages.icons)
    select("bar")
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
ns.AddOptionsPanel({
    open = function()
        if not (Config.frame and Config.frame:IsShown()) then Config:Toggle() end
    end,
    commands = { { "/xiv", "open or close the settings" } },
})
