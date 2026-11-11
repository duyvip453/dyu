-- Launcher có thể truyền cấu hình riêng cho lần chạy này.
local environment = type(getgenv) == "function" and getgenv() or _G
local launchConfig = environment.RobloxHubConfig
environment.RobloxHubConfig = nil
if type(launchConfig) ~= "table" then launchConfig = nil end
local launchToggles = launchConfig and type(launchConfig.toggles) == "table" and launchConfig.toggles or {}
local startupActions = {}

-- Thêm một URL Raw vào danh sách cho mỗi file xử lý mới.
local urls = {
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/farm.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/rank.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/automatic.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/optimize.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/mail.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/main/webhook.lua",
}

local features = {}
for _, url in ipairs(urls) do
    local filename = url:match("[^/]+$")
    local loadTab = assert(loadstring(game:HttpGet(url), "@" .. filename))
    for flag, feature in pairs(loadTab()) do
        features[flag] = feature
    end
end
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "Menu Roblox",
    sidebarLayout = true,
    configuration = {
        autoSave = launchConfig == nil,
        autoLoad = launchConfig == nil,
        fileName = "RobloxHubUI",
    },
})

window:CreateTab({ name = "Stats" })
local farm = window:CreateTab({ name = "farm" })
local optimize = window:CreateTab({ name = "optimize" })
window:CreateTab({ name = "Event" })
local mail = window:CreateTab({ name = "mail" })
local trading = window:CreateTab({ name = "trading" })
local rank = window:CreateTab({ name = "rank" })
local automatic = window:CreateTab({ name = "automatic" })
window:CreateTab({ name = "webhook" })
window:CreateTab({ name = "setting" })

local function createToggle(tab, name, flag)
    local initial = launchToggles[flag] == true
    local applied = false
    local function apply(enabled)
        local feature = features[flag]
        if feature and (not launchConfig or applied ~= enabled) then
            applied = enabled
            feature.duy(enabled, features)
        end
    end

    tab:CreateToggle({
        name = name,
        flag = flag,
        value = initial,
        callback = apply,
    })
    if initial then table.insert(startupActions, function() apply(true) end) end
end

createToggle(farm, "inf pet speed", "FarmInfinityPetSpeed")
createToggle(farm, "fast farm", "FarmFastFarm")
createToggle(farm, "auto tap", "FarmAutoTap")
createToggle(farm, "Tự nhặt orb", "FarmAutoCollectOrb")
createToggle(farm, "tele to best area", "FarmTeleToBestArea")
createToggle(farm, "tele to best world", "FarmTeleToBestWorld")
createToggle(farm, "auto buy next area", "FarmAutoBuyNextArea")

farm:CreateSection({ name = "Nâng cấp slot" })
createToggle(farm, "auto upd pet slot", "FarmAutoPetSlot")
createToggle(farm, "auto upd egg slot", "FarmAutoEggSlot")

optimize:CreateSection({ name = "Loot boxes" })
createToggle(optimize, "disable loot boxes", "OptimizeDisableLootBoxes")
optimize:CreateSection({ name = "Dropped objects" })
createToggle(optimize, "disable objects", "OptimizeDisableObjects")
optimize:CreateSection({ name = "Combined" })
createToggle(optimize, "super optimize", "OptimizeSuper")

createToggle(mail, "Tự nhận thư", "MailAutoClaim")
mail:CreateInput({
    name = "User Name",
    flag = "MailUserName",
    value = "",
    placeholder = "...",
})

-- Các lựa chọn mẫu để thử lưu cấu hình. Thay bằng dữ liệu trong game khi có.
mail:CreateDropdown({
    name = "Item Class",
    flag = "ItemClass",
    options = { "A", "B" },
    multiSelect = true,
    value = {},
})
mail:CreateDropdown({
    name = "Item Name",
    flag = "ItemName",
    options = { "A", "B" },
    multiSelect = true,
    value = {},
})
createToggle(mail, "auto gift", "MailAutoGift")

local boothSnipe = trading:CreateGroup({ direction = "column" })
boothSnipe:CreateSection({ name = "Săn món ở gian hàng" })

local boothSeller = trading:CreateGroup({ direction = "column" })
boothSeller:CreateSection({ name = "Bán ở gian hàng" })

createToggle(rank, "auto claim rank reward", "RankAutoClaimReward")
rank:CreateSection({ name = "auto quest" })
createToggle(rank, "auto rank quest", "RankAutoQuest")
createToggle(rank, "stats gui", "RankStatsGui")
if features.RankWebhook then features.RankWebhook.mount(rank) end

createToggle(automatic, "auto claim free gift", "AutoClaimFreeGift")

automatic:CreateSection({ name = "Enchant" })
local enchantFeature = features.AutoEquipEnchant
local selectedEnchant

-- Việc đọc inventory qua EnchantItem có thể làm mất quyền tạo UI trên luồng hiện tại.
local function runEnchantInventoryAction(action, ...)
    local result
    task.spawn(function(...)
        result = table.pack(pcall(action, ...))
    end, ...)
    while not result do task.wait() end
    return table.unpack(result, 1, result.n)
end

local hasEnchantNames, enchantNames = runEnchantInventoryAction(enchantFeature.getNames)
if not hasEnchantNames then
    warn("[Enchant UI] " .. tostring(enchantNames))
    enchantNames = {}
end
local enchantDropdown = automatic:CreateDropdown({
    name = "Enchant",
    flag = "AutoEnchantSelection",
    multiSelect = false,
    options = enchantNames,
    callback = function(value) selectedEnchant = value end,
})
local enchantText = automatic:CreateText({ text = "enchant : (trống)" })
local function updateEnchantText()
    local list = enchantFeature.getList()
    enchantText:Set("enchant : " .. (#list > 0 and table.concat(list, ", ") or "(trống)"))
end
automatic:CreateButton({
    name = "add enchant",
    callback = function()
        local name = selectedEnchant or enchantDropdown.value[1]
        if name then
            local ok, err = runEnchantInventoryAction(enchantFeature.add, name)
            if not ok then warn("[Enchant UI] " .. tostring(err)) end
        end
        updateEnchantText()
    end,
})
automatic:CreateButton({
    name = "clear enchant",
    callback = function()
        enchantFeature.clear()
        updateEnchantText()
    end,
})
createToggle(automatic, "auto equip enchant", "AutoEquipEnchant")

-- Dọn vòng làm mới inventory còn chạy từ bản UI cũ.
if environment.RobloxHubEnchantUiJob then
    pcall(task.cancel, environment.RobloxHubEnchantUiJob)
    environment.RobloxHubEnchantUiJob = nil
end

local giftFeature = features.AutoOpenGifts
local giftOptions = giftFeature and giftFeature.getOptions and giftFeature.getOptions()
    or { "Gift Bag", "Large Gift Bag", "Mini Chest" }
local initialGifts = {}
if launchConfig and type(launchConfig.gifts) == "table" then
    for _, id in ipairs(giftOptions) do
        if table.find(launchConfig.gifts, id) then table.insert(initialGifts, id) end
    end
end
local function setGiftSelection(values)
    local feature = features.AutoOpenGifts
    if feature then feature.setSelection(values) end
end

automatic:CreateDropdown({
    name = "Gifts",
    flag = "AutoOpenGiftTypes",
    options = giftOptions,
    multiSelect = true,
    value = initialGifts,
    callback = setGiftSelection,
})
if launchConfig then setGiftSelection(initialGifts) end
createToggle(automatic, "auto open gifts", "AutoOpenGifts")

for _, start in ipairs(startupActions) do start() end

-- Tiện ích nền / Anti-AFK: nhảy mỗi 12 phút, không tạo phần tử giao diện.
-- Chạy lại UI thì hủy vòng cũ để không tích lũy nhiều vòng nhảy.
if environment.RobloxHubAntiAfkJob then
    pcall(task.cancel, environment.RobloxHubAntiAfkJob)
end
environment.RobloxHubAntiAfkJob = task.spawn(function()
    local player = game:GetService("Players").LocalPlayer
    while true do
        task.wait(12 * 60)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Jump = true
        end
    end
end)
