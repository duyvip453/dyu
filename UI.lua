local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/maclib.lua"))()

local Window = MacLib:Window({
	Title = "Porn hub",
	Subtitle = "by duy duy",
	Size = UDim2.fromOffset(700, 500),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = false,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
})

local tabGroups = {
	TabGroup1 = Window:TabGroup()
	TabGroup2 = Window:TabGroup()
}

local tabs = {
	Farm = tabGroups.TabGroup1:Tab({ Name = "Farm"}),
	Mail = tabGroups.TabGroup1:Tab({ Name = "Mail"})
	
}

local sections = {
	FarmL = tabs.Farm:Section({ Side = "Left" }),
	FarmR = tabs.Farm:Section({ Side = "Right" }),
	FarmL2 = tabs.Farm:Section({ Side = "Left" }),
	FarmR2 = tabs.Farm:Section({ Side = "Right" }),

	MailL = tabs.Mail:Section({ Side = "Left" }),
	MailR = tabs.Mail:Section({ Side = "Left" })
}
local Scripts = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/farmm.lua"))()

--farm trái ô 1
sections.FarmL:Toggle({
	Name = "Infinity Pet Speed",
	Default = false,
	Callback = function(value)
    Scripts.infpetspeed(value)
end

		
		}, "infpetspeed")
sections.FarmL:Toggle({
	Name = "Auto Tap",
	Default = false,
	Callback = function(value)
    Scripts.autotap(value)
end

		
		}, "autotap")
sections.FarmL:Toggle({
	Name = "Auto Ultimate",
	Default = false,
	Callback = function(value)
    Scripts.autoultimate(value)
end
		}, "autoUltimate")
--end farm trái ô 1

--farm trái ô 2
sections.FarmL2:Toggle({
	Name = "Auto Unclock area",
	Default = false,
	Callback = function(value)
    Scripts.autounclockarea(value)
end
		}, "autounclockmap")

sections.FarmL2:Toggle({
	Name = "Auto tele to best area",
	Default = false,
	Callback = function(value)
    Scripts.autotelebestarea(value)
end
		}, "autotelebestarea")

sections.FarmL2:Toggle({
	Name = "Auto tele to best World",
	Default = false,
	Callback = function(value)
    Scripts.autotelebestworld(value)
end
		}, "autotelebestworld")
--end farm trái ô 2

--farm phải ô 1
sections.FarmR:Toggle({
	Name = "Auto Update egg slot",
	Default = false,
	Callback = function(value)
    Scripts.autoupdateeggslot(value)
end
		}, "autoupdateeggslot")

sections.FarmR:Toggle({
	Name = "Auto Update pet slot",
	Default = false,
	Callback = function(value)
    Scripts.autoupdatepetslot(value)
end
		}, "autoupdatepetslot")
--end farm phải ô 1

local MailScripts = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/Mail.lua"))()


sections.MailL:Toggle({
	Name = "Auto Claim Mail",
	Default = false,
	Callback = function(value)
    Scripts.autoclaimmail(value)
end
		}, "autoclaimmail")

local danhSachLoai = {}

sections.MailR:Dropdown({
    Name = "Type",
	Placeholder = "typemail",
    Options = {"Gargantuan", "Titanic", "Huge"},
    Multi = true,
    Callback = function(cacLoaiDaChon)
        danhSachLoai = {}

        for loai in pairs(cacLoaiDaChon) do
            table.insert(danhSachLoai, tonumber(loai))
        end
    end
}, "mailtype")

sections.MailR:Toggle({
	Name = "Auto Send Mail",
	Default = false,
	Callback = function(value)
    MailScripts.autosendmail(value)
end
		}, "autosendmail")
