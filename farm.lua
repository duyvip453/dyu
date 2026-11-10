local features = {}
local player = game:GetService("Players").LocalPlayer
local playerPet = require(game:GetService("ReplicatedStorage").Library.Client.PlayerPet)
local originalSpeedMultiplier = playerPet.CalculateSpeedMultiplier
local client = game:GetService("ReplicatedStorage").Library.Client
local tele = require(client.TeleportMapCmds)
local worlds = require(client.Parent.Util.WorldsUtil)

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

-- Tọa độ cố định được quản lý riêng trong id area.lua.
local areaData
local areaDataWarning = false
local function getAreaData()
    if areaData then return areaData end
    local ok, result = pcall(function()
        local source = game:HttpGet("https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/id%20area.lua")
        return assert(loadstring(source))()
    end)
    if ok and type(result) == "table" and type(result.Worlds) == "table" then
        areaData = result
        return areaData
    end
    if not areaDataWarning then
        areaDataWarning = true
        warn("[Auto Tele] Không tải được id area.lua; chờ tải lại.")
    end
end

features.FarmTeleToBestArea = teleportFeature(function(on)
    run("area", on, 3, function()
        local char = player.Character
        local world = worlds.GetWorldNumber()
        if not char or not world then return end
        local data = getAreaData()
        local entry = data and data.Worlds[world]
        if not entry or type(entry.MaxArea) ~= "number" then return end

        local best = 0
        for id, zone in pairs(dir.Zones) do
            if zone.ZoneNumber > best and zones.Owns(id) then
                best = zone.ZoneNumber
            end
        end
        if best == 0 then return end
        local target = math.min(best, entry.MaxArea)
        local position = entry.Areas[target]
        -- Chưa điền tọa độ: chờ, không tự dò map hoặc teleport của game.
        if typeof(position) == "CFrame" then
            char:PivotTo(position)
        end
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
