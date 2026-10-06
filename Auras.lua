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

local A = FrogLib.Auras -- the rows' building blocks (FrogLib's Auras.lua)

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
        -- FFXIV prints the timer under the icon rather than on it.
        local d = A.InitButton(button, { border = harmful and { 0.75, 0.12, 0.08 } or nil, style = StyleButton })
        table.insert(styled, d)
    end
end

local function Layout(cfg)
    -- Extra line spacing leaves room for the timer printed under each icon.
    return { elementWidth = cfg.size, elementHeight = cfg.size, elementSpacing = cfg.spacing,
        lineSpacing = cfg.spacing + (cfg.showTimer and 12 or 0) }
end

local function Signature(cfg, top)
    return cfg.mode .. "|" .. cfg.max .. "|" .. top
end

-- top: how far below the anchor's bottom edge the icons start.
local function Build(parent, anchor, top)
    local cfg = ns.db.auras
    A.Release(container)
    container = nil
    local c = A.NewContainer(parent)
    if not c then return end

    c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -top)
    A.Flow(c, "TOPLEFT", "RIGHT", "DOWN")

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
    signature = Signature(cfg, top)
end

-- top: as in Build (6 below the bar, more under a power gauge). Where the container sits is
-- part of what it's built with, so moving it means building it again.
function Auras:Apply(parent, anchor, top)
    local cfg = ns.db.auras
    top = top or 6
    if not container or signature ~= Signature(cfg, top) then
        Build(parent, anchor, top)
    end
    if not container then return end
    local layout = Layout(cfg)
    for _, key in ipairs(keys) do
        pcall(container.SetAuraGroupLayout, container, key, layout)
    end
    A.SetLineSize(container, ns.db.width + 0.4)
    container:SetShown(cfg.enabled)
    for _, d in ipairs(styled) do pcall(StyleButton, d) end
end

-- The container is bound to the "target" token; a new target needs a fresh parse.
function Auras:TargetChanged()
    if container then pcall(container.UpdateAllAuras, container) end
end
