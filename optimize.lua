local features = {}
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local tweenService = game:GetService("TweenService")

-- Chỉ thay đổi hiển thị cục bộ; không xóa instance hay thay đổi dữ liệu game.
local states = {
    lootBoxes = false,
    objects = false,
    super = false,
}
local originals = setmetatable({}, { __mode = "k" })
local watchedFolders = setmetatable({}, { __mode = "k" })
local fogOriginals
local objectBoxes = {}
local damageConnection
local boxSize = Vector3.new(1.75, 1.75, 1.75)
local bounceInfo = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local invisibleParticles = NumberSequence.new(1)

local objectFolders = {
    Breakables = true,
    AnimatedBreakables = true,
    Chests = true,
    RandomEvents = true,
}

local function getZoneObject(instance)
    local current = instance
    while current and current ~= workspace do
        local parent = current.Parent
        local things = parent and parent.Parent
        if things and things.Name == "__THINGS" and things.Parent == workspace then
            if objectFolders[parent.Name] and (current:IsA("Model") or current:IsA("BasePart")) then
                return current
            end
            return nil
        end
        current = parent
    end
    return nil
end

local function isOtherCharacter(instance)
    local current = instance
    while current and current.Parent ~= workspace do current = current.Parent end
    if not current or not current:IsA("Model") then return false end
    local player = players:GetPlayerFromCharacter(current)
    return player ~= nil and player ~= localPlayer
end

local function ensureObjectBox(object)
    local record = objectBoxes[object]
    if record and record.box.Parent then return end
    local anchor = object:IsA("BasePart") and object
        or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    if not anchor then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "OptimizeObjectBox"
    box.Adornee = anchor
    box.Size = boxSize
    box.Color3 = Color3.fromRGB(128, 128, 128)
    objectBoxes[object] = { box = box, nextBounce = 0 }
    box.Parent = anchor
end

local function removeObjectBox(object)
    local record = objectBoxes[object]
    if not record then return end
    objectBoxes[object] = nil
    record.box:Destroy()
end

local function connectObjectDamage()
    if damageConnection then return end
    local client = game:GetService("ReplicatedStorage").Library.Client
    local breakables = require(client.BreakableCmds)
    if not states.objects or damageConnection then return end
    damageConnection = breakables.DamageDealt:Connect(function(data)
        if not states.objects or not data.model then return end
        local object = getZoneObject(data.model)
        local record = object and objectBoxes[object]
        local now = os.clock()
        if not record or not record.box.Parent or now < record.nextBounce then return end
        record.nextBounce = now + 0.24
        record.box.CFrame = CFrame.identity
        tweenService:Create(record.box, bounceInfo, { CFrame = CFrame.new(0, 0.55, 0) }):Play()
    end)
end

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
    elseif instance:IsA("ParticleEmitter") then
        return { { "Enabled", false }, { "Transparency", invisibleParticles } }
    elseif instance:IsA("Trail")
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
    if states.super and isOtherCharacter(instance) then return true end
    if states.objects then
        if getZoneObject(instance) then return true end
        if isWorldEffect(instance) then
            local current = instance
            while current and current.Parent ~= workspace do
                local parent = current.Parent
                if parent and parent.Name == "__DEBRIS" and parent.Parent == workspace then
                    if current.Name:match("^ParticleHost_") or current.Name == "RewardBillboard" then return true end
                    break
                end
                current = parent
            end
        end
    end
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
        if states.objects and instance:IsA("BasePart") then
            local object = getZoneObject(instance)
            if object then ensureObjectBox(object) end
        end
        if getHiddenProperties(instance) or originals[instance] then
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
    if states.objects and instance:IsA("BasePart") then
        local object = getZoneObject(instance)
        if object then ensureObjectBox(object) end
    end
    if getVisualFolderName(instance) then
        watchFolder(instance)
    elseif getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

workspace.DescendantRemoving:Connect(function(instance)
    if objectBoxes[instance] then removeObjectBox(instance) end
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
    if key == "objects" then
        if enabled then
            task.defer(connectObjectDamage)
        else
            if damageConnection then damageConnection:Disconnect(); damageConnection = nil end
            for object in pairs(objectBoxes) do removeObjectBox(object) end
        end
    end
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
