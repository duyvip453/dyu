local features = {}
local library = game:GetService("ReplicatedStorage").Library
local http = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local save = require(library.Client.Save)
local pets = require(library.Directory).Pets
local petItem = require(library.Items.PetItem)
local exist = require(library.Client.GlobalExistCmds)
local rap = require(library.Client.RAPCmds)

-- Khai báo các loại pet có thể chọn để nhận thông báo.
local eventOptions = { "Huge", "Titanic", "Gargantuan" }
local selected = {}
local webhookUrl = ""
local watchJob
-- Giữ URL ảnh đã tra theo ID asset Roblox.
local thumbnails = {}

-- Phân loại pet theo cờ Huge, Titanic hoặc Gargantuan.
local function petCategory(definition)
    if definition.gargantuan then return "Gargantuan" end
    if definition.titanic then return "Titanic" end
    if definition.huge then return "Huge" end
end

-- So sánh theo ID và biến thể để việc gộp stack hoặc đổi UID không tạo báo giả.
local function readPets()
    local data = save.Get()
    local inventory = data and ((data.Inventory and data.Inventory.Pet) or data.Pet)
    if type(inventory) ~= "table" then return nil end
    local snapshot = {}
    for _, entry in pairs(inventory) do
        local definition = rawget(pets, entry.id)
        local category = definition and petCategory(definition)
        if category then
            local petType = entry.pt or 0
            local shiny = entry.sh == true
            local key = entry.id .. ":" .. petType .. ":" .. tostring(shiny)
            local record = snapshot[key]
            if not record then
                record = { id = entry.id, petType = petType, shiny = shiny, category = category, amount = 0 }
                snapshot[key] = record
            end
            record.amount += entry._am or 1
        end
    end
    return snapshot
end

-- Định dạng số Exist và RAP có dấu phân cách hàng nghìn.
local function formatNumber(value)
    if type(value) ~= "number" then return "Chưa có dữ liệu" end
    local digits = string.format("%.0f", value)
    return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Đổi ID asset của pet sang URL ảnh dùng trong Discord.
local function thumbnailUrl(icon)
    local id = type(icon) == "string" and icon:match("^rbxassetid://(%d+)$")
    if not id then return nil end
    if thumbnails[id] then return thumbnails[id] end
    local ok, result = pcall(function()
        local source = game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. id
            .. "&size=150x150&format=Png&isCircular=false")
        local row = http:JSONDecode(source).data[1]
        return row and row.state == "Completed" and row.imageUrl or nil
    end)
    if ok and type(result) == "string" and result:match("^https://") then
        thumbnails[id] = result
        return result
    end
end

-- Dựng embed thông báo pet với dữ liệu theo biến thể.
local function buildDropPayload(record)
    local item = petItem(record.id):SetType(record.petType):SetShiny(record.shiny)
    local embed = {
        title = record.category:upper() .. " DROP",
        description = ("**Name Pet: %s**\n**Exist: %s**\n**Rap: %s**\n**Account:**\n||%s||"):format(
            item:GetName(), formatNumber(exist.Get(item)), formatNumber(rap.Get(item)), player.Name),
        color = 16769288,
    }
    local image = thumbnailUrl(item:GetIcon())
    if image then embed.thumbnail = { url = image } end
    return { embeds = { embed }, allowed_mentions = { parse = {} } }
end

-- Gửi payload JSON tới URL Discord và kiểm tra mã HTTP.
local function postWebhook(url, buildPayload, value)
    if not url:match("^https://discord%.com/api/webhooks/%d+/[%w_-]+$") then
        return false, "Hãy nhập URL webhook Discord hợp lệ"
    end
    local send = request or http_request
    if type(send) ~= "function" then return false, "Executor không hỗ trợ HTTP request" end

    local ok, result = pcall(function()
        return send({
            Url = url .. "?wait=true",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = http:JSONEncode(buildPayload(value)),
        })
    end)
    -- Không đưa URL/token vào Output khi request lỗi.
    if not ok or type(result) ~= "table" then return false, "Không gửi được tới Discord" end
    local status = tonumber(result.StatusCode)
    if not status or status < 200 or status >= 300 then
        return false, "Discord HTTP " .. tostring(status or "không rõ")
    end
    return true
end

-- Gửi thông báo pet tới URL webhook chung.
local function postDrop(record)
    return postWebhook(webhookUrl, buildDropPayload, record)
end

-- Báo khi số lượng pet thuộc loại đã chọn tăng.
local function watchDrops()
    local previous
    while true do
        local current = readPets()
        if current then
            if previous then
                for key, record in pairs(current) do
                    local oldAmount = previous[key] and previous[key].amount or 0
                    if record.amount > oldAmount and selected[record.category] then
                        local ok, reason = postDrop(record)
                        if not ok then warn("[Webhook] " .. reason) end
                    end
                end
            end
            previous = current
        end
        task.wait(1)
    end
end

-- Xuất chức năng cấu hình và bật webhook báo pet.
features.WebhookEnabled = {
    getOptions = function() return table.clone(eventOptions) end,
    setUrl = function(value) webhookUrl = value:match("^%s*(.-)%s*$") end,
    setSelection = function(values)
        selected = {}
        for _, value in ipairs(values or {}) do selected[value] = true end
    end,
    duy = function(enabled)
        if enabled and not watchJob then
            watchJob = task.defer(watchDrops)
        elseif not enabled and watchJob then
            task.cancel(watchJob)
            watchJob = nil
        end
    end,
    test = function()
        task.defer(function()
            if next(selected) == nil then
                warn("[Webhook] Chọn Huge, Titanic hoặc Gargantuan trước khi test")
                return
            end
            local snapshot = readPets()
            if not snapshot then
                warn("[Webhook] Chưa đọc được kho pet")
                return
            end
            -- Kho không có thứ tự cố định. Chọn ID/biến thể đầu tiên theo thứ tự tên.
            local firstKey, firstPet
            for key, record in pairs(snapshot) do
                if selected[record.category] and record.amount > 0 and (not firstKey or key < firstKey) then
                    firstKey, firstPet = key, record
                end
            end
            if not firstPet then
                warn("[Webhook] Kho chưa có pet thuộc các loại đã chọn")
                return
            end
            local ok, reason = postDrop(firstPet)
            if ok then print("[Webhook] Discord đã nhận tin test")
            else warn("[Webhook] " .. reason) end
        end)
    end,
}

-- Webhook Rank dùng URL, mốc và vòng theo dõi riêng.
local rankWebhookUrl = ""
local targetRank
local rankJob
-- Ghi nhớ các cặp URL và mốc rank đã báo trong phiên.
local notifiedRanks = {}

-- Dựng embed báo mốc rank theo mẫu đã chọn.
local function buildRankPayload(rank)
    return {
        embeds = {{
            title = "Rank quest completed",
            description = ("||%s|| **has reached rank %s**\n\nbecause your mom is fat!😂"):format(player.Name, rank),
            color = 65464,
        }},
        allowed_mentions = { parse = {} },
    }
end

-- Theo dõi rank hiện tại để gửi khi đạt mốc.
local function watchRank()
    while true do
        local url, target = rankWebhookUrl, targetRank
        local data = save.Get()
        local currentRank = data and tonumber(data.Rank)
        local delay = 1
        if url ~= "" and target and currentRank and currentRank >= target then
            local key = url .. ":" .. target
            if not notifiedRanks[key] then
                local ok, reason = postWebhook(url, buildRankPayload, currentRank)
                if ok then
                    notifiedRanks[key] = true
                else
                    warn("[Webhook Rank] " .. reason)
                    delay = 10
                end
            end
        end
        task.wait(delay)
    end
end

-- Xuất chức năng cấu hình và bật Webhook Rank.
features.RankWebhookEnabled = {
    setUrl = function(value) rankWebhookUrl = value:match("^%s*(.-)%s*$") end,
    -- Nhận rank mục tiêu là số nguyên dương.
    setTarget = function(value)
        local number = tonumber(value)
        targetRank = number and number >= 1 and number < math.huge and number % 1 == 0 and number or nil
    end,
    duy = function(enabled)
        if enabled and not rankJob then
            rankJob = task.defer(watchRank)
        elseif not enabled and rankJob then
            task.cancel(rankJob)
            rankJob = nil
        end
    end,
    test = function()
        local url, target = rankWebhookUrl, targetRank
        if not target then
            warn("[Webhook Rank] Nhập Target Rank là số nguyên dương để test")
            return
        end
        task.defer(function()
            local ok, reason = postWebhook(url, buildRankPayload, target)
            if ok then print("[Webhook Rank] Discord đã nhận tin test")
            else warn("[Webhook Rank] " .. reason) end
        end)
    end,
}

return features
