-- 1. Cấu hình khởi chạy
-- Launcher có thể truyền cấu hình riêng cho lần chạy này.
local environment = type(getgenv) == "function" and getgenv() or _G
local launchConfig = environment.RobloxHubConfig
environment.RobloxHubConfig = nil
if type(launchConfig) ~= "table" then launchConfig = nil end
local launchToggles = launchConfig and type(launchConfig.toggles) == "table" and launchConfig.toggles or {}
local startupActions = {}

-- Danh sách Add Enchant không phải control có flag, nên lưu riêng theo tài khoản.
local enchantConfigPath = "RobloxHubEnchantList_" .. game:GetService("Players").LocalPlayer.UserId .. ".json"
local httpService = game:GetService("HttpService")

-- Đọc danh sách enchant đã lưu của tài khoản.
local function loadEnchantList()
    if launchConfig then
        return type(launchConfig.enchants) == "table" and launchConfig.enchants or {}
    end
    if type(readfile) ~= "function" then return {} end
    if type(isfile) == "function" and not isfile(enchantConfigPath) then return {} end
    local ok, list = pcall(function()
        return httpService:JSONDecode(readfile(enchantConfigPath))
    end)
    return ok and type(list) == "table" and list or {}
end

-- Lưu thứ tự Add Enchant vào JSON cục bộ.
local function saveEnchantList(list)
    if launchConfig then return end
    local ok = pcall(function()
        writefile(enchantConfigPath, httpService:JSONEncode(list))
    end)
    if not ok then warn("[Enchant UI] Không lưu được danh sách enchant vào config") end
end

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

-- Gộp tính năng từ các module theo tên flag.
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

-- Khai báo các tab theo thứ tự xuất hiện trên menu.
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
-- Nối toggle Rayfield với tính năng cùng flag.
local function createToggle(tab, name, flag)
    local initial = launchToggles[flag] == true
    local applied = false
    -- Áp dụng trạng thái bật tắt từ giao diện hoặc launcher.
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

-- Đọc kho ở luồng riêng để giữ quyền tạo UI của Rayfield.
local function runInventoryAction(action, ...)
    local result
    task.spawn(function(...)
        result = table.pack(pcall(action, ...))
    end, ...)
    while not result do task.wait() end
    return table.unpack(result, 1, result.n)
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


-- Tạo các toggle tối ưu hiển thị.
local function buildOptimizeTab()
    optimize:CreateSection({ name = "Loot boxes" })
    createToggle(optimize, "disable loot boxes", "OptimizeDisableLootBoxes")
    optimize:CreateSection({ name = "Dropped objects" })
    createToggle(optimize, "disable objects", "OptimizeDisableObjects")
    optimize:CreateSection({ name = "Combined" })
    createToggle(optimize, "super optimize", "OptimizeSuper")

    -- Cấu hình giới hạn FPS của client.
    local fpsLimit = features.OptimizeFpsLimit
    local initialFps = "30"
    if fpsLimit and launchConfig and launchConfig.fpsTarget ~= nil then
        if fpsLimit.setTarget(launchConfig.fpsTarget) then
            initialFps = tostring(tonumber(launchConfig.fpsTarget))
        end
    end
    optimize:CreateSection({ name = "FPS" })
    optimize:CreateInput({
        name = "Target FPS",
        flag = "OptimizeFpsTarget",
        numeric = true,
        value = initialFps,
        placeholder = "Nhập FPS mong muốn",
        callback = function(value)
            if fpsLimit then fpsLimit.setTarget(value) end
        end,
    })
    createToggle(optimize, "Limit FPS", "OptimizeFpsLimit")
end

-- Tạo giao diện nhận thư và cấu hình gửi quà.
local function buildMailTab()
    createToggle(mail, "Tự nhận thư", "MailAutoClaim")
    local gift = features.MailAutoGift
    if not gift then return end
    mail:CreateInput({
        name = "User Name",
        flag = "MailUserName",
        value = "",
        placeholder = "...",
        callback = gift.setRecipient,
    })

    local selectedClass, itemDropdown
    -- Đổi danh sách Item ID theo Class đang chọn.
    local function selectClass(class)
        local changed = selectedClass ~= nil and selectedClass ~= class
        selectedClass = class
        if itemDropdown then
            if changed then itemDropdown:Set("", true) end
            itemDropdown:Refresh(gift.getNames(class))
        end
    end
    mail:CreateDropdown({
        name = "Item Class",
        flag = "MailGiftClass",
        options = gift.getClasses(),
        multiSelect = false,
        callback = selectClass,
    })
    itemDropdown = mail:CreateDropdown({
        name = "Item ID",
        flag = "MailGiftItem",
        options = {},
        multiSelect = false,
    })
    if selectedClass then selectClass(selectedClass) end

    local amount = mail:CreateInput({
        name = "Amount",
        flag = "MailGiftAmount",
        value = "",
        placeholder = "Ví dụ: 100k",
    })
    local keep = mail:CreateInput({
        name = "Keep",
        flag = "MailGiftKeep",
        value = "",
        placeholder = "Ví dụ: 10k hoặc 0",
    })
    local giftText = mail:CreateText({ text = "Danh sách gift: (trống)" })
    -- Hiện mỗi quy tắc gửi quà trên một dòng.
    local function updateGiftText()
        local lines = {}
        for _, rule in ipairs(gift.getList()) do
            lines[#lines + 1] = ("%s, %s, %s, %s"):format(rule.class, rule.name, rule.amount, rule.keep)
        end
        giftText:Set(#lines > 0 and table.concat(lines, "\n") or "Danh sách gift: (trống)")
    end
    mail:CreateButton({
        name = "Add Item",
        callback = function()
            local added, reason = gift.add(selectedClass, itemDropdown.value[1], amount.value, keep.value)
            if added then updateGiftText() else warn("[Auto Gift] " .. reason) end
        end,
    })
    mail:CreateButton({
        name = "Clear 1 Item",
        callback = function()
            gift.removeLast()
            updateGiftText()
        end,
    })
    createToggle(mail, "auto gift", "MailAutoGift")
end

-- Tạo giao diện cấu hình webhook.
local function buildWebhookTab()
    -- Webhook chung: URL, loại thông báo và nút điều khiển.
    local petWebhook = features.WebhookEnabled
    webhook:CreateSection({ name = "webhook" })
    webhook:CreateInput({
        name = "Webhook URL",
        flag = "WebhookUrl",
        value = "",
        placeholder = "Dán link webhook",
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
    local rankWebhook = features.RankWebhookEnabled
    local rankPreset = launchConfig and type(launchConfig.rankWebhook) == "table" and launchConfig.rankWebhook or {}
    local initialRankUrl = type(rankPreset.url) == "string" and rankPreset.url or ""
    local initialRankTarget = rankPreset.target ~= nil and tostring(rankPreset.target) or ""
    webhook:CreateSection({ name = "webhook rank" })
    webhook:CreateInput({
        name = "Rank Webhook URL",
        flag = "RankWebhookUrl",
        value = initialRankUrl,
        placeholder = "Dán link webhook rank",
        callback = function(value)
            if rankWebhook then rankWebhook.setUrl(value) end
        end,
    })
    webhook:CreateInput({
        name = "Target Rank",
        flag = "RankWebhookTarget",
        numeric = true,
        value = initialRankTarget,
        placeholder = "Nhập rank để kích hoạt",
        callback = function(value)
            if rankWebhook then rankWebhook.setTarget(value) end
        end,
    })
    if rankWebhook and launchConfig then
        rankWebhook.setUrl(initialRankUrl)
        rankWebhook.setTarget(initialRankTarget)
    end
    createToggle(webhook, "Start Rank Webhook", "RankWebhookEnabled")
    webhook:CreateButton({
        name = "Test Rank Webhook",
        callback = function()
            if rankWebhook then rankWebhook.test() end
        end,
    })
end

-- Tạo các nhóm giao diện giao dịch.
local function buildTradingTab()
    local boothSnipe = trading:CreateGroup({ direction = "column" })
    boothSnipe:CreateSection({ name = "Săn món ở gian hàng" })

    local boothSeller = trading:CreateGroup({ direction = "column" })
    boothSeller:CreateSection({ name = "Bán ở gian hàng" })
end

-- 6. Các tab tính năng thường xuyên mở rộng


-- Tạo giao diện cho các tính năng farm.
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

-- Tạo giao diện cho các tính năng rank.
local function buildRankTab()
    createToggle(rank, "auto claim rank reward", "RankAutoClaimReward")
    rank:CreateSection({ name = "auto quest" })
    createToggle(rank, "auto rank quest", "RankAutoQuest")
    createToggle(rank, "stats gui", "RankStatsGui")
end

-- Tạo giao diện cho các tính năng tự động.
local function buildAutomaticTab()
    -- Nhận quà online
    createToggle(automatic, "auto claim free gift", "AutoClaimFreeGift")

    -- Trang bị enchant
    automatic:CreateSection({ name = "Enchant" })
    local enchantFeature = features.AutoEquipEnchant
    local selectedEnchant

    local hasEnchantNames, enchantNames = runInventoryAction(enchantFeature.getNames)
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
    -- Hiện sách theo đúng thứ tự trong danh sách Add Enchant.
    local function updateEnchantText()
        local list = enchantFeature.getList()
        enchantText:Set("enchant : " .. (#list > 0 and table.concat(list, ", ") or "(trống)"))
    end

    -- Khôi phục danh sách trước khi Rayfield có thể bật lại Auto Equip từ config.
    local savedEnchants = loadEnchantList()
    if #savedEnchants > 0 then
        local ok, err = runInventoryAction(function()
            for _, name in ipairs(savedEnchants) do
                if type(name) == "string" then enchantFeature.add(name) end
            end
        end)
        if not ok then warn("[Enchant UI] " .. tostring(err)) end
        updateEnchantText()
    end
    automatic:CreateButton({
        name = "add enchant",
        callback = function()
            local name = selectedEnchant or enchantDropdown.value[1]
            if name then
                local ok, err = runInventoryAction(enchantFeature.add, name)
                if not ok then warn("[Enchant UI] " .. tostring(err)) end
                if ok and err then saveEnchantList(enchantFeature.getList()) end
            end
            updateEnchantText()
        end,
    })
    automatic:CreateButton({
        name = "clear enchant",
        callback = function()
            enchantFeature.clear()
            saveEnchantList(enchantFeature.getList())
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
    if launchConfig then
        local giftPreset = launchConfig.gifts
        for _, id in ipairs(giftOptions) do
            if type(id) == "string" and id:find("%S")
                and (giftPreset == "all" or (type(giftPreset) == "table" and table.find(giftPreset, id))) then
                table.insert(initialGifts, id)
            end
        end
    end
    -- Chuyển các loại quà đã chọn sang module Automatic.
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

-- Áp dụng các toggle được launcher đặt sẵn.
for _, start in ipairs(startupActions) do start() end
startAntiAfk()
