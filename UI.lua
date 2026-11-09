-- Thêm một URL Raw vào danh sách cho mỗi file xử lý mới.
local urls = {
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/farm.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/rank.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/automatic.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/optimize.lua",
    "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/mail.lua",
}

local features = {}
for _, url in ipairs(urls) do
    local loadTab = assert(loadstring(game:HttpGet(url)))
    for flag, feature in pairs(loadTab()) do
        features[flag] = feature
    end
end
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "Menu Roblox",
    sidebarLayout = true,
    configuration = {
        autoSave = true,
        autoLoad = true,
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
window:CreateTab({ name = "setting" })

local function createToggle(tab, name, flag)
    tab:CreateToggle({
        name = name,
        flag = flag,
        value = false,
        callback = function(enabled)
            local feature = features[flag]
            if feature then
                feature.duy(enabled)
            end
        end,
    })
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

createToggle(automatic, "auto claim free gift", "AutoClaimFreeGift")
