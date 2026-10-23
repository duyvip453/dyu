local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/event/refs/heads/main/maclib.lua"))()

local Window = MacLib:Window({
	Title = "Porn hub",
	Subtitle = "by duy duy",
	Size = UDim2.fromOffset(868, 650),
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
	FarmR = tabs.Farm:Section({ Side = "Right" })
}

sections.FarmL:Toggle({
	Name = "inf pet speed",
	Default = false,
	Callback = function(value)
    Scripts.infpetspeed(value)
end
		}, "infpetspeed")
