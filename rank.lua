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

return features

