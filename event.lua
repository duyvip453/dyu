-- Khai báo các tính năng Event theo flag của UI.
local features = {}

local player = game:GetService("Players").LocalPlayer
local library = game:GetService("ReplicatedStorage").Library
local client = library.Client
local instancing = require(client.InstancingCmds)
local tycoon = require(client.PumpkinTycoonCmds)
local tycoonTypes = require(library.Types.PumpkinTycoon)
local buttons = require(library.Util.PumpkinTycoonButtons)
local customEggs = require(client.CustomEggsCmds)
local currency = require(client.CurrencyCmds)
local eggPrice = require(library.Balancing.CalcEggPricePlayer)
local network = require(client.Network)
local playerPet = require(client.PlayerPet)
local breakables = require(client.BreakableFrontend)
local petCmds = require(client.PetCmds)

-- Cấu hình mở map Pumpkin Tycoon.
local instanceId = "PumpkinTycoon"
local entryRetryDelay = 10
local scanInterval = 0.5
local pressTimeout = 2
local retryDelay = 5
local yellowRetryDelay = 15
local lastZone = tycoonTypes.PART1_ZONES
local hatchGoal = 15
local hatchInterval = 1
local hatchCounts = {}
local enabled = false
local pumpkinEnabled = false
local workerRunning = false
local generation = 0

-- Vào map sự kiện.

-- Kiểm tra trạng thái instance của người chơi.
local function isInEvent()
    return instancing.GetInstanceID() == instanceId
end

-- Dùng luồng dịch chuyển của game để vào Pumpkin Tycoon.
local function enterEvent()
    if not instancing.DoesMeetRequirement(instanceId) then return end
    local ok, err = pcall(instancing.Enter, instanceId)
    if not ok then warn("[Auto Open Map Event] Vào map: " .. tostring(err)) end
end

-- Nhận diện pad mở được.

-- Chỉ chọn mặt Press màu vàng, xanh lá hoặc xanh dương.
local function getPress(pad)
    if string.find(string.lower(pad.Name), "completionreward", 1, true) then return end
    local press = pad:FindFirstChild("Press")
    if not press or not press:IsA("BasePart") or press.Transparency >= 1 then return end
    local touch = press:FindFirstChild("Touch")
    if not touch or not touch:IsA("BasePart") or not touch.CanTouch then return end

    local hue, saturation, brightness = press.Color:ToHSV()
    if hue >= 0.11 and hue <= 0.73 and saturation >= 0.35 and brightness >= 0.25 then
        return press, touch, hue < 0.25
    end
end

-- Chọn pad hợp lệ gần nhân vật nhất.
local function findPad(folder, origin, retryAt)
    local now = os.clock()
    local bestPad, bestDistance
    for _, pad in ipairs(folder:GetChildren()) do
        if now < (retryAt[pad] or 0) then continue end
        local press = getPress(pad)
        if press then
            local distance = (press.Position - origin).Magnitude
            if not bestDistance or distance < bestDistance then
                bestPad, bestDistance = pad, distance
            end
        end
    end
    return bestPad
end

-- Kích hoạt pad bằng cách tiếp đất.

-- Đặt bàn chân cao hơn mặt pad 1,5 stud để tiếp đất tự nhiên.
local function pressPad(folder, pad, character, humanoid, root, runGeneration)
    if pad.Parent ~= folder then return end
    local press, touch, isYellow = getPress(pad)
    if not press then return end

    local original = character:GetPivot()
    local rootOffset = original:ToObjectSpace(root.CFrame)
    local surface = math.abs(press.CFrame.RightVector.Y) * press.Size.X / 2
        + math.abs(press.CFrame.UpVector.Y) * press.Size.Y / 2
        + math.abs(press.CFrame.LookVector.Y) * press.Size.Z / 2
    local leg = character:FindFirstChild("Left Leg")
    local footOffset = root.Size.Y / 2 + humanoid.HipHeight
    if humanoid.RigType == Enum.HumanoidRigType.R6 and leg then
        footOffset += leg.Size.Y
    end
    local position = Vector3.new(touch.Position.X, press.Position.Y + surface + footOffset + 1.5, touch.Position.Z)

    -- Chờ pad biến mất để xác nhận lần mở.
    local ok, err = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(position) * root.CFrame.Rotation * rootOffset:Inverse())
        local deadline = os.clock() + pressTimeout
        repeat
            task.wait(0.05)
        until pad.Parent ~= folder or press.Parent ~= pad or os.clock() >= deadline
            or generation ~= runGeneration or player.Character ~= character or humanoid.Health <= 0
            or not isInEvent()
    end)

    -- Trả nhân vật hiện tại về vị trí đã lưu.
    if isInEvent() and player.Character == character and humanoid.Health > 0 and root.Parent == character then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(original)
    end
    if not ok then warn("[Auto Open Map Event] " .. tostring(err)) end
    return isYellow and yellowRetryDelay or retryDelay, ok and pad.Parent ~= folder
end

-- Xác định zone cao nhất trên đảo của người chơi.
local function getFarmZone()
    local owned = tycoon.Feature("Buttons").State()
    local plot = tycoon.Feature("Island").Plot()
    local model = plot and plot:GetModel()
    if not owned or not model then return end
    local zone = buttons.FarmZone(owned, lastZone)
    local slab = zone and buttons.ZoneSlab(model, zone)
    return zone, slab, plot.ModelId, owned
end

-- Đưa nhân vật vào phần sát trứng nhất vẫn nằm trong zone farm.
local function standInZone(character, humanoid, root, slab, eggPosition)
    local point = slab.CFrame:PointToObjectSpace(eggPosition or slab.Position)
    local x = math.max(0, slab.Size.X / 2 - 1)
    local z = math.max(0, slab.Size.Z / 2 - 1)
    local floor = slab.CFrame:PointToWorldSpace(Vector3.new(
        math.clamp(point.X, -x, x), slab.Size.Y / 2, math.clamp(point.Z, -z, z)))
    local current = slab.CFrame:PointToObjectSpace(root.Position)
    if math.abs(current.X) <= x and math.abs(current.Z) <= z and math.abs(current.Y) < 12
        and (not eggPosition or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(floor.X, 0, floor.Z)).Magnitude < 3) then
        return
    end
    local height = root.Size.Y / 2 + humanoid.HipHeight + 0.5
    local leg = humanoid.RigType == Enum.HumanoidRigType.R6 and character:FindFirstChild("Left Leg")
    if leg then height += leg.Size.Y end
    local offset = root.CFrame:ToObjectSpace(character:GetPivot())
    root.AssemblyLinearVelocity = Vector3.zero
    character:PivotTo(CFrame.new(floor + Vector3.new(0, height, 0)) * root.CFrame.Rotation * offset)
end

-- Gửi pet đánh breaker thuộc đúng zone và đảo hiện tại.
local function farmZone(state, zone, plotId)
    local now = os.clock()
    if now < state.nextFarm then return end
    state.nextFarm = now + 1
    if now >= state.nextEquip then
        petCmds.EquipBest()
        state.nextEquip = now + 15
    end

    local things = workspace:FindFirstChild("__THINGS")
    local folder = things and things:FindFirstChild("Breakables")
    if not folder then return end
    local area = tycoonTypes.ZONES[zone].Section .. "_Zone_" .. tostring(plotId)
    local targets = {}
    for _, model in ipairs(folder:GetChildren()) do
        if model:GetAttribute("ParentID") == instanceId and model:GetAttribute("AreaID") == area then
            local uid = model:GetAttribute("BreakableUID")
            local data = uid and breakables.Get(uid)
            if data and data.health > 0 and not data.disableDamage then table.insert(targets, uid) end
        end
    end
    if #targets == 0 then return end
    local assigned, index = {}, 0
    for _, pet in pairs(playerPet.GetByPlayer(player) or {}) do
        if pet.euid then
            assigned[pet.euid] = targets[index % #targets + 1]
            index += 1
        end
    end
    if next(assigned) then network.Fire("Breakables_JoinPetBulk", assigned) end
    network.UnreliableFire("Breakables_PlayerDealDamage", targets[1])
end

-- Tìm trứng theo zone và tên cấu hình của game.
local function findZoneEgg(zone)
    local things = workspace:FindFirstChild("__THINGS")
    local folder = things and things:FindFirstChild("CustomEggs")
    if not folder then return end
    local eggName = tycoonTypes.ZONES[zone].Egg
    for _, model in ipairs(folder:GetChildren()) do
        if model:GetAttribute("ZoneNumber") == zone then
            local egg = customEggs.Get(model.Name)
            if egg and egg._id == eggName and egg:IsHatchable() then return egg end
        end
    end
end

-- Mở đúng một quả khi đủ xu và đếm lượt server xác nhận.
local function hatchOne(state, zone, egg)
    local now = os.clock()
    if now < state.nextHatch then return end
    state.nextHatch = now + hatchInterval
    local directory = egg:Directory()
    local price = eggPrice(directory, nil, not egg._allowChargedAndGolden)
    if not currency.CanAfford(directory.currency, price) then return end
    local success = network.Invoke("CustomEggs_Hatch", egg._uid, 1)
    if success == true then hatchCounts[zone] = (hatchCounts[zone] or 0) + 1 end
end

-- Tạm dừng mở pad trong lúc chuẩn bị đủ 15 trứng của zone.
local function updateEvent(state, character, humanoid, root)
    local zone, slab, plotId, owned = getFarmZone()
    if not owned or (zone and not slab) then return end
    if zone then
        local egg
        local waitingForEgg = false
        if zone < lastZone and (hatchCounts[zone] or 0) < hatchGoal then
            egg = findZoneEgg(zone)
            waitingForEgg = egg ~= nil or buttons.Owned(owned, tycoonTypes.ZONES[zone].Section .. "_Egg")
        end
        standInZone(character, humanoid, root, slab, egg and egg:GetPosition())
        farmZone(state, zone, plotId)
        if waitingForEgg then
            if egg then hatchOne(state, zone, egg) end
            return
        end
    end

    local folder = workspace:FindFirstChild("PumpkinTycoonPads")
    local pad = folder and findPad(folder, root.Position, state.retryAt)
    if pad then
        local delay, opened = pressPad(folder, pad, character, humanoid, root, generation)
        if delay and pad.Parent == folder then state.retryAt[pad] = os.clock() + delay end
        if opened then task.wait(0.5) end
    end
end

-- Auto Pumpkin / Chỉ chọn bí ngô còn sống trên đảo của mình.
local function findPumpkin(position)
    local plot = tycoon.Feature("Island").Plot()
    local target, distance
    for _, breaker in pairs(plot and plot.Breakables or {}) do
        if breaker.parentID ~= instanceId or not string.match(breaker.areaID or "", "^Pedestal_%d+$")
            or breaker.health <= 0 or breaker.disableDamage
            or not breaker.model or not breaker.model.Parent then continue end
        local nextDistance = (breaker.position - position).Magnitude
        if not distance or nextDistance < distance then
            target, distance = breaker, nextDistance
        end
    end
    return target
end

-- Lưu vị trí trước khi đứng cạnh bí ngô.
local function attackPumpkin(target, character, humanoid, root)
    local original = character:GetPivot()
    local assigned = {}
    local ok, err = pcall(function()
        petCmds.EquipBest()
        while pumpkinEnabled and isInEvent() and player.Character == character
            and humanoid.Health > 0 and root.Parent == character do
            local breaker = breakables.Get(target.uid)
            if not breaker or breaker.health <= 0 or not breaker.model or not breaker.model.Parent then break end
            if (root.Position - breaker.position).Magnitude > 8 then
                local direction = root.Position - breaker.position
                local flat = Vector3.new(direction.X, 0, direction.Z)
                local offset = flat.Magnitude > 0.01 and flat.Unit * 4 or Vector3.new(4, 0, 0)
                local height = root.Size.Y / 2 + humanoid.HipHeight + 0.5
                local leg = humanoid.RigType == Enum.HumanoidRigType.R6 and character:FindFirstChild("Left Leg")
                if leg then height += leg.Size.Y end
                local rootOffset = root.CFrame:ToObjectSpace(character:GetPivot())
                root.AssemblyLinearVelocity = Vector3.zero
                character:PivotTo(CFrame.new(breaker.position + offset + Vector3.new(0, height, 0))
                    * root.CFrame.Rotation * rootOffset)
            end
            local batch = {}
            for _, pet in pairs(playerPet.GetByPlayer(player) or {}) do
                if pet.euid then
                    batch[pet.euid] = target.uid
                    assigned[pet.euid] = true
                end
            end
            if next(batch) then network.Fire("Breakables_JoinPetBulk", batch) end
            network.UnreliableFire("Breakables_PlayerDealDamage", target.uid)
            task.wait(0.25)
        end
    end)

    -- Quay lại trước khi cho phép các vòng farm chạy tiếp.
    local restored, restoreError = pcall(function()
        if isInEvent() and player.Character == character and humanoid.Health > 0 and root.Parent == character then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            character:PivotTo(original)
        end
        for _, pet in pairs(playerPet.GetByPlayer(player) or {}) do
            if pet.euid and assigned[pet.euid] and pet:GetTargetType() == "Breakable"
                and pet:GetTargetValue() == target.uid then
                pet:ClearTarget()
            end
        end
    end)
    if not ok or not restored then warn("[Auto Pumpkin] " .. tostring(err or restoreError)) end
end

-- Điều phối chung để bí ngô và mở map không tranh vị trí.
local function startWorker()
    if workerRunning then return end
    workerRunning = true

    task.defer(function()
        local state = { retryAt = setmetatable({}, { __mode = "k" }), nextFarm = 0, nextEquip = 0, nextHatch = 0 }
        local nextEntryAt = 0
        while enabled or pumpkinEnabled do
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = humanoid and humanoid.RootPart
            if root and humanoid.Health > 0 then
                if isInEvent() then
                    local pumpkin = pumpkinEnabled and findPumpkin(root.Position)
                    if pumpkin then
                        attackPumpkin(pumpkin, character, humanoid, root)
                    elseif enabled then
                        local ok, err = pcall(updateEvent, state, character, humanoid, root)
                        if not ok then
                            warn("[Auto Open Map Event] " .. tostring(err))
                            task.wait(retryDelay)
                        end
                    end
                elseif enabled and os.clock() >= nextEntryAt then
                    enterEvent()
                    nextEntryAt = os.clock() + entryRetryDelay
                end
            end
            task.wait(scanInterval)
        end
        workerRunning = false
    end)
end

-- Quét riêng PumpkinTycoonPads để bỏ qua các nút thưởng trong PumpkinTycoonIslands.
features.EventAutoOpenMap = {
    duy = function(on)
        if enabled == on then return end
        enabled = on
        generation += 1
        if on then startWorker() end
    end,
}

-- Bật ưu tiên đánh bí ngô trong sự kiện.
features.EventAutoPumpkin = {
    duy = function(on)
        pumpkinEnabled = on
        if on then startWorker() end
    end,
}

-- Optimize Event / Chỉ thay đổi hiển thị của Pumpkin Tycoon.
do
    local job
    local original = setmetatable({}, { __mode = "k" })
    local invisible = NumberSequence.new(1)

    -- Lưu thuộc tính gốc trước khi đổi hiển thị.
    local function hideProperty(object, property, value)
        local previous = object[property]
        if previous == value then return end
        local record = original[object] or {}
        if not record[property] then
            record[property] = { previous = previous, hidden = value }
            original[object] = record
        end
        object[property] = value
    end

    -- Khôi phục hiển thị khi tắt toggle hoặc rời sự kiện.
    local function restore()
        for object, record in pairs(original) do
            if object.Parent then
                for property, saved in pairs(record) do
                    if object[property] == saved.hidden then object[property] = saved.previous end
                end
            end
        end
        table.clear(original)
    end

    -- Giữ viền farm, nút thưởng và các part mở khóa.
    local function hideVisual(object, scope, debrisPosition)
        local isPart = object:IsA("BasePart")
        local isSurface = object:IsA("Decal") or object:IsA("Texture")
        local isParticle = object:IsA("ParticleEmitter")
        local isEffect = isParticle or object:IsA("Beam") or object:IsA("Trail")
            or object:IsA("Light") or object:IsA("Smoke") or object:IsA("Fire")
            or object:IsA("Sparkles")
        if not (isPart or isSurface or isEffect) then return end

        local wall = false
        local debrisPart
        local parent = object
        while parent and parent ~= scope do
            local name = string.lower(parent.Name)
            if name == "buttons" or name == "press" or name == "touch"
                or name:find("completionreward", 1, true) or name:find("breakzoneline", 1, true)
                or name:find("pumpkinbreakline", 1, true) then
                return
            end
            if name:find("wall", 1, true) then wall = true end
            if debrisPosition and not debrisPart and parent:IsA("BasePart") then debrisPart = parent end
            parent = parent.Parent
        end

        if debrisPosition then
            if not isEffect or not debrisPart or (debrisPart.Position - debrisPosition).Magnitude > 220 then return end
        elseif wall and isPart and object.Transparency < 1 then
            hideProperty(object, "LocalTransparencyModifier", 1)
        elseif wall and isSurface then
            hideProperty(object, "Transparency", 1)
        end

        if isEffect then hideProperty(object, "Enabled", false) end
        if isParticle then hideProperty(object, "Transparency", invisible) end
    end

    -- Quét hiệu ứng mới tải trong các thư mục của sự kiện.
    local function optimizeEvent()
        local instance = instancing.Get()
        if not instance or instance.instanceID ~= instanceId then
            if next(original) then restore() end
            return
        end
        local function scan(root, debrisPosition)
            if not root then return end
            for _, object in ipairs(root:GetDescendants()) do
                hideVisual(object, root, debrisPosition)
            end
        end
        scan(instance.model)
        scan(workspace:FindFirstChild("PumpkinTycoonIslands"))
        scan(workspace:FindFirstChild("PumpkinTycoonPumpkins"))
        local character = player.Character
        if character then scan(workspace:FindFirstChild("__DEBRIS"), character:GetPivot().Position) end
    end

    -- Chạy một vòng tối ưu riêng cho toggle Event.
    features.EventOptimize = {
        duy = function(on)
            if job then
                if on then return end
                task.cancel(job)
                job = nil
            end
            if not on then
                restore()
                return
            end
            job = task.defer(function()
                while true do
                    optimizeEvent()
                    task.wait(1)
                end
            end)
        end,
    }
end

return features
