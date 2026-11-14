-- Dùng mốc của UI hoặc thời điểm tải rank khi chạy riêng.
local startedAt = ...
local scriptStartedAt = type(startedAt) == "number" and startedAt or os.clock()
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
-- Ánh xạ số sao của quest sang độ khó.
local questTiers = { "Easy", "Medium", "Hard", "Extreme" }
local questActions = {}
local questJob
local activeQuest
-- Khai báo tính năng Farm dùng để đi tới world và area mục tiêu.
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

-- So khớp từ khóa nguyên từ trong tiêu đề quest.
local function hasKeyword(text, keywords)
    for _, keyword in ipairs(keywords) do
        if text:find("%f[%a]" .. keyword .. "%f[^%a]") then return true end
    end
    return false
end

-- Nhận diện loại quest theo bảng ưu tiên.
local function classifyQuest(title)
    local normalized = title:lower():gsub("ñ", "n"):gsub("Ñ", "n"):gsub("%s+", " ")
    for priority, rule in ipairs(questPriority) do
        if hasKeyword(normalized, rule.verbs)
            and (not rule.keywords or hasKeyword(normalized, rule.keywords)) then
            return rule.kind, priority, rule.interval
        end
    end
end

-- Tìm area có số lớn nhất đã được mở.
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

-- Bật hoặc nhả yêu cầu teleport của Auto Rank Quest.
local function requestTravel(allFeatures, enabled)
    for _, flag in ipairs(travelFeatures) do
        allFeatures[flag].request("rankQuest", enabled)
    end
end

-- Đưa nhân vật tới điểm cần đứng để làm quest.
local function goToPosition(position)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    if (character:GetPivot().Position - position).Magnitude > 4 then
        character:PivotTo(CFrame.new(position))
        return false
    end
    return true
end

-- Goals là nguồn các ô HUD. UID giữ nguyên khi tiêu đề đổi theo tiến độ.
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

-- Dựng danh sách quest đã sắp theo priority.
local function rankQuestList(goals)
    local list = {}
    for stars in ipairs(questTiers) do
        local goal = goals[stars]
        if goal then
            local title = questCmds.MakeTitle(goal) or ""
            local kind, priority, interval = classifyQuest(title)
            table.insert(list, {
                stars = stars, uid = goal.UID, title = title,
                kind = kind, priority = priority, interval = interval,
                current = goal.Progress, target = goal.Amount,
            })
        end
    end
    table.sort(list, function(a, b)
        local left, right = a.priority or math.huge, b.priority or math.huge
        if left == right then return a.stars < b.stars end
        return left < right
    end)
    return list
end

-- Chọn quest ưu tiên sau khi đủ số ô theo rank.
local function selectQuest(goals)
    -- Đọc lại rank mỗi lần chọn để tự chuyển từ 3 sang 4 quest khi lên rank 5.
    local data = save.Get()
    local rank = data and tonumber(data.Rank)
    if not rank then return nil, true end
    local requiredCount = rank < 5 and 3 or 4
    local list = rankQuestList(goals)
    if #list == requiredCount then
        for _, quest in ipairs(list) do
            if quest.priority and quest.current < quest.target then return quest, false end
        end
    end
    return nil, true
end

-- Vòng điều phối. Chỉ một quest được chạy tại một thời điểm.
local function runQuest(quest, action)
    local repeatCollect = quest.kind == "collectPotion" or quest.kind == "collectEnchant"
    local repeatSummon = quest.kind == "coinJar" or quest.kind == "comet"
        or quest.kind == "pinata" or quest.kind == "luckyBlock"
    local fastRepeat = repeatSummon or quest.kind == "eggs" or quest.kind == "legendary"
    local actionInterval = fastRepeat and 0 or (quest.interval or 3)
    local nextAttempt = 0
    local sentAtProgress
    local lastMessage

    while true do
        local goal = readGoals()[quest.stars]
        if goal then
            if goal.UID ~= quest.uid or goal.Progress >= goal.Amount then return end

            if os.clock() >= nextAttempt and (fastRepeat or goal.Progress ~= sentAtProgress) then
                quest.current, quest.target, quest.potionTier = goal.Progress, goal.Amount, goal.PotionTier
                quest.potionId, quest.enchantId, quest.enchantTier = goal.PotionID, goal.EnchantID, goal.EnchantTier
                local ok, waitForProgress, message, retryDelay = pcall(action, quest)
                if not ok then
                    message = tostring(waitForProgress)
                    waitForProgress = true
                end
                if repeatCollect and message then
                    local reason = tostring(message):lower()
                    if reason:find("too quickly", 1, true)
                        or reason:find("cooldown", 1, true)
                        or reason:find("too many requests", 1, true)
                        or reason:match("wait%s+[%d.]+%s*second") then
                        local seconds = tonumber(reason:match("([%d.]+)%s*second")) or 0
                        actionInterval = math.max(seconds, math.min(math.max(1, actionInterval * 2), 30))
                        waitForProgress = false
                        message = ("%s (thử lại sau %g giây)"):format(tostring(message), actionInterval)
                    end
                end
                nextAttempt = os.clock() + math.max(actionInterval, retryDelay or 0)
                if message and message ~= lastMessage then
                    warn("[Rank quest] " .. quest.title .. ": " .. tostring(message))
                end
                lastMessage = message
                if waitForProgress and not fastRepeat and not repeatCollect then
                    sentAtProgress = quest.current
                end
            end
        end
        task.wait(fastRepeat and 0 or 0.25)
    end
end

-- Xuất vòng tự chọn và thực hiện quest rank.
features.RankAutoQuest = {
    duy = function(on, allFeatures)
        if questJob then
            task.cancel(questJob)
            questJob = nil
        end
        activeQuest = nil
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
                local quest, shouldWaitAtArea = selectQuest(readGoals())
                local action = quest and questActions[quest.kind]
                if action then
                    activeQuest = quest
                    runQuest(quest, action)
                    activeQuest = nil
                    task.wait(1)
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

-- Chọn stack mở khóa theo cấp và sức chứa yêu cầu.
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

-- Ánh xạ số La Mã trong tiêu đề quest sang cấp số.
local romanTiers = { i = 1, ii = 2, iii = 3, iv = 4, v = 5, vi = 6,
    vii = 7, viii = 8, ix = 9, x = 10, xi = 11 }

-- Đọc cấp vật phẩm cần dùng hoặc nâng từ tiêu đề quest.
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

-- Gọi máy với UID và số đầu ra cần tạo.
local function invokeMachine(remote, uid, count)
    local success, reason = net.Invoke(remote, uid, count)
    if not success then return true, reason or "Máy từ chối yêu cầu" end
    return true
end

-- Khai báo cấu hình máy nâng cấp cho Potion và Enchant.
local upgradeMachines = {
    Potion = {
        directory = dir.Potions,
        requiredPerOutput = balancing.CalcPotionsPerTierRequired,
        remote = "UpgradePotionsMachine_Activate",
    },
    Enchant = {
        directory = dir.Enchants,
        requiredPerOutput = balancing.CalcEnchantsPerTierRequired,
        remote = "UpgradeEnchantsMachine_Activate",
    },
}

-- Tính số đầu ra nâng cấp có thể tạo từ từng stack.
local function upgradeStacks(category, inputTier, itemId)
    local machine = upgradeMachines[category]
    local stacks = {}
    for uid, item in pairs(inventory(category)) do
        local entry = machine.directory[item.id]
        local tier = item.tn
        if not item._lk and entry and tier and entry.MaxTier and tier < entry.MaxTier
            and (not inputTier or tier == inputTier) and (not itemId or item.id == itemId) then
            local required = machine.requiredPerOutput(tier)
            if required and required > 0 then
                local capacity = math.floor((item._am or 1) / required)
                if capacity > 0 then table.insert(stacks, { uid = uid, tier = tier, capacity = capacity }) end
            end
        end
    end
    return stacks
end

-- Gom nhiều stack thành một lô đủ số đầu ra.
local function buildUpgradeBatch(stacks, count)
    local batch = {}
    for _, stack in ipairs(stacks) do
        local amount = math.min(stack.capacity, count)
        batch[stack.uid] = amount
        count -= amount
        if count == 0 then return batch end
    end
    return nil
end

-- Upgrade: gom đủ nguyên liệu cho toàn bộ số đầu ra còn thiếu trước khi gọi máy.
local function upgradeExact(quest, category, goalTier, itemId)
    local fromTier = readRequiredTier(quest.title, "from%s+")
    local toTier = goalTier or readRequiredTier(quest.title, "to%s+")
    if not fromTier and not toTier then toTier = readRequiredTier(quest.title, "") end
    if quest.title:lower():find("tier", 1, true) and not (fromTier or toTier) then
        return false, "Không đọc được cấp nâng cấp yêu cầu"
    end
    if toTier and fromTier and fromTier + 1 ~= toTier then
        return false, "Cấp đầu vào và đầu ra không khớp"
    end

    local stacks = upgradeStacks(category, toTier and toTier - 1 or fromTier, itemId)
    local count = quest.target - quest.current
    local remote = upgradeMachines[category].remote
    table.sort(stacks, function(a, b)
        if a.tier == b.tier then return a.capacity > b.capacity end
        return a.tier < b.tier
    end)
    for _, stack in ipairs(stacks) do
        if stack.capacity >= count then
            local success, reason = net.Invoke(remote, stack.uid, count)
            return success, not success and (reason or "Máy từ chối nâng cấp") or nil
        end
    end

    local batch = buildUpgradeBatch(stacks, count)
    if batch then
        local success, reason = net.Invoke(remote .. "Bulk", batch)
        return success, not success and (reason or "Máy từ chối nâng cấp theo lô") or nil
    end
    return false, "Chưa đủ nguyên liệu để nâng cấp đủ số lượng trong một lượt"
end

-- Nâng enchant tới cấp mà quest yêu cầu.
function questActions.upgradeEnchant(quest)
    return upgradeExact(quest, "Enchant", quest.enchantTier, quest.enchantId)
end

-- Nâng potion tới cấp mà quest yêu cầu.
function questActions.upgradePotion(quest)
    return upgradeExact(quest, "Potion", quest.potionTier, quest.potionId)
end

-- Collect: tạo đúng số lượng còn thiếu từ bất kỳ cấp nào có thể nâng.
local function collectByUpgrading(quest, category)
    local count = quest.target - quest.current
    if count <= 0 then return false end
    local stacks = upgradeStacks(category)
    local remote = upgradeMachines[category].remote
    local partialStacks = {}
    local lastError
    for _, stack in ipairs(stacks) do
        if stack.capacity >= count then
            local ok, success, reason = pcall(net.Invoke, remote, stack.uid, count)
            if ok and success then return true, nil, 3 end
            lastError = (ok and reason or success) or "Máy từ chối nâng cấp"
        else
            table.insert(partialStacks, stack)
        end
    end

    local batch = buildUpgradeBatch(partialStacks, count)
    if batch then
        local ok, success, reason = pcall(net.Invoke, remote .. "Bulk", batch)
        if ok and success then return true, nil, 3 end
        lastError = (ok and reason or success) or "Máy từ chối nâng cấp theo lô"
    end
    return false, lastError or "Chưa đủ nguyên liệu để Collect đúng số lượng"
end

-- Tạo đúng số Potion còn thiếu cho quest Collect.
function questActions.collectPotion(quest)
    return collectByUpgrading(quest, "Potion")
end

-- Tạo đúng số Enchant còn thiếu cho quest Collect.
function questActions.collectEnchant(quest)
    return collectByUpgrading(quest, "Enchant")
end

-- Mở trứng ở đúng điểm. Legendary có thể cần nhiều lượt trước khi tăng tiến độ.
local function hatch(eggId, position, fastHatch)
    local atEgg = goToPosition(position)
    -- Quest hatch gửi lệnh ngay cả khi client vừa teleport hoặc còn ở xa trứng.
    if not atEgg and not fastHatch then return false, nil, 0.25 end
    if not save.Get() then return false end
    local count = eggs.GetMaxHatch(dir.Eggs[eggId])
    if not count or count < 1 then return false, "Không đọc được số slot mở trứng" end
    local success, reason = eggs.RequestPurchase(eggId, count)
    if not success then return not fastHatch, reason or "Game từ chối mở trứng" end
    return false
end

-- Mở Hollow Egg để làm quest Hatch Eggs.
function questActions.eggs()
    return hatch("Hollow Egg", hollowPosition, true)
end

-- Mở Veilroot Egg để tìm pet Legendary cho quest.
function questActions.legendary()
    return hatch("Veilroot Egg", veilrootPosition, true)
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

-- Tạo Wisp Griffin Golden cho quest Make Golden.
function questActions.makeGolden(quest)
    local remaining = quest.target - quest.current
    local uid, batch, capacity = petStock(0)
    if capacity < remaining then return hatch("Hollow Egg", hollowPosition) end
    return invokeMachine("GoldMachine_Activate", uid, math.min(batch, remaining))
end

-- Tạo Wisp Griffin Rainbow cho quest Make Rainbow.
function questActions.makeRainbow(quest)
    local remaining = quest.target - quest.current
    local goldenUid, goldenBatch, rainbowCapacity = petStock(1)
    if rainbowCapacity >= remaining then
        quest.goldenToMake = nil
        return invokeMachine("RainbowMachine_Activate", goldenUid, math.min(goldenBatch, remaining))
    end

    local normalUid, normalBatch, goldenCapacity = petStock(0)
    local goldenNeeded = quest.goldenToMake or remaining * 10
    if goldenCapacity < goldenNeeded then return hatch("Hollow Egg", hollowPosition) end

    local count = math.min(normalBatch, goldenNeeded)
    local success, reason = net.Invoke("GoldMachine_Activate", normalUid, count)
    if not success then return true, reason or "Máy từ chối đổi Golden" end
    quest.goldenToMake = math.max(1, goldenNeeded - count)
    return false
end

-- Gửi lệnh ngay cả khi nhân vật vừa teleport; server tự xác nhận vị trí.
local function summon(position, itemId, remote)
    goToPosition(position)
    local uid = chooseStack("Misc", function(item)
        return item.id == itemId and (item._am or 1) or 0
    end)
    if not uid then return false, "Không có " .. itemId .. " trong inventory" end
    local success, reason = net.Invoke(remote, uid)
    if not success then return false, reason or "Game từ chối triệu hồi " .. itemId end
    return false
end

-- Dùng Comet trong kho để triệu hồi cho quest.
function questActions.comet()
    return summon(waitPosition, "Comet", "Comet_Spawn")
end

-- Dùng Basic Coin Jar trong kho để triệu hồi cho quest.
function questActions.coinJar()
    return summon(waitPosition, "Basic Coin Jar", "CoinJar_Spawn")
end

-- Dùng Mini Pinata trong kho để triệu hồi cho quest.
function questActions.pinata()
    return summon(waitPosition, "Mini Pinata", "MiniPinata_Consume")
end

-- Dùng Mini Lucky Block trong kho để triệu hồi cho quest.
function questActions.luckyBlock()
    return summon(waitPosition, "Mini Lucky Block", "MiniLuckyBlock_Consume")
end

-- Stats GUI / Dữ liệu rank và danh sách quest dùng chung với bộ auto.
local statsGui
local statsJob

-- Định dạng thời gian đã chạy theo giờ, phút và giây.
local function onlineTimeText()
    local seconds = math.floor(os.clock() - scriptStartedAt)
    return ("Đã online · %02d:%02d:%02d"):format(
        math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

-- Tính số phần thưởng rank chưa nhận.
local function rewardProgress(data)
    local id = ranks.RankIDFromNumber(data.Rank)
    local rank = id and dir.Ranks[id]
    if not rank or not rank.Rewards then return "Đang tải phần thưởng…" end

    local locked, claimable, required = 0, 0, 0
    local redeemed = data.RedeemedRankRewards or {}
    for index, reward in ipairs(rank.Rewards) do
        required += reward.StarsRequired
        if redeemed[tostring(index)] == nil then
            if (data.RankStars or 0) < required then
                locked += 1
            else
                claimable += 1
            end
        end
    end
    local line = ("%d reward còn lại để lên rank"):format(locked + claimable)
    if claimable > 0 then line ..= ("  ·  %d có thể nhận ngay"):format(claimable) end
    return line
end

-- Tạo một nhãn chữ co giãn trong Stats GUI.
local function statsLabel(parent, y, height, maxSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromScale(0.05, y)
    label.Size = UDim2.fromScale(0.90, height)
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = color
    label.TextScaled = true
    label.TextWrapped = true
    label.Text = ""
    label.Parent = parent

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MinTextSize = 1
    constraint.MaxTextSize = maxSize
    constraint.Parent = label
    return label
end

-- Xuất toggle hiển thị rank và tiến độ quest toàn màn hình.
features.RankStatsGui = {
    duy = function(on)
        if statsJob then task.cancel(statsJob); statsJob = nil end
        if statsGui then statsGui:Destroy(); statsGui = nil end
        if not on then return end

        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return end
        local gui = Instance.new("ScreenGui")
        gui.Name = "RankStatsOverlay"
        gui.IgnoreGuiInset = true
        gui.ScreenInsets = Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea = false
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 100

        local background = Instance.new("Frame")
        background.Size = UDim2.fromScale(1, 1)
        background.BackgroundColor3 = Color3.new(0, 0, 0)
        background.BorderSizePixel = 0
        background.Parent = gui

        local white = Color3.fromRGB(245, 245, 245)
        local muted = Color3.fromRGB(176, 182, 194)
        local accent = Color3.fromRGB(106, 212, 255)
        local rankLabel = statsLabel(background, 0.09, 0.14, 72, white)
        local rewardsLabel = statsLabel(background, 0.23, 0.07, 26, muted)
        local onlineLabel = statsLabel(background, 0.30, 0.04, 20, muted)
        onlineLabel.Text = onlineTimeText()
        statsLabel(background, 0.34, 0.05, 22, accent).Text = "đang làm nhìn lon"
        local activeLabel = statsLabel(background, 0.40, 0.12, 32, white)
        statsLabel(background, 0.57, 0.05, 22, accent).Text = "nhiệm vụ nè:"
        local rows = {}
        for i = 1, #questTiers do
            rows[i] = statsLabel(background, 0.63 + (i - 1) * 0.07, 0.065, 23, white)
        end

        gui.Parent = playerGui
        statsGui = gui
        statsJob = task.defer(function()
            while gui.Parent do
                onlineLabel.Text = onlineTimeText()
                local data = save.Get()
                local goals = readGoals()
                local list = rankQuestList(goals)
                rankLabel.Text = data and ("RANK %s"):format(tostring(data.Rank)) or "RANK …"
                rewardsLabel.Text = data and rewardProgress(data) or "Đang tải dữ liệu rank…"

                local current = activeQuest
                local goal = current and goals[current.stars]
                if current and goal and goal.UID == current.uid then
                    activeLabel.Text = ("%s\n%d/%d"):format(current.title, goal.Progress, goal.Amount)
                else
                    activeLabel.Text = questJob and "Đợi bố m tí" or "Auto rank quest đang tắt"
                end

                for index, label in ipairs(rows) do
                    local quest = list[index]
                    if quest then
                        label.Text = ("%s  ·  %s  ·  %d/%d"):format(
                            questTiers[quest.stars], quest.title, quest.current, quest.target)
                        label.TextColor3 = quest.priority and white or muted
                    else
                        label.Text = ""
                    end
                end
                task.wait(0.5)
            end
        end)
    end,
}

return features
