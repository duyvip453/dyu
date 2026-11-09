local features = {}

-- Phần dùng chung
local lib = game:GetService("ReplicatedStorage").Library
local net = require(lib.Client.Network)
local save = require(lib.Client.Save)
local dir = require(lib.Directory)
local ranks = require(lib.Util.RanksUtil)
local job

-- Rank / Tự nhận thưởng rank
features.RankAutoClaimReward = {
    duy = function(on)
        if job then task.cancel(job); job = nil end
        if not on then return end

        job = task.defer(function()
            while true do
                local data = save.Get()
                local id = data and ranks.RankIDFromNumber(data.Rank)
                local rank = id and dir.Ranks[id]
                if rank then
                    local stars = 0
                    for i, reward in ipairs(rank.Rewards) do
                        stars += reward.StarsRequired
                        if stars > data.RankStars then break end
                        if data.RedeemedRankRewards[tostring(i)] == nil then
                            net.Fire("Ranks_ClaimReward", i)
                            break
                        end
                    end
                end
                task.wait(2)
            end
        end)
    end,
}

-- Auto rank quest / Khu vực và cấu hình
local player = game:GetService("Players").LocalPlayer
local zones = require(lib.Client.ZoneCmds)
local eggs = require(lib.Client.EggCmds)
local questCmds = require(lib.Client.QuestCmds)
local balancing = require(lib.Balancing)
local targetArea = 279
local waitPosition = Vector3.new(-15044.994140625, 16.23734474182129, 2202.712646484375)
local hollowPosition = Vector3.new(-15044.8525390625, 16.23734474182129, 2145.985595703125)
local veilrootPosition = Vector3.new(-14887.7763671875, 17.05313491821289, 2226.709228515625)
local questTiers = { "Easy", "Medium", "Hard", "Extreme" }
local questActions = {}
local questJob
local travelFeatures = { "FarmTeleToBestArea", "FarmTeleToBestWorld" }

-- Thứ tự trong bảng là priority: 1 được ưu tiên cao nhất.
local questPriority = {
    { kind = "usePotion", verbs = { "use" }, keywords = { "potion", "potions" } },
    { kind = "collectPotion", verbs = { "collect" }, keywords = { "potion", "potions" }, interval = 1 },
    { kind = "collectEnchant", verbs = { "collect" }, keywords = { "enchant", "enchants" }, interval = 1 },
    { kind = "upgradeEnchant", verbs = { "upgrade", "update" }, keywords = { "enchant", "enchants" } },
    { kind = "upgradePotion", verbs = { "upgrade", "update" }, keywords = { "potion", "potions" } },
    { kind = "legendary", verbs = { "hatch" }, keywords = { "legendary", "legendarys" } },
    { kind = "eggs", verbs = { "hatch" } }, -- Xét sau Legendary.
    { kind = "makeGolden", verbs = { "make" }, keywords = { "golden" } },
    { kind = "makeRainbow", verbs = { "make" }, keywords = { "rainbow" } },
    { kind = "comet", verbs = { "break" }, keywords = { "comet", "comets" } },
    { kind = "coinJar", verbs = { "break" }, keywords = { "coin jar", "coin jars" } },
    { kind = "pinata", verbs = { "break" }, keywords = { "pinata", "pinatas" } },
    { kind = "luckyBlock", verbs = { "break", "trigger" }, keywords = { "lucky block", "lucky blocks" } },
}

local function hasKeyword(text, keywords)
    for _, keyword in ipairs(keywords) do
        if text:find("%f[%a]" .. keyword .. "%f[^%a]") then return true end
    end
    return false
end

local function classifyQuest(title)
    local normalized = title:lower():gsub("ñ", "n"):gsub("Ñ", "n"):gsub("%s+", " ")
    for priority, rule in ipairs(questPriority) do
        if hasKeyword(normalized, rule.verbs)
            and (not rule.keywords or hasKeyword(normalized, rule.keywords)) then
            return rule.kind, priority, rule.interval
        end
    end
end

local function getBestArea()
    if not save.Get() then return nil end
    local best = 0
    for id, zone in pairs(dir.Zones) do
        if zone.ZoneNumber > best and zones.Owns(id) then
            best = zone.ZoneNumber
        end
    end
    return best
end

local function requestTravel(allFeatures, enabled)
    for _, flag in ipairs(travelFeatures) do
        allFeatures[flag].request("rankQuest", enabled)
    end
end

local function goToPosition(position)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    if (character:GetPivot().Position - position).Magnitude > 4 then
        character:PivotTo(CFrame.new(position))
        return false
    end
    return true
end

-- Goals là nguồn của bốn ô HUD. UID giữ nguyên khi tiêu đề đổi theo tiến độ.
local function readGoals()
    local data = save.Get()
    local goals = {}
    for _, goal in pairs(data and data.Goals or {}) do
        if questTiers[goal.Stars] and goal.UID
            and type(goal.Progress) == "number" and type(goal.Amount) == "number" and goal.Amount > 0 then
            goals[goal.Stars] = goal
        end
    end
    return goals
end

local function selectQuest()
    local goals = readGoals()
    local selected
    for stars in ipairs(questTiers) do
        local goal = goals[stars]
        if not goal then return nil, true end
        if goal.Progress < goal.Amount then
            local title = questCmds.MakeTitle(goal)
            local kind, priority, interval = classifyQuest(title or "")
            if priority and (not selected or priority < selected.priority) then
                selected = {
                    stars = stars, uid = goal.UID, title = title,
                    kind = kind, priority = priority, interval = interval,
                }
            end
        end
    end
    return selected, selected == nil
end

-- Vòng điều phối. Chỉ một quest được chạy tại một thời điểm.
local function runQuest(quest, action)
    local repeatCollect = quest.kind == "collectPotion" or quest.kind == "collectEnchant"
    local nextAttempt = 0
    local sentAtProgress
    local lastMessage

    while true do
        local goal = readGoals()[quest.stars]
        if goal then
            if goal.UID ~= quest.uid or goal.Progress >= goal.Amount then return end

            if os.clock() >= nextAttempt and goal.Progress ~= sentAtProgress then
                quest.current, quest.target, quest.potionTier = goal.Progress, goal.Amount, goal.PotionTier
                local ok, waitForProgress, message = pcall(action, quest)
                nextAttempt = os.clock() + (quest.interval or 3)
                if not ok then
                    message = tostring(waitForProgress)
                    waitForProgress = true
                end
                if message and message ~= lastMessage then
                    warn("[Rank quest] " .. quest.title .. ": " .. tostring(message))
                end
                lastMessage = message
                if waitForProgress and not repeatCollect then
                    sentAtProgress = quest.current
                end
            end
        end
        task.wait(0.25)
    end
end

features.RankAutoQuest = {
    duy = function(on, allFeatures)
        if questJob then
            task.cancel(questJob)
            questJob = nil
        end
        requestTravel(allFeatures, false)
        if not on then return end

        questJob = task.defer(function()
            local bestArea = getBestArea()
            while bestArea ~= targetArea do
                if bestArea then requestTravel(allFeatures, true) end
                task.wait(10)
                bestArea = getBestArea()
            end
            requestTravel(allFeatures, false)

            while true do
                local quest, shouldWaitAtArea = selectQuest()
                local action = quest and questActions[quest.kind]
                if action then
                    runQuest(quest, action)
                    task.wait(4)
                else
                    if shouldWaitAtArea then goToPosition(waitPosition) end
                    task.wait(1)
                end
            end
        end)
    end,
}

-- Inventory / Mỗi lần thao tác lấy lại UID, cấp và số lượng hiện tại.
local function inventory(category)
    local data = save.Get()
    return data and (data[category] or (data.Inventory and data.Inventory[category])) or {}
end

local function chooseStack(category, getCapacity)
    local selected, selectedCapacity, selectedTier
    for uid, item in pairs(inventory(category)) do
        if not item._lk then
            local capacity = getCapacity(item)
            local tier = item.tn or 0
            if capacity > 0 and (not selected or tier < selectedTier
                or (tier == selectedTier and capacity > selectedCapacity)) then
                selected, selectedCapacity, selectedTier = uid, capacity, tier
            end
        end
    end
    return selected, selectedCapacity
end

local romanTiers = { i = 1, ii = 2, iii = 3, iv = 4, v = 5, vi = 6,
    vii = 7, viii = 8, ix = 9, x = 10, xi = 11 }

local function readRequiredTier(title, prefix)
    local token = title:lower():match(prefix .. "tier%s+([%w]+)")
    if token then return tonumber(token) or romanTiers[token] end
end

-- Dùng potion và nâng cấp. Tham số số lượng của máy là số vật phẩm đầu ra.
function questActions.usePotion(quest)
    local tier = quest.potionTier or readRequiredTier(quest.title, "")
    if quest.title:lower():find("tier", 1, true) and not tier then
        return false, "Không đọc được cấp potion yêu cầu"
    end
    local uid, available = chooseStack("Potion", function(item)
        return (not tier or item.tn == tier) and (item._am or 1) or 0
    end)
    if not uid then return false, "Chưa có potion phù hợp" end
    net.Fire("Potions: Consume", uid, math.min(available, quest.target - quest.current))
    return true
end

local function invokeMachine(remote, uid, count)
    local success, reason = net.Invoke(remote, uid, count)
    if not success then return true, reason or "Máy từ chối yêu cầu" end
    return true
end

local function upgrade(quest, category, directory, requiredPerOutput, remote, collect)
    local fromTier, toTier
    if not collect then
        fromTier = readRequiredTier(quest.title, "from%s+")
        toTier = readRequiredTier(quest.title, "to%s+")
        -- "Upgrade 2 Tier III potions" cũng mô tả cấp đầu ra.
        if not fromTier and not toTier then toTier = readRequiredTier(quest.title, "") end
        if quest.title:lower():find("tier", 1, true) and not (fromTier or toTier) then
            return false, "Không đọc được cấp nâng cấp yêu cầu"
        end
    end
    local uid, capacity = chooseStack(category, function(item)
        local entry = directory[item.id]
        local tier = item.tn
        if not entry or not tier or not entry.MaxTier or tier >= entry.MaxTier
            or (fromTier and tier ~= fromTier) or (toTier and tier + 1 ~= toTier) then
            return 0
        end
        local required = requiredPerOutput(tier)
        return required and required > 0 and math.floor((item._am or 1) / required) or 0
    end)
    if not uid then return false, "Chưa đủ vật phẩm để nâng cấp" end
    local count = collect and 1 or math.min(capacity, quest.target - quest.current)
    return invokeMachine(remote, uid, count)
end

function questActions.upgradeEnchant(quest)
    return upgrade(quest, "Enchant", dir.Enchants, balancing.CalcEnchantsPerTierRequired,
        "UpgradeEnchantsMachine_Activate")
end

function questActions.upgradePotion(quest)
    return upgrade(quest, "Potion", dir.Potions, balancing.CalcPotionsPerTierRequired,
        "UpgradePotionsMachine_Activate")
end

function questActions.collectPotion(quest)
    return upgrade(quest, "Potion", dir.Potions, balancing.CalcPotionsPerTierRequired,
        "UpgradePotionsMachine_Activate", true)
end

function questActions.collectEnchant(quest)
    return upgrade(quest, "Enchant", dir.Enchants, balancing.CalcEnchantsPerTierRequired,
        "UpgradeEnchantsMachine_Activate", true)
end

-- Mở trứng ở đúng điểm. Legendary có thể cần nhiều lượt trước khi tăng tiến độ.
local function hatch(eggId, position, waitForQuestProgress)
    if not goToPosition(position) then return false end
    if not save.Get() then return false end
    local count = eggs.GetMaxHatch(dir.Eggs[eggId])
    if not count or count < 1 then return false, "Không đọc được số slot mở trứng" end
    local success, reason = eggs.RequestPurchase(eggId, count)
    if not success then return true, reason or "Game từ chối mở trứng" end
    return waitForQuestProgress
end

function questActions.eggs()
    return hatch("Hollow Egg", hollowPosition, true)
end

function questActions.legendary()
    return hatch("Veilroot Egg", veilrootPosition, false)
end

-- Đổi Wisp Griffin theo tỷ lệ 10:1. Mỗi lần gọi máy dùng UID của một stack.
local function petStock(inputType)
    local uid, biggest, total = nil, 0, 0
    for stackUid, item in pairs(inventory("Pet")) do
        if item.id == "Wisp Griffin" and (item.pt or 0) == inputType and not item._lk and not item.sh then
            local capacity = math.floor((item._am or 1) / 10)
            total += capacity
            if capacity > biggest then uid, biggest = stackUid, capacity end
        end
    end
    return uid, biggest, total
end

function questActions.makeGolden(quest)
    local remaining = quest.target - quest.current
    local uid, batch, capacity = petStock(0)
    if capacity < remaining then return hatch("Hollow Egg", hollowPosition, false) end
    return invokeMachine("GoldMachine_Activate", uid, math.min(batch, remaining))
end

function questActions.makeRainbow(quest)
    local remaining = quest.target - quest.current
    local goldenUid, goldenBatch, rainbowCapacity = petStock(1)
    if rainbowCapacity >= remaining then
        quest.goldenToMake = nil
        return invokeMachine("RainbowMachine_Activate", goldenUid, math.min(goldenBatch, remaining))
    end

    local normalUid, normalBatch, goldenCapacity = petStock(0)
    local goldenNeeded = quest.goldenToMake or remaining * 10
    if goldenCapacity < goldenNeeded then return hatch("Hollow Egg", hollowPosition, false) end

    local count = math.min(normalBatch, goldenNeeded)
    local success, reason = net.Invoke("GoldMachine_Activate", normalUid, count)
    if not success then return true, reason or "Máy từ chối đổi Golden" end
    quest.goldenToMake = math.max(1, goldenNeeded - count)
    return false
end

-- Triệu hồi một vật thể mỗi lần, rồi chờ quest ghi nhận trước khi dùng thêm.
local function summon(position, itemId, remote)
    if not goToPosition(position) then return false end
    local uid = chooseStack("Misc", function(item)
        return item.id == itemId and (item._am or 1) or 0
    end)
    if not uid then return false, "Không có " .. itemId .. " trong inventory" end
    local success, reason = net.Invoke(remote, uid)
    if not success then return true, reason or "Game từ chối triệu hồi " .. itemId end
    return true
end

function questActions.comet()
    return summon(waitPosition, "Comet", "Comet_Spawn")
end

function questActions.coinJar()
    return summon(waitPosition, "Basic Coin Jar", "CoinJar_Spawn")
end

function questActions.pinata()
    return summon(waitPosition, "Mini Pinata", "MiniPinata_Consume")
end

function questActions.luckyBlock()
    return summon(waitPosition, "Mini Lucky Block", "MiniLuckyBlock_Consume")
end

return features
