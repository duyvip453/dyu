-- Dán URL Raw của file xử lý vào giữa hai dấu ngoặc kép.
local featuresUrl = "https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/farm.lua"
assert(featuresUrl ~= "", "Bạn cần dán URL Raw của file xử lý vào featuresUrl.")
local loadFeatures = assert(loadstring(game:HttpGet(featuresUrl)))
local features = loadFeatures()
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
window:CreateTab({ name = "Event" })
local mail = window:CreateTab({ name = "mail" })
local trading = window:CreateTab({ name = "trading" })
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
createToggle(farm, "tele to best area", "FarmTeleToBestArea")
createToggle(farm, "tele to best world", "FarmTeleToBestWorld")
createToggle(farm, "auto buy next area", "FarmAutoBuyNextArea")
createToggle(farm, "Tự nhặt orb", "FarmAutoCollectOrb")

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

