-- 1. Cấu hình khởi chạy
-- Launcher có thể truyền cấu hình riêng cho lần chạy này.
local environment = type(getgenv) == "function" and getgenv() or _G
local launchConfig = environment.RobloxHubConfig
environment.RobloxHubConfig = nil
if type(launchConfig) ~= "table" then launchConfig = nil end
local launchToggles = launchConfig and type(launchConfig.toggles) == "table" and launchConfig.toggles or {}
local startupActions = {}

-- 2. Tải các module tính năng
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
    local source = game:HttpGet(url)
    -- Một số client còn nhận bản webhook giữ chỗ rỗng từ cache.
    if filename == "webhook.lua" and not source:find("%S") then continue end
    local loadTab = assert(loadstring(source, "@" .. filename))
    local moduleFeatures = loadTab()
    assert(type(moduleFeatures) == "table", filename .. " phải trả về bảng features")
    for flag, feature in pairs(moduleFeatures) do
        features[flag] = feature
    end
end

-- 3. Tạo cửa sổ và các tab
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
local webhook = window:CreateTab({ name = "webhook" })
window:CreateTab({ name = "setting" })

-- 4. Hàm tạo toggle và tiện ích nền
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

local function startAntiAfk()
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
end

-- 5. Các tab cấu hình và tiện ích


local function buildOptimizeTab()
    optimize:CreateSection({ name = "Loot boxes" })
    createToggle(optimize, "disable loot boxes", "OptimizeDisableLootBoxes")
    optimize:CreateSection({ name = "Dropped objects" })
    createToggle(optimize, "disable objects", "OptimizeDisableObjects")
    optimize:CreateSection({ name = "Combined" })
    createToggle(optimize, "super optimize", "OptimizeSuper")
end

local function buildMailTab()
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
end

local function buildWebhookTab()
    -- Webhook chung: URL, loại thông báo và nút điều khiển.
    local petWebhook = features.WebhookEnabled
    webhook:CreateSection({ name = "webhook" })
    webhook:CreateInput({
        name = "Webhook URL",
        flag = "WebhookUrl",
        value = "",
        placeholder = "Dán link webhook",
        forgetState = true,
        callback = function(value)
            if petWebhook then petWebhook.setUrl(value) end
        end,
    })
    webhook:CreateDropdown({
        name = "Webhook Events",
        flag = "WebhookEvents",
        options = petWebhook and petWebhook.getOptions() or {},
        multiSelect = true,
        value = {},
        placeholder = "Chọn loại pet muốn báo",
        callback = function(values)
            if petWebhook then petWebhook.setSelection(values) end
        end,
    })
    createToggle(webhook, "Start Webhook", "WebhookEnabled")
    webhook:CreateButton({
        name = "Test Webhook",
        callback = function()
            if petWebhook then petWebhook.test() end
        end,
    })

    -- Webhook Rank dùng URL và cấu hình riêng.
    webhook:CreateSection({ name = "webhook rank" })
    webhook:CreateInput({
        name = "Rank Webhook URL",
        flag = "RankWebhookUrl",
        value = "",
        placeholder = "Dán link webhook rank",
        forgetState = true,
    })
    webhook:CreateInput({
        name = "Target Rank",
        flag = "RankWebhookTarget",
        numeric = true,
        value = "",
        placeholder = "Nhập rank để kích hoạt",
    })
    webhook:CreateToggle({
        name = "Start Rank Webhook",
        flag = "RankWebhookEnabled",
        value = false,
    })
    webhook:CreateButton({
        name = "Test Rank Webhook",
        callback = function() end,
    })
end

local function buildTradingTab()
    local boothSnipe = trading:CreateGroup({ direction = "column" })
    boothSnipe:CreateSection({ name = "Săn món ở gian hàng" })

    local boothSeller = trading:CreateGroup({ direction = "column" })
    boothSeller:CreateSection({ name = "Bán ở gian hàng" })
end

-- 6. Các tab tính năng thường xuyên mở rộng


local function buildFarmTab()
    -- Farm và di chuyển
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
end

local function buildRankTab()
    createToggle(rank, "auto claim rank reward", "RankAutoClaimReward")
    rank:CreateSection({ name = "auto quest" })
    createToggle(rank, "auto rank quest", "RankAutoQuest")
    createToggle(rank, "stats gui", "RankStatsGui")
end

local function buildAutomaticTab()
    -- Nhận quà online
    createToggle(automatic, "auto claim free gift", "AutoClaimFreeGift")

    -- Trang bị enchant
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

    -- Chọn loại và tự mở quà
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
end

-- 7. Khởi động UI và áp dụng cấu hình
-- Giữ thứ tự tạo control và chạy các toggle từ launcher như bản cũ.
buildFarmTab()
buildOptimizeTab()
buildMailTab()
buildTradingTab()
buildRankTab()
buildWebhookTab()
buildAutomaticTab()

for _, start in ipairs(startupActions) do start() end
startAntiAfk()
