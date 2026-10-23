local MacLib = loadstring(game:HttpGet(
    "https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"
))()


local Window = MacLib:Window({
	Title = "porn hub",
	Subtitle = "duy duy",
	Size = UDim2.fromOffset(868, 650),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = true,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()

local Farm = TabGroup:Tab({
  Name = "Farm"
})
local FarmL = Farm:Section({
    Side = "Left"
})
local FarmR = Farm:Section({
    Side = "Right"
})

local scripts = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/event/refs/heads/main/farm.lua"))()
FarmL:Toggle({
    Name = "inf pet speed",
    Default = false,
    Callback = scripts.infpetspeed
})
FarmL:Toggle({
    Name = "Auto tap",
    Default = false,
    Callback = scripts.autotap
})
FarmL:Toggle({
    Name = "Fast farm",
    Default = false,
    Callback = scripts.fastfarn
})
FarmL:Toggle({
    Name = "auto ultimate",
    Default = false,
    Callback = scripts.autoultimate
})
FarmR:Toggle({
    Name = "update pet slot",
    Default = false,
    Callback = scripts.petslot
})
FarmR:Toggle({
    Name = "update egg slot",
    Default = false,
    Callback = scripts.eggslot
})
MacLib:SetFolder("Maclib")
tabs.Settings:InsertConfigSection("Left")

Window.onUnloaded(function()
	print("Unloaded!")
end)

tabs.Main:Select()
MacLib:LoadAutoLoadConfig()
