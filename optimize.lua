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
local itemPopupOriginal
local itemPopupJobRunning = false
-- Theo dõi khối thay thế của từng vật thể trong zone.
local objectBoxes = {}
local damageConnection
local boxSize = Vector3.new(1.75, 1.75, 1.75)
local bounceInfo = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local invisibleParticles = NumberSequence.new(1)

-- Khai báo các nhóm vật thể được thay bằng khối xám.
local objectFolders = {
    Breakables = true,
    AnimatedBreakables = true,
    Chests = true,
    RandomEvents = true,
}

-- Tìm vật thể gốc thuộc nhóm đối tượng trong zone.
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

-- Nhận diện nhân vật của người chơi khác.
local function isOtherCharacter(instance)
    local current = instance
    while current and current.Parent ~= workspace do current = current.Parent end
    if not current or not current:IsA("Model") then return false end
    local player = players:GetPlayerFromCharacter(current)
    return player ~= nil and player ~= localPlayer
end

-- Gắn khối xám hiển thị vào part của vật thể.
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

-- Dọn khối xám do script tạo cho vật thể.
local function removeObjectBox(object)
    local record = objectBoxes[object]
    if not record then return end
    objectBoxes[object] = nil
    record.box:Destroy()
end

-- Làm khối xám nảy khi vật thể nhận sát thương.
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

-- Nhận diện tên các thư mục chứa đồ rơi.
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

-- Liệt kê nhóm map đặc biệt nằm trực tiếp dưới Workspace.
local mapRoots = {
    ["PSX Hall"] = true,
    ["PSX Portal"] = true,
    GREYBOX_WIP = true,
}

-- Liệt kê nhóm map nằm trong Workspace.__THINGS.
local mapThings = {
    Ornaments = true,
    __FAKE_GROUND = true,
    __FAKE_INSTANCE_GROUND = true,
    __FAKE_INSTANCE_BREAK_ZONES = true,
}

-- Nhận diện hình khối map có thể ẩn trong Super Optimize.
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

-- Nhận diện thư mục hiển thị theo đúng cây object của game.
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

-- Nhận diện thư mục túi quà và hộp quà.
local function isLootBoxFolder(name)
    name = string.lower(name)
    return name == "lootbags" or name == "lootboxes" or name == "lootbox"
end

-- Kiểm tra toggle hiện tại có yêu cầu ẩn nhóm đó không.
local function isFolderDisabled(name)
    if states.super then return true end
    if states.lootBoxes and isLootBoxFolder(name) then return true end
    return states.objects and (name == "coins" or name == "orbs" or name == "currency")
end

-- Chọn thuộc tính hiển thị cần đổi theo loại instance.
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

-- Đổi hiển thị cục bộ có lưu giá trị để khôi phục.
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

-- Nhận diện các instance thuộc nhóm hiệu ứng hiển thị.
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

-- Kiểm tra instance có nằm trong nhóm đang bị ẩn không.
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

-- Xác định instance có cần ẩn theo cấu hình hiện tại không.
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

-- Áp dụng trạng thái hiển thị cho cả cây instance.
local function applyTree(root)
    setLocalHidden(root, shouldHide(root))
    for _, descendant in ipairs(root:GetDescendants()) do
        setLocalHidden(descendant, shouldHide(descendant))
    end
end

-- Theo dõi object mới được thêm vào thư mục đã nhận diện.
local function watchFolder(folder)
    if watchedFolders[folder] then return end
    watchedFolders[folder] = true
    applyTree(folder)
    folder.DescendantAdded:Connect(function(descendant)
        setLocalHidden(descendant, shouldHide(descendant))
    end)
end

-- Tìm các thư mục hiển thị dưới __THINGS và __DEBRIS.
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

-- Đổi trạng thái sương theo toggle tối ưu.
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

-- Đồng bộ hiển thị của các instance đang tải.
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

-- Áp dụng bộ lọc tối ưu cho object mới trong Workspace.
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

-- Dọn khối xám khi vật thể gốc rời Workspace.
workspace.DescendantRemoving:Connect(function(instance)
    if objectBoxes[instance] then removeObjectBox(instance) end
end)

-- Áp dụng bộ lọc tối ưu cho hiệu ứng Lighting mới.
lighting.DescendantAdded:Connect(function(instance)
    if getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

-- Áp dụng bộ lọc tối ưu cho hiệu ứng UI mới.
playerGui.DescendantAdded:Connect(function(instance)
    if getHiddenProperties(instance) then
        setLocalHidden(instance, shouldHide(instance))
    end
end)

-- Đồng bộ tùy chọn Item Popups theo Super Optimize.
local function syncItemPopups()
    if itemPopupJobRunning then return end
    itemPopupJobRunning = true
    task.defer(function()
        local ok, err = pcall(function()
            local library = game:GetService("ReplicatedStorage").Library
            local settings = require(library.Client.SettingsCmds)
            local save = require(library.Client.Save)
            local network = require(library.Client.Network)
            local key = "ItemNotifications"
            local options = require(library.Shared.Variables).SettingsInfo[key].options
            local off = assert(table.find(options, "Off"), "Không tìm thấy tùy chọn Off")
            local current = settings.GetValue(key)
            assert(options[current], "Chưa đọc được Item Popups")

            -- Remote của menu chỉ chuyển sang lựa chọn kế tiếp trong vòng.
            local attempts = 0
            local lastTarget
            while true do
                if states.super and itemPopupOriginal == nil then itemPopupOriginal = current end
                local target = states.super and off or itemPopupOriginal
                if not target or current == target then
                    if not states.super then itemPopupOriginal = nil end
                    return
                end
                if target ~= lastTarget then
                    lastTarget = target
                    attempts = 0
                end
                assert(attempts < #options, "Không chuyển được Item Popups tới lựa chọn yêu cầu")
                attempts += 1
                local success, reason, newValue = network.Invoke("Toggle Setting", key)
                assert(success and options[newValue], reason or "Game từ chối đổi Item Popups")
                current = newValue
                local data = save.Get()
                if data and data.Settings then data.Settings[key] = current end
                if current ~= target then task.wait(0.2) end
            end
        end)
        itemPopupJobRunning = false
        if not ok then warn("[Super Optimize] Item Popups: " .. tostring(err)) end
    end)
end

-- Áp dụng thay đổi trạng thái của một toggle Optimize.
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
    if key == "super" then syncItemPopups() end
    refreshVisuals()
end

-- Xuất toggle ẩn loot box và hiệu ứng liên quan.
features.OptimizeDisableLootBoxes = {
    duy = function(enabled)
        updateState("lootBoxes", enabled)
    end,
}

-- Xuất toggle thay vật thể trong zone bằng khối xám.
features.OptimizeDisableObjects = {
    duy = function(enabled)
        updateState("objects", enabled)
    end,
}

-- Xuất toggle tối ưu hiển thị tổng hợp.
features.OptimizeSuper = {
    duy = function(enabled)
        updateState("super", enabled)
    end,
}

-- Lưu giới hạn FPS của client trước khi bật toggle.
local fpsTarget = 30
local previousFpsCap
local fpsEnabled = false
local setFpsCap = setfpscap or set_fps_cap
local getFpsCap = getfpscap or get_fps_cap

-- Áp dụng giới hạn FPS qua API của executor.
local function applyFpsCap(value)
    if type(setFpsCap) ~= "function" then
        warn("[FPS Limit] Executor không hỗ trợ giới hạn FPS")
        return false
    end
    local ok, err = pcall(setFpsCap, value)
    if not ok then warn("[FPS Limit] " .. tostring(err)) end
    return ok
end

features.OptimizeFpsLimit = {
    setTarget = function(value)
        local fps = tonumber(value)
        if not fps or fps < 1 or fps > 2000 or fps % 1 ~= 0 then
            warn("[FPS Limit] Nhập số nguyên từ 1 đến 2000")
            return false
        end
        fpsTarget = fps
        if fpsEnabled then applyFpsCap(fpsTarget) end
        return true
    end,
    duy = function(enabled)
        if enabled == fpsEnabled then return end
        if enabled then
            local saved = 0
            if type(getFpsCap) == "function" then
                local ok, value = pcall(getFpsCap)
                if ok and type(value) == "number" then saved = value end
            end
            if applyFpsCap(fpsTarget) then
                previousFpsCap = saved
                fpsEnabled = true
            end
        elseif applyFpsCap(previousFpsCap) then
            previousFpsCap = nil
            fpsEnabled = false
        end
    end,
}

return features
