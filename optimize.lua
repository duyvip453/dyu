local features = {}

-- Đây chỉ ẩn hình ảnh ở client; vật thể vẫn còn để game xử lý/nhặt.
local states = {
    lootBoxes = false,
    objects = false,
    super = false,
}
local originals = setmetatable({}, { __mode = "k" })
local watchedFolders = setmetatable({}, { __mode = "k" })
local dropFolderNames = {
    coins = true,
    orbs = true,
    lootbags = true,
    lootboxes = true,
    lootbox = true,
}

local function isLootBoxFolder(name)
    name = string.lower(name)
    return name == "lootbags" or name == "lootboxes" or name == "lootbox"
end

local function isHiddenFolder(name)
    if states.super then return true end
    if states.lootBoxes and isLootBoxFolder(name) then return true end
    return states.objects and (string.lower(name) == "coins" or string.lower(name) == "orbs")
end

local function setLocalHidden(instance, hidden)
    local property
    if instance:IsA("BasePart") then
        property = "LocalTransparencyModifier"
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail")
        or instance:IsA("Beam") or instance:IsA("BillboardGui")
        or instance:IsA("SurfaceGui") or instance:IsA("Highlight") then
        property = "Enabled"
    end

    if not property then return end
    local saved = originals[instance]
    if hidden then
        if not saved then
            saved = {}
            originals[instance] = saved
        end
        if saved[property] == nil then saved[property] = instance[property] end
        instance[property] = property == "LocalTransparencyModifier" and 1 or false
    elseif saved and saved[property] ~= nil then
        instance[property] = saved[property]
        saved[property] = nil
        if next(saved) == nil then originals[instance] = nil end
    end
end

local function setTreeHidden(root, hidden)
    setLocalHidden(root, hidden)
    for _, descendant in ipairs(root:GetDescendants()) do
        setLocalHidden(descendant, hidden)
    end
end

local function refreshWatchedFolders()
    for folder in pairs(watchedFolders) do
        setTreeHidden(folder, isHiddenFolder(folder.Name))
    end
end

local function watchFolder(folder)
    if watchedFolders[folder] then return end
    watchedFolders[folder] = true
    setTreeHidden(folder, isHiddenFolder(folder.Name))
    folder.DescendantAdded:Connect(function(descendant)
        if isHiddenFolder(folder.Name) then setLocalHidden(descendant, true) end
    end)
end

local function scanFolders()
    for _, instance in ipairs(workspace:GetDescendants()) do
        if dropFolderNames[string.lower(instance.Name)]
            and (instance:IsA("Folder") or instance:IsA("Model")) then
            watchFolder(instance)
        end
    end
end

workspace.DescendantAdded:Connect(function(instance)
    if dropFolderNames[string.lower(instance.Name)]
        and (instance:IsA("Folder") or instance:IsA("Model")) then
        watchFolder(instance)
    end
end)

local function updateState(key, enabled)
    states[key] = enabled
    if enabled then scanFolders() end
    refreshWatchedFolders()
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

