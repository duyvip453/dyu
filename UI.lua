-- Dán URL Raw của file xử lý vào giữa hai dấu ngoặc kép.
local featuresUrl = ""
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

window:CreateTab({ name = "Thống kê" })
local farm = window:CreateTab({ name = "Cày" })
window:CreateTab({ name = "Sự kiện" })
local mail = window:CreateTab({ name = "Thư" })
local trading = window:CreateTab({ name = "Giao dịch" })
window:CreateTab({ name = "Cài đặt" })

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

createToggle(farm, "Tốc độ thú cưng vô hạn", "FarmInfinityPetSpeed")
createToggle(farm, "Cày nhanh", "FarmFastFarm")
createToggle(farm, "Tự động nhấn", "FarmAutoTap")
createToggle(farm, "Dịch chuyển đến khu tốt nhất", "FarmTeleToBestArea")
createToggle(farm, "Dịch chuyển đến thế giới tốt nhất", "FarmTeleToBestWorld")
createToggle(farm, "Tự mua khu tiếp theo", "FarmAutoBuyNextArea")

createToggle(mail, "Tự nhận thư", "MailAutoClaim")
mail:CreateInput({
    name = "Tên người dùng",
    flag = "MailUsername",
    value = "",
    placeholder = "Nhập tên người dùng",
})

-- Các lựa chọn mẫu để thử lưu cấu hình. Thay bằng dữ liệu trong game khi có.
mail:CreateDropdown({
    name = "Loại vật phẩm",
    flag = "MailItemClass",
    options = { "Loại mẫu A", "Loại mẫu B" },
    multiSelect = true,
    value = {},
})
mail:CreateDropdown({
    name = "Tên vật phẩm",
    flag = "MailItemName",
    options = { "Vật phẩm mẫu A", "Vật phẩm mẫu B" },
    multiSelect = true,
    value = {},
})
createToggle(mail, "Tự gửi quà", "MailAutoGift")

local boothSnipe = trading:CreateGroup({ direction = "column" })
boothSnipe:CreateSection({ name = "Săn món ở gian hàng" })

local boothSeller = trading:CreateGroup({ direction = "column" })
boothSeller:CreateSection({ name = "Bán ở gian hàng" })

