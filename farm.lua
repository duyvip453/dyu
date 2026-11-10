local features = {}
local player = game:GetService("Players").LocalPlayer
local playerPet = require(game:GetService("ReplicatedStorage").Library.Client.PlayerPet)
local originalSpeedMultiplier = playerPet.CalculateSpeedMultiplier
local client = game:GetService("ReplicatedStorage").Library.Client
local tele = require(client.TeleportMapCmds)
local worlds = require(client.Parent.Util.WorldsUtil)
local mapUtil = require(client.Parent.Util.MapUtil)
local dir = require(client.Parent.Directory)
local net = require(client.Network)
local map = require(client.MapCmds)
local zones = require(client.ZoneCmds)
local breaks = require(client.BreakableCmds)
local orb = require(client.OrbCmds.Orb)
local orbDist = orb.CollectDistance
local jobs = {}

local function run(key, on, delay, step)
    if jobs[key] then
        task.cancel(jobs[key])
        jobs[key] = nil
    end
    if on then
        jobs[key] = task.defer(function()
            while true do
                local ok, more = pcall(step)
                if ok and more == false then break end
                task.wait(type(more) == "number" and more or delay)
            end
            jobs[key] = nil
        end)
    end
end

local function boostedSpeedMultiplier(pet)
    local multiplier = originalSpeedMultiplier(pet)
    return pet.owner == player and multiplier * 100 or multiplier
end
-- Cày / Tốc độ thú cưng vô hạn
features.FarmInfinityPetSpeed = {
    duy = function(enabled)
        playerPet.CalculateSpeedMultiplier = enabled and boostedSpeedMultiplier or originalSpeedMultiplier
    end,
}


features.FarmAutoTap = {
    duy = function(on)
        run("tap", on, 0.08, function()
            local zone = map.GetCurrentZone()
            if not zone then return end

            local ids = {}
            for _, class in ipairs({ "Normal", "Chest" }) do
                for _, obj in pairs(breaks.AllByZoneAndClass(zone, class)) do
                    local id = obj:GetAttribute("BreakableUID")
                    if id then ids[#ids + 1] = id end
                end
            end
            if #ids > 0 then
                net.UnreliableFire("Breakables_PlayerDealDamage", ids[math.random(#ids)])
            end
        end)
    end,
}


features.FarmAutoBuyNextArea = {
    duy = function(on)
        run("buy", on, 5, function()
            -- Game lấy khu cao nhất đã mở rồi cộng 1.
            local _, nextZone = zones.GetNextZone()
            if nextZone then
                net.Invoke("Zones_RequestPurchase", nextZone._id)
            end
        end)
    end,
}

features.FarmAutoCollectOrb = {
    duy = function(on)
        -- Dùng luồng nhặt có sẵn của game với bán kính lớn hơn.
        orb.CollectDistance = on and 150 or orbDist
    end,
}

-- Mỗi tính năng có thể yêu cầu dịch chuyển mà không tắt toggle của người dùng.
local function teleportFeature(setEnabled)
    local owners = {}
    local function request(owner, on)
        local wasEnabled = next(owners) ~= nil
        owners[owner] = on and true or nil
        local enabled = next(owners) ~= nil
        if enabled ~= wasEnabled then setEnabled(enabled) end
    end
    return {
        duy = function(on) request("farm", on) end,
        request = request,
    }
end

features.FarmTeleToBestArea = teleportFeature(function(on)
    run("area", on, 3, function()
        local char = player.Character
        local world = worlds.GetWorldNumber()
        if not char or not world then return end

        local best, num = nil, 0
        for id, zone in pairs(dir.Zones) do
            if zone.WorldNumber == world and zone.ZoneNumber > num and zones.Owns(id) then
                best, num = id, zone.ZoneNumber
            end
        end

        local area
        if best then
            area = mapUtil.GetZone(best)
        else
            area = mapUtil.GetSpawnZone()
        end
        local interact = area and area:FindFirstChild("INTERACT")
        if not interact then return 1 end

        local bounds = interact:FindFirstChild("BREAK_ZONES")
        if not bounds then return end

        local skip = world == 3 and num == 200
            and Vector3.new(92.21322631835938, 0.3999999761581421, 72.61753845214844)
        local skipPosition = world == 1 and num == 1
            and Vector3.new(214.122131, 24.4171562, -587.119263)
        local main, maxSize = nil, 0
        for _, part in ipairs(bounds:GetChildren()) do
            if part.Name == "BREAK_ZONE" and part:IsA("BasePart") then
                if skipPosition and (part.Position - skipPosition).Magnitude < 0.01 then continue end
                if num == 210 then
                    main = part
                    break
                end
                local s = part.Size
                if skip and (s - skip).Magnitude < 0.001 then continue end
                local size = math.max(s.X * s.Y, s.X * s.Z, s.Y * s.Z)
                if size > maxSize then
                    main, maxSize = part, size
                end
            end
        end
        if main then char:PivotTo(main.CFrame + Vector3.new(0, 4, 0)) end
    end)
end)

-- Dịch chuyển tới world cao nhất đã mở.
features.FarmTeleToBestWorld = teleportFeature(function(on)
    run("world", on, 5, function()
        local cur = worlds.GetWorldNumber()
        if not cur then return end

        for id = 4, cur + 1, -1 do
            if tele.CanTeleportToWorldRaw(id) then
                net.Invoke("World" .. id .. "Teleport")
                break
            end
        end
    end)
end)

-- Mỗi lần bật, thử lần lượt các ID từ 1 đến 99.
local function updSlot(key, on, remote)
    local id = 0
    run(key, on, 0.5, function()
        id = id % 99 + 1
        pcall(net.Invoke, remote, id)
    end)
end

features.FarmAutoPetSlot = {
    duy = function(on)
        updSlot("petSlot", on, "EquipSlotsMachine_RequestPurchase")
    end,
}

features.FarmAutoEggSlot = {
    duy = function(on)
        updSlot("eggSlot", on, "EggHatchSlotsMachine_RequestPurchase")
    end,
}

return features
