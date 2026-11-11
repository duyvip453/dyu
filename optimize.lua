local features = {}
local lighting = game:GetService("Lighting")
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Chỉ thay đổi hiển thị cục bộ; không xóa instance hay thay đổi dữ liệu game.
local states = {
    lootBoxes = false,
    objects = false,
    super = false,
}
local originals = setmetatable({}, { __mode = "k" })
local watchedFolders = setmetatable({}, { __mode = "k" })
local fogOriginals

local dropFolderNames = {
    coins = true,
    orbs = true,
    lootbags = true,
    lootboxes = true,
    lootbox = true,
}

-- Chỉ ẩn hình khối trong các nhóm render đã xác nhận dưới Workspace.__THINGS.
local superVisualFolders = {
    pets = true,
    shinyrelics = true,
    hoverboards = true,
}

local mapRoots = {
    ["PSX Hall"] = true,
    ["PSX Portal"] = true,
    GREYBOX_WIP = true,
}

local mapThings = {
    Ornaments = true,
    __FAKE_GROUND = true,
    __FAKE_INSTANCE_GROUND = true,
    __FAKE_INSTANCE_BREAK_ZONES = true,
}

local function isMapGeometry(instance)
    if not (instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture")) then
        return false
    end
    local current = instance
    while current and current ~= workspace do
        local name = current.Name
        local lowerName = string.lower(name)
        if lowerName:find("chest", 1, true) or lowerName:find("breakable", 1, true) then
            return false
        end
        local parent = current.Parent
        if parent == workspace then
            return mapRoots[name] == true or name:match("^Map%d*$") ~= nil
                or name:match("^Border%d+$") ~= nil or name:match("^ALWAYS_RENDERING_%d+$") ~= nil
                or name:match("^Zone %d+$") ~= nil
        end
        if parent and parent.Parent == workspace and parent.Name == "__THINGS" then
            return mapThings[name] == true
        end
        current = parent
    end
    return false
end

local function getVisualFolderName(instance)
    local parent = instance.Parent
    if not parent or parent.Parent ~= workspace then return nil end
    if not (instance:IsA("Folder") or instance:IsA("Model")) then return nil end
    local name = string.lower(instance.Name)
    if parent.Name == "__THINGS" and (dropFolderNames[name] or superVisualFolders[name]) then
        return name
    end
    if parent.Name == "__DEBRIS" and name == "currency" then return name end
    return nil
end

local function isLootBoxFolder(name)
    name = string.lower(name)
    return name == "lootbags" or name == "lootboxes" or name == "lootbox"
end

local function isFolderDisabled(name)
    if states.super then return true end
    if states.lootBoxes and isLootBoxFolder(name) then return true end
    return states.objects and (name == "coins" or name == "orbs" or name == "currency")
end

local function getHiddenProperties(instance)
    if instance:IsA("BasePart") then
        return { { "LocalTransparencyModifier", 1 } }
    elseif instance:IsA("Decal") or instance:IsA("Texture") then
        return { { "Transparency", 1 } }
    elseif instance:IsA("Atmosphere") then
        return {
            { "Density", 0 },
            { "Haze", 0 },
            { "Glare", 0 },
        }
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail")
        or instance:IsA("Beam") or instance:IsA("BillboardGui")
        or instance:IsA("SurfaceGui") or instance:IsA("Highlight")
        or instance:IsA("Smoke") or instance:IsA("Fire")
        or instance:IsA("Sparkles") or instance:IsA("PostEffect")
        or instance:IsA("Clouds") or instance:IsA("PointLight")
        or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        return { { "Enabled", false } }
    end
    return nil
end

local function setLocalHidden(instance, hidden)
    local properties = getHiddenProperties(instance)
    if not properties then return end

    local saved = originals[instance]
    if hidden then
        if not saved then
            saved = {}
            originals[instance] = saved
        end
        for _, entry in ipairs(properties) do
            local property, hiddenValue = entry[1], entry[2]
            if saved[property] == nil then saved[property] = instance[property] end
            instance[property] = hiddenValue
        end
    elseif saved then
        for property, originalValue in pairs(saved) do
            instance[property] = originalValue
        end
        originals[instance] = nil
    end
end

local function isWorldEffect(instance)
    return instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")
        or instance:IsA("ParticleEmitter") or instance:IsA("Trail")
        or instance:IsA("Beam") or instance:IsA("Highlight")
        or instance:IsA("Smoke") or instance:IsA("Fire")
        or instance:IsA("Sparkles") or instance:IsA("PostEffect")
        or instance:IsA("Clouds") or instance:IsA("PointLight")
        or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
        or instance:IsA("Atmosphere")
end

local function hasDisabledFolderAncestor(instance)
    local current = instance
    while current and current ~= workspace do
        local name = getVisualFolderName(current)
        if name and isFolderDisabled(name) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function shouldHide(instance)
    if states.super and isMapGeometry(instance) then return true end
    if instance:IsA("BasePart") and instance.CanCollide then return false end
    return hasDisabledFolderAncestor(instance)
        or ((states.lootBoxes or states.super) and isWorldEffect(instance))
end

local function applyTree(root)
    setLocalHidden(root, shouldHide(root))
    for _, descendant in ipairs(root:GetDescendants()) do
        setLocalHidden(descendant, shouldHide(descendant))
    end
end

local function watchFolder(folder)
    if watchedFolders[folder] then return end
    watchedFolders[folder] = true
    applyTree(folder)
    folder.DescendantAdded:Connect(function(descendant)
        setLocalHidden(descendant, shouldHide(descendant))
    end)
end

local function scanFolders()
    for _, name in ipairs({ "__THINGS", "__DEBRIS" }) do
        local container = workspace:FindFirstChild(name)
        if container then
            for _, instance in ipairs(container:GetChildren()) do
                if getVisualFolderName(instance) then watchFolder(instance) end
            end
        end
    end
end

local function setFogHidden(hidden)
    if hidden then
        if not fogOriginals then
            fogOriginals = {
                FogStart = lighting.FogStart,
                FogEnd = lighting.FogEnd,
            }
        end
        lighting.FogStart = 0
        lighting.FogEnd = 1000000
    elseif fogOriginals then
        lighting.FogStart = fogOriginals.FogStart
        lighting.FogEnd = fogOriginals.FogEnd
        fogOriginals = nil
    end
end

local function refreshVisuals()
    scanFolders()
    for folder in pairs(watchedFolders) do
        applyTree(folder)
    end
    for _, instance in ipairs(workspace:GetDescendants()) do
        if originals[instance] or isWorldEffect(instance) or (states.super and isMapGeometry(instance)) then
            setLocalHidden(instance, shouldHide(instance))
        end
    end
    for _, instance in ipairs(lighting:GetDescendants()) do
        if isWorldEffect(instance) then setLocalHidden(instance, shouldHide(instance)) end
    end
    for _, instance in ipairs(playerGui:GetDescendants()) do
        if isWorldEffect(instance) then setLocalHidden(instance, shouldHide(instance)) end
    end
    setFogHidden(states.lootBoxes or states.super)
end

workspace.DescendantAdded:Connect(function(instance)
    if getVisualFolderName(instance) then
        watchFolder(instance)
    elseif getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

lighting.DescendantAdded:Connect(function(instance)
    if getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

playerGui.DescendantAdded:Connect(function(instance)
    if getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

local function updateState(key, enabled)
    states[key] = enabled
    refreshVisuals()
end

features.OptimizeDisableLootBoxes = {
    duy = function(enabled)
        updateState("lootBoxes", enabled)
    end,
}

features.OptimizeDisableObjects = {
    duy = function(enabled)
        updateState("objects", enabled)
    end,
}

features.OptimizeSuper = {
    duy = function(enabled)
        updateState("super", enabled)
    end,
}

return features
