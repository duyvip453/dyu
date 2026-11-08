local features = {}
local player = game:GetService("Players").LocalPlayer
local playerPet = require(game:GetService("ReplicatedStorage").Library.Client.PlayerPet)
local originalSpeedMultiplier = playerPet.CalculateSpeedMultiplier
local client = game:GetService("ReplicatedStorage").Library.Client
local net = require(client.Network)
local map = require(client.MapCmds)
local zones = require(client.ZoneCmds)
local breaks = require(client.BreakableCmds)
local jobs = {}

local function run(key, on, delay, step)
    if jobs[key] then
        task.cancel(jobs[key])
        jobs[key] = nil
    end
    if on then
        jobs[key] = task.defer(function()
            while true do
                pcall(step)
                task.wait(delay)
            end
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
        run("tap", on, 0.2, function()
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

return features
