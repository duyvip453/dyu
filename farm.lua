local features = {}
local player = game:GetService("Players").LocalPlayer
local playerPet = require(game:GetService("ReplicatedStorage").Library.Client.PlayerPet)
local originalSpeedMultiplier = playerPet.CalculateSpeedMultiplier
local client = game:GetService("ReplicatedStorage").Library.Client
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
                task.wait(delay)
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

features.FarmTeleToBestArea = {
    duy = function(on)
        run("area", on, 3, function()
            local id, data = zones.GetMaxOwnedZone()
            local char = player.Character
            if not id or not data or not char then return end

            local root = workspace:FindFirstChild("Map")
            local area = root and root:FindFirstChild(data.ZoneNumber .. " | " .. id)
            local interact = area and area:FindFirstChild("INTERACT")
            local bounds = interact and interact:FindFirstChild("BREAK_ZONES")
            local part = bounds and bounds:FindFirstChild("BREAK_ZONE")
            if part and part:IsA("BasePart") then
                char:PivotTo(part.CFrame + Vector3.new(0, 4, 0))
            end
        end)
    end,
}

-- Mỗi lần bật, thử lần lượt các ID từ 1 đến 99.
local function updSlot(key, on, remote)
    local id = 0
    run(key, on, 0.5, function()
        id += 1
        pcall(net.Invoke, remote, id)
        return id < 99
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
