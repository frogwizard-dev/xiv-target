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

local AuraKit = FrogLib.Auras -- the rows' building blocks (FrogLib's Auras.lua)

local function StyleButton(slot)
    local cfg, text = ns.db.auras, ns.db.text
    if slot.size ~= cfg.size and pcall(slot.button.SetSize, slot.button, cfg.size, cfg.size) then
        slot.size = cfg.size
    end
    local font, size = cfg.font or text.font, math.max(9, math.floor(cfg.size * 0.46))
    ns.Media:SetFont(slot.stack, font, size, text.outline)
    ns.Media:SetFont(slot.duration, font, size, text.outline)
    slot.duration:SetShown(cfg.showTimer)
end

local function MakeInit(harmful)
    return function(button)
        -- FFXIV prints the timer under the icon rather than on it.
        local slot = AuraKit.InitButton(button, { border = harmful and { 0.75, 0.12, 0.08 } or nil, style = StyleButton })
        table.insert(styled, slot)
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
    AuraKit.Release(container)
    container = nil
    local built = AuraKit.NewContainer(parent)
    if not built then return end

    built:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -top)
    AuraKit.Flow(built, "TOPLEFT", "RIGHT", "DOWN")

    wipe(styled)
    keys = {}
    local layout = Layout(cfg)
    local function Add(key, filter, harmful)
        local ok, err = pcall(built.AddAuraGroup, built, key, filter, {
            maxFrameCount = cfg.max, sortMethod = SORT, sortDirection = SORT_DIR,
            initializeFrame = MakeInit(harmful), layout = layout,
        })
        if ok then keys[#keys + 1] = key else ns.Print("Couldn't set up status effects:", err) end
    end
    -- Your own debuffs first, like FFXIV; then everyone else's; then the target's buffs.
    Add("mine", "HARMFUL|PLAYER", true)
    if cfg.mode == "all" then
        Add("others", "HARMFUL|!PLAYER", true)
        Add("buffs", "HELPFUL", false)
    end
    built:SetUnit("target")
    built:UpdateAllAuras()
    container = built
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
    AuraKit.SetLineSize(container, ns.db.width + 0.4)
    container:SetShown(cfg.enabled)
    for _, slot in ipairs(styled) do pcall(StyleButton, slot) end
end

-- The container is bound to the "target" token; a new target needs a fresh parse.
function Auras:TargetChanged()
    if container then pcall(container.UpdateAllAuras, container) end
end
