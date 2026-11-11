local features = {}
local library = game:GetService("ReplicatedStorage").Library
local http = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local save = require(library.Client.Save)
local pets = require(library.Directory).Pets
local petItem = require(library.Items.PetItem)
local exist = require(library.Client.GlobalExistCmds)
local rap = require(library.Client.RAPCmds)

local eventOptions = { "Huge", "Titanic", "Gargantuan" }
local selected = {}
local webhookUrl = ""
local watchJob
local thumbnails = {}

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

local function formatNumber(value)
    if type(value) ~= "number" then return "Chưa có dữ liệu" end
    local digits = string.format("%.0f", value)
    return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

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

local function buildDropPayload(record, isTest)
    local item = petItem(record.id):SetType(record.petType):SetShiny(record.shiny)
    local embed = {
        title = (isTest and "TEST · " or "") .. record.category:upper() .. " DROP",
        description = ("**Name Pet: %s**\n**Exist: %s**\n**Rap: %s**\n**Account:**\n||%s||"):format(
            item:GetName(), formatNumber(exist.Get(item)), formatNumber(rap.Get(item)), player.Name),
        color = 16769288,
    }
    local image = thumbnailUrl(item:GetIcon())
    if image then embed.thumbnail = { url = image } end
    return { embeds = { embed }, allowed_mentions = { parse = {} } }
end

local function postDrop(record, isTest)
    local url = webhookUrl
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
            Body = http:JSONEncode(buildDropPayload(record, isTest)),
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

local function watchDrops()
    local previous
    while true do
        local current = readPets()
        if current then
            if previous then
                for key, record in pairs(current) do
                    local oldAmount = previous[key] and previous[key].amount or 0
                    if record.amount > oldAmount and selected[record.category] then
                        local ok, reason = postDrop(record, false)
                        if not ok then warn("[Webhook] " .. reason) end
                    end
                end
            end
            previous = current
        end
        task.wait(1)
    end
end

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
            local ok, reason = postDrop({ id = "Huge Hollow Bat", petType = 0, shiny = false, category = "Huge" }, true)
            if ok then print("[Webhook] Discord đã nhận tin test")
            else warn("[Webhook] " .. reason) end
        end)
    end,
}

return features
