local _, ns = ...
local Auras = {}
ns.Auras = Auras

-- Status effects under the target bar, rendered by 12.1's AuraContainer (the engine picks and
-- draws the auras, so it keeps working where addons can't read aura data). Lessons carried
-- over from PersonalResourceTweaks: position the container before setting it up, never
-- anchor anything to it, and size the buttons ourselves (the engine makes them 0x0).

local SORT = AuraContainerSortMethod and AuraContainerSortMethod.Default
local SORT_DIR = AuraContainerSortDirection and AuraContainerSortDirection.Normal

local container, signature, keys
local styled = {}

local formatter
local function DurationFormatter()
    if formatter ~= nil then return formatter or nil end
    formatter = false
    local R = Enum.NumericRuleFormatRounding
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and R then
        local f = C_StringUtil.CreateNumericRuleFormatter()
        if pcall(f.SetBreakpoints, f, {
            { threshold = 0, format = "%d", step = 1, rounding = R.Up },
            { threshold = 60, format = "%dm", step = 1, rounding = R.Up, components = { { div = 60 } } },
            { threshold = 61, format = "%dm", step = 1, rounding = R.Down, components = { { div = 60 } } },
            { threshold = 3600, format = "%dh", step = 1, rounding = R.Down, components = { { div = 3600 } } },
        }) then
            formatter = f
        end
    end
    return formatter or nil
end

local function CallEither(c, newName, oldName, ...)
    local f = c[newName] or c[oldName]
    if f then pcall(f, c, ...) end
end

local function StyleButton(d)
    local cfg, t = ns.db.auras, ns.db.text
    if d.size ~= cfg.size and pcall(d.button.SetSize, d.button, cfg.size, cfg.size) then
        d.size = cfg.size
    end
    local font, size = cfg.font or t.font, math.max(9, math.floor(cfg.size * 0.46))
    ns.Media:SetFont(d.stack, font, size, t.outline)
    ns.Media:SetFont(d.duration, font, size, t.outline)
    d.duration:SetShown(cfg.showTimer)
end

local function MakeInit(harmful)
    return function(button)
        local d = { button = button }
        d.border = button:CreateTexture(nil, "BACKGROUND")
        d.border:SetAllPoints()
        if harmful then
            d.border:SetColorTexture(0.75, 0.12, 0.08, 1)
        else
            d.border:SetColorTexture(0, 0, 0, 1)
        end
        d.icon = button:CreateTexture(nil, "ARTWORK")
        d.icon:SetPoint("TOPLEFT", 1, -1)
        d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        d.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        d.cooldown:SetAllPoints(d.icon)
        d.cooldown:SetDrawEdge(false)
        d.cooldown:SetReverse(true)
        d.cooldown:SetHideCountdownNumbers(true)
        local carrier = CreateFrame("Frame", nil, button)
        carrier:SetAllPoints()
        carrier:SetFrameLevel(d.cooldown:GetFrameLevel() + 1)
        carrier:EnableMouse(false)
        d.stack = carrier:CreateFontString(nil, "OVERLAY")
        d.stack:SetPoint("BOTTOMRIGHT", -1, 1)
        -- FFXIV prints the timer under the icon rather than on it.
        d.duration = carrier:CreateFontString(nil, "OVERLAY")
        d.duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
        StyleButton(d)

        pcall(button.SetMouseClickEnabled, button, false)
        button:SetIcon(d.icon)
        button:SetDurationCooldown(d.cooldown)
        button:SetApplicationCount(d.stack, {})
        if not pcall(button.SetDurationText, button, d.duration, { textFormatter = DurationFormatter() }) then
            pcall(button.SetDurationText, button, d.duration, {})
        end
        table.insert(styled, d)
    end
end

local function Layout(cfg)
    -- Extra line spacing leaves room for the timer printed under each icon.
    return { elementWidth = cfg.size, elementHeight = cfg.size, elementSpacing = cfg.spacing,
        lineSpacing = cfg.spacing + (cfg.showTimer and 12 or 0) }
end

local function Build(parent, anchor)
    local cfg = ns.db.auras
    if container then
        pcall(container.SetUnit, container, "none")
        container:Hide()
        container = nil
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok then return end

    c:SetSize(1, 1)
    c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    CallEither(c, "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint", "TOPLEFT")
    CallEither(c, "SetFlowLayoutGrowthDirection", "SetAuraLayoutGrowthDirection",
        AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)

    wipe(styled)
    keys = {}
    local layout = Layout(cfg)
    local function add(key, filter, harmful)
        local ok2, err = pcall(c.AddAuraGroup, c, key, filter, {
            maxFrameCount = cfg.max, sortMethod = SORT, sortDirection = SORT_DIR,
            initializeFrame = MakeInit(harmful), layout = layout,
        })
        if ok2 then keys[#keys + 1] = key else ns.Print("Couldn't set up status effects:", err) end
    end
    -- Your own debuffs first, like FFXIV; then everyone else's; then the target's buffs.
    add("mine", "HARMFUL|PLAYER", true)
    if cfg.mode == "all" then
        add("others", "HARMFUL|!PLAYER", true)
        add("buffs", "HELPFUL", false)
    end
    c:SetUnit("target")
    c:UpdateAllAuras()
    container = c
    signature = cfg.mode .. "|" .. cfg.max
end

function Auras:Apply(parent, anchor)
    local cfg = ns.db.auras
    if not container or signature ~= (cfg.mode .. "|" .. cfg.max) then
        Build(parent, anchor)
    end
    if not container then return end
    local layout = Layout(cfg)
    for _, key in ipairs(keys) do
        pcall(container.SetAuraGroupLayout, container, key, layout)
    end
    CallEither(container, "SetFlowLayoutMaximumLineSize", "SetAuraLayoutRowWidth", ns.db.width + 0.4)
    container:SetShown(cfg.enabled)
    for _, d in ipairs(styled) do pcall(StyleButton, d) end
end

-- The container is bound to the "target" token; a new target needs a fresh parse.
function Auras:TargetChanged()
    if container then pcall(container.UpdateAllAuras, container) end
end
