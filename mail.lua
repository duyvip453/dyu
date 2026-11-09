local features = {}

local lib = game:GetService("ReplicatedStorage").Library
local net = require(lib.Client.Network)
local mailJob

-- Tự nhận toàn bộ thư; khi server báo cooldown thì đợi 30 giây.
features.MailAutoClaim = {
    duy = function(on)
        if mailJob then
            task.cancel(mailJob)
            mailJob = nil
        end
        if not on then return end

        mailJob = task.defer(function()
            while true do
                local ok, result, message = pcall(net.Invoke, "Mailbox: Claim All")
                local responseText = string.lower(tostring(message or result or ""))
                local cooldown = responseText:find("wait") and responseText:find("second")
                task.wait(cooldown and 30 or 5)
            end
        end)
    end,
}

return features

