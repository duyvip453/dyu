local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/dyu/refs/heads/main/maclib.lua"))()

local Window = MacLib:Window({
	Title = "Porn hub",
	Subtitle = "by duy duy",
	Size = UDim2.fromOffset(800, 500),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = false,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
})
local tabGroups = {
	TabGroup1 = Window:TabGroup()
}

local tabs = {
	Farm = tabGroups.TabGroup1:Tab({ Name = "Farm"})
}

local sections = {
	FarmL = tabs.Farm:Section({ Side = "Left" }),
	FarmR = tabs.Farm:Section({ Side = "Right" }),
	FarmL2 = tabs.Farm:Section({ Side = "Left" }),
	FarmR2 = tabs.Farm:Section({ Side = "Right" })
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
