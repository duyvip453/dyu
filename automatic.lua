local features = {}

-- Phần dùng chung
local lib = game:GetService("ReplicatedStorage").Library
local net = require(lib.Client.Network)
local save = require(lib.Client.Save)
local dir = require(lib.Directory)
local job
local giftOrder = { "Gift Bag", "Large Gift Bag", "Mini Chest" }
local selectedGifts = {}
local openingGifts = false
local giftJob

-- Automatic / Tự nhận quà online
features.AutoClaimFreeGift = {
    duy = function(on)
        if job then task.cancel(job); job = nil end
        if not on then return end

        job = task.defer(function()
            while true do
                local data = save.Get()
                if data then
                    for _, gift in pairs(dir.FreeGifts) do
                        if gift.WaitTime <= data.FreeGiftsTime
                            and not table.find(data.FreeGiftsRedeemed, gift.Id) then
                            pcall(net.Invoke, "Redeem Free Gift", gift.Id)
                            break
                        end
                    end
                end
                task.wait(3)
            end
        end)
    end,
}

-- Automatic / Mở hết từng loại quà đã chọn.
local function readGiftAmounts()
    local data = save.Get()
    if not data then return nil end
    local misc = data.Misc or (data.Inventory and data.Inventory.Misc)
    if type(misc) ~= "table" then return nil end

    local amounts = {}
    for _, item in pairs(misc) do
        if selectedGifts[item.id] then
            amounts[item.id] = (amounts[item.id] or 0) + (item._am or 1)
        end
    end
    return amounts
end

local function openSelectedGifts()
    local current
    local retryDelay = 0.25
    while openingGifts do
        local amounts = readGiftAmounts()
        if amounts then
            if not current or not amounts[current] or amounts[current] <= 0 then
                current = nil
                for _, id in ipairs(giftOrder) do
                    if (amounts[id] or 0) > 0 then
                        current = id
                        retryDelay = 0.25
                        break
                    end
                end
            end

            if current then
                local before = amounts[current]
                local ok, success, reason = pcall(net.Invoke, "GiftBag_Open", current, 1)
                if ok and success then
                    retryDelay = 0.25
                    -- Chờ inventory xác nhận để lần kế tiếp đọc đúng số quà còn lại.
                    while openingGifts and selectedGifts[current] do
                        local live = readGiftAmounts()
                        if live and (live[current] or 0) < before then break end
                        task.wait()
                    end
                else
                    local message = tostring((ok and reason or (not ok and success)) or ""):lower()
                    local seconds = tonumber(message:match("([%d.]+)%s*second")) or 0
                    retryDelay = math.max(seconds, math.min(retryDelay * 2, 30))
                    task.wait(retryDelay)
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
    giftJob = nil
end

features.AutoOpenGifts = {
    setSelection = function(values)
        selectedGifts = {}
        for _, id in ipairs(values or {}) do
            selectedGifts[id] = true
        end
    end,
    duy = function(on)
        openingGifts = on
        if on and not giftJob then
            giftJob = task.defer(openSelectedGifts)
        end
    end,
}

return features
