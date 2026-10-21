--!strict
-- ============================================================================
-- Send Robux Modal Controller with Advanced Settings
-- Features:
--   1. Send Robux Modal layout (476px height) matching UI.lua design.
--   2. Authentic Roblox assets: Roblox tilt logo ("rbxassetid://125746152594286")
--      and Robux coin icons ("rbxassetid://16884178261", rect [190, 152, 36, 36]).
--   3. Sleek Left-side Settings Menu with smooth sliding transitions.
--   4. Persistent Total Amount (auto-saved across script re-runs via file / memory).
--   5. Persistent Start Hidden / Auto-Unshow toggle (auto-saved across script runs).
--   6. Persistent Keybind Selector button (Default: F4, auto-saved across runs).
--   7. Configurable Random Popup Delay (Default: 1.0s to 2.0s, configurable in Settings).
--   8. On Send button click: direct dark layer (stationary on button), 2s wait, instant direct close.
--   9. Animated entrance for "Purchase completed" Modal:
--      - Exact layout matching user's reference mockup
--      - "Purchase completed" header (same font and size)
--      - Checkmark circle icon ("rbxassetid://98579402919536")
--      - "You have successfully sent <Amount> Robux."
--      - Blue "OK" button, hover effect disabled
--      - Robux deduction happens on OK/Close completion
-- ============================================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local UserService = game:GetService("UserService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
if not player then
	repeat
		task.wait()
		player = Players.LocalPlayer
	until player
end
local playerGui = player:WaitForChild("PlayerGui", 10) or player:FindFirstChild("PlayerGui")

local getHuiFunc = (type(gethui) == "function" and gethui) or nil
local guiParent: Instance = (getHuiFunc and getHuiFunc()) or playerGui

-- ============================================================================
-- Persistent Configuration Storage (Executor File System + Environment Fallback)
-- ============================================================================

local CONFIG_FILE = "VIP_Buy_Settings.json"

local currentTotalAmount = "903"
local currentRecipientUser = "Powerbank225w"
local currentRecipientDisplay = "Powerbank225w"
local currentActiveItemName = "Powerbank225w"
local currentActivePriceStr = "10"
local currentActivePriceNum = 10
local isScriptEnabled = true
local autoHideOnRun = false
local currentKeybind: Enum.KeyCode = Enum.KeyCode.F4
local minPopupDelay = 0.6
local maxPopupDelay = 1.6
local customDonatedStr = "0"
local customRaisedStr = "0"
local customFireStreak = 0
local useOriginalStats = true
local realGameDonated = ""
local realGameRaised = ""
local addedDonatedOffset = 0
local originalDonatedStr = ""
local originalRaisedStr = ""
local isVipNameTagEnabled = true
local hasInitialVipChecked = true
local captureOriginalStatsFromGame: () -> () = function() end
local updatePlayerlistStats: () -> () = function() end
local updateHeadTag: (char: Model?) -> () = function() end
local updatePlayerlistName: () -> () = function() end
local refreshVipButtonVisual: () -> () = function() end
local refreshDelayPresetsVisual: () -> () = function() end
local updateMasterToggleVisual: (animate: boolean) -> () = function() end
local addGiftbux: (amountToAdd: number) -> () = function() end
local hookGiftbux: () -> () = function() end
local resetGiftbux: () -> () = function() end
local playDonationPopupAnimation: (amount: number | string, username: string, stayDuration: number?) -> () = function() end

local function formatWithCommas(strOrNum: string | number): string
	local raw = tostring(strOrNum):gsub("%D", "")
	if raw == "" then return "" end
	local formatted = raw
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function getActiveDonated(): string
	if useOriginalStats then
		local base = tonumber(realGameDonated) or tonumber(originalDonatedStr) or 0
		return tostring(base + addedDonatedOffset)
	else
		local base = tonumber(customDonatedStr) or 0
		return tostring(base)
	end
end

local function getActiveRaised(): string
	if useOriginalStats then
		local base = tonumber(realGameRaised) or tonumber(originalRaisedStr) or 0
		return tostring(base)
	else
		local base = tonumber(customRaisedStr) or 0
		return tostring(base)
	end
end

local function loadSavedConfig()
	local loadedData = nil

	-- 1. Try reading from executor disk file (writefile / readfile)
	if type(readfile) == "function" then
		local canRead = true
		if type(isfile) == "function" then
			local s, exists = pcall(isfile, CONFIG_FILE)
			if s and not exists then
				canRead = false
			end
		end
		if canRead then
			local s2, content = pcall(readfile, CONFIG_FILE)
			if s2 and type(content) == "string" and content ~= "" then
				local s3, parsed = pcall(function()
					return HttpService:JSONDecode(content)
				end)
				if s3 and type(parsed) == "table" then
					loadedData = parsed
				end
			end
		end
	end

	-- 2. Fallback to session environment (getgenv / shared / _G)
	if not loadedData then
		local genv = (type(getgenv) == "function" and getgenv()) or nil
		if genv and type(genv.VIP_BUY_SAVED_CONFIG) == "table" then
			loadedData = genv.VIP_BUY_SAVED_CONFIG
		elseif type(shared) == "table" and type(shared.VIP_BUY_SAVED_CONFIG) == "table" then
			loadedData = shared.VIP_BUY_SAVED_CONFIG
		elseif type(_G) == "table" and type(_G.VIP_BUY_SAVED_CONFIG) == "table" then
			loadedData = _G.VIP_BUY_SAVED_CONFIG
		end
	end

	if loadedData and type(loadedData) == "table" then
		if loadedData.TotalAmount ~= nil then
			currentTotalAmount = tostring(loadedData.TotalAmount)
		end
		if loadedData.TransferAmount ~= nil then
			currentActivePriceNum = tonumber(loadedData.TransferAmount) or 10
			currentActivePriceStr = tostring(currentActivePriceNum)
		end
		if loadedData.ScriptEnabled ~= nil then
			isScriptEnabled = (loadedData.ScriptEnabled == true)
		end
		if loadedData.AutoHideOnRun ~= nil then
			autoHideOnRun = (loadedData.AutoHideOnRun == true)
		end
		if loadedData.Keybind and type(loadedData.Keybind) == "string" then
			local success, keyEnum = pcall(function()
				return (Enum.KeyCode :: any)[loadedData.Keybind]
			end)
			if success and keyEnum then
				currentKeybind = keyEnum
			end
		end
		if loadedData.MinDelay ~= nil then
			minPopupDelay = tonumber(loadedData.MinDelay) or 0.6
		end
		if loadedData.MaxDelay ~= nil then
			maxPopupDelay = tonumber(loadedData.MaxDelay) or 1.6
		end
		if loadedData.AddedDonatedOffset ~= nil then
			addedDonatedOffset = tonumber(loadedData.AddedDonatedOffset) or 0
		end
		if loadedData.RealGameDonated ~= nil and tostring(loadedData.RealGameDonated) ~= "" then
			realGameDonated = tostring(loadedData.RealGameDonated)
		end
		if loadedData.RealGameRaised ~= nil and tostring(loadedData.RealGameRaised) ~= "" then
			realGameRaised = tostring(loadedData.RealGameRaised)
		end
		if loadedData.CustomDonated ~= nil then
			customDonatedStr = tostring(loadedData.CustomDonated)
		end
		if loadedData.CustomRaised ~= nil then
			customRaisedStr = tostring(loadedData.CustomRaised)
		end
		if loadedData.OriginalDonated ~= nil then
			originalDonatedStr = tostring(loadedData.OriginalDonated)
		end
		if loadedData.OriginalRaised ~= nil then
			originalRaisedStr = tostring(loadedData.OriginalRaised)
		end
		if loadedData.UseOriginalStats ~= nil then
			useOriginalStats = (loadedData.UseOriginalStats == true)
		else
			useOriginalStats = true
		end
		if loadedData.VipNameTagEnabled ~= nil then
			isVipNameTagEnabled = (loadedData.VipNameTagEnabled == true)
		else
			isVipNameTagEnabled = true
		end
		if loadedData.FireStreak ~= nil then
			customFireStreak = tonumber(loadedData.FireStreak) or 0
		end
	end
end

local function saveConfigToStorage()
	local configData = {
		TotalAmount = currentTotalAmount,
		TransferAmount = currentActivePriceNum,
		ScriptEnabled = isScriptEnabled,
		AutoHideOnRun = autoHideOnRun,
		Keybind = currentKeybind.Name,
		MinDelay = minPopupDelay,
		MaxDelay = maxPopupDelay,
		AddedDonatedOffset = addedDonatedOffset,
		RealGameDonated = realGameDonated,
		RealGameRaised = realGameRaised,
		CustomDonated = customDonatedStr,
		CustomRaised = customRaisedStr,
		OriginalDonated = originalDonatedStr,
		OriginalRaised = originalRaisedStr,
		UseOriginalStats = useOriginalStats,
		VipNameTagEnabled = isVipNameTagEnabled,
		FireStreak = customFireStreak,
	}

	-- Save to executor disk file
	if type(writefile) == "function" then
		pcall(function()
			writefile(CONFIG_FILE, HttpService:JSONEncode(configData))
		end)
	end

	-- Save to session environment
	if type(getgenv) == "function" then
		pcall(function()
			getgenv().VIP_BUY_SAVED_CONFIG = configData
		end)
	end
	if type(shared) == "table" then
		shared.VIP_BUY_SAVED_CONFIG = configData
	end
	if type(_G) == "table" then
		_G.VIP_BUY_SAVED_CONFIG = configData
	end
end

-- Load persistent settings at startup
loadSavedConfig()
saveConfigToStorage()

local objects = {}

local function cleanupPreviousGui()
	pcall(function()
		local old = playerGui:FindFirstChild("VIP_Buy_Item_Demo")
		if old then old:Destroy() end
	end)
	if getHuiFunc then
		pcall(function()
			local old = getHuiFunc():FindFirstChild("VIP_Buy_Item_Demo")
			if old then old:Destroy() end
		end)
	end
end
cleanupPreviousGui()

-- [[1: ScreenGui "VIP_Buy_Item_Demo"]]
objects[1] = Instance.new("ScreenGui")
objects[1].Name = "VIP_Buy_Item_Demo"
objects[1].ResetOnSpawn = false
objects[1].ZIndexBehavior = Enum.ZIndexBehavior.Sibling
objects[1].DisplayOrder = 100
objects[1].IgnoreGuiInset = true
objects[1].ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
objects[1].Parent = guiParent

-- [[2: Frame "DarkOverlay"]]
objects[2] = Instance.new("Frame")
objects[2].Name = "DarkOverlay"
objects[2].Active = true
objects[2].Size = UDim2.new(1, 0, 1, 0)
objects[2].BackgroundColor3 = Color3.fromRGB(0, 0, 0)
objects[2].BackgroundTransparency = 1
objects[2].BorderSizePixel = 0
objects[2].Visible = false
objects[2].Parent = objects[1]

-- [[3: Frame "Shadow"]]
objects[3] = Instance.new("Frame")
objects[3].Name = "Shadow"
objects[3].Size = UDim2.new(0, 460, 0, 496)
objects[3].Position = UDim2.new(0.5, 0, 0.491261, 7)
objects[3].AnchorPoint = Vector2.new(0.5, 0.5)
objects[3].ZIndex = 2
objects[3].BackgroundColor3 = Color3.fromRGB(0, 0, 0)
objects[3].BackgroundTransparency = 1
objects[3].BorderSizePixel = 0
objects[3].Parent = objects[2]

-- [[4: UICorner "UICorner"]]
objects[4] = Instance.new("UICorner")
objects[4].CornerRadius = UDim.new(0, 18)
objects[4].Parent = objects[3]

-- [[5: UIScale "UIScale"]]
objects[5] = Instance.new("UIScale")
objects[5].Scale = 1.0
objects[5].Parent = objects[3]

-- [[6: CanvasGroup "BuyItemModal" (Main Modal Frame)]]
objects[6] = Instance.new("CanvasGroup")
objects[6].Name = "BuyItemModal"
objects[6].Size = UDim2.new(0, 460, 0, 496)
objects[6].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[6].AnchorPoint = Vector2.new(0.5, 0.5)
objects[6].ZIndex = 3
objects[6].BackgroundColor3 = Color3.fromRGB(25, 26, 31)
objects[6].BorderSizePixel = 0
objects[6].GroupTransparency = 1
objects[6].Parent = objects[2]

-- [[7: UICorner "UICorner"]]
objects[7] = Instance.new("UICorner")
objects[7].CornerRadius = UDim.new(0, 18)
objects[7].Parent = objects[6]

-- [[8: UIStroke "UIStroke"]]
objects[8] = Instance.new("UIStroke")
objects[8].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
objects[8].Color = Color3.fromRGB(43, 45, 48)
objects[8].Transparency = 0
objects[8].Thickness = 1
objects[8].Parent = objects[6]

-- [[9: UIScale "UIScale"]]
objects[9] = Instance.new("UIScale")
objects[9].Scale = 1.0
objects[9].Parent = objects[6]

local function updateModalResponsiveScale()
	local camera = workspace.CurrentCamera
	local vp = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
	local screenH = vp.Y
	local screenW = vp.X

	local targetScale = 1.0
	if UserInputService.TouchEnabled or screenH < 540 or screenW < 500 then
		local scaleH = (screenH * 0.90) / 496
		local scaleW = (screenW * 0.90) / 460
		targetScale = math.clamp(math.min(scaleH, scaleW), 0.45, 1.0)
	else
		targetScale = 1.0
	end

	objects[5].Scale = targetScale
	objects[9].Scale = targetScale
end

updateModalResponsiveScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateModalResponsiveScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local cam = workspace.CurrentCamera
	if cam then
		updateModalResponsiveScale()
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateModalResponsiveScale)
	end
end)

-- ============================================================================
-- View 1: Send Robux View Container (Styled from UI.lua)
-- ============================================================================
local buyView = Instance.new("Frame")
buyView.Name = "BuyView"
buyView.Size = UDim2.new(1, 0, 1, 0)
buyView.BackgroundTransparency = 1
buyView.ZIndex = 3
buyView.Visible = true
buyView.Parent = objects[6]

-- [[Top-Left Roblox Logo Image (Asset from Main.lua: rbxassetid://125746152594286)]]
local robloxLogo = Instance.new("ImageLabel")
robloxLogo.Name = "RobloxLogo"
robloxLogo.Size = UDim2.new(0, 22, 0, 22)
robloxLogo.Position = UDim2.new(0, 20, 0, 21)
robloxLogo.ZIndex = 4
robloxLogo.BackgroundTransparency = 1
robloxLogo.BorderSizePixel = 0
robloxLogo.Image = "rbxassetid://125746152594286"
robloxLogo.ScaleType = Enum.ScaleType.Fit
robloxLogo.Parent = buyView

-- [[10: TextLabel "TitleLabel" (Send Robux)]]
objects[10] = Instance.new("TextLabel")
objects[10].Name = "TitleLabel"
objects[10].Size = UDim2.new(0, 180, 0, 27)
objects[10].Position = UDim2.new(0, 50, 0, 19)
objects[10].ZIndex = 4
objects[10].BackgroundTransparency = 1
objects[10].BorderSizePixel = 0
objects[10].Text = "Send Robux"
objects[10].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[10].TextTransparency = 0
objects[10].TextSize = 24
objects[10].TextScaled = false
objects[10].TextWrapped = false
objects[10].TextXAlignment = Enum.TextXAlignment.Left
objects[10].TextYAlignment = Enum.TextYAlignment.Center
objects[10].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[10].TextTruncate = Enum.TextTruncate.AtEnd
objects[10].Parent = buyView

-- [[32: ImageLabel "RobuxTopRightIcon" (Robux Icon next to Balance)]]
objects[32] = Instance.new("ImageLabel")
objects[32].Name = "RobuxTopRightIcon"
objects[32].Size = UDim2.new(0, 24, 0, 24)
objects[32].Position = UDim2.new(0, 340, 0, 20)
objects[32].ZIndex = 4
objects[32].BackgroundTransparency = 1
objects[32].BorderSizePixel = 0
objects[32].Image = "rbxassetid://16884178261"
objects[32].ImageRectOffset = Vector2.new(190, 152)
objects[32].ImageRectSize = Vector2.new(36, 36)
objects[32].ScaleType = Enum.ScaleType.Fit
objects[32].Parent = buyView

-- [[11: TextLabel "TotalAmountLabel" (Top-right beside Close Button)]]
objects[11] = Instance.new("TextLabel")
objects[11].Name = "TotalAmountLabel"
objects[11].Size = UDim2.new(0, 45, 0, 24)
objects[11].Position = UDim2.new(0, 368, 0, 20)
objects[11].ZIndex = 4
objects[11].BackgroundTransparency = 1
objects[11].BorderSizePixel = 0
objects[11].Text = currentTotalAmount
objects[11].TextColor3 = Color3.fromRGB(229, 229, 231)
objects[11].TextTransparency = 0
objects[11].TextSize = 19
objects[11].TextScaled = false
objects[11].TextWrapped = false
objects[11].TextXAlignment = Enum.TextXAlignment.Right
objects[11].TextYAlignment = Enum.TextYAlignment.Center
objects[11].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[11].TextTruncate = Enum.TextTruncate.None
objects[11].Parent = buyView

-- [[12: TextButton "CloseButton"]]
objects[12] = Instance.new("TextButton")
objects[12].Name = "CloseButton"
objects[12].AutoButtonColor = false
objects[12].Size = UDim2.new(0, 22, 0, 24)
objects[12].Position = UDim2.new(0, 418, 0, 20)
objects[12].ZIndex = 7
objects[12].BackgroundTransparency = 1
objects[12].Text = ""
objects[12].Parent = buyView

objects[13] = Instance.new("Frame")
objects[13].Name = "CloseLine1"
objects[13].Size = UDim2.new(0, 2, 0, 16)
objects[13].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[13].AnchorPoint = Vector2.new(0.5, 0.5)
objects[13].Rotation = 45
objects[13].ZIndex = 8
objects[13].BackgroundColor3 = Color3.fromRGB(229, 229, 231)
objects[13].BorderSizePixel = 0
objects[13].Parent = objects[12]

objects[14] = Instance.new("Frame")
objects[14].Name = "CloseLine2"
objects[14].Size = UDim2.new(0, 2, 0, 16)
objects[14].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[14].AnchorPoint = Vector2.new(0.5, 0.5)
objects[14].Rotation = -45
objects[14].ZIndex = 8
objects[14].BackgroundColor3 = Color3.fromRGB(229, 229, 231)
objects[14].BorderSizePixel = 0
objects[14].Parent = objects[12]

-- ============================================================================
-- Recipient Card
-- ============================================================================
local recipientPanel = Instance.new("Frame")
recipientPanel.Name = "RecipientInfoPanel"
recipientPanel.Size = UDim2.new(0, 420, 0, 178)
recipientPanel.Position = UDim2.new(0, 20, 0, 56)
recipientPanel.BackgroundColor3 = Color3.fromRGB(32, 33, 40)
recipientPanel.BorderSizePixel = 0
recipientPanel.ZIndex = 4
recipientPanel.Parent = buyView

local recipientCorner = Instance.new("UICorner")
recipientCorner.CornerRadius = UDim.new(0, 12)
recipientCorner.Parent = recipientPanel

local avatarFrame = Instance.new("CanvasGroup")
avatarFrame.Name = "OfficerAvatar"
avatarFrame.Size = UDim2.new(0, 64, 0, 64)
avatarFrame.Position = UDim2.new(0, 178, 0, 16)
avatarFrame.BackgroundColor3 = Color3.fromRGB(45, 51, 59)
avatarFrame.BorderSizePixel = 0
avatarFrame.ZIndex = 5
avatarFrame.Parent = recipientPanel

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(0, 32)
avatarCorner.Parent = avatarFrame

local avatarStroke = Instance.new("UIStroke")
avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
avatarStroke.Color = Color3.fromRGB(56, 59, 63)
avatarStroke.Thickness = 1
avatarStroke.Parent = avatarFrame

local avatarThumbnail = Instance.new("ImageLabel")
avatarThumbnail.Name = "ActualAvatarThumbnail"
avatarThumbnail.Size = UDim2.fromScale(1, 1)
avatarThumbnail.BackgroundTransparency = 1
avatarThumbnail.Visible = false
avatarThumbnail.ZIndex = 6
avatarThumbnail.Parent = avatarFrame

local avatarThumbnailCorner = Instance.new("UICorner")
avatarThumbnailCorner.CornerRadius = UDim.new(0, 32)
avatarThumbnailCorner.Parent = avatarThumbnail

local function updateRecipientAvatar(username: string)
	if avatarThumbnail then
		avatarThumbnail.Visible = false
		avatarThumbnail.Image = ""
	end
	task.spawn(function()
		local ok, imageUrl = pcall(function()
			local userId = Players:GetUserIdFromNameAsync(username)
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and imageUrl and avatarThumbnail and avatarThumbnail.Parent then
			avatarThumbnail.Image = imageUrl
			avatarThumbnail.Visible = true
		end
	end)
end
updateRecipientAvatar(currentRecipientUser)

-- [[20: TextLabel "ItemNameLabel" (Recipient Display Name)]]
objects[20] = Instance.new("TextLabel")
objects[20].Name = "ItemNameLabel"
objects[20].Size = UDim2.new(0, 380, 0, 22)
objects[20].Position = UDim2.new(0, 20, 0, 90)
objects[20].ZIndex = 5
objects[20].BackgroundTransparency = 1
objects[20].BorderSizePixel = 0
objects[20].Text = currentRecipientDisplay
objects[20].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[20].TextTransparency = 0
objects[20].TextSize = 17
objects[20].TextScaled = false
objects[20].TextWrapped = false
objects[20].TextXAlignment = Enum.TextXAlignment.Center
objects[20].TextYAlignment = Enum.TextYAlignment.Center
objects[20].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[20].Parent = recipientPanel

local recipientUsernameLabel = Instance.new("TextLabel")
recipientUsernameLabel.Name = "RecipientUsername"
recipientUsernameLabel.Size = UDim2.new(0, 380, 0, 20)
recipientUsernameLabel.Position = UDim2.new(0, 20, 0, 114)
recipientUsernameLabel.ZIndex = 5
recipientUsernameLabel.BackgroundTransparency = 1
recipientUsernameLabel.BorderSizePixel = 0
recipientUsernameLabel.Text = "@" .. currentRecipientUser
recipientUsernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
recipientUsernameLabel.TextSize = 15
recipientUsernameLabel.TextScaled = false
recipientUsernameLabel.TextWrapped = false
recipientUsernameLabel.TextXAlignment = Enum.TextXAlignment.Center
recipientUsernameLabel.TextYAlignment = Enum.TextYAlignment.Center
recipientUsernameLabel.FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
recipientUsernameLabel.Parent = recipientPanel

-- Friends & Info Centered Row
local friendsInfoRow = Instance.new("Frame")
friendsInfoRow.Name = "FriendsInfoRow"
friendsInfoRow.Size = UDim2.new(1, 0, 0, 22)
friendsInfoRow.Position = UDim2.new(0, 0, 0, 142)
friendsInfoRow.BackgroundTransparency = 1
friendsInfoRow.ZIndex = 5
friendsInfoRow.Parent = recipientPanel

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 14)
rowLayout.Parent = friendsInfoRow

local friendsGroup = Instance.new("Frame")
friendsGroup.Name = "FriendsGroup"
friendsGroup.AutomaticSize = Enum.AutomaticSize.XY
friendsGroup.BackgroundTransparency = 1
friendsGroup.ZIndex = 5
friendsGroup.Parent = friendsInfoRow

local friendsGroupLayout = Instance.new("UIListLayout")
friendsGroupLayout.FillDirection = Enum.FillDirection.Horizontal
friendsGroupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
friendsGroupLayout.Padding = UDim.new(0, 6)
friendsGroupLayout.Parent = friendsGroup

local friendsIcon = Instance.new("Frame")
friendsIcon.Name = "FriendsIcon"
friendsIcon.Size = UDim2.new(0, 18, 0, 18)
friendsIcon.BackgroundTransparency = 1
friendsIcon.ZIndex = 5
friendsIcon.Parent = friendsGroup

local function addFriendPart(x, y, w, h, r)
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BorderSizePixel = 0
	f.ZIndex = 5
	f.Parent = friendsIcon
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end
addFriendPart(1, 1, 7, 7, 4)
addFriendPart(9, 1, 7, 7, 4)
addFriendPart(0, 9, 10, 7, 5)
addFriendPart(10, 9, 7, 7, 5)

local friendsText = Instance.new("TextLabel")
friendsText.Name = "FriendsText"
friendsText.AutomaticSize = Enum.AutomaticSize.XY
friendsText.BackgroundTransparency = 1
friendsText.BorderSizePixel = 0
friendsText.Text = "0 mutual Friends"
friendsText.TextColor3 = Color3.fromRGB(255, 255, 255)
friendsText.TextSize = 15
friendsText.Font = Enum.Font.GothamMedium
friendsText.TextXAlignment = Enum.TextXAlignment.Left
friendsText.ZIndex = 5
friendsText.Parent = friendsGroup

local infoGroup = Instance.new("Frame")
infoGroup.Name = "InfoGroup"
infoGroup.AutomaticSize = Enum.AutomaticSize.XY
infoGroup.BackgroundTransparency = 1
infoGroup.ZIndex = 5
infoGroup.Parent = friendsInfoRow

local infoGroupLayout = Instance.new("UIListLayout")
infoGroupLayout.FillDirection = Enum.FillDirection.Horizontal
infoGroupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
infoGroupLayout.Padding = UDim.new(0, 6)
infoGroupLayout.Parent = infoGroup

local infoIcon = Instance.new("Frame")
infoIcon.Name = "InfoIcon"
infoIcon.Size = UDim2.new(0, 16, 0, 16)
infoIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
infoIcon.BorderSizePixel = 0
infoIcon.ZIndex = 5
infoIcon.Parent = infoGroup

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoIcon

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.fromScale(1, 1)
infoText.BackgroundTransparency = 1
infoText.Text = "i"
infoText.TextColor3 = Color3.fromRGB(32, 33, 40)
infoText.TextSize = 11
infoText.Font = Enum.Font.GothamBold
infoText.ZIndex = 6
infoText.Parent = infoIcon

local joinedText = Instance.new("TextLabel")
joinedText.Name = "JoinedText"
joinedText.AutomaticSize = Enum.AutomaticSize.XY
joinedText.BackgroundTransparency = 1
joinedText.BorderSizePixel = 0
joinedText.Text = "Joined in 0"
joinedText.TextColor3 = Color3.fromRGB(255, 255, 255)
joinedText.TextSize = 15
joinedText.Font = Enum.Font.GothamMedium
joinedText.TextXAlignment = Enum.TextXAlignment.Left
joinedText.ZIndex = 5
joinedText.Parent = infoGroup

-- ============================================================================
-- Transfer Amount Card
-- ============================================================================
local amountPanel = Instance.new("Frame")
amountPanel.Name = "TransferAmountPanel"
amountPanel.Size = UDim2.new(0, 420, 0, 126)
amountPanel.Position = UDim2.new(0, 20, 0, 246)
amountPanel.BackgroundColor3 = Color3.fromRGB(32, 33, 40)
amountPanel.BorderSizePixel = 0
amountPanel.ZIndex = 4
amountPanel.Parent = buyView

local amountCorner = Instance.new("UICorner")
amountCorner.CornerRadius = UDim.new(0, 12)
amountCorner.Parent = amountPanel

local amountRow = Instance.new("Frame")
amountRow.Name = "AmountRow"
amountRow.Size = UDim2.new(1, 0, 0, 50)
amountRow.Position = UDim2.new(0, 0, 0, 14)
amountRow.BackgroundTransparency = 1
amountRow.ZIndex = 5
amountRow.Parent = amountPanel

local amountLayout = Instance.new("UIListLayout")
amountLayout.SortOrder = Enum.SortOrder.LayoutOrder
amountLayout.FillDirection = Enum.FillDirection.Horizontal
amountLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
amountLayout.VerticalAlignment = Enum.VerticalAlignment.Center
amountLayout.Padding = UDim.new(0, 8)
amountLayout.Parent = amountRow

-- [[33: ImageLabel "RobuxItemIcon" (Large 48px Robux Hex Icon on Left)]]
objects[33] = Instance.new("ImageLabel")
objects[33].Name = "RobuxItemIcon"
objects[33].Size = UDim2.new(0, 48, 0, 48)
objects[33].LayoutOrder = 1
objects[33].ZIndex = 5
objects[33].BackgroundTransparency = 1
objects[33].BorderSizePixel = 0
objects[33].Image = "rbxassetid://16884178261"
objects[33].ImageRectOffset = Vector2.new(190, 152)
objects[33].ImageRectSize = Vector2.new(36, 36)
objects[33].ScaleType = Enum.ScaleType.Fit
objects[33].Parent = amountRow

-- [[21: TextLabel "ItemPriceLabel" (Large 50px Amount Text on Right)]]
objects[21] = Instance.new("TextLabel")
objects[21].Name = "ItemPriceLabel"
objects[21].AutomaticSize = Enum.AutomaticSize.X
objects[21].Size = UDim2.new(0, 0, 0, 50)
objects[21].LayoutOrder = 2
objects[21].ZIndex = 5
objects[21].BackgroundTransparency = 1
objects[21].BorderSizePixel = 0
objects[21].Text = currentActivePriceStr
objects[21].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[21].TextTransparency = 0
objects[21].TextSize = 50
objects[21].TextScaled = false
objects[21].TextWrapped = false
objects[21].TextXAlignment = Enum.TextXAlignment.Left
objects[21].TextYAlignment = Enum.TextYAlignment.Center
objects[21].Font = Enum.Font.BuilderSansBold
objects[21].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[21].Parent = amountRow

-- Fee Disclaimer 2-row container with increased gap between the two rows
local feeContainer = Instance.new("Frame")
feeContainer.Name = "FeeDisclaimerContainer"
feeContainer.Size = UDim2.new(1, -20, 0, 42)
feeContainer.Position = UDim2.new(0.5, 0, 0, 70)
feeContainer.AnchorPoint = Vector2.new(0.5, 0)
feeContainer.BackgroundTransparency = 1
feeContainer.ZIndex = 5
feeContainer.Parent = amountPanel

local feeLayout = Instance.new("UIListLayout")
feeLayout.SortOrder = Enum.SortOrder.LayoutOrder
feeLayout.FillDirection = Enum.FillDirection.Vertical
feeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
feeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
feeLayout.Padding = UDim.new(0, 4) -- Gap between rows
feeLayout.Parent = feeContainer

local calculatedCut = math.floor((tonumber(currentActivePriceNum) or 10) * 0.9)

local feeLine1 = Instance.new("TextLabel")
feeLine1.Name = "FeeLine1"
feeLine1.LayoutOrder = 1
feeLine1.AutomaticSize = Enum.AutomaticSize.XY
feeLine1.BackgroundTransparency = 1
feeLine1.BorderSizePixel = 0
feeLine1.TextColor3 = Color3.fromRGB(229, 229, 231)
feeLine1.TextSize = 13.5
feeLine1.Font = Enum.Font.GothamMedium
feeLine1.Text = "The recipient will get " .. tostring(calculatedCut) .. " Robux after fees. In-game transfers include"
feeLine1.ZIndex = 5
feeLine1.Parent = feeContainer

local feeLine2 = Instance.new("TextLabel")
feeLine2.Name = "FeeLine2"
feeLine2.LayoutOrder = 2
feeLine2.AutomaticSize = Enum.AutomaticSize.XY
feeLine2.BackgroundTransparency = 1
feeLine2.BorderSizePixel = 0
feeLine2.TextColor3 = Color3.fromRGB(229, 229, 231)
feeLine2.TextSize = 13.5
feeLine2.Font = Enum.Font.GothamMedium
feeLine2.Text = "a 10% creator fee."
feeLine2.ZIndex = 5
feeLine2.Parent = feeContainer

local function updateTransferAmount(newAmount: number | string)
	local num = tonumber(newAmount) or 10
	currentActivePriceNum = num
	currentActivePriceStr = tostring(num)
	if objects[21] then
		objects[21].Text = currentActivePriceStr
	end
	if feeLine1 then
		local cut = math.floor(num * 0.9)
		feeLine1.Text = "The recipient will get " .. tostring(cut) .. " Robux after fees. In-game transfers include"
	end
end

local function setRecipient(username: string, displayName: string?)
	local user = tostring(username or "Powerbank225w")
	local disp = tostring(displayName or user)
	currentRecipientUser = user
	currentRecipientDisplay = disp
	currentActiveItemName = disp

	if objects[20] then
		objects[20].Text = disp
	end
	if recipientUsernameLabel then
		recipientUsernameLabel.Text = "@" .. user
	end
	updateRecipientAvatar(user)
end

-- ============================================================================
-- Footer: Send Button (BuyButton) and Legal Notice
-- ============================================================================
-- [[22: TextButton "BuyButton" (Send Robux Button)]]
objects[22] = Instance.new("TextButton")
objects[22].Name = "BuyButton"
objects[22].AutoButtonColor = false
objects[22].Selectable = false
objects[22].ClipsDescendants = true
objects[22].Size = UDim2.new(0, 420, 0, 40)
objects[22].Position = UDim2.new(0, 20, 0, 386)
objects[22].ZIndex = 5
objects[22].BackgroundColor3 = Color3.fromRGB(51, 95, 255)
objects[22].BorderSizePixel = 0
objects[22].Text = "Send"
objects[22].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[22].TextTransparency = 0
objects[22].TextSize = 16
objects[22].TextScaled = false
objects[22].TextWrapped = false
objects[22].TextXAlignment = Enum.TextXAlignment.Center
objects[22].TextYAlignment = Enum.TextYAlignment.Center
objects[22].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[22].Parent = buyView

objects[23] = Instance.new("UICorner")
objects[23].CornerRadius = UDim.new(0, 10)
objects[23].Parent = objects[22]

local buyButtonSizeConstraint = Instance.new("UISizeConstraint")
buyButtonSizeConstraint.MinSize = Vector2.new(420, 40)
buyButtonSizeConstraint.MaxSize = Vector2.new(420, 40)
buyButtonSizeConstraint.Parent = objects[22]

-- Buy Button Reveal Layer (Stationary dark layer on click)
local revealContainer = Instance.new("CanvasGroup")
revealContainer.Name = "RevealContainer"
revealContainer.Size = UDim2.new(1, 0, 1, 0)
revealContainer.Position = UDim2.new(0, 0, 0, 0)
revealContainer.BackgroundTransparency = 1
revealContainer.BorderSizePixel = 0
revealContainer.ZIndex = 7
revealContainer.Active = false
revealContainer.Parent = objects[22]

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = objects[23].CornerRadius
containerCorner.Parent = revealContainer

local revealOverlay = Instance.new("Frame")
revealOverlay.Name = "RevealOverlay"
revealOverlay.Size = UDim2.new(1, 0, 1, 0)
revealOverlay.Position = UDim2.new(0, 0, 0, 0)
revealOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
revealOverlay.BackgroundTransparency = 0.45
revealOverlay.BorderSizePixel = 0
revealOverlay.ZIndex = 8
revealOverlay.Active = false
revealOverlay.Parent = revealContainer

-- Legal Notice Text
local legalNotice = Instance.new("TextLabel")
legalNotice.Name = "LegalNotice"
legalNotice.Size = UDim2.new(0, 416, 0, 36)
legalNotice.Position = UDim2.new(0, 22, 0, 440)
legalNotice.BackgroundTransparency = 1
legalNotice.BorderSizePixel = 0
legalNotice.Text = "You need an age check or parental consent to send Robux. Once you send, you cannot cancel."
legalNotice.TextColor3 = Color3.fromRGB(229, 229, 231)
legalNotice.TextSize = 8
legalNotice.TextWrapped = true
legalNotice.TextXAlignment = Enum.TextXAlignment.Left
legalNotice.TextYAlignment = Enum.TextYAlignment.Top
legalNotice.ZIndex = 4
legalNotice.Parent = buyView

-- ============================================================================
-- View 2: Purchase Completed Modal View (Exact match to User's Mockup)
-- ============================================================================
local successView = Instance.new("Frame")
successView.Name = "SuccessView"
successView.Size = UDim2.new(1, 0, 1, 0)
successView.BackgroundTransparency = 1
successView.ZIndex = 3
successView.Visible = false
successView.Parent = objects[6]

-- Success Top-Left Logo Image (Shown when modal is Send Robux / Error mode)
local successLogo = Instance.new("ImageLabel")
successLogo.Name = "SuccessRobloxLogo"
successLogo.Size = UDim2.new(0, 22, 0, 22)
successLogo.Position = UDim2.new(0, 20, 0, 21)
successLogo.ZIndex = 4
successLogo.BackgroundTransparency = 1
successLogo.BorderSizePixel = 0
successLogo.Image = "rbxassetid://125746152594286"
successLogo.ScaleType = Enum.ScaleType.Fit
successLogo.Visible = false
successLogo.Parent = successView

-- Success Header: "Purchase completed" or "Send Robux"
local successTitle = Instance.new("TextLabel")
successTitle.Name = "SuccessTitle"
successTitle.Size = UDim2.new(0, 320, 0, 28)
successTitle.Position = UDim2.new(0, 20, 0, 18)
successTitle.BackgroundTransparency = 1
successTitle.BorderSizePixel = 0
successTitle.Text = "Purchase completed"
successTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
successTitle.TextSize = 26
successTitle.TextScaled = false
successTitle.TextWrapped = false
successTitle.TextXAlignment = Enum.TextXAlignment.Left
successTitle.TextYAlignment = Enum.TextYAlignment.Center
successTitle.FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
successTitle.ZIndex = 4
successTitle.Parent = successView

-- Success Close Button (Top right 'X')
local successCloseBtn = Instance.new("TextButton")
successCloseBtn.Name = "SuccessCloseButton"
successCloseBtn.AutoButtonColor = false
successCloseBtn.Size = UDim2.new(0, 24, 0, 26)
successCloseBtn.Position = UDim2.new(0, 412, 0, 17)
successCloseBtn.ZIndex = 7
successCloseBtn.BackgroundTransparency = 1
successCloseBtn.Text = ""
successCloseBtn.Parent = successView

local successCloseLine1 = Instance.new("Frame")
successCloseLine1.Name = "Line1"
successCloseLine1.Size = UDim2.new(0, 2, 0, 17)
successCloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
successCloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
successCloseLine1.Rotation = 45
successCloseLine1.ZIndex = 8
successCloseLine1.BackgroundColor3 = Color3.fromRGB(161, 161, 170)
successCloseLine1.BorderSizePixel = 0
successCloseLine1.Parent = successCloseBtn

local successCloseLine2 = Instance.new("Frame")
successCloseLine2.Name = "Line2"
successCloseLine2.Size = UDim2.new(0, 2, 0, 17)
successCloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
successCloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
successCloseLine2.Rotation = -45
successCloseLine2.ZIndex = 8
successCloseLine2.BackgroundColor3 = Color3.fromRGB(161, 161, 170)
successCloseLine2.BorderSizePixel = 0
successCloseLine2.Parent = successCloseBtn

-- Center Checkmark Circle Icon
local successIcon = Instance.new("ImageLabel")
successIcon.Name = "SuccessIcon"
successIcon.Size = UDim2.new(0, 56, 0, 56)
successIcon.Position = UDim2.new(0.5, 0, 0, 104)
successIcon.AnchorPoint = Vector2.new(0.5, 0.5)
successIcon.BackgroundTransparency = 1
successIcon.BorderSizePixel = 0
successIcon.Image = "rbxassetid://98579402919536"
successIcon.ScaleType = Enum.ScaleType.Fit
successIcon.ZIndex = 5
successIcon.Parent = successView

-- Success Description: "You have successfully bought <ItemName>."
local successDesc = Instance.new("TextLabel")
successDesc.Name = "SuccessDescription"
successDesc.Size = UDim2.new(1, -40, 0, 24)
successDesc.Position = UDim2.new(0.5, 0, 0, 153)
successDesc.AnchorPoint = Vector2.new(0.5, 0.5)
successDesc.BackgroundTransparency = 1
successDesc.BorderSizePixel = 0
successDesc.Text = "You send " .. tostring(currentActivePriceStr) .. " Robux"
successDesc.TextColor3 = Color3.fromRGB(215, 220, 230)
successDesc.TextSize = 16
successDesc.Font = Enum.Font.BuilderSansMedium
successDesc.FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
successDesc.TextXAlignment = Enum.TextXAlignment.Center
successDesc.TextYAlignment = Enum.TextYAlignment.Center
successDesc.ZIndex = 5
successDesc.Parent = successView

-- Bottom Blue "OK" Button
local okButton = Instance.new("TextButton")
okButton.Name = "OkButton"
okButton.AutoButtonColor = false
okButton.Selectable = false
okButton.Size = UDim2.new(0, 410, 0, 42)
okButton.Position = UDim2.new(0, 20, 0, 186)
okButton.ZIndex = 5
okButton.BackgroundColor3 = Color3.fromRGB(57, 105, 252)
okButton.BorderSizePixel = 0
okButton.Text = "OK"
okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
okButton.TextSize = 18
okButton.Font = Enum.Font.BuilderSansBold
okButton.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
okButton.Parent = successView

local okCorner = Instance.new("UICorner")
okCorner.CornerRadius = UDim.new(0, 10)
okCorner.Parent = okButton

-- Prevent game hover scripts from enlarging / scaling the OK button
local okButtonSizeConstraint = Instance.new("UISizeConstraint")
okButtonSizeConstraint.Name = "OkButtonSizeConstraint"
okButtonSizeConstraint.MinSize = Vector2.new(410, 42)
okButtonSizeConstraint.MaxSize = Vector2.new(410, 42)
okButtonSizeConstraint.Parent = okButton

okButton.ChildAdded:Connect(function(child)
	if child:IsA("UIScale") then
		task.defer(function()
			child:Destroy()
		end)
	end
end)

-- ============================================================================
-- Dynamic Balance / Amount Position Sync
-- ============================================================================

local function updateAmountDisplay(amountStr: string)
	local sanitized = tostring(amountStr)
	currentTotalAmount = sanitized
	local formatted = formatWithCommas(sanitized)
	objects[11].Text = formatted

	local charLen = string.len(formatted)
	local calculatedWidth = math.clamp(charLen * 12 + 4, 20, 140)

	-- Move closer to close button (which is at X = 418)
	-- Amount label right edge is at X = 414 (only 4px gap to CloseButton)
	local rightX = 414
	objects[11].Size = UDim2.new(0, calculatedWidth, 0, 26)
	objects[11].Position = UDim2.new(0, rightX - calculatedWidth, 0, 19)
	objects[32].Position = UDim2.new(0, rightX - calculatedWidth - 23, 0, 20)
end

updateAmountDisplay(currentTotalAmount)

-- ============================================================================
-- State & Animation Controller for Modal
-- ============================================================================

local isModalOpen = false
local isModalBusy = false
local currentRevealTween: Tween? = nil

local isPendingBuy = false
local isProcessingPurchase = false

local function playReveal()
	if currentRevealTween then
		currentRevealTween:Cancel()
	end
	revealContainer.Visible = true
	revealOverlay.Position = UDim2.new(0, 0, 0, 0)
	local tween = TweenService:Create(
		revealOverlay,
		TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(1, 0, 0, 0)}
	)
	currentRevealTween = tween
	tween:Play()
	tween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			revealContainer.Visible = false
			currentRevealTween = nil
		end
	end)
end

local function openModal()
	if isModalBusy or isModalOpen then return end
	isModalBusy = true

	-- Always start with BuyView visible and SuccessView hidden
	buyView.Visible = true
	successView.Visible = false
	updateAmountDisplay(currentTotalAmount)
	objects[6].Size = UDim2.new(0, 460, 0, 496)
	objects[3].Size = UDim2.new(0, 460, 0, 496)

	objects[2].Visible = true
	objects[2].BackgroundTransparency = 1
	objects[3].Position = UDim2.new(0.5, 0, 0.491261, 52)
	objects[3].BackgroundTransparency = 0.7
	updateModalResponsiveScale()
	objects[6].Position = UDim2.new(0.5, 0, 0.5, 45)
	objects[6].GroupTransparency = 0.4
	revealContainer.Visible = true
	revealOverlay.Position = UDim2.new(0, 0, 0, 0)

	local moveInfo = TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local overlayInfo = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tPosModal = TweenService:Create(objects[6], moveInfo, {Position = UDim2.new(0.5, 0, 0.5, 0)})
	local tPosShadow = TweenService:Create(objects[3], moveInfo, {Position = UDim2.new(0.5, 0, 0.491261, 7)})
	local tFadeModal = TweenService:Create(objects[6], fadeInfo, {GroupTransparency = 0})
	local tFadeShadow = TweenService:Create(objects[3], fadeInfo, {BackgroundTransparency = 0.5})
	local tFadeOverlay = TweenService:Create(objects[2], overlayInfo, {BackgroundTransparency = 0.4})

	tPosModal:Play()
	tPosShadow:Play()
	tFadeModal:Play()
	tFadeShadow:Play()
	tFadeOverlay:Play()

	task.delay(0.08, function()
		if isModalOpen or isModalBusy then
			playReveal()
		end
	end)

	tPosModal.Completed:Wait()

	isModalOpen = true
	isModalBusy = false
	objects[1]:SetAttribute("IsOpen", true)
end

local amountTextBox: TextBox
local minDelayInput: TextBox
local maxDelayInput: TextBox
local donatedInput: TextBox
local raisedInput: TextBox
local toggleKnob: Frame
local toggleSwitch: TextButton
local keybindButton: TextButton
local addLog: (message: string, tag: string?) -> ()

local function closeModal(isNormalClose: boolean?)
	if isModalBusy or not isModalOpen then return end
	isModalBusy = true
	isModalOpen = false
	objects[1]:SetAttribute("IsOpen", false)

	if currentRevealTween then
		currentRevealTween:Cancel()
		currentRevealTween = nil
	end

	-- Direct instant close: border, fill, and shadow vanish simultaneously with zero lingering border
	objects[2].Visible = false
	objects[6].GroupTransparency = 1
	objects[3].BackgroundTransparency = 1
	objects[2].BackgroundTransparency = 1
	objects[6].Position = UDim2.new(0.5, 0, 0.5, 45)
	objects[3].Position = UDim2.new(0.5, 0, 0.491261, 52)
	revealOverlay.Position = UDim2.new(0, 0, 0, 0)
	revealContainer.Visible = false
	objects[22].BackgroundColor3 = Color3.fromRGB(51, 95, 255)
	isModalBusy = false

	-- POST-CLOSE LOGIC: Modal is now completely closed!
	-- Deduct Robux balance if pending buy
	if isPendingBuy then
		isPendingBuy = false
		local currentBalance = tonumber((string.gsub(tostring(currentTotalAmount), "%D", ""))) or 0
		local cost = tonumber(currentActivePriceNum) or tonumber((string.gsub(tostring(currentActivePriceStr), "%D", ""))) or 0
		local newBalance = math.max(0, currentBalance - cost)
		local newBalanceStr = tostring(newBalance)

		currentTotalAmount = newBalanceStr
		updateAmountDisplay(newBalanceStr)
		if amountTextBox then
			amountTextBox.Text = newBalanceStr
		end
		objects[1]:SetAttribute("TotalAmount", currentTotalAmount)

		-- Increase Donated stat in player status (+ cost)
		addedDonatedOffset = addedDonatedOffset + cost
		local curCustom = tonumber((string.gsub(tostring(customDonatedStr), "%D", ""))) or 0
		customDonatedStr = tostring(curCustom + cost)
		if donatedInput and not donatedInput:IsFocused() then
			donatedInput.Text = formatWithCommas(getActiveDonated())
		end
		updatePlayerlistStats()

		-- Increase Giftbux Balance (1.5x / hafe se zeyada, e.g. 2 send -> 3 add)
		local giftbuxGain = math.max(1, math.ceil(cost * 1.5))
		if addGiftbux then
			addGiftbux(giftbuxGain)
		end

		saveConfigToStorage()

		if addLog then
			addLog(string.format("Modal closed! Deducted %d R$ | Donated: +%d (%s) | Giftbux: +%d", cost, cost, formatWithCommas(newDonated), giftbuxGain), "POPUP")
		end
	end

	-- Reset view visibility and modal sizes for next run
	buyView.Visible = true
	successView.Visible = false
	successTitle.Text = "Purchase completed"
	successIcon.Image = "rbxassetid://98579402919536"
	objects[6].Size = UDim2.new(0, 460, 0, 496)
	objects[3].Size = UDim2.new(0, 460, 0, 496)
	isProcessingPurchase = false
end

-- ============================================================================
-- Left-Side Settings Menu UI System
-- ============================================================================

local isListeningForKey = false
local isMenuOpen = false
local isMenuAnimating = false

local function getTimestamp(): string
	local success, result = pcall(function()
		return os.date("%X")
	end)
	if success and result then
		return result
	end
	return string.format("%.1fs", os.clock())
end

local menuShadow = Instance.new("Frame")
menuShadow.Name = "SettingsMenuShadow"
menuShadow.Size = UDim2.new(0, 310, 0, 480)
menuShadow.Position = UDim2.new(0, -340, 0.5, 4)
menuShadow.AnchorPoint = Vector2.new(0, 0.5)
menuShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
menuShadow.BackgroundTransparency = 0.6
menuShadow.BorderSizePixel = 0
menuShadow.ZIndex = 49
menuShadow.Parent = objects[1]

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = menuShadow

local shadowScale = Instance.new("UIScale")
shadowScale.Scale = 1.0
shadowScale.Parent = menuShadow

local menuFrame = Instance.new("Frame")
menuFrame.Name = "SettingsMenu"
menuFrame.Size = UDim2.new(0, 310, 0, 480)
menuFrame.Position = UDim2.new(0, -340, 0.5, 0)
menuFrame.AnchorPoint = Vector2.new(0, 0.5)
menuFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
menuFrame.BorderSizePixel = 0
menuFrame.ZIndex = 50
menuFrame.Parent = objects[1]

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 14)
menuCorner.Parent = menuFrame

local menuScale = Instance.new("UIScale")
menuScale.Scale = 1.0
menuScale.Parent = menuFrame

local function updateMenuResponsiveScale()
	local camera = workspace.CurrentCamera
	local vp = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
	local screenH = vp.Y
	local screenW = vp.X

	local targetScale = 1.0
	if UserInputService.TouchEnabled or screenH < 560 or screenW < 750 then
		local scaleH = (screenH * 0.86) / 480
		local scaleW = (screenW * 0.42) / 310
		targetScale = math.clamp(math.min(scaleH, scaleW), 0.48, 0.95)
	else
		targetScale = 1.0
	end

	menuScale.Scale = targetScale
	shadowScale.Scale = targetScale
end

updateMenuResponsiveScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuResponsiveScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local cam = workspace.CurrentCamera
	if cam then
		updateMenuResponsiveScale()
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuResponsiveScale)
	end
end)

local menuStroke = Instance.new("UIStroke")
menuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
menuStroke.Color = Color3.fromRGB(48, 54, 70)
menuStroke.Thickness = 1.2
menuStroke.Transparency = 0.2
menuStroke.Parent = menuFrame

-- Header
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 46)
headerFrame.BackgroundColor3 = Color3.fromRGB(23, 26, 35)
headerFrame.BorderSizePixel = 0
headerFrame.ZIndex = 51
headerFrame.Parent = menuFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = headerFrame

local headerBottomCover = Instance.new("Frame")
headerBottomCover.Name = "BottomCover"
headerBottomCover.Size = UDim2.new(1, 0, 0, 10)
headerBottomCover.Position = UDim2.new(0, 0, 1, -10)
headerBottomCover.BackgroundColor3 = Color3.fromRGB(23, 26, 35)
headerBottomCover.BorderSizePixel = 0
headerBottomCover.ZIndex = 51
headerBottomCover.Parent = headerFrame

local headerDivider = Instance.new("Frame")
headerDivider.Name = "HeaderDivider"
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.Position = UDim2.new(0, 0, 1, 0)
headerDivider.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
headerDivider.BorderSizePixel = 0
headerDivider.ZIndex = 52
headerDivider.Parent = headerFrame

local accentPill = Instance.new("Frame")
accentPill.Name = "AccentPill"
accentPill.Size = UDim2.new(0, 4, 0, 20)
accentPill.Position = UDim2.new(0, 14, 0.5, 0)
accentPill.AnchorPoint = Vector2.new(0, 0.5)
accentPill.BackgroundColor3 = Color3.fromRGB(57, 105, 252)
accentPill.BorderSizePixel = 0
accentPill.ZIndex = 53
accentPill.Parent = headerFrame

local accentPillCorner = Instance.new("UICorner")
accentPillCorner.CornerRadius = UDim.new(1, 0)
accentPillCorner.Parent = accentPill

local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "HeaderTitle"
headerTitle.Size = UDim2.new(0, 190, 0, 20)
headerTitle.Position = UDim2.new(0, 26, 0, 6)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "CONFIG & SETTINGS"
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.TextSize = 13
headerTitle.Font = Enum.Font.BuilderSansBold
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 53
headerTitle.Parent = headerFrame

local headerSubtitle = Instance.new("TextLabel")
headerSubtitle.Name = "HeaderSubtitle"
headerSubtitle.Size = UDim2.new(0, 190, 0, 14)
headerSubtitle.Position = UDim2.new(0, 26, 0, 25)
headerSubtitle.BackgroundTransparency = 1
headerSubtitle.Text = "VIP Popup Control Panel"
headerSubtitle.TextColor3 = Color3.fromRGB(130, 138, 158)
headerSubtitle.TextSize = 10
headerSubtitle.Font = Enum.Font.GothamMedium
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
headerSubtitle.ZIndex = 53
headerSubtitle.Parent = headerFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.AutoButtonColor = false
minimizeButton.Size = UDim2.new(0, 26, 0, 26)
minimizeButton.Position = UDim2.new(1, -34, 0.5, 0)
minimizeButton.AnchorPoint = Vector2.new(0, 0.5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(33, 37, 49)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "—"
minimizeButton.TextColor3 = Color3.fromRGB(180, 186, 204)
minimizeButton.TextSize = 13
minimizeButton.Font = Enum.Font.BuilderSansBold
minimizeButton.ZIndex = 54
minimizeButton.Parent = headerFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeButton

-- Content Scroll Frame
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, 0, 1, -48)
contentFrame.Position = UDim2.new(0, 0, 0, 48)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 3
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 68, 88)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.ZIndex = 51
contentFrame.Parent = menuFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 10)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.PaddingLeft = UDim.new(0, 12)
contentPadding.PaddingRight = UDim.new(0, 12)
contentPadding.Parent = contentFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 9)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = contentFrame

-- 0. Master Script Status Card (ON / OFF Toggle)
local masterCard = Instance.new("Frame")
masterCard.Name = "MasterSwitchCard"
masterCard.LayoutOrder = 0
masterCard.Size = UDim2.new(1, 0, 0, 52)
masterCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
masterCard.BorderSizePixel = 0
masterCard.ZIndex = 52
masterCard.Parent = contentFrame

local masterCorner = Instance.new("UICorner")
masterCorner.CornerRadius = UDim.new(0, 8)
masterCorner.Parent = masterCard

local masterStroke = Instance.new("UIStroke")
masterStroke.Color = Color3.fromRGB(42, 47, 62)
masterStroke.Thickness = 1
masterStroke.Parent = masterCard

local masterTitle = Instance.new("TextLabel")
masterTitle.Name = "Title"
masterTitle.Size = UDim2.new(1, -70, 0, 16)
masterTitle.Position = UDim2.new(0, 10, 0, 9)
masterTitle.BackgroundTransparency = 1
masterTitle.Text = "ENABLE SCRIPT (ON / OFF)"
masterTitle.TextColor3 = Color3.fromRGB(240, 243, 250)
masterTitle.TextSize = 12
masterTitle.Font = Enum.Font.BuilderSansBold
masterTitle.TextXAlignment = Enum.TextXAlignment.Left
masterTitle.ZIndex = 53
masterTitle.Parent = masterCard

local masterSub = Instance.new("TextLabel")
masterSub.Name = "Subtitle"
masterSub.Size = UDim2.new(1, -70, 0, 14)
masterSub.Position = UDim2.new(0, 10, 0, 26)
masterSub.BackgroundTransparency = 1
masterSub.Text = "Master switch for custom modal & blocker"
masterSub.TextColor3 = Color3.fromRGB(120, 128, 146)
masterSub.TextSize = 10
masterSub.Font = Enum.Font.GothamMedium
masterSub.TextXAlignment = Enum.TextXAlignment.Left
masterSub.ZIndex = 53
masterSub.Parent = masterCard

local masterSwitch = Instance.new("TextButton")
masterSwitch.Name = "MasterSwitch"
masterSwitch.AutoButtonColor = false
masterSwitch.Size = UDim2.new(0, 44, 0, 24)
masterSwitch.Position = UDim2.new(1, -54, 0.5, 0)
masterSwitch.AnchorPoint = Vector2.new(0, 0.5)
masterSwitch.BackgroundColor3 = isScriptEnabled and Color3.fromRGB(57, 105, 252) or Color3.fromRGB(42, 46, 58)
masterSwitch.BorderSizePixel = 0
masterSwitch.Text = ""
masterSwitch.ZIndex = 53
masterSwitch.Parent = masterCard

local masterSwitchCorner = Instance.new("UICorner")
masterSwitchCorner.CornerRadius = UDim.new(1, 0)
masterSwitchCorner.Parent = masterSwitch

local masterKnob = Instance.new("Frame")
masterKnob.Name = "Knob"
masterKnob.Size = UDim2.new(0, 18, 0, 18)
masterKnob.Position = isScriptEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
masterKnob.AnchorPoint = Vector2.new(0, 0.5)
masterKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
masterKnob.BorderSizePixel = 0
masterKnob.ZIndex = 54
masterKnob.Parent = masterSwitch

local masterKnobCorner = Instance.new("UICorner")
masterKnobCorner.CornerRadius = UDim.new(1, 0)
masterKnobCorner.Parent = masterKnob

-- 1. Total Amount Card
do
	local amountCard = Instance.new("Frame")
	amountCard.Name = "AmountCard"
	amountCard.LayoutOrder = 1
	amountCard.Size = UDim2.new(1, 0, 0, 62)
	amountCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	amountCard.BorderSizePixel = 0
	amountCard.ZIndex = 52
	amountCard.Parent = contentFrame

	local amountCardCorner = Instance.new("UICorner")
	amountCardCorner.CornerRadius = UDim.new(0, 8)
	amountCardCorner.Parent = amountCard

	local amountCardStroke = Instance.new("UIStroke")
	amountCardStroke.Color = Color3.fromRGB(42, 47, 62)
	amountCardStroke.Thickness = 1
	amountCardStroke.Parent = amountCard

	local amountLabelTitle = Instance.new("TextLabel")
	amountLabelTitle.Name = "Title"
	amountLabelTitle.Size = UDim2.new(1, -20, 0, 16)
	amountLabelTitle.Position = UDim2.new(0, 10, 0, 7)
	amountLabelTitle.BackgroundTransparency = 1
	amountLabelTitle.Text = "TOTAL AMOUNT"
	amountLabelTitle.TextColor3 = Color3.fromRGB(150, 158, 178)
	amountLabelTitle.TextSize = 10
	amountLabelTitle.Font = Enum.Font.GothamBold
	amountLabelTitle.TextXAlignment = Enum.TextXAlignment.Left
	amountLabelTitle.ZIndex = 53
	amountLabelTitle.Parent = amountCard

	local amountInputBoxFrame = Instance.new("Frame")
	amountInputBoxFrame.Name = "InputContainer"
	amountInputBoxFrame.Size = UDim2.new(1, -20, 0, 28)
	amountInputBoxFrame.Position = UDim2.new(0, 10, 0, 26)
	amountInputBoxFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	amountInputBoxFrame.BorderSizePixel = 0
	amountInputBoxFrame.ZIndex = 53
	amountInputBoxFrame.Parent = amountCard

	local amountInputCorner = Instance.new("UICorner")
	amountInputCorner.CornerRadius = UDim.new(0, 6)
	amountInputCorner.Parent = amountInputBoxFrame

	local amountInputStroke = Instance.new("UIStroke")
	amountInputStroke.Color = Color3.fromRGB(50, 56, 74)
	amountInputStroke.Thickness = 1
	amountInputStroke.Parent = amountInputBoxFrame

	local amountRobuxIcon = Instance.new("ImageLabel")
	amountRobuxIcon.Name = "RobuxIcon"
	amountRobuxIcon.Size = UDim2.new(0, 16, 0, 16)
	amountRobuxIcon.Position = UDim2.new(0, 8, 0.5, 0)
	amountRobuxIcon.AnchorPoint = Vector2.new(0, 0.5)
	amountRobuxIcon.BackgroundTransparency = 1
	amountRobuxIcon.Image = "rbxassetid://16884178261"
	amountRobuxIcon.ImageRectOffset = Vector2.new(190, 152)
	amountRobuxIcon.ImageRectSize = Vector2.new(36, 36)
	amountRobuxIcon.ZIndex = 54
	amountRobuxIcon.Parent = amountInputBoxFrame

	amountTextBox = Instance.new("TextBox")
	amountTextBox.Name = "AmountInput"
	amountTextBox.Size = UDim2.new(1, -34, 1, 0)
	amountTextBox.Position = UDim2.new(0, 30, 0, 0)
	amountTextBox.BackgroundTransparency = 1
	amountTextBox.Text = currentTotalAmount
	amountTextBox.PlaceholderText = "Set amount (e.g. 903)"
	amountTextBox.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
	amountTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	amountTextBox.TextSize = 13
	amountTextBox.Font = Enum.Font.BuilderSansBold
	amountTextBox.TextXAlignment = Enum.TextXAlignment.Left
	amountTextBox.ClearTextOnFocus = false
	amountTextBox.ZIndex = 54
	amountTextBox.Parent = amountInputBoxFrame
end

-- 2. Popup Delay Card
do
	local delayCard = Instance.new("Frame")
	delayCard.Name = "DelayCard"
	delayCard.LayoutOrder = 2
	delayCard.Size = UDim2.new(1, 0, 0, 94)
	delayCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	delayCard.BorderSizePixel = 0
	delayCard.ZIndex = 52
	delayCard.Parent = contentFrame

	local delayCardCorner = Instance.new("UICorner")
	delayCardCorner.CornerRadius = UDim.new(0, 8)
	delayCardCorner.Parent = delayCard

	local delayCardStroke = Instance.new("UIStroke")
	delayCardStroke.Color = Color3.fromRGB(42, 47, 62)
	delayCardStroke.Thickness = 1
	delayCardStroke.Parent = delayCard

	local delayTitle = Instance.new("TextLabel")
	delayTitle.Name = "Title"
	delayTitle.Size = UDim2.new(1, -20, 0, 16)
	delayTitle.Position = UDim2.new(0, 10, 0, 7)
	delayTitle.BackgroundTransparency = 1
	delayTitle.Text = "POPUP OPEN DELAY (SECONDS)"
	delayTitle.TextColor3 = Color3.fromRGB(150, 158, 178)
	delayTitle.TextSize = 10
	delayTitle.Font = Enum.Font.GothamBold
	delayTitle.TextXAlignment = Enum.TextXAlignment.Left
	delayTitle.ZIndex = 53
	delayTitle.Parent = delayCard

	-- Quick Selectable Preset Buttons Row
	local presetRow = Instance.new("Frame")
	presetRow.Name = "PresetRow"
	presetRow.Size = UDim2.new(1, -20, 0, 22)
	presetRow.Position = UDim2.new(0, 10, 0, 26)
	presetRow.BackgroundTransparency = 1
	presetRow.ZIndex = 53
	presetRow.Parent = delayCard

	local presetLayout = Instance.new("UIListLayout")
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	presetLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	presetLayout.Padding = UDim.new(0, 5)
	presetLayout.Parent = presetRow

	local presets = {
		{name = "0s Instant", min = 0.0, max = 0.0, width = 56},
		{name = "0.6 - 1.6s", min = 0.6, max = 1.6, width = 64},
		{name = "0.5s", min = 0.5, max = 0.5, width = 36},
		{name = "1.0s", min = 1.0, max = 1.0, width = 36},
		{name = "1 - 2s", min = 1.0, max = 2.0, width = 42},
	}
	local presetButtons = {}

	for _, p in ipairs(presets) do
		local btn = Instance.new("TextButton")
		btn.Name = "Preset_" .. p.name
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(0, p.width, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(33, 37, 50)
		btn.BorderSizePixel = 0
		btn.Text = p.name
		btn.TextColor3 = Color3.fromRGB(190, 198, 220)
		btn.TextSize = 9.5
		btn.Font = Enum.Font.BuilderSansBold
		btn.ZIndex = 54
		btn.Parent = presetRow

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 5)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = Color3.fromRGB(50, 56, 76)
		bStroke.Thickness = 1
		bStroke.Parent = btn

		btn.Activated:Connect(function()
			minPopupDelay = p.min
			maxPopupDelay = p.max
			if minDelayInput then
				minDelayInput.Text = string.format("%.1f", minPopupDelay)
			end
			if maxDelayInput then
				maxDelayInput.Text = string.format("%.1f", maxPopupDelay)
			end
			refreshDelayPresetsVisual()
			saveConfigToStorage()
			if addLog then
				addLog(string.format("Popup delay preset selected: Min=%.1fs, Max=%.1fs", minPopupDelay, maxPopupDelay), "CONFIG")
			end
		end)

		table.insert(presetButtons, {btn = btn, stroke = bStroke, p = p})
	end

	refreshDelayPresetsVisual = function()
		for _, item in ipairs(presetButtons) do
			local isMatch = (math.abs(minPopupDelay - item.p.min) < 0.05 and math.abs(maxPopupDelay - item.p.max) < 0.05)
			if isMatch then
				item.btn.BackgroundColor3 = Color3.fromRGB(57, 105, 252)
				item.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				item.stroke.Color = Color3.fromRGB(110, 150, 255)
			else
				item.btn.BackgroundColor3 = Color3.fromRGB(33, 37, 50)
				item.btn.TextColor3 = Color3.fromRGB(190, 198, 220)
				item.stroke.Color = Color3.fromRGB(50, 56, 76)
			end
		end
	end

	refreshDelayPresetsVisual()

	-- Custom Min/Max Inputs Row
	local delayInputsRow = Instance.new("Frame")
	delayInputsRow.Name = "DelayInputsRow"
	delayInputsRow.Size = UDim2.new(1, -20, 0, 26)
	delayInputsRow.Position = UDim2.new(0, 10, 0, 56)
	delayInputsRow.BackgroundTransparency = 1
	delayInputsRow.ZIndex = 53
	delayInputsRow.Parent = delayCard

	local delayRowLayout = Instance.new("UIListLayout")
	delayRowLayout.FillDirection = Enum.FillDirection.Horizontal
	delayRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	delayRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	delayRowLayout.Padding = UDim.new(0, 8)
	delayRowLayout.Parent = delayInputsRow

	-- Min Delay Box
	local minDelayBoxFrame = Instance.new("Frame")
	minDelayBoxFrame.Name = "MinBox"
	minDelayBoxFrame.Size = UDim2.new(0.5, -4, 1, 0)
	minDelayBoxFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	minDelayBoxFrame.BorderSizePixel = 0
	minDelayBoxFrame.ZIndex = 54
	minDelayBoxFrame.Parent = delayInputsRow

	local minCorner = Instance.new("UICorner")
	minCorner.CornerRadius = UDim.new(0, 6)
	minCorner.Parent = minDelayBoxFrame

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = Color3.fromRGB(50, 56, 74)
	minStroke.Thickness = 1
	minStroke.Parent = minDelayBoxFrame

	local minLabel = Instance.new("TextLabel")
	minLabel.Size = UDim2.new(0, 32, 1, 0)
	minLabel.Position = UDim2.new(0, 6, 0, 0)
	minLabel.BackgroundTransparency = 1
	minLabel.Text = "Min:"
	minLabel.TextColor3 = Color3.fromRGB(130, 138, 158)
	minLabel.Font = Enum.Font.BuilderSansBold
	minLabel.TextSize = 12
	minLabel.TextXAlignment = Enum.TextXAlignment.Left
	minLabel.ZIndex = 55
	minLabel.Parent = minDelayBoxFrame

	minDelayInput = Instance.new("TextBox")
	minDelayInput.Name = "MinDelayInput"
	minDelayInput.Size = UDim2.new(1, -40, 1, 0)
	minDelayInput.Position = UDim2.new(0, 36, 0, 0)
	minDelayInput.BackgroundTransparency = 1
	minDelayInput.Text = string.format("%.1f", minPopupDelay)
	minDelayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	minDelayInput.Font = Enum.Font.BuilderSansBold
	minDelayInput.TextSize = 13
	minDelayInput.ClearTextOnFocus = false
	minDelayInput.ZIndex = 55
	minDelayInput.Parent = minDelayBoxFrame

	-- Max Delay Box
	local maxDelayBoxFrame = Instance.new("Frame")
	maxDelayBoxFrame.Name = "MaxBox"
	maxDelayBoxFrame.Size = UDim2.new(0.5, -4, 1, 0)
	maxDelayBoxFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	maxDelayBoxFrame.BorderSizePixel = 0
	maxDelayBoxFrame.ZIndex = 54
	maxDelayBoxFrame.Parent = delayInputsRow

	local maxCorner = Instance.new("UICorner")
	maxCorner.CornerRadius = UDim.new(0, 6)
	maxCorner.Parent = maxDelayBoxFrame

	local maxStroke = Instance.new("UIStroke")
	maxStroke.Color = Color3.fromRGB(50, 56, 74)
	maxStroke.Thickness = 1
	maxStroke.Parent = maxDelayBoxFrame

	local maxLabel = Instance.new("TextLabel")
	maxLabel.Size = UDim2.new(0, 34, 1, 0)
	maxLabel.Position = UDim2.new(0, 6, 0, 0)
	maxLabel.BackgroundTransparency = 1
	maxLabel.Text = "Max:"
	maxLabel.TextColor3 = Color3.fromRGB(130, 138, 158)
	maxLabel.Font = Enum.Font.BuilderSansBold
	maxLabel.TextSize = 12
	maxLabel.TextXAlignment = Enum.TextXAlignment.Left
	maxLabel.ZIndex = 55
	maxLabel.Parent = maxDelayBoxFrame

	maxDelayInput = Instance.new("TextBox")
	maxDelayInput.Name = "MaxDelayInput"
	maxDelayInput.Size = UDim2.new(1, -42, 1, 0)
	maxDelayInput.Position = UDim2.new(0, 38, 0, 0)
	maxDelayInput.BackgroundTransparency = 1
	maxDelayInput.Text = string.format("%.1f", maxPopupDelay)
	maxDelayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	maxDelayInput.Font = Enum.Font.BuilderSansBold
	maxDelayInput.TextSize = 13
	maxDelayInput.ClearTextOnFocus = false
	maxDelayInput.ZIndex = 55
	maxDelayInput.Parent = maxDelayBoxFrame
end

-- 3. Auto-Hide Card
do
	local autoHideCard = Instance.new("Frame")
	autoHideCard.Name = "AutoHideCard"
	autoHideCard.LayoutOrder = 3
	autoHideCard.Size = UDim2.new(1, 0, 0, 52)
	autoHideCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	autoHideCard.BorderSizePixel = 0
	autoHideCard.ZIndex = 52
	autoHideCard.Parent = contentFrame

	local autoHideCorner = Instance.new("UICorner")
	autoHideCorner.CornerRadius = UDim.new(0, 8)
	autoHideCorner.Parent = autoHideCard

	local autoHideStroke = Instance.new("UIStroke")
	autoHideStroke.Color = Color3.fromRGB(42, 47, 62)
	autoHideStroke.Thickness = 1
	autoHideStroke.Parent = autoHideCard

	local autoHideTitle = Instance.new("TextLabel")
	autoHideTitle.Name = "Title"
	autoHideTitle.Size = UDim2.new(1, -70, 0, 16)
	autoHideTitle.Position = UDim2.new(0, 10, 0, 9)
	autoHideTitle.BackgroundTransparency = 1
	autoHideTitle.Text = "Start Hidden (Auto-Unshow)"
	autoHideTitle.TextColor3 = Color3.fromRGB(240, 243, 250)
	autoHideTitle.TextSize = 12
	autoHideTitle.Font = Enum.Font.BuilderSansBold
	autoHideTitle.TextXAlignment = Enum.TextXAlignment.Left
	autoHideTitle.ZIndex = 53
	autoHideTitle.Parent = autoHideCard

	local autoHideSub = Instance.new("TextLabel")
	autoHideSub.Name = "Subtitle"
	autoHideSub.Size = UDim2.new(1, -70, 0, 14)
	autoHideSub.Position = UDim2.new(0, 10, 0, 26)
	autoHideSub.BackgroundTransparency = 1
	autoHideSub.Text = "Hides menu initially on script run"
	autoHideSub.TextColor3 = Color3.fromRGB(120, 128, 146)
	autoHideSub.TextSize = 10
	autoHideSub.Font = Enum.Font.GothamMedium
	autoHideSub.TextXAlignment = Enum.TextXAlignment.Left
	autoHideSub.ZIndex = 53
	autoHideSub.Parent = autoHideCard

	toggleSwitch = Instance.new("TextButton")
	toggleSwitch.Name = "ToggleSwitch"
	toggleSwitch.AutoButtonColor = false
	toggleSwitch.Size = UDim2.new(0, 44, 0, 24)
	toggleSwitch.Position = UDim2.new(1, -54, 0.5, 0)
	toggleSwitch.AnchorPoint = Vector2.new(0, 0.5)
	toggleSwitch.BackgroundColor3 = autoHideOnRun and Color3.fromRGB(57, 105, 252) or Color3.fromRGB(42, 46, 58)
	toggleSwitch.BorderSizePixel = 0
	toggleSwitch.Text = ""
	toggleSwitch.ZIndex = 53
	toggleSwitch.Parent = autoHideCard

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(1, 0)
	toggleCorner.Parent = toggleSwitch

	toggleKnob = Instance.new("Frame")
	toggleKnob.Name = "Knob"
	toggleKnob.Size = UDim2.new(0, 18, 0, 18)
	toggleKnob.Position = autoHideOnRun and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	toggleKnob.AnchorPoint = Vector2.new(0, 0.5)
	toggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toggleKnob.BorderSizePixel = 0
	toggleKnob.ZIndex = 54
	toggleKnob.Parent = toggleSwitch

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = toggleKnob
end

-- 4. Keybind Card
do
	local keybindCard = Instance.new("Frame")
	keybindCard.Name = "KeybindCard"
	keybindCard.LayoutOrder = 4
	keybindCard.Size = UDim2.new(1, 0, 0, 52)
	keybindCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	keybindCard.BorderSizePixel = 0
	keybindCard.ZIndex = 52
	keybindCard.Parent = contentFrame

	local keybindCorner = Instance.new("UICorner")
	keybindCorner.CornerRadius = UDim.new(0, 8)
	keybindCorner.Parent = keybindCard

	local keybindStroke = Instance.new("UIStroke")
	keybindStroke.Color = Color3.fromRGB(42, 47, 62)
	keybindStroke.Thickness = 1
	keybindStroke.Parent = keybindCard

	local keybindTitle = Instance.new("TextLabel")
	keybindTitle.Name = "Title"
	keybindTitle.Size = UDim2.new(1, -110, 0, 16)
	keybindTitle.Position = UDim2.new(0, 10, 0, 9)
	keybindTitle.BackgroundTransparency = 1
	keybindTitle.Text = "Toggle Keybind"
	keybindTitle.TextColor3 = Color3.fromRGB(240, 243, 250)
	keybindTitle.TextSize = 12
	keybindTitle.Font = Enum.Font.BuilderSansBold
	keybindTitle.TextXAlignment = Enum.TextXAlignment.Left
	keybindTitle.ZIndex = 53
	keybindTitle.Parent = keybindCard

	local keybindSub = Instance.new("TextLabel")
	keybindSub.Name = "Subtitle"
	keybindSub.Size = UDim2.new(1, -110, 0, 14)
	keybindSub.Position = UDim2.new(0, 10, 0, 26)
	keybindSub.BackgroundTransparency = 1
	keybindSub.Text = "Show / unshow this menu"
	keybindSub.TextColor3 = Color3.fromRGB(120, 128, 146)
	keybindSub.TextSize = 10
	keybindSub.Font = Enum.Font.GothamMedium
	keybindSub.TextXAlignment = Enum.TextXAlignment.Left
	keybindSub.ZIndex = 53
	keybindSub.Parent = keybindCard

	keybindButton = Instance.new("TextButton")
	keybindButton.Name = "KeybindButton"
	keybindButton.AutoButtonColor = false
	keybindButton.Size = UDim2.new(0, 86, 0, 28)
	keybindButton.Position = UDim2.new(1, -96, 0.5, 0)
	keybindButton.AnchorPoint = Vector2.new(0, 0.5)
	keybindButton.BackgroundColor3 = Color3.fromRGB(33, 37, 50)
	keybindButton.BorderSizePixel = 0
	keybindButton.Text = "[ " .. currentKeybind.Name .. " ]"
	keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	keybindButton.TextSize = 12
	keybindButton.Font = Enum.Font.BuilderSansBold
	keybindButton.ZIndex = 53
	keybindButton.Parent = keybindCard

	local keyButtonCorner = Instance.new("UICorner")
	keyButtonCorner.CornerRadius = UDim.new(0, 6)
	keyButtonCorner.Parent = keybindButton

	local keyButtonStroke = Instance.new("UIStroke")
	keyButtonStroke.Color = Color3.fromRGB(56, 62, 82)
	keyButtonStroke.Thickness = 1
	keyButtonStroke.Parent = keybindButton
end

-- 5. Preview Modal Quick Trigger Button
local testButton = Instance.new("TextButton")
testButton.Name = "TestButton"
testButton.LayoutOrder = 5
testButton.AutoButtonColor = false
testButton.Size = UDim2.new(1, 0, 0, 30)
testButton.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
testButton.BorderSizePixel = 0
testButton.Text = "👁️ Preview Send Robux Popup"
testButton.TextColor3 = Color3.fromRGB(215, 222, 240)
testButton.TextSize = 12
testButton.Font = Enum.Font.BuilderSansBold
testButton.ZIndex = 52
testButton.Parent = contentFrame

local testButtonCorner = Instance.new("UICorner")
testButtonCorner.CornerRadius = UDim.new(0, 8)
testButtonCorner.Parent = testButton

local testButtonStroke = Instance.new("UIStroke")
testButtonStroke.Color = Color3.fromRGB(48, 56, 76)
testButtonStroke.Thickness = 1
testButtonStroke.Parent = testButton

testButton.MouseEnter:Connect(function()
	TweenService:Create(testButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(36, 42, 58)}):Play()
end)

testButton.MouseLeave:Connect(function()
	TweenService:Create(testButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28, 32, 44)}):Play()
end)

testButton.Activated:Connect(function()
	if isModalOpen then
		closeModal(true)
	else
		local minD = math.max(0, tonumber(minPopupDelay) or 0)
		local maxD = math.max(minD, tonumber(maxPopupDelay) or minD)
		local delaySec = (maxD > minD) and (minD + (math.random() * (maxD - minD))) or minD

		if delaySec > 0 then
			if addLog then
				addLog(string.format("Preview delay active: waiting %.2fs before opening...", delaySec), "POPUP")
			end
			task.spawn(function()
				task.wait(delaySec)
				if not isModalOpen and not isModalBusy then
					openModal()
				end
			end)
		else
			openModal()
		end
	end
end)

-- 6. Player Stats Editor Card (Donated & Raised with Original Toggle)
do
	local statsCard = Instance.new("Frame")
	statsCard.Name = "StatsCard"
	statsCard.LayoutOrder = 6
	statsCard.Size = UDim2.new(1, 0, 0, 108)
	statsCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	statsCard.BorderSizePixel = 0
	statsCard.ZIndex = 52
	statsCard.Parent = contentFrame

	local statsCardCorner = Instance.new("UICorner")
	statsCardCorner.CornerRadius = UDim.new(0, 8)
	statsCardCorner.Parent = statsCard

	local statsCardStroke = Instance.new("UIStroke")
	statsCardStroke.Color = Color3.fromRGB(42, 47, 62)
	statsCardStroke.Thickness = 1
	statsCardStroke.Parent = statsCard

	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "Title"
	statsTitle.Size = UDim2.new(1, -20, 0, 16)
	statsTitle.Position = UDim2.new(0, 10, 0, 7)
	statsTitle.BackgroundTransparency = 1
	statsTitle.Text = "PLAYER STATS (DONATED & RAISED)"
	statsTitle.TextColor3 = Color3.fromRGB(150, 158, 178)
	statsTitle.TextSize = 10
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.ZIndex = 53
	statsTitle.Parent = statsCard

	-- Container for both inputs (Donated & Raised)
	local inputsRow = Instance.new("Frame")
	inputsRow.Name = "InputsRow"
	inputsRow.Size = UDim2.new(1, -20, 0, 48)
	inputsRow.Position = UDim2.new(0, 10, 0, 24)
	inputsRow.BackgroundTransparency = 1
	inputsRow.ZIndex = 53
	inputsRow.Parent = statsCard

	-- Donated Column (Left)
	local donatedCol = Instance.new("Frame")
	donatedCol.Name = "DonatedCol"
	donatedCol.Size = UDim2.new(0.5, -5, 1, 0)
	donatedCol.Position = UDim2.new(0, 0, 0, 0)
	donatedCol.BackgroundTransparency = 1
	donatedCol.ZIndex = 53
	donatedCol.Parent = inputsRow

	local donatedLbl = Instance.new("TextLabel")
	donatedLbl.Size = UDim2.new(1, 0, 0, 14)
	donatedLbl.BackgroundTransparency = 1
	donatedLbl.Text = "DONATED"
	donatedLbl.TextColor3 = Color3.fromRGB(130, 138, 155)
	donatedLbl.TextSize = 9
	donatedLbl.Font = Enum.Font.GothamBold
	donatedLbl.TextXAlignment = Enum.TextXAlignment.Left
	donatedLbl.ZIndex = 54
	donatedLbl.Parent = donatedCol

	local donatedBoxFrame = Instance.new("Frame")
	donatedBoxFrame.Size = UDim2.new(1, 0, 0, 28)
	donatedBoxFrame.Position = UDim2.new(0, 0, 0, 16)
	donatedBoxFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	donatedBoxFrame.BorderSizePixel = 0
	donatedBoxFrame.ZIndex = 54
	donatedBoxFrame.Parent = donatedCol

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 6)
	dCorner.Parent = donatedBoxFrame

	local dStroke = Instance.new("UIStroke")
	dStroke.Color = Color3.fromRGB(50, 56, 74)
	dStroke.Thickness = 1
	dStroke.Parent = donatedBoxFrame

	local dIcon = Instance.new("ImageLabel")
	dIcon.Size = UDim2.new(0, 14, 0, 14)
	dIcon.Position = UDim2.new(0, 6, 0.5, 0)
	dIcon.AnchorPoint = Vector2.new(0, 0.5)
	dIcon.BackgroundTransparency = 1
	dIcon.Image = "rbxassetid://16884178261"
	dIcon.ImageRectOffset = Vector2.new(190, 152)
	dIcon.ImageRectSize = Vector2.new(36, 36)
	dIcon.ZIndex = 55
	dIcon.Parent = donatedBoxFrame

	donatedInput = Instance.new("TextBox")
	donatedInput.Name = "DonatedInput"
	donatedInput.Size = UDim2.new(1, -26, 1, 0)
	donatedInput.Position = UDim2.new(0, 24, 0, 0)
	donatedInput.BackgroundTransparency = 1
	donatedInput.Text = formatWithCommas(getActiveDonated())
	donatedInput.PlaceholderText = "190"
	donatedInput.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
	donatedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	donatedInput.TextSize = 12
	donatedInput.Font = Enum.Font.BuilderSansBold
	donatedInput.TextXAlignment = Enum.TextXAlignment.Left
	donatedInput.ClearTextOnFocus = false
	donatedInput.ZIndex = 55
	donatedInput.Parent = donatedBoxFrame

	-- Raised Column (Right)
	local raisedCol = Instance.new("Frame")
	raisedCol.Name = "RaisedCol"
	raisedCol.Size = UDim2.new(0.5, -5, 1, 0)
	raisedCol.Position = UDim2.new(0.5, 5, 0, 0)
	raisedCol.BackgroundTransparency = 1
	raisedCol.ZIndex = 53
	raisedCol.Parent = inputsRow

	local raisedLbl = Instance.new("TextLabel")
	raisedLbl.Size = UDim2.new(1, 0, 0, 14)
	raisedLbl.BackgroundTransparency = 1
	raisedLbl.Text = "RAISED"
	raisedLbl.TextColor3 = Color3.fromRGB(130, 138, 155)
	raisedLbl.TextSize = 9
	raisedLbl.Font = Enum.Font.GothamBold
	raisedLbl.TextXAlignment = Enum.TextXAlignment.Left
	raisedLbl.ZIndex = 54
	raisedLbl.Parent = raisedCol

	local raisedBoxFrame = Instance.new("Frame")
	raisedBoxFrame.Size = UDim2.new(1, 0, 0, 28)
	raisedBoxFrame.Position = UDim2.new(0, 0, 0, 16)
	raisedBoxFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	raisedBoxFrame.BorderSizePixel = 0
	raisedBoxFrame.ZIndex = 54
	raisedBoxFrame.Parent = raisedCol

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 6)
	rCorner.Parent = raisedBoxFrame

	local rStroke = Instance.new("UIStroke")
	rStroke.Color = Color3.fromRGB(50, 56, 74)
	rStroke.Thickness = 1
	rStroke.Parent = raisedBoxFrame

	local rIcon = Instance.new("ImageLabel")
	rIcon.Size = UDim2.new(0, 14, 0, 14)
	rIcon.Position = UDim2.new(0, 6, 0.5, 0)
	rIcon.AnchorPoint = Vector2.new(0, 0.5)
	rIcon.BackgroundTransparency = 1
	rIcon.Image = "rbxassetid://16884178261"
	rIcon.ImageRectOffset = Vector2.new(190, 152)
	rIcon.ImageRectSize = Vector2.new(36, 36)
	rIcon.ZIndex = 55
	rIcon.Parent = raisedBoxFrame

	raisedInput = Instance.new("TextBox")
	raisedInput.Name = "RaisedInput"
	raisedInput.Size = UDim2.new(1, -26, 1, 0)
	raisedInput.Position = UDim2.new(0, 24, 0, 0)
	raisedInput.BackgroundTransparency = 1
	raisedInput.Text = formatWithCommas(getActiveRaised())
	raisedInput.PlaceholderText = "190"
	raisedInput.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
	raisedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	raisedInput.TextSize = 12
	raisedInput.Font = Enum.Font.BuilderSansBold
	raisedInput.TextXAlignment = Enum.TextXAlignment.Left
	raisedInput.ClearTextOnFocus = false
	raisedInput.ZIndex = 55
	raisedInput.Parent = raisedBoxFrame

	-- Small Original toggle button below both inputs
	local originalBtn = Instance.new("TextButton")
	originalBtn.Name = "OriginalButton"
	originalBtn.AutoButtonColor = false
	originalBtn.Size = UDim2.new(0, 80, 0, 22)
	originalBtn.Position = UDim2.new(0, 10, 0, 78)
	originalBtn.BackgroundColor3 = useOriginalStats and Color3.fromRGB(38, 140, 80) or Color3.fromRGB(35, 40, 54)
	originalBtn.BorderSizePixel = 0
	originalBtn.Text = useOriginalStats and "[✓] Original" or "Original"
	originalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	originalBtn.TextSize = 10
	originalBtn.Font = Enum.Font.BuilderSansBold
	originalBtn.ZIndex = 55
	originalBtn.Parent = statsCard

	local origCorner = Instance.new("UICorner")
	origCorner.CornerRadius = UDim.new(0, 5)
	origCorner.Parent = originalBtn

	local origStroke = Instance.new("UIStroke")
	origStroke.Color = useOriginalStats and Color3.fromRGB(60, 180, 110) or Color3.fromRGB(50, 56, 74)
	origStroke.Thickness = 1
	origStroke.Parent = originalBtn

	-- Small VIP Name Tag toggle button next to Original button
	local vipTagBtn = Instance.new("TextButton")
	vipTagBtn.Name = "VipTagButton"
	vipTagBtn.AutoButtonColor = false
	vipTagBtn.Size = UDim2.new(0, 36, 0, 22)
	vipTagBtn.Position = UDim2.new(0, 96, 0, 78)
	vipTagBtn.BackgroundColor3 = isVipNameTagEnabled and Color3.fromRGB(38, 140, 80) or Color3.fromRGB(35, 40, 54)
	vipTagBtn.BorderSizePixel = 0
	vipTagBtn.Text = "\xee\x80\x81"
	vipTagBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	vipTagBtn.TextSize = 13
	vipTagBtn.Font = Enum.Font.BuilderSansBold
	vipTagBtn.ZIndex = 55
	vipTagBtn.Parent = statsCard

	local vipCorner = Instance.new("UICorner")
	vipCorner.CornerRadius = UDim.new(0, 5)
	vipCorner.Parent = vipTagBtn

	local vipStroke = Instance.new("UIStroke")
	vipStroke.Color = isVipNameTagEnabled and Color3.fromRGB(60, 180, 110) or Color3.fromRGB(50, 56, 74)
	vipStroke.Thickness = 1
	vipStroke.Parent = vipTagBtn

	-- Fire Streak Container & Input next to VIP button
	local fireFrame = Instance.new("Frame")
	fireFrame.Name = "FireContainer"
	fireFrame.Size = UDim2.new(0, 70, 0, 22)
	fireFrame.Position = UDim2.new(0, 138, 0, 78)
	fireFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	fireFrame.BorderSizePixel = 0
	fireFrame.ZIndex = 54
	fireFrame.Parent = statsCard

	local fireCorner = Instance.new("UICorner")
	fireCorner.CornerRadius = UDim.new(0, 5)
	fireCorner.Parent = fireFrame

	local fireStroke = Instance.new("UIStroke")
	fireStroke.Color = Color3.fromRGB(50, 56, 74)
	fireStroke.Thickness = 1
	fireStroke.Parent = fireFrame

	local fireIcon = Instance.new("TextLabel")
	fireIcon.Name = "FireIcon"
	fireIcon.Size = UDim2.new(0, 20, 1, 0)
	fireIcon.Position = UDim2.new(0, 2, 0, 0)
	fireIcon.BackgroundTransparency = 1
	fireIcon.Text = "🔥"
	fireIcon.TextSize = 12
	fireIcon.Font = Enum.Font.BuilderSansBold
	fireIcon.ZIndex = 55
	fireIcon.Parent = fireFrame

	local fireInput = Instance.new("TextBox")
	fireInput.Name = "FireInput"
	fireInput.Size = UDim2.new(1, -24, 1, 0)
	fireInput.Position = UDim2.new(0, 22, 0, 0)
	fireInput.BackgroundTransparency = 1
	fireInput.Text = (customFireStreak > 0) and tostring(customFireStreak) or ""
	fireInput.PlaceholderText = "0"
	fireInput.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
	fireInput.TextColor3 = Color3.fromRGB(255, 150, 50)
	fireInput.TextSize = 11
	fireInput.Font = Enum.Font.BuilderSansBold
	fireInput.TextXAlignment = Enum.TextXAlignment.Center
	fireInput.ClearTextOnFocus = false
	fireInput.ZIndex = 55
	fireInput.Parent = fireFrame

	local function refreshStatsCardUI()
		inputsRow.Visible = true
		statsCard.Size = UDim2.new(1, 0, 0, 108)

		if useOriginalStats then
			originalBtn.BackgroundColor3 = Color3.fromRGB(38, 140, 80)
			origStroke.Color = Color3.fromRGB(60, 180, 110)
			originalBtn.Text = "[✓] Original"
		else
			originalBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 54)
			origStroke.Color = Color3.fromRGB(50, 56, 74)
			originalBtn.Text = "Original"
		end

		if isVipNameTagEnabled then
			vipTagBtn.BackgroundColor3 = Color3.fromRGB(38, 140, 80)
			vipStroke.Color = Color3.fromRGB(60, 180, 110)
		else
			vipTagBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 54)
			vipStroke.Color = Color3.fromRGB(50, 56, 74)
		end
	end

	refreshVipButtonVisual = function()
		refreshStatsCardUI()
		if player.Character then
			updateHeadTag(player.Character)
		end
		updatePlayerlistName()
	end

	refreshStatsCardUI()

	originalBtn.Activated:Connect(function()
		useOriginalStats = not useOriginalStats
		if useOriginalStats then
			captureOriginalStatsFromGame()
			local d = getActiveDonated()
			local r = getActiveRaised()
			donatedInput.Text = formatWithCommas(d)
			raisedInput.Text = formatWithCommas(r)
		else
			customDonatedStr = getActiveDonated()
			customRaisedStr = getActiveRaised()
			donatedInput.Text = formatWithCommas(customDonatedStr)
			raisedInput.Text = formatWithCommas(customRaisedStr)
		end
		refreshStatsCardUI()
		saveConfigToStorage()
		updatePlayerlistStats()
		if addLog then
			addLog("Stats mode: " .. (useOriginalStats and "Original (Auto-Typed)" or "Custom"), "CONFIG")
		end
	end)

	vipTagBtn.Activated:Connect(function()
		hasInitialVipChecked = true
		isVipNameTagEnabled = not isVipNameTagEnabled
		refreshStatsCardUI()
		saveConfigToStorage()
		if player.Character then
			updateHeadTag(player.Character)
		end
		updatePlayerlistName()
		if addLog then
			addLog("VIP Tag mode: " .. (isVipNameTagEnabled and "ON" or "OFF"), "CONFIG")
		end
	end)

	fireInput:GetPropertyChangedSignal("Text"):Connect(function()
		local cur = fireInput.Text
		local raw = (string.gsub(cur, "%D", ""))
		if cur ~= raw then
			fireInput.Text = raw
		end
		customFireStreak = tonumber(raw) or 0
		saveConfigToStorage()
		updatePlayerlistName()
	end)

	fireInput.FocusLost:Connect(function()
		local raw = (string.gsub(fireInput.Text, "%D", ""))
		customFireStreak = tonumber(raw) or 0
		fireInput.Text = (customFireStreak > 0) and tostring(customFireStreak) or ""
		saveConfigToStorage()
		updatePlayerlistName()
		if addLog then
			addLog("Fire streak set to: " .. tostring(customFireStreak), "CONFIG")
		end
	end)

	local isUpdatingDonated = false
	donatedInput:GetPropertyChangedSignal("Text"):Connect(function()
		if isUpdatingDonated then return end
		local curText = donatedInput.Text
		local raw = (string.gsub(curText, "%D", ""))
		local formatted = (raw ~= "") and formatWithCommas(raw) or ""
		if curText ~= formatted then
			isUpdatingDonated = true
			donatedInput.Text = formatted
			isUpdatingDonated = false
		end
		if donatedInput:IsFocused() then
			customDonatedStr = (raw ~= "") and raw or "0"
			if useOriginalStats then
				useOriginalStats = false
				refreshStatsCardUI()
				saveConfigToStorage()
			end
			updatePlayerlistStats()
		end
	end)

	donatedInput.FocusLost:Connect(function()
		local raw = (string.gsub(donatedInput.Text, "%D", ""))
		customDonatedStr = (raw ~= "") and raw or "0"
		donatedInput.Text = formatWithCommas(customDonatedStr)
		saveConfigToStorage()
		updatePlayerlistStats()
		if addLog then
			addLog("Donated stat set to: " .. donatedInput.Text, "CONFIG")
		end
	end)

	local isUpdatingRaised = false
	raisedInput:GetPropertyChangedSignal("Text"):Connect(function()
		if isUpdatingRaised then return end
		local curText = raisedInput.Text
		local raw = (string.gsub(curText, "%D", ""))
		local formatted = (raw ~= "") and formatWithCommas(raw) or ""
		if curText ~= formatted then
			isUpdatingRaised = true
			raisedInput.Text = formatted
			isUpdatingRaised = false
		end
		if raisedInput:IsFocused() then
			customRaisedStr = (raw ~= "") and raw or "0"
			if useOriginalStats then
				useOriginalStats = false
				refreshStatsCardUI()
				saveConfigToStorage()
			end
			updatePlayerlistStats()
		end
	end)

	raisedInput.FocusLost:Connect(function()
		local raw = (string.gsub(raisedInput.Text, "%D", ""))
		customRaisedStr = (raw ~= "") and raw or "0"
		raisedInput.Text = formatWithCommas(customRaisedStr)
		saveConfigToStorage()
		updatePlayerlistStats()
		if addLog then
			addLog("Raised stat set to: " .. raisedInput.Text, "CONFIG")
		end
	end)
end

-- 7. Reset Settings Card (Placed directly above Connection & Event Logs)
do
	local resetCard = Instance.new("Frame")
	resetCard.Name = "ResetSettingsCard"
	resetCard.LayoutOrder = 7
	resetCard.Size = UDim2.new(1, 0, 0, 34)
	resetCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	resetCard.BorderSizePixel = 0
	resetCard.ZIndex = 52
	resetCard.Parent = contentFrame

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 8)
	resetCorner.Parent = resetCard

	local resetStroke = Instance.new("UIStroke")
	resetStroke.Color = Color3.fromRGB(65, 38, 48)
	resetStroke.Thickness = 1
	resetStroke.Parent = resetCard

	local resetBtn = Instance.new("TextButton")
	resetBtn.Name = "ResetButton"
	resetBtn.AutoButtonColor = false
	resetBtn.Size = UDim2.new(1, 0, 1, 0)
	resetBtn.Position = UDim2.new(0, 0, 0, 0)
	resetBtn.BackgroundColor3 = Color3.fromRGB(34, 24, 30)
	resetBtn.BorderSizePixel = 0
	resetBtn.Text = "↺ Reset All Settings to Default"
	resetBtn.TextColor3 = Color3.fromRGB(255, 145, 145)
	resetBtn.TextSize = 11
	resetBtn.Font = Enum.Font.BuilderSansBold
	resetBtn.ZIndex = 53
	resetBtn.Parent = resetCard

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = resetBtn

	resetBtn.MouseEnter:Connect(function()
		TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(48, 28, 38)}):Play()
	end)
	resetBtn.MouseLeave:Connect(function()
		TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(34, 24, 30)}):Play()
	end)

	resetBtn.Activated:Connect(function()
		currentTotalAmount = "903"
		isScriptEnabled = true
		autoHideOnRun = false
		currentKeybind = Enum.KeyCode.F4
		minPopupDelay = 0.6
		maxPopupDelay = 1.6
		customFireStreak = 0
		useOriginalStats = true
		isVipNameTagEnabled = true
		hasInitialVipChecked = true
		addedDonatedOffset = 0
		realGameDonated = ""
		realGameRaised = ""
		originalDonatedStr = ""
		originalRaisedStr = ""

		-- Reset stats back to fresh baseline from game
		captureOriginalStatsFromGame()
		customDonatedStr = getActiveDonated()
		customRaisedStr = getActiveRaised()

		if amountTextBox then
			amountTextBox.Text = "903"
		end
		updateAmountDisplay("903")
		objects[1]:SetAttribute("TotalAmount", "903")

		objects[1]:SetAttribute("ScriptEnabled", true)
		if updateMasterToggleVisual then
			updateMasterToggleVisual(true)
		end

		if toggleKnob and toggleSwitch then
			toggleKnob.Position = UDim2.new(0, 3, 0.5, 0)
			toggleSwitch.BackgroundColor3 = Color3.fromRGB(42, 46, 58)
		end

		if keybindButton then
			keybindButton.Text = "[ F4 ]"
			keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			keybindButton.BackgroundColor3 = Color3.fromRGB(33, 37, 50)
		end
		objects[1]:SetAttribute("ToggleKey", "F4")

		if minDelayInput then
			minDelayInput.Text = "0.6"
		end
		if maxDelayInput then
			maxDelayInput.Text = "1.6"
		end
		if refreshDelayPresetsVisual then
			refreshDelayPresetsVisual()
		end

		if donatedInput then
			donatedInput.Text = formatWithCommas(getActiveDonated())
		end
		if raisedInput then
			raisedInput.Text = formatWithCommas(getActiveRaised())
		end
		if fireInput then
			fireInput.Text = ""
		end
		refreshStatsCardUI()
		updatePlayerlistStats()
		if player.Character then
			updateHeadTag(player.Character)
		end
		updatePlayerlistName()
		if resetGiftbux then
			resetGiftbux()
		end

		saveConfigToStorage()

		resetBtn.Text = "✓ Settings Reset Successfully!"
		resetBtn.TextColor3 = Color3.fromRGB(120, 255, 170)
		resetBtn.BackgroundColor3 = Color3.fromRGB(26, 52, 36)
		task.delay(1.5, function()
			if resetBtn and resetBtn.Parent then
				resetBtn.Text = "↺ Reset All Settings to Default"
				resetBtn.TextColor3 = Color3.fromRGB(255, 145, 145)
				resetBtn.BackgroundColor3 = Color3.fromRGB(34, 24, 30)
			end
		end)

		if addLog then
			addLog("All settings have been reset to factory defaults.", "CONFIG")
		end
	end)
end

-- 8. Activity & Connection Logs
local logsCard = Instance.new("Frame")
logsCard.Name = "LogsCard"
logsCard.LayoutOrder = 8
logsCard.Size = UDim2.new(1, 0, 0, 160)
logsCard.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
logsCard.BorderSizePixel = 0
logsCard.ZIndex = 52
logsCard.Parent = contentFrame

local logsCardCorner = Instance.new("UICorner")
logsCardCorner.CornerRadius = UDim.new(0, 8)
logsCardCorner.Parent = logsCard

local logsCardStroke = Instance.new("UIStroke")
logsCardStroke.Color = Color3.fromRGB(38, 42, 56)
logsCardStroke.Thickness = 1
logsCardStroke.Parent = logsCard

local logsHeaderFrame = Instance.new("Frame")
logsHeaderFrame.Name = "LogsHeader"
logsHeaderFrame.Size = UDim2.new(1, -16, 0, 22)
logsHeaderFrame.Position = UDim2.new(0, 8, 0, 6)
logsHeaderFrame.BackgroundTransparency = 1
logsHeaderFrame.ZIndex = 53
logsHeaderFrame.Parent = logsCard

local logsTitle = Instance.new("TextLabel")
logsTitle.Name = "Title"
logsTitle.Size = UDim2.new(1, -40, 1, 0)
logsTitle.BackgroundTransparency = 1
logsTitle.Text = "CONNECTION & EVENT LOGS"
logsTitle.TextColor3 = Color3.fromRGB(140, 148, 168)
logsTitle.TextSize = 10
logsTitle.Font = Enum.Font.GothamBold
logsTitle.TextXAlignment = Enum.TextXAlignment.Left
logsTitle.ZIndex = 54
logsTitle.Parent = logsHeaderFrame

local clearLogsButton = Instance.new("TextButton")
clearLogsButton.Name = "ClearLogs"
clearLogsButton.AutoButtonColor = false
clearLogsButton.Size = UDim2.new(0, 38, 0, 18)
clearLogsButton.Position = UDim2.new(1, -38, 0.5, 0)
clearLogsButton.AnchorPoint = Vector2.new(0, 0.5)
clearLogsButton.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
clearLogsButton.BorderSizePixel = 0
clearLogsButton.Text = "Clear"
clearLogsButton.TextColor3 = Color3.fromRGB(140, 146, 165)
clearLogsButton.TextSize = 9
clearLogsButton.Font = Enum.Font.GothamBold
clearLogsButton.ZIndex = 54
clearLogsButton.Parent = logsHeaderFrame

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 4)
clearCorner.Parent = clearLogsButton

local logsContainer = Instance.new("ScrollingFrame")
logsContainer.Name = "LogsScroll"
logsContainer.Size = UDim2.new(1, -16, 1, -34)
logsContainer.Position = UDim2.new(0, 8, 0, 28)
logsContainer.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
logsContainer.BorderSizePixel = 0
logsContainer.ScrollBarThickness = 3
logsContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 68, 88)
logsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
logsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
logsContainer.ZIndex = 53
logsContainer.Parent = logsCard

local logsScrollCorner = Instance.new("UICorner")
logsScrollCorner.CornerRadius = UDim.new(0, 6)
logsScrollCorner.Parent = logsContainer

local logsScrollPadding = Instance.new("UIPadding")
logsScrollPadding.PaddingTop = UDim.new(0, 6)
logsScrollPadding.PaddingBottom = UDim.new(0, 6)
logsScrollPadding.PaddingLeft = UDim.new(0, 6)
logsScrollPadding.PaddingRight = UDim.new(0, 6)
logsScrollPadding.Parent = logsContainer

local logsListLayout = Instance.new("UIListLayout")
logsListLayout.Padding = UDim.new(0, 4)
logsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
logsListLayout.Parent = logsContainer

-- ============================================================================
-- Logger & Controller Logic
-- ============================================================================

local logCounter = 0

addLog = function(message: string, tag: string?)
	logCounter += 1
	local tagName = tag or "INFO"
	local timeString = getTimestamp()

	local logLabel = Instance.new("TextLabel")
	logLabel.Name = "Log_" .. tostring(logCounter)
	logLabel.LayoutOrder = logCounter
	logLabel.Size = UDim2.new(1, 0, 0, 0)
	logLabel.AutomaticSize = Enum.AutomaticSize.Y
	logLabel.BackgroundTransparency = 1
	logLabel.RichText = true
	logLabel.Font = Enum.Font.GothamMedium
	logLabel.TextSize = 11
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Top
	logLabel.TextWrapped = true
	logLabel.ZIndex = 54

	local tagHex = "#38bdf8"
	if tagName == "CONFIG" then
		tagHex = "#c084fc"
	elseif tagName == "KEYBIND" then
		tagHex = "#fbbf24"
	elseif tagName == "SYSTEM" then
		tagHex = "#34d399"
	elseif tagName == "CONNECT" then
		tagHex = "#60a5fa"
	elseif tagName == "POPUP" then
		tagHex = "#f472b6"
	elseif tagName == "TRACK" then
		tagHex = "#10b981"
	elseif tagName == "WARN" then
		tagHex = "#ef4444"
	end

	logLabel.Text = string.format(
		'<font color="#64748b">[%s]</font> <font color="%s">[%s]</font> <font color="#e2e8f0">%s</font>',
		timeString,
		tagHex,
		tagName,
		message
	)
	logLabel.Parent = logsContainer

	task.defer(function()
		logsContainer.CanvasPosition = Vector2.new(0, 999999)
	end)
end

clearLogsButton.Activated:Connect(function()
	for _, child in ipairs(logsContainer:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	addLog("Logs cleared.", "SYSTEM")
end)

-- Total Amount input event with auto-save
amountTextBox.FocusLost:Connect(function(enterPressed)
	local val = amountTextBox.Text
	if val == "" then
		val = "0"
		amountTextBox.Text = val
	end
	updateAmountDisplay(val)
	saveConfigToStorage()
	addLog("Total amount saved: " .. val, "CONFIG")
end)

amountTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	local val = amountTextBox.Text
	if val ~= "" then
		updateAmountDisplay(val)
		saveConfigToStorage()
	end
end)

-- Delay Input listeners with validation & auto-save
minDelayInput:GetPropertyChangedSignal("Text"):Connect(function()
	local raw = string.match(minDelayInput.Text, "%d*%.?%d*")
	if raw and raw ~= "" then
		local num = tonumber(raw)
		if num and num >= 0 then
			minPopupDelay = num
			saveConfigToStorage()
			if refreshDelayPresetsVisual then refreshDelayPresetsVisual() end
		end
	end
end)

minDelayInput.FocusLost:Connect(function()
	local val = tonumber(minDelayInput.Text)
	if not val or val < 0 then val = 0.0 end
	minPopupDelay = val
	minDelayInput.Text = string.format("%.1f", val)
	saveConfigToStorage()
	if refreshDelayPresetsVisual then refreshDelayPresetsVisual() end
	addLog(string.format("Min popup delay set to: %.1fs", val), "CONFIG")
end)

maxDelayInput:GetPropertyChangedSignal("Text"):Connect(function()
	local raw = string.match(maxDelayInput.Text, "%d*%.?%d*")
	if raw and raw ~= "" then
		local num = tonumber(raw)
		if num and num >= 0 then
			maxPopupDelay = num
			saveConfigToStorage()
			if refreshDelayPresetsVisual then refreshDelayPresetsVisual() end
		end
	end
end)

maxDelayInput.FocusLost:Connect(function()
	local val = tonumber(maxDelayInput.Text)
	if not val or val < 0 then val = minPopupDelay end
	maxPopupDelay = val
	maxDelayInput.Text = string.format("%.1f", val)
	saveConfigToStorage()
	if refreshDelayPresetsVisual then refreshDelayPresetsVisual() end
	addLog(string.format("Max popup delay set to: %.1fs", val), "CONFIG")
end)

-- Master Script Status (ON / OFF) switch visual update & handler
updateMasterToggleVisual = function(animate: boolean)
	local targetKnobPos = isScriptEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	local targetColor = isScriptEnabled and Color3.fromRGB(57, 105, 252) or Color3.fromRGB(42, 46, 58)

	if animate then
		TweenService:Create(masterKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetKnobPos}):Play()
		TweenService:Create(masterSwitch, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
	else
		masterKnob.Position = targetKnobPos
		masterSwitch.BackgroundColor3 = targetColor
	end
end

masterSwitch.Activated:Connect(function()
	isScriptEnabled = not isScriptEnabled
	updateMasterToggleVisual(true)
	objects[1]:SetAttribute("ScriptEnabled", isScriptEnabled)
	saveConfigToStorage()

	if isScriptEnabled then
		addLog("Script Status: ON (Active & blocking default purchase popups)", "CONFIG")
	else
		if isModalOpen then
			closeModal(true)
		end
		addLog("Script Status: OFF (Disabled, clicks ignored, default behavior restored)", "WARN")
	end
end)

-- Toggle switch visual update
local function updateToggleVisual(animate: boolean)
	local targetKnobPos = autoHideOnRun and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	local targetColor = autoHideOnRun and Color3.fromRGB(57, 105, 252) or Color3.fromRGB(42, 46, 58)

	if animate then
		TweenService:Create(toggleKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetKnobPos}):Play()
		TweenService:Create(toggleSwitch, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
	else
		toggleKnob.Position = targetKnobPos
		toggleSwitch.BackgroundColor3 = targetColor
	end
end

toggleSwitch.Activated:Connect(function()
	autoHideOnRun = not autoHideOnRun
	updateToggleVisual(true)
	objects[1]:SetAttribute("AutoHideOnRun", autoHideOnRun)
	saveConfigToStorage()

	if autoHideOnRun then
		addLog("Start Hidden: ON (Saved: menu will be hidden on launch)", "CONFIG")
	else
		addLog("Start Hidden: OFF (Saved: menu will show on launch)", "CONFIG")
	end
end)

-- Keybind button listening logic
keybindButton.Activated:Connect(function()
	if isListeningForKey then return end
	isListeningForKey = true
	keybindButton.Text = "[ Press Key ]"
	keybindButton.TextColor3 = Color3.fromRGB(56, 189, 248)
	keybindButton.BackgroundColor3 = Color3.fromRGB(24, 38, 62)
	addLog("Awaiting key press for menu toggle...", "KEYBIND")
end)

-- Toggle Menu Show / Unshow Animation
local function setMenuVisible(visible: boolean, instant: boolean?)
	if isMenuAnimating and not instant then return end
	isMenuOpen = visible
	objects[1]:SetAttribute("IsMenuOpen", visible)

	local targetPos = visible and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, -340, 0.5, 0)
	local shadowPos = visible and UDim2.new(0, 24, 0.5, 4) or UDim2.new(0, -340, 0.5, 4)

	if instant then
		menuFrame.Position = targetPos
		menuShadow.Position = shadowPos
		return
	end

	isMenuAnimating = true
	local animInfo = TweenInfo.new(0.28, Enum.EasingStyle.Cubic, visible and Enum.EasingDirection.Out or Enum.EasingDirection.In)

	local tFrame = TweenService:Create(menuFrame, animInfo, {Position = targetPos})
	local tShadow = TweenService:Create(menuShadow, animInfo, {Position = shadowPos})

	tFrame:Play()
	tShadow:Play()

	tFrame.Completed:Connect(function()
		isMenuAnimating = false
	end)
end

local function toggleMenu()
	setMenuVisible(not isMenuOpen)
end

minimizeButton.Activated:Connect(function()
	setMenuVisible(false)
end)

-- Mobile Floating Circle Button (Left side, Touch Draggable & Tap Toggle)
do
	local mobileCircleBtn = Instance.new("ImageButton")
	mobileCircleBtn.Name = "MobileMenuToggleBtn"
	mobileCircleBtn.Size = UDim2.new(0, 42, 0, 42)
	mobileCircleBtn.Position = UDim2.new(0, 12, 0.5, -21)
	mobileCircleBtn.AnchorPoint = Vector2.new(0, 0.5)
	mobileCircleBtn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	mobileCircleBtn.BorderSizePixel = 0
	mobileCircleBtn.ZIndex = 65
	mobileCircleBtn.Active = true
	mobileCircleBtn.AutoButtonColor = false
	mobileCircleBtn.Visible = UserInputService.TouchEnabled
	mobileCircleBtn.Parent = objects[1]

	local mBtnCorner = Instance.new("UICorner")
	mBtnCorner.CornerRadius = UDim.new(1, 0)
	mBtnCorner.Parent = mobileCircleBtn

	local mBtnStroke = Instance.new("UIStroke")
	mBtnStroke.Color = Color3.fromRGB(57, 105, 252)
	mBtnStroke.Thickness = 1.5
	mBtnStroke.Transparency = 0.2
	mBtnStroke.Parent = mobileCircleBtn

	local mBtnIcon = Instance.new("ImageLabel")
	mBtnIcon.Name = "Icon"
	mBtnIcon.Size = UDim2.new(0, 22, 0, 22)
	mBtnIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	mBtnIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	mBtnIcon.BackgroundTransparency = 1
	mBtnIcon.Image = "rbxassetid://125746152594286"
	mBtnIcon.ImageColor3 = Color3.fromRGB(240, 243, 255)
	mBtnIcon.ZIndex = 66
	mBtnIcon.Parent = mobileCircleBtn

	local isDragging = false
	local dragMoved = false
	local touchStartPos = Vector2.zero
	local touchStartTime = 0

	mobileCircleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			dragMoved = false
			touchStartPos = Vector2.new(input.Position.X, input.Position.Y)
			touchStartTime = os.clock()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local curPos = Vector2.new(input.Position.X, input.Position.Y)
			local deltaY = curPos.Y - touchStartPos.Y
			local deltaX = curPos.X - touchStartPos.X
			if math.abs(deltaY) > 8 or math.abs(deltaX) > 8 then
				dragMoved = true
			end
			if dragMoved then
				local camera = workspace.CurrentCamera
				local screenH = (camera and camera.ViewportSize.Y) or 360
				local targetY = math.clamp(curPos.Y, 26, screenH - 26)
				mobileCircleBtn.Position = UDim2.new(0, 12, 0, targetY)
			end
		end
	end)

	local function onInputEnd(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			isDragging = false
			local duration = os.clock() - touchStartTime
			if not dragMoved and duration < 0.45 then
				toggleMenu()
			end
		end
	end

	UserInputService.InputEnded:Connect(onInputEnd)
end

-- UserInputService listener for Keybind trigger and Keybind reconfiguration
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if isListeningForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				currentKeybind = input.KeyCode
				isListeningForKey = false
				keybindButton.Text = "[ " .. input.KeyCode.Name .. " ]"
				keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
				keybindButton.BackgroundColor3 = Color3.fromRGB(33, 37, 50)
				objects[1]:SetAttribute("ToggleKey", input.KeyCode.Name)
				saveConfigToStorage()
				addLog("Toggle keybind saved: " .. input.KeyCode.Name, "KEYBIND")
			end
		end
		return
	end

	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKeybind then
		toggleMenu()
	end
end)

-- ============================================================================
-- Post-Purchase Donation Popup Banner (send animation with sound)
-- ============================================================================

do
	local ROBUX_ICON_UNICODE = "\u{E002}"
	local CONTENT_DARK_GREEN = Color3.fromHex("#08541a")
	local BG_BRIGHT_GREEN = Color3.fromHex("#17ff4d")
	local SOUND_ID = "rbxassetid://14674192018"

	local warnPopup = Instance.new("Frame")
	warnPopup.Name = "DonationSuccessPopup"
	warnPopup.Active = false
	warnPopup.AnchorPoint = Vector2.new(0.5, 1)
	warnPopup.AutomaticSize = Enum.AutomaticSize.XY
	warnPopup.BackgroundColor3 = BG_BRIGHT_GREEN
	warnPopup.BackgroundTransparency = 0
	warnPopup.BorderSizePixel = 0
	warnPopup.ClipsDescendants = true
	warnPopup.Position = UDim2.new(0.5, 0, 0.9, 0)
	warnPopup.Size = UDim2.new(0, 0, 0, 0)
	warnPopup.Visible = false
	warnPopup.ZIndex = 120
	warnPopup.Parent = objects[1]

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
	icon.Text = ROBUX_ICON_UNICODE
	icon.TextColor3 = CONTENT_DARK_GREEN
	icon.TextSize = 28
	icon.BackgroundTransparency = 1
	icon.LayoutOrder = 0
	icon.Size = UDim2.new(0, 30, 0, 30)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextYAlignment = Enum.TextYAlignment.Center
	icon.ZIndex = 121
	icon.Parent = warnPopup

	local uiAspect = Instance.new("UIAspectRatioConstraint")
	uiAspect.AspectRatio = 1
	uiAspect.AspectType = Enum.AspectType.FitWithinMaxSize
	uiAspect.DominantAxis = Enum.DominantAxis.Width
	uiAspect.Parent = icon

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
	message.LineHeight = 1
	message.MaxVisibleGraphemes = 0
	message.RichText = true
	message.Text = ""
	message.TextColor3 = CONTENT_DARK_GREEN
	message.TextSize = 22
	message.BackgroundTransparency = 1
	message.BorderSizePixel = 0
	message.LayoutOrder = 1
	message.AutomaticSize = Enum.AutomaticSize.XY
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.TextYAlignment = Enum.TextYAlignment.Center
	message.ZIndex = 121
	message.Parent = warnPopup

	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Padding = UDim.new(0, 10)
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiListLayout.Parent = warnPopup

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 30)
	uiCorner.Parent = warnPopup

	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingBottom = UDim.new(0, 12)
	uiPadding.PaddingLeft = UDim.new(0, 18)
	uiPadding.PaddingRight = UDim.new(0, 20)
	uiPadding.PaddingTop = UDim.new(0, 12)
	uiPadding.Parent = warnPopup

	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = Color3.fromHex("#000000")
	uiStroke.Enabled = true
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Thickness = 3
	uiStroke.Transparency = 0.97
	uiStroke.Parent = warnPopup

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = warnPopup

	playDonationPopupAnimation = function(amount: number | string, username: string, stayDuration: number?)
		task.spawn(function()
			local cleanAmt = tostring(amount):gsub("%D", "")
			if cleanAmt == "" then cleanAmt = "10" end
			local cleanUser = tostring(username):gsub("^@", "")
			if cleanUser == "" then cleanUser = currentRecipientUser or "Powerbank225w" end

			message.Text = string.format("you donated %s%s to @%s", ROBUX_ICON_UNICODE, formatWithCommas(cleanAmt), cleanUser)

			local rawText = message.ContentText
			local totalChars = utf8.len(rawText) or #rawText

			-- Play Notification Sound
			pcall(function()
				local sound = Instance.new("Sound")
				sound.Name = "DonationNotificationSound"
				sound.SoundId = SOUND_ID
				sound.Volume = 1
				sound.Parent = objects[1]
				sound:Play()
				sound.Ended:Connect(function()
					sound:Destroy()
				end)
			end)

			-- Initial State
			uiScale.Scale = 0
			message.MaxVisibleGraphemes = 0
			warnPopup.Visible = true

			-- 1. Pop-in Scale Animation (Back Out)
			local scaleInInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local scaleInTween = TweenService:Create(uiScale, scaleInInfo, {Scale = 1})
			scaleInTween:Play()

			-- 2. Text Expanding (Typewriter) Animation
			local textDuration = math.clamp(totalChars * 0.025, 0.4, 1.2)
			local textTweenInfo = TweenInfo.new(textDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			local textTween = TweenService:Create(message, textTweenInfo, {MaxVisibleGraphemes = totalChars})
			textTween:Play()

			textTween.Completed:Wait()
			message.MaxVisibleGraphemes = -1

			-- Auto-close
			local duration = stayDuration or 3
			task.wait(duration)
			local scaleOutInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local scaleOutTween = TweenService:Create(uiScale, scaleOutInfo, {Scale = 0})
			scaleOutTween:Play()
			scaleOutTween.Completed:Wait()
			warnPopup.Visible = false
		end)
	end
end

-- ============================================================================
-- Buy & Close Button Listeners (Transition to Purchase Completed Modal)
-- ============================================================================

local buyButton = objects[22] :: TextButton
local closeButton = objects[12] :: TextButton
local closeLine1 = objects[13] :: Frame
local closeLine2 = objects[14] :: Frame

local BUY_NORMAL_COLOR = Color3.fromRGB(51, 95, 255)

-- Hover effect disabled on buyButton and okButton as requested (stays normal blue)

buyButton.ChildAdded:Connect(function(child)
	if child:IsA("UIScale") then
		task.defer(function()
			child:Destroy()
		end)
	end
end)

-- Helper to open Purchase Completed or Insufficient Robux Error Modal with the SAME entrance animation
local function openPurchaseCompletedModal(isError: boolean?, neededRobux: number?)
	isModalBusy = true

	if isError then
		local deficit = neededRobux or 0
		successLogo.Visible = true
		successTitle.Position = UDim2.new(0, 50, 0, 19)
		successTitle.TextSize = 24
		successTitle.Text = "Send Robux"
		successIcon.Image = "rbxassetid://11419713314"
		successIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		successDesc.TextSize = 18
		successDesc.Text = "Buy " .. tostring(deficit) .. " Robux to complete this transaction"
		okButton.Text = "Buy"
	else
		successLogo.Visible = false
		successTitle.Position = UDim2.new(0, 20, 0, 18)
		successTitle.TextSize = 26
		successTitle.Text = "Purchase completed"
		successIcon.Image = "rbxassetid://98579402919536"
		successIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		successDesc.TextSize = 16
		successDesc.Text = "You send " .. tostring(currentActivePriceStr) .. " Robux"
		okButton.Text = "OK"
	end

	-- 2. Compact height (248px) with clean spacing below Title and snug at bottom
	objects[6].Size = UDim2.new(0, 460, 0, 248)
	objects[3].Size = UDim2.new(0, 460, 0, 248)

	buyView.Visible = false
	successView.Visible = true

	-- 3. Initial animation setup (identical entrance to Buy Item popup)
	objects[2].Visible = true
	objects[2].BackgroundTransparency = 1
	objects[3].Position = UDim2.new(0.5, 0, 0.491261, 52)
	objects[3].BackgroundTransparency = 0.7
	objects[5].Scale = 1.0
	objects[6].Position = UDim2.new(0.5, 0, 0.5, 45)
	objects[6].GroupTransparency = 0.4
	objects[9].Scale = 1.0

	local moveInfo = TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local overlayInfo = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tPosModal = TweenService:Create(objects[6], moveInfo, {Position = UDim2.new(0.5, 0, 0.5, 0)})
	local tPosShadow = TweenService:Create(objects[3], moveInfo, {Position = UDim2.new(0.5, 0, 0.491261, 7)})
	local tFadeModal = TweenService:Create(objects[6], fadeInfo, {GroupTransparency = 0})
	local tFadeShadow = TweenService:Create(objects[3], fadeInfo, {BackgroundTransparency = 0.5})
	local tFadeOverlay = TweenService:Create(objects[2], overlayInfo, {BackgroundTransparency = 0.4})

	tPosModal:Play()
	tPosShadow:Play()
	tFadeModal:Play()
	tFadeShadow:Play()
	tFadeOverlay:Play()

	tPosModal.Completed:Wait()

	isModalOpen = true
	isModalBusy = false
	objects[1]:SetAttribute("IsOpen", true)

	if isError then
		addLog(string.format("Transaction failed: Buy %d Robux to complete", neededRobux or 0), "WARN")
	else
		addLog(string.format("Purchase completed modal opened for [%s Robux]", tostring(currentActivePriceStr)), "POPUP")
	end
end

-- Buy Button Click:
-- 1. Plays pressed layer sweep across button
-- 2. Waits 2 seconds
-- 3. Directly closes modal with NO animation
-- 4. Checks balance: If sufficient, deducts & shows completed; If insufficient, shows error warning modal
buyButton.Activated:Connect(function()
	if isModalBusy or not isModalOpen then return end
	isModalBusy = true

	-- 1. Directly apply dark layer over Buy button (stays stationary/darkened)
	revealOverlay.Position = UDim2.new(0, 0, 0, 0)
	revealContainer.Visible = true

	-- 2. Wait 2 seconds (layer stays stopped/frozen on button)
	task.wait(2)

	-- 3. Close Buy Item modal directly with NO animation
	objects[2].Visible = false
	objects[6].GroupTransparency = 1
	objects[3].BackgroundTransparency = 1
	objects[2].BackgroundTransparency = 1
	isModalOpen = false
	revealContainer.Visible = false
	revealOverlay.Position = UDim2.new(0, 0, 0, 0)

	local currentBalance = tonumber((string.gsub(tostring(currentTotalAmount), "%D", ""))) or 0
	local cost = tonumber(currentActivePriceNum) or tonumber((string.gsub(tostring(currentActivePriceStr), "%D", ""))) or 0

	if currentBalance >= cost then
		-- Sufficient balance: Deduct Robux balance on send
		local newBalance = math.max(0, currentBalance - cost)
		local newBalanceStr = tostring(newBalance)

		currentTotalAmount = newBalanceStr
		updateAmountDisplay(newBalanceStr)
		if amountTextBox then
			amountTextBox.Text = newBalanceStr
		end
		objects[1]:SetAttribute("TotalAmount", currentTotalAmount)
		isPendingBuy = false

		-- 1. Increase Donated in player status (+ cost)
		addedDonatedOffset = addedDonatedOffset + cost
		local curCustom = tonumber((string.gsub(tostring(customDonatedStr), "%D", ""))) or 0
		customDonatedStr = tostring(curCustom + cost)
		if donatedInput and not donatedInput:IsFocused() then
			donatedInput.Text = formatWithCommas(getActiveDonated())
		end
		updatePlayerlistStats()

		-- 2. Increase Giftbux Balance (1.5x / hafe se zeyada, e.g. 2 send -> 3 add)
		local giftbuxGain = math.max(1, math.ceil(cost * 1.5))
		if addGiftbux then
			addGiftbux(giftbuxGain)
		end

		saveConfigToStorage()

		if addLog then
			addLog(string.format("Sent %d Robux! Balance: %d R$ | Donated: +%d (%s) | Giftbux: +%d", cost, newBalance, cost, formatWithCommas(newDonated), giftbuxGain), "POPUP")
		end

		-- 4. Open "Purchase completed" modal with checkmark
		openPurchaseCompletedModal(false)
	else
		-- Insufficient balance: Do NOT deduct Robux, show error warning modal
		local neededRobux = cost - currentBalance
		isPendingBuy = false

		if addLog then
			addLog(string.format("Insufficient Robux! Needed %d more (Have: %d, Cost: %d)", neededRobux, currentBalance, cost), "WARN")
		end

		-- 4. Open "Error" modal with warning icon
		openPurchaseCompletedModal(true, neededRobux)
	end
end)

-- Close Button (X) on Buy View
closeButton.MouseEnter:Connect(function()
	if isModalOpen and not isModalBusy then
		local white = Color3.fromRGB(255, 255, 255)
		TweenService:Create(closeLine1, TweenInfo.new(0.12), {BackgroundColor3 = white}):Play()
		TweenService:Create(closeLine2, TweenInfo.new(0.12), {BackgroundColor3 = white}):Play()
	end
end)

closeButton.MouseLeave:Connect(function()
	local originalColor = Color3.fromRGB(161, 161, 170)
	TweenService:Create(closeLine1, TweenInfo.new(0.12), {BackgroundColor3 = originalColor}):Play()
	TweenService:Create(closeLine2, TweenInfo.new(0.12), {BackgroundColor3 = originalColor}):Play()
end)

closeButton.Activated:Connect(function()
	if isModalBusy or not isModalOpen then return end
	isPendingBuy = false
	addLog("Purchase dismissed for: " .. currentActiveItemName, "POPUP")
	closeModal(false)
end)

-- OK Button on Purchase Completed View (No hover effect, static blue color)
okButton.Activated:Connect(function()
	if isModalBusy or not isModalOpen then return end
	local isSuccessView = successView.Visible
	local isRealSuccess = (okButton.Text == "OK")
	local sentAmt = currentActivePriceNum or currentActivePriceStr or 10
	local sentUser = currentRecipientUser or "Powerbank225w"

	closeModal(true)

	if isSuccessView and isRealSuccess and playDonationPopupAnimation then
		playDonationPopupAnimation(sentAmt, sentUser, 3)
	end
end)

-- Close Button (X) on Purchase Completed View
successCloseBtn.MouseEnter:Connect(function()
	if isModalOpen and not isModalBusy then
		local white = Color3.fromRGB(255, 255, 255)
		TweenService:Create(successCloseLine1, TweenInfo.new(0.12), {BackgroundColor3 = white}):Play()
		TweenService:Create(successCloseLine2, TweenInfo.new(0.12), {BackgroundColor3 = white}):Play()
	end
end)

successCloseBtn.MouseLeave:Connect(function()
	local originalColor = Color3.fromRGB(161, 161, 170)
	TweenService:Create(successCloseLine1, TweenInfo.new(0.12), {BackgroundColor3 = originalColor}):Play()
	TweenService:Create(successCloseLine2, TweenInfo.new(0.12), {BackgroundColor3 = originalColor}):Play()
end)

successCloseBtn.Activated:Connect(function()
	if isModalBusy or not isModalOpen then return end
	closeModal(true)
end)

-- Bindable triggers & attribute controls for external script integration
do
	local openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenModal"
	openEvent.Event:Connect(openModal)
	openEvent.Parent = objects[1]

	local closeEvent = Instance.new("BindableEvent")
	closeEvent.Name = "CloseModal"
	closeEvent.Event:Connect(function(isNormal)
		closeModal(isNormal == true)
	end)
	closeEvent.Parent = objects[1]
end

objects[1]:GetAttributeChangedSignal("IsOpen"):Connect(function()
	local shouldOpen = objects[1]:GetAttribute("IsOpen")
	if shouldOpen and not isModalOpen and not isModalBusy then
		openModal()
	elseif shouldOpen == false and isModalOpen and not isModalBusy then
		closeModal(true)
	end
end)

-- ============================================================================
-- Console Donation Button Tracking Logic (from selector.lua & Monitor+removePopup.lua)
-- ============================================================================

local lastProcessedTime = 0
local lastProcessedMsg = ""

local function parseConsoleMessage(msg: string)
	if not isScriptEnabled then return end
	if not msg or type(msg) ~= "string" then return end

	-- Fast plain text match
	if not string.find(msg, "Transfering transfer donation:", 1, true) then return end

	local now = os.clock()
	if now - lastProcessedTime < 0.2 and msg == lastProcessedMsg then
		return
	end
	lastProcessedTime = now
	lastProcessedMsg = msg

	local recipient = string.match(msg, "recipient%s+(%d+)")
	local amount = string.match(msg, "amount%s+(%d+)")

	local recipientId = tonumber(recipient)
	local donationAmount = tonumber(amount)

	if not donationAmount then return end

	task.spawn(function()
		addLog(string.format("Booth button detected! Recipient=[%s] Amount=[%d R$]", tostring(recipient), donationAmount), "DETECT")

		local username: string? = nil
		local displayName: string? = nil

		if recipientId then
			-- 1. Try instant in-server player lookup (0ms)
			local targetPlayer = Players:GetPlayerByUserId(recipientId)
			if targetPlayer then
				username = targetPlayer.Name
				displayName = targetPlayer.DisplayName
			end

			-- 2. If not found in current server, fetch via Roblox API
			if not username then
				pcall(function()
					local userInfos = UserService:GetUserInfosByUserIdsAsync({recipientId})
					if userInfos and #userInfos > 0 then
						username = userInfos[1].Username
						displayName = userInfos[1].DisplayName
					end
				end)
			end

			if not username then
				pcall(function()
					username = Players:GetNameFromUserIdAsync(recipientId)
					displayName = username
				end)
			end
		end

		local finalUser = (username and username ~= "") and username or ("User_" .. tostring(recipientId or "Unknown"))
		local finalDisplay = (displayName and displayName ~= "") and displayName or finalUser

		currentRecipientUser = finalUser
		currentRecipientDisplay = finalDisplay
		currentActiveItemName = finalDisplay

		if objects[20] then
			objects[20].Text = finalDisplay
		end
		if recipientUsernameLabel then
			recipientUsernameLabel.Text = "@" .. finalUser
		end

		-- Reset thumbnail to blank before new headshot arrives
		if avatarThumbnail then
			avatarThumbnail.Visible = false
			avatarThumbnail.Image = ""
		end

		-- Update transfer amount & fee calculation
		updateTransferAmount(donationAmount)

		-- Fetch and apply avatar headshot thumbnail
		if recipientId then
			task.spawn(function()
				local s, thumbUrl = pcall(function()
					return Players:GetUserThumbnailAsync(recipientId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				end)
				if s and thumbUrl and avatarThumbnail then
					avatarThumbnail.Image = thumbUrl
					avatarThumbnail.Visible = true
				end
			end)
		end

		-- Open modal with configured popup delay!
		if isScriptEnabled and not isModalOpen and not isModalBusy then
			local minD = math.max(0, tonumber(minPopupDelay) or 0)
			local maxD = math.max(minD, tonumber(maxPopupDelay) or minD)
			local delaySec = (maxD > minD) and (minD + (math.random() * (maxD - minD))) or minD

			if delaySec > 0 then
				if addLog then
					addLog(string.format("Popup delay active: waiting %.2fs before opening...", delaySec), "POPUP")
				end
				task.wait(delaySec)
			end

			if isScriptEnabled and not isModalOpen and not isModalBusy then
				openModal()
			end
		end
	end)
end

-- Listen to live console messages with pre-filter check
local logConnection = LogService.MessageOut:Connect(function(message, messageType)
	if isScriptEnabled and string.find(message, "Transfering transfer donation:", 1, true) then
		parseConsoleMessage(message)
	end
end)

-- Check console history on start
for _, log in ipairs(LogService:GetLogHistory()) do
	if string.find(log.message, "Transfering transfer donation:", 1, true) then
		parseConsoleMessage(log.message)
	end
end

-- ============================================================================
-- Block Real Roblox Send Robux / Purchase Prompts (from Monitor+removePopup.lua)
-- ============================================================================

local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local function setPromptVisibility(visible: boolean)
	pcall(function()
		for _, v in ipairs(CoreGui:GetChildren()) do
			local lower = string.lower(v.Name)
			if string.find(lower, "purchaseprompt") or string.find(lower, "productpurchase") or string.find(lower, "purchase") or string.find(lower, "prompt") or string.find(lower, "transfer") then
				if v:IsA("ScreenGui") and v ~= objects[1] and v.Name ~= "VIP_Buy_Item_Demo" then
					v.Enabled = visible
				end
				for _, sub in ipairs(v:GetDescendants()) do
					if sub:IsA("ScreenGui") and sub ~= objects[1] and sub.Name ~= "VIP_Buy_Item_Demo" then
						sub.Enabled = visible
					elseif sub:IsA("GuiObject") then
						sub.Visible = visible
					end
				end
			end
		end
	end)
	pcall(function()
		local robloxGui = CoreGui:FindFirstChild("RobloxGui")
		if robloxGui then
			for _, v in ipairs(robloxGui:GetChildren()) do
				local lower = string.lower(v.Name)
				if string.find(lower, "purchaseprompt") or string.find(lower, "productpurchase") or string.find(lower, "purchase") or string.find(lower, "prompt") or string.find(lower, "transfer") then
					if v:IsA("ScreenGui") then v.Enabled = visible end
					for _, sub in ipairs(v:GetDescendants()) do
						if sub:IsA("ScreenGui") then sub.Enabled = visible
						elseif sub:IsA("GuiObject") then sub.Visible = visible end
					end
				end
			end
		end
	end)
	pcall(function()
		if not visible and GuiService.SetPurchasePromptIsShown then
			GuiService:SetPurchasePromptIsShown(false)
		end
	end)
end

-- Pehle se hi prompt ko hide kar dein
setPromptVisibility(false)

-- Event listener: Naya prompt aate hi foran disable aur hide karein
pcall(function()
	CoreGui.DescendantAdded:Connect(function(desc)
		if not isScriptEnabled then return end
		local lower = string.lower(desc.Name)
		if string.find(lower, "purchaseprompt") or string.find(lower, "productpurchase") or lower == "productpurchasecontainer" then
			if desc:IsA("ScreenGui") and desc ~= objects[1] and desc.Name ~= "VIP_Buy_Item_Demo" then
				desc.Enabled = false
			elseif desc:IsA("GuiObject") then
				desc.Visible = false
			end
			pcall(function()
				if GuiService.SetPurchasePromptIsShown then
					GuiService:SetPurchasePromptIsShown(false)
				end
			end)
		end
	end)
end)

-- Fast loop jo popup ko khulne se foran rokega (from Monitor+removePopup.lua)
task.spawn(function()
	while true do
		if isScriptEnabled then
			setPromptVisibility(false)
		end
		task.wait(0.03)
	end
end)

-- Server Invoke ko block karein taake server prompt bhej hi na sake (from Monitor+removePopup.lua)
pcall(function()
	if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			local args = {...}

			if isScriptEnabled and method == "InvokeServer" then
				local isArg1User = (type(args[1]) == "number" and args[1] > 0)
				local arg2Num = tonumber(args[2])
				local isArg2Amount = (type(args[2]) == "number" or type(args[2]) == "string") and (arg2Num ~= nil and arg2Num > 0)

				if isArg1User and isArg2Amount then
					setPromptVisibility(false)
					task.spawn(function()
						updateTransferAmount(arg2Num)
					end)
					return nil -- Server call block! Purchase modal trigger hi na ho
				end
			end
			return oldNamecall(self, ...)
		end)
	end
end)

objects[1].Destroying:Connect(function()
	if logConnection then
		logConnection:Disconnect()
	end
end)

-- ============================================================================
-- VIP Name Tag & Playerlist Stats Controller
-- ============================================================================
do
	local VIP_NAME_ICON = "\xee\x80\x81"
	local STATS_ROBUX_ICON = "\xee\x80\x82"

	local headTagConnection: RBXScriptConnection? = nil
	local playerlistConnection: RBXScriptConnection? = nil
	local donatedConnection: RBXScriptConnection? = nil
	local raisedConnection: RBXScriptConnection? = nil

	local isEnforcingHeadTag = false
	local isEnforcingPlayerlist = false
	local isEnforcingDonated = false
	local isEnforcingRaised = false

	captureOriginalStatsFromGame = function()
		pcall(function()
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local dVal = leaderstats:FindFirstChild("Donated")
				local rVal = leaderstats:FindFirstChild("Raised")
				if dVal and dVal:IsA("ValueBase") then
					local v = tostring((dVal :: any).Value)
					local clean = (v:gsub("%D", ""))
					if clean ~= "" and (realGameDonated == "" or realGameDonated == "0") then
						realGameDonated = clean
						originalDonatedStr = clean
					end
				end
				if rVal and rVal:IsA("ValueBase") then
					local v = tostring((rVal :: any).Value)
					local clean = (v:gsub("%D", ""))
					if clean ~= "" and (realGameRaised == "" or realGameRaised == "0") then
						realGameRaised = clean
						originalRaisedStr = clean
					end
				end
			end
			local customCore = playerGui:FindFirstChild("CustomCoreGui")
			local playerlist = customCore and customCore:FindFirstChild("Playerlist")
			local scroll = playerlist and playerlist:FindFirstChild("ScrollingFrame")
			local userFrame = scroll and (scroll:FindFirstChild("User" .. tostring(player.UserId)) or scroll:FindFirstChild(tostring(player.UserId)))
			if not userFrame and scroll then
				for _, child in ipairs(scroll:GetChildren()) do
					if string.find(child.Name, tostring(player.UserId), 1, true) or string.find(child.Name, player.Name, 1, true) then
						userFrame = child
						break
					end
				end
			end
			local stats = userFrame and userFrame:FindFirstChild("Stats")
			if stats then
				local dLabel = stats:FindFirstChild("Donated")
				local rLabel = stats:FindFirstChild("Raised")
				if dLabel and dLabel:IsA("TextLabel") and (realGameDonated == "" or realGameDonated == "0") then
					local num = string.match(dLabel.Text, "%d[%d,%s]*")
					if num then
						local clean = (num:gsub("%D", ""))
						if clean ~= "" then
							realGameDonated = clean
							originalDonatedStr = clean
						end
					end
				end
				if rLabel and rLabel:IsA("TextLabel") and (realGameRaised == "" or realGameRaised == "0") then
					local num = string.match(rLabel.Text, "%d[%d,%s]*")
					if num then
						local clean = (num:gsub("%D", ""))
						if clean ~= "" then
							realGameRaised = clean
							originalRaisedStr = clean
						end
					end
				end
			end
		end)
	end

	local function enforceHeadTag(display: TextLabel)
		if isEnforcingHeadTag or not isScriptEnabled then return end
		local cur = display.Text
		local cleanName = string.gsub(cur, VIP_NAME_ICON .. "%s*", "")
		cleanName = string.gsub(cleanName, "[\238\128\129]%s*", "")
		cleanName = string.gsub(cleanName, "^%s*(.-)%s*$", "%1")
		if cleanName == "" then
			cleanName = player.DisplayName
		end
		local desired = isVipNameTagEnabled and (VIP_NAME_ICON .. " " .. cleanName) or cleanName

		if display.Text ~= desired then
			isEnforcingHeadTag = true
			display.Text = desired
			isEnforcingHeadTag = false
		end
	end

	updateHeadTag = function(char: Model?)
		if not isScriptEnabled then return end
		pcall(function()
			local targetChar = char or player.Character or workspace:FindFirstChild(player.Name)
			if not targetChar then return end
			local head = targetChar:FindFirstChild("Head")
			local headTag = head and head:FindFirstChild("HeadTag")
			local display = headTag and headTag:FindFirstChild("Display")
			if display and display:IsA("TextLabel") then
				if headTagConnection then
					headTagConnection:Disconnect()
					headTagConnection = nil
				end
				enforceHeadTag(display)
				headTagConnection = display:GetPropertyChangedSignal("Text"):Connect(function()
					enforceHeadTag(display)
				end)
			end
		end)
	end

	local function enforcePlayerlistName(disp: TextLabel)
		if isEnforcingPlayerlist or not isScriptEnabled then return end
		local cur = disp.Text

		local noVip = string.gsub(cur, VIP_NAME_ICON .. "%s*", "")
		noVip = string.gsub(noVip, "[\238\128\129]%s*", "")
		local cleanBase = string.gsub(noVip, "%s*<font.-</font>", "")
		cleanBase = string.gsub(cleanBase, "%s*%d+%s*🔥", "")
		cleanBase = string.gsub(cleanBase, "^%s*(.-)%s*$", "%1")
		if cleanBase == "" then
			cleanBase = player.DisplayName
		end

		local prefix = isVipNameTagEnabled and (VIP_NAME_ICON .. " ") or ""
		local suffix = ""
		if customFireStreak > 0 then
			suffix = string.format(' <font color="rgb(255,125,0)" size="11">%d 🔥</font>', customFireStreak)
		end

		local desired = prefix .. cleanBase .. suffix
		disp.RichText = true
		if disp.Text ~= desired then
			isEnforcingPlayerlist = true
			disp.Text = desired
			isEnforcingPlayerlist = false
		end
	end

	updatePlayerlistName = function()
		if not isScriptEnabled then return end
		pcall(function()
			local customCore = playerGui:FindFirstChild("CustomCoreGui")
			local playerlist = customCore and customCore:FindFirstChild("Playerlist")
			local scroll = playerlist and playerlist:FindFirstChild("ScrollingFrame")
			if not scroll then return end

			local userFrame = scroll:FindFirstChild("User" .. tostring(player.UserId)) or scroll:FindFirstChild(tostring(player.UserId))
			if not userFrame then
				for _, child in ipairs(scroll:GetChildren()) do
					if string.find(child.Name, tostring(player.UserId), 1, true) or string.find(child.Name, player.Name, 1, true) then
						userFrame = child
						break
					end
				end
			end

			local info = userFrame and userFrame:FindFirstChild("Info")
			local disp = info and info:FindFirstChild("DisplayName")
			if disp and disp:IsA("TextLabel") then
				if playerlistConnection then
					playerlistConnection:Disconnect()
					playerlistConnection = nil
				end
				enforcePlayerlistName(disp)
				playerlistConnection = disp:GetPropertyChangedSignal("Text"):Connect(function()
					enforcePlayerlistName(disp)
				end)
			end
		end)
	end

	local function enforceDonated(donatedLabel: TextLabel)
		if isEnforcingDonated or not isScriptEnabled then return end
		captureOriginalStatsFromGame()
		local displayVal = getActiveDonated()
		local prefixIcon = STATS_ROBUX_ICON
		local curText = donatedLabel.Text
		local matchedPrefix = string.match(curText, "^([^%d]+)")
		if matchedPrefix and matchedPrefix ~= "" then
			prefixIcon = matchedPrefix
		end
		local desired = prefixIcon .. formatWithCommas(displayVal)
		if donatedLabel.Text ~= desired then
			isEnforcingDonated = true
			donatedLabel.Text = desired
			isEnforcingDonated = false
		end
	end

	local function enforceRaised(raisedLabel: TextLabel)
		if isEnforcingRaised or not isScriptEnabled then return end
		captureOriginalStatsFromGame()
		local displayVal = getActiveRaised()
		local prefixIcon = STATS_ROBUX_ICON
		local curText = raisedLabel.Text
		local matchedPrefix = string.match(curText, "^([^%d]+)")
		if matchedPrefix and matchedPrefix ~= "" then
			prefixIcon = matchedPrefix
		end
		local desired = prefixIcon .. formatWithCommas(displayVal)
		if raisedLabel.Text ~= desired then
			isEnforcingRaised = true
			raisedLabel.Text = desired
			isEnforcingRaised = false
		end
	end

	updatePlayerlistStats = function()
		if not isScriptEnabled then return end
		pcall(function()
			captureOriginalStatsFromGame()
			local customCore = playerGui:FindFirstChild("CustomCoreGui")
			local playerlist = customCore and customCore:FindFirstChild("Playerlist")
			local scroll = playerlist and playerlist:FindFirstChild("ScrollingFrame")
			if not scroll then return end

			local userFrame = scroll:FindFirstChild("User" .. tostring(player.UserId)) or scroll:FindFirstChild(tostring(player.UserId))
			if not userFrame then
				for _, child in ipairs(scroll:GetChildren()) do
					if string.find(child.Name, tostring(player.UserId), 1, true) or string.find(child.Name, player.Name, 1, true) then
						userFrame = child
						break
					end
				end
			end
			local stats = userFrame and userFrame:FindFirstChild("Stats")
			if not stats then return end

			local donatedLabel = stats:FindFirstChild("Donated")
			local raisedLabel = stats:FindFirstChild("Raised")

			if donatedLabel and donatedLabel:IsA("TextLabel") then
				if donatedConnection then donatedConnection:Disconnect() end
				enforceDonated(donatedLabel)
				donatedConnection = donatedLabel:GetPropertyChangedSignal("Text"):Connect(function()
					enforceDonated(donatedLabel)
				end)
			end

			if raisedLabel and raisedLabel:IsA("TextLabel") then
				if raisedConnection then raisedConnection:Disconnect() end
				enforceRaised(raisedLabel)
				raisedConnection = raisedLabel:GetPropertyChangedSignal("Text"):Connect(function()
					enforceRaised(raisedLabel)
				end)
			end
		end)

		-- Also keep UI inputs in Settings card synchronized if in Original mode
		if useOriginalStats then
			if donatedInput and not donatedInput:IsFocused() then
				local dText = formatWithCommas(getActiveDonated())
				if donatedInput.Text ~= dText then
					donatedInput.Text = dText
				end
			end
			if raisedInput and not raisedInput:IsFocused() then
				local rText = formatWithCommas(getActiveRaised())
				if raisedInput.Text ~= rText then
					raisedInput.Text = rText
				end
			end
		end
	end

	-- Connect character spawn
	player.CharacterAdded:Connect(function(newChar)
		task.wait(0.3)
		updateHeadTag(newChar)
	end)

	if player.Character then
		task.spawn(function()
			task.wait(0.2)
			updateHeadTag(player.Character)
		end)
	end

	-- Periodic sync loop (re-verifies bindings in case UI was reloaded)
	task.spawn(function()
		while true do
			if isScriptEnabled then
				updateHeadTag(player.Character)
				updatePlayerlistName()
				updatePlayerlistStats()
			end
			task.wait(1.0)
		end
	end)
end

-- ============================================================================
-- MainGUI Giftbux Balance Controller
-- Path: game:GetService("Players").LocalPlayer.PlayerGui.MainGUI.Giftbux.Balance
-- ============================================================================
do
	local currentGiftbuxBalance: number? = nil
	local initialRealGiftbuxBalance: number? = nil
	local isEnforcingGiftbux = false
	local giftbuxConnection: RBXScriptConnection? = nil

	local function getGiftbuxBalanceLabel(): TextLabel?
		local mainGui = playerGui:FindFirstChild("MainGUI")
		if not mainGui then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if string.lower(gui.Name) == "maingui" then
					mainGui = gui
					break
				end
			end
		end
		if not mainGui then return nil end

		local giftbux = mainGui:FindFirstChild("Giftbux")
		if not giftbux then
			for _, child in ipairs(mainGui:GetChildren()) do
				if string.lower(child.Name) == "giftbux" then
					giftbux = child
					break
				end
			end
		end
		if not giftbux then return nil end

		local balance = giftbux:FindFirstChild("Balance")
		if not balance then
			for _, child in ipairs(giftbux:GetChildren()) do
				if string.lower(child.Name) == "balance" and child:IsA("TextLabel") then
					balance = child
					break
				end
			end
		end

		if balance and balance:IsA("TextLabel") then
			return balance
		end
		return nil
	end

	local function enforceGiftbux(label: TextLabel)
		if isEnforcingGiftbux or not isScriptEnabled then return end
		if currentGiftbuxBalance == nil then
			local raw = tonumber((string.gsub(label.Text, "%D", ""))) or 0
			currentGiftbuxBalance = raw
			initialRealGiftbuxBalance = raw
		end
		local desired = formatWithCommas(currentGiftbuxBalance)
		if label.Text ~= desired then
			isEnforcingGiftbux = true
			label.Text = desired
			isEnforcingGiftbux = false
		end
	end

	hookGiftbux = function()
		if not isScriptEnabled then return end
		pcall(function()
			local label = getGiftbuxBalanceLabel()
			if label then
				if giftbuxConnection then
					giftbuxConnection:Disconnect()
					giftbuxConnection = nil
				end
				enforceGiftbux(label)
				giftbuxConnection = label:GetPropertyChangedSignal("Text"):Connect(function()
					enforceGiftbux(label)
				end)
			end
		end)
	end

	addGiftbux = function(amountToAdd: number)
		pcall(function()
			local label = getGiftbuxBalanceLabel()
			if label and currentGiftbuxBalance == nil then
				local raw = tonumber((string.gsub(label.Text, "%D", ""))) or 0
				currentGiftbuxBalance = raw
				initialRealGiftbuxBalance = raw
			end
			currentGiftbuxBalance = (currentGiftbuxBalance or 0) + amountToAdd
			if label then
				enforceGiftbux(label)
			end
			if addLog then
				addLog(string.format("Giftbux balance updated: +%d | Total: %s", amountToAdd, formatWithCommas(currentGiftbuxBalance or 0)), "SYSTEM")
			end
		end)
	end

	resetGiftbux = function()
		pcall(function()
			local label = getGiftbuxBalanceLabel()
			if initialRealGiftbuxBalance ~= nil then
				currentGiftbuxBalance = initialRealGiftbuxBalance
				if label then
					enforceGiftbux(label)
				end
				if addLog then
					addLog(string.format("Giftbux balance restored to original: %s", formatWithCommas(initialRealGiftbuxBalance)), "SYSTEM")
				end
			end
		end)
	end

	-- Initial hook and periodic sync
	task.spawn(function()
		task.wait(0.5)
		hookGiftbux()
		while true do
			if isScriptEnabled then
				hookGiftbux()
			end
			task.wait(1.5)
		end
	end)
end

-- ============================================================================
-- Exposed External API & Bindables for Future Connections
-- ============================================================================

do
	local apiFolder = Instance.new("Folder")
	apiFolder.Name = "SettingsAPI"
	apiFolder.Parent = objects[1]

	local bindLog = Instance.new("BindableEvent")
	bindLog.Name = "AddLog"
	bindLog.Event:Connect(function(msg, tag)
		addLog(tostring(msg), tag and tostring(tag) or "CONNECT")
	end)
	bindLog.Parent = apiFolder

	local bindSetAmount = Instance.new("BindableEvent")
	bindSetAmount.Name = "SetAmount"
	bindSetAmount.Event:Connect(function(newAmt)
		local str = tostring(newAmt)
		amountTextBox.Text = str
		updateAmountDisplay(str)
		saveConfigToStorage()
		addLog("External connection set total balance to: " .. str, "CONNECT")
	end)
	bindSetAmount.Parent = apiFolder

	local bindSetTransfer = Instance.new("BindableEvent")
	bindSetTransfer.Name = "SetTransferAmount"
	bindSetTransfer.Event:Connect(function(newAmt)
		updateTransferAmount(newAmt)
		saveConfigToStorage()
		addLog("External connection set transfer amount to: " .. tostring(newAmt), "CONNECT")
	end)
	bindSetTransfer.Parent = apiFolder

	local bindSetRecipient = Instance.new("BindableEvent")
	bindSetRecipient.Name = "SetRecipient"
	bindSetRecipient.Event:Connect(function(username, displayName)
		setRecipient(username, displayName)
		addLog("Recipient updated to: @" .. tostring(username), "CONNECT")
	end)
	bindSetRecipient.Parent = apiFolder

	local bindToggle = Instance.new("BindableEvent")
	bindToggle.Name = "ToggleMenu"
	bindToggle.Event:Connect(function()
		toggleMenu()
	end)
	bindToggle.Parent = apiFolder
end

objects[1]:SetAttribute("TotalAmount", currentTotalAmount)
objects[1]:SetAttribute("TransferAmount", currentActivePriceNum)
objects[1]:SetAttribute("ScriptEnabled", isScriptEnabled)
objects[1]:SetAttribute("AutoHideOnRun", autoHideOnRun)
objects[1]:SetAttribute("ToggleKey", currentKeybind.Name)
objects[1]:SetAttribute("MinDelay", minPopupDelay)
objects[1]:SetAttribute("MaxDelay", maxPopupDelay)
objects[1]:SetAttribute("IsMenuOpen", isMenuOpen)
objects[1]:SetAttribute("FireStreak", customFireStreak)

-- Initial Startup sequence
addLog("Settings system initialized.", "SYSTEM")
addLog("Ready for new transfer logic.", "CONNECT")
addLog(string.format("Popup Delay set to [%.1fs - %.1fs].", minPopupDelay, maxPopupDelay), "CONFIG")
addLog("Loaded config (Amount: " .. currentTotalAmount .. ", AutoHide: " .. (autoHideOnRun and "ON" or "OFF") .. ", Key: [" .. currentKeybind.Name .. "]).", "CONFIG")
addLog(string.format("Press [%s] to show/hide this Config menu at any time.", currentKeybind.Name), "KEYBIND")

print(string.format("[Send Robux UI] Script initialized successfully! Menu is %s (Press [%s] to toggle)", autoHideOnRun and "HIDDEN (AutoHideOnRun=ON)" or "VISIBLE", currentKeybind.Name))

if not autoHideOnRun then
	setMenuVisible(true, false)
else
	setMenuVisible(false, true)
end

return objects[1]
