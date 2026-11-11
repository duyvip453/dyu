local features = {}

-- Phần dùng chung
local lib = game:GetService("ReplicatedStorage").Library
local net = require(lib.Client.Network)
local save = require(lib.Client.Save)
local dir = require(lib.Directory)
local job
local giftOrder = {
    "Gift Bag","Large Gift Bag","Mini Chest","Enchant Bundle","Large Enchant Bundle","Potion Bundle","Large Potion Bundle","Toy Bundle",
    "Flag Bundle",
    "Fruit Bundle",
    "Rainbow Mini Chest",
    "",
    "",
    
}

-- Điền ID tên enchant tại đây, mỗi dòng một ID đúng như trong game.
local enchantOrder = {
    "Tap Power","Criticals","Treasure Hunter","Strong Pets","Lucky Eggs","Coins","Diamonds","Magnet","Walkspeed","Chest Breaker","Large Taps","Tap Teamwork","Swift Taps","Explosive","Shiny Supercharge","Shiny Hunter","Angelic",
    "Demonic","Corruption","Fruity","Boss Chest Mimic",
    "Chest Mimic",
    "Lucky Block",
    "Fireworks",
    "Party Time",
    "Magic Orb",
    "Fortune",
    "Huge Hunter",
    "Super Lightning",
    "Happy Pets",
    "Massive Comet",
    "Boss Lucky Block",
    "Super Magnet",
    "Super Treasure Hunter",
    "Lucky Block Breaker",
    
}

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
    getOptions = function() return table.clone(giftOrder) end,
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

-- Automatic / Enchant: thứ tự Add là thứ tự equip, tên trùng là nhiều quyển.
local enchantItems = require(lib.Items.EnchantItem)
local enchantCmds = require(lib.Client.EnchantCmds)
local enchantWanted = {}
local enchantRevision = 0
local enchantJob

local function equippedAt(data, slot)
    local equipped = data.EquippedEnchants or {}
    return equipped[tostring(slot)] or equipped[slot]
end

local function enchantSlots(data)
    local slots = {}
    for slot = 1, enchantCmds.GetMaxEquippedEnchants() do slots[#slots + 1] = slot end
    for slot = 7, 6 + (data.MaxPaidEnchantsEquipped or 0) do slots[#slots + 1] = slot end
    return slots
end

local function enchantCandidates()
    local items = {}
    for uid, item in pairs(enchantItems:All()) do
        items[#items + 1] = {
            uid = uid, name = item:GetId(), tier = item:GetTier(), amount = item:GetAmount(),
        }
    end
    table.sort(items, function(a, b)
        if a.tier == b.tier then return a.uid < b.uid end
        return a.tier > b.tier
    end)
    return items
end

-- Chọn từ cấp cao xuống thấp, trừ số bản sao đã dành cho các mục trước.
-- Hết sách hoặc mọi cấp đều bị từ chối: bỏ qua mục đó, tiếp tục mục kế.
local function enchantPlan(items, slots, rejected)
    local plan, used = {}, {}
    for index, name in ipairs(enchantWanted) do
        if #plan >= #slots then break end
        for _, item in ipairs(items) do
            if item.name == name and not rejected[index .. ":" .. item.uid]
                and (used[item.uid] or 0) < item.amount then
                plan[#plan + 1] = {uid = item.uid, index = index}
                used[item.uid] = (used[item.uid] or 0) + 1
                break
            end
        end
    end
    return plan
end

features.AutoEquipEnchant = {
    getNames = function() return table.clone(enchantOrder) end,
    getList = function() return table.clone(enchantWanted) end,
    add = function(name)
        if not table.find(enchantOrder, name) then return false end
        enchantWanted[#enchantWanted + 1] = name
        enchantRevision += 1
        return true
    end,
    clear = function()
        table.clear(enchantWanted)
        enchantRevision += 1
    end,
    duy = function(on)
        if enchantJob then task.cancel(enchantJob); enchantJob = nil end
        if not on then return end
        local rejected, pending = {}, nil
        local phase = "check"
        local revision = enchantRevision
        local inventorySignature
        local lastError

        local function step()
            local data = save.Get()
            if not data then return end
            -- Mỗi request chờ data xác nhận tối đa 3s trước khi thao tác tiếp.
            if pending then
                local actual = equippedAt(data, pending.slot)
                local done = pending.clear and actual == nil or not pending.clear and actual == pending.uid
                if not done and os.clock() < pending.deadline then return end
                if not done and not pending.clear and pending.revision == enchantRevision then
                    rejected[pending.index .. ":" .. pending.uid] = true
                end
                pending = nil
            end
            if revision ~= enchantRevision then
                revision = enchantRevision
                table.clear(rejected)
                phase = "check"
            end
            -- Clear button reset danh sách yêu cầu; danh sách rỗng thì dừng equip.
            if #enchantWanted == 0 then return end
            local slots = enchantSlots(data)
            local items = enchantCandidates()
            local signature = {tostring(data.Rank), table.concat(slots, ",")}
            for _, item in ipairs(items) do
                signature[#signature + 1] = item.uid .. ":" .. item.tier .. ":" .. item.amount
            end
            signature = table.concat(signature, "|")
            if inventorySignature and inventorySignature ~= signature then
                table.clear(rejected)
                phase = "check"
            end
            inventorySignature = signature
            local plan = enchantPlan(items, slots, rejected)

            local function send(clear, slot, entry)
                if clear then net.Fire("Enchants_ClearSlot", slot)
                else net.Fire("Enchants_Equip", entry.uid) end
                pending = {
                    clear = clear, slot = slot, uid = entry and entry.uid,
                    index = entry and entry.index, revision = revision, deadline = os.clock() + 3,
                }
            end

            if phase == "check" then
                if #plan == 0 then return end -- Chưa có sách phù hợp để thay bộ hiện tại.
                local matches = true
                for index, slot in ipairs(slots) do
                    if equippedAt(data, slot) ~= (plan[index] and plan[index].uid) then
                        matches = false
                        break
                    end
                end
                if matches then return end -- Đúng bộ: không gửi remote.
                phase = "clear"
            end
            if phase == "clear" then
                -- Sai bộ: clear từng ô đang đeo, xác nhận hết rồi mới equip lại.
                for index = #slots, 1, -1 do
                    if equippedAt(data, slots[index]) then
                        send(true, slots[index])
                        return
                    end
                end
                phase = "equip"
            end
            if phase == "equip" then
                for index, entry in ipairs(plan) do
                    local actual = equippedAt(data, slots[index])
                    if actual ~= entry.uid then
                        if actual then phase = "clear"; return end
                        send(false, slots[index], entry)
                        return
                    end
                end
                phase = "check"
            end
        end

        enchantJob = task.defer(function()
            while true do
                local ok, err = pcall(step)
                if not ok and tostring(err) ~= lastError then
                    lastError = tostring(err)
                    warn("[Auto Enchant] " .. lastError)
                elseif ok then lastError = nil end
                task.wait(0.5)
            end
        end)
    end,
}

return features
