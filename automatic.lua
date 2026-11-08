local features = {}

-- Phần dùng chung
local lib = game:GetService("ReplicatedStorage").Library
local net = require(lib.Client.Network)
local save = require(lib.Client.Save)
local dir = require(lib.Directory)
local job

-- Automatic / Tự nhận quà online
features.AutoClaimFreeGift = {
    duy = function(on)
        if job then task.cancel(job); job = nil end
        if not on then return end

        job = task.defer(function()
            while true do
                local data = save.Get()
                if data then
                    for _, gift in pairs(dir.FreeGifts) do
                        if gift.WaitTime <= data.FreeGiftsTime
                            and not table.find(data.FreeGiftsRedeemed, gift.Id) then
                            pcall(net.Invoke, "Redeem Free Gift", gift.Id)
                            break
                        end
                    end
                end
                task.wait(3)
            end
        end)
    end,
}

return features

