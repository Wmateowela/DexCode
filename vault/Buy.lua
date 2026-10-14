--!strict
-- ============================================================================
-- VIP Buy Item Demo with Advanced Settings & Live Button Tracking Controller
-- Features:
--   1. Direct Buy Modal auto-popup disabled on launch.
--   2. Sleek Left-side Settings Menu with smooth sliding transitions.
--   3. Persistent Total Amount (auto-saved across script re-runs via file / memory).
--   4. Persistent Start Hidden / Auto-Unshow toggle (auto-saved across script runs).
--   5. Persistent Keybind Selector button (Default: F4, auto-saved across runs).
--   6. Configurable Random Popup Delay (Default: 1.0s to 2.0s, configurable in Settings).
--   7. Button Price Text shows "..." while popup is open, and restores on modal close.
--   8. On Buy button click: direct dark layer (stationary on button), 2s wait, instant direct close.
--   9. Animated entrance for "Purchase completed" Modal:
--      - Exact layout matching user's reference mockup
--      - "Purchase completed" header (same font and size)
--      - Checkmark circle icon ("rbxassetid://98579402919536")
--      - "You have successfully bought <ItemName>." (TextSize = 16)
--      - Blue "OK" button moved up, hover effect disabled
--      - Snug modal height (248px) with membership banner removed
--      - Robux deduction happens on OK/Close completion
--  10. Multi-Category Shop Tracking (Gamepasses, SpeedPacks, Potions, CashPacks, EggsPack, etc.).
--  11. Dynamic Icon Extraction from Inner.Icon for non-egg items (EggsPack preserves clean egg logo).
--  12. GiftPlayer Select Button Shield: blocks default prompt, opens custom modal with item price.
--  13. Click Shop.lua Integration: clicks LeftHUD.Shop via VirtualInputManager during gift delay.
-- ============================================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- Persistent Configuration Storage (Executor File System + Environment Fallback)
-- ============================================================================

local CONFIG_FILE = "VIP_Buy_Settings.json"

local currentTotalAmount = "903"
local autoHideOnRun = false
local currentKeybind = Enum.KeyCode.F4
local minPopupDelay = 1.0
local maxPopupDelay = 2.0

local function loadSavedConfig()
	local loadedData = nil

	-- 1. Try reading from executor disk file (writefile / readfile)
	if type(isfile) == "function" and type(readfile) == "function" then
		local s, exists = pcall(isfile, CONFIG_FILE)
		if s and exists then
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
		if loadedData.AutoHideOnRun ~= nil then
			autoHideOnRun = (loadedData.AutoHideOnRun == true)
		end
		if loadedData.Keybind and type(loadedData.Keybind) == "string" then
			local success, keyEnum = pcall(function()
				return Enum.KeyCode[loadedData.Keybind]
			end)
			if success and keyEnum then
				currentKeybind = keyEnum
			end
		end
		if loadedData.MinDelay ~= nil then
			minPopupDelay = tonumber(loadedData.MinDelay) or 1.0
		end
		if loadedData.MaxDelay ~= nil then
			maxPopupDelay = tonumber(loadedData.MaxDelay) or 2.0
		end
	end
end

local function saveConfigToStorage()
	local configData = {
		TotalAmount = currentTotalAmount,
		AutoHideOnRun = autoHideOnRun,
		Keybind = currentKeybind.Name,
		MinDelay = minPopupDelay,
		MaxDelay = maxPopupDelay,
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

local objects = {}

local existingGui = playerGui:FindFirstChild("VIP_Buy_Item_Demo")
if existingGui then existingGui:Destroy() end

-- [[1: ScreenGui "VIP_Buy_Item_Demo"]]
objects[1] = Instance.new("ScreenGui")
objects[1].Name = "VIP_Buy_Item_Demo"
objects[1].ResetOnSpawn = false
objects[1].ZIndexBehavior = Enum.ZIndexBehavior.Sibling
objects[1].DisplayOrder = 100
objects[1].IgnoreGuiInset = true
objects[1].ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
objects[1].Parent = playerGui

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
objects[3].Size = UDim2.new(0, 450, 0, 286)
objects[3].Position = UDim2.new(0.5, 0, 0.491261, 7)
objects[3].AnchorPoint = Vector2.new(0.5, 0.5)
objects[3].ZIndex = 2
objects[3].BackgroundColor3 = Color3.fromRGB(0, 0, 0)
objects[3].BackgroundTransparency = 1
objects[3].BorderSizePixel = 0
objects[3].Parent = objects[2]

-- [[4: UICorner "UICorner"]]
objects[4] = Instance.new("UICorner")
objects[4].CornerRadius = UDim.new(0, 16)
objects[4].Parent = objects[3]

-- [[5: UIScale "UIScale"]]
objects[5] = Instance.new("UIScale")
objects[5].Scale = 1.0
objects[5].Parent = objects[3]

-- [[6: CanvasGroup "BuyItemModal" (Main Modal Frame)]]
objects[6] = Instance.new("CanvasGroup")
objects[6].Name = "BuyItemModal"
objects[6].Size = UDim2.new(0, 450, 0, 286)
objects[6].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[6].AnchorPoint = Vector2.new(0.5, 0.5)
objects[6].ZIndex = 3
objects[6].BackgroundColor3 = Color3.fromRGB(26, 28, 34)
objects[6].BorderSizePixel = 0
objects[6].GroupTransparency = 1
objects[6].Parent = objects[2]

-- [[7: UICorner "UICorner"]]
objects[7] = Instance.new("UICorner")
objects[7].CornerRadius = UDim.new(0, 16)
objects[7].Parent = objects[6]

-- [[8: UIStroke "UIStroke"]]
objects[8] = Instance.new("UIStroke")
objects[8].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
objects[8].Color = Color3.fromRGB(255, 255, 255)
objects[8].Transparency = 0.95
objects[8].Parent = objects[6]

-- [[9: UIScale "UIScale"]]
objects[9] = Instance.new("UIScale")
objects[9].Scale = 1.0
objects[9].Parent = objects[6]

-- ============================================================================
-- View 1: Buy Item View Container
-- ============================================================================
local buyView = Instance.new("Frame")
buyView.Name = "BuyView"
buyView.Size = UDim2.new(1, 0, 1, 0)
buyView.BackgroundTransparency = 1
buyView.ZIndex = 3
buyView.Visible = true
buyView.Parent = objects[6]

-- [[10: TextLabel "TitleLabel"]]
objects[10] = Instance.new("TextLabel")
objects[10].Name = "TitleLabel"
objects[10].Size = UDim2.new(0, 200, 0, 28)
objects[10].Position = UDim2.new(0, 20, 0, 18)
objects[10].ZIndex = 4
objects[10].BackgroundTransparency = 1
objects[10].BorderSizePixel = 0
objects[10].Text = "Buy item"
objects[10].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[10].TextTransparency = 0
objects[10].TextSize = 26
objects[10].TextScaled = false
objects[10].TextWrapped = false
objects[10].TextXAlignment = Enum.TextXAlignment.Left
objects[10].TextYAlignment = Enum.TextYAlignment.Center
objects[10].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[10].TextTruncate = Enum.TextTruncate.AtEnd
objects[10].Parent = buyView

-- [[11: TextLabel "TotalAmountLabel" (Top-right beside Close Button)]]
objects[11] = Instance.new("TextLabel")
objects[11].Name = "TotalAmountLabel"
objects[11].Size = UDim2.new(0, 41, 0, 27)
objects[11].Position = UDim2.new(0, 365, 0, 17)
objects[11].ZIndex = 4
objects[11].BackgroundTransparency = 1
objects[11].BorderSizePixel = 0
objects[11].Text = currentTotalAmount
objects[11].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[11].TextTransparency = 0
objects[11].TextSize = 16
objects[11].TextScaled = false
objects[11].TextWrapped = false
objects[11].TextXAlignment = Enum.TextXAlignment.Left
objects[11].TextYAlignment = Enum.TextYAlignment.Center
objects[11].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[11].TextTruncate = Enum.TextTruncate.None
objects[11].Parent = buyView

-- [[12: TextButton "CloseButton"]]
objects[12] = Instance.new("TextButton")
objects[12].Name = "CloseButton"
objects[12].AutoButtonColor = false
objects[12].Size = UDim2.new(0, 24, 0, 26)
objects[12].Position = UDim2.new(0, 412, 0, 17)
objects[12].ZIndex = 7
objects[12].BackgroundTransparency = 1
objects[12].Text = ""
objects[12].Parent = buyView

objects[13] = Instance.new("Frame")
objects[13].Name = "CloseLine1"
objects[13].Size = UDim2.new(0, 2, 0, 17)
objects[13].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[13].AnchorPoint = Vector2.new(0.5, 0.5)
objects[13].Rotation = 45
objects[13].ZIndex = 8
objects[13].BackgroundColor3 = Color3.fromRGB(161, 161, 170)
objects[13].BorderSizePixel = 0
objects[13].Parent = objects[12]

objects[14] = Instance.new("Frame")
objects[14].Name = "CloseLine2"
objects[14].Size = UDim2.new(0, 2, 0, 17)
objects[14].Position = UDim2.new(0.5, 0, 0.5, 0)
objects[14].AnchorPoint = Vector2.new(0.5, 0.5)
objects[14].Rotation = -45
objects[14].ZIndex = 8
objects[14].BackgroundColor3 = Color3.fromRGB(161, 161, 170)
objects[14].BorderSizePixel = 0
objects[14].Parent = objects[12]

-- [[17: ImageLabel "Logo" (Permanent 1 Single Clean Image)]]
local DEFAULT_SINGLE_LOGO = "rbxassetid://140521974946567"
objects[17] = Instance.new("ImageLabel")
objects[17].Name = "Logo"
objects[17].Size = UDim2.new(0, 76, 0, 76)
objects[17].Position = UDim2.new(0, 20, 0, 64)
objects[17].ZIndex = 5
objects[17].BackgroundTransparency = 1
objects[17].BorderSizePixel = 0
objects[17].Image = DEFAULT_SINGLE_LOGO
objects[17].ScaleType = Enum.ScaleType.Fit
objects[17].ImageRectOffset = Vector2.zero
objects[17].ImageRectSize = Vector2.zero
objects[17].Parent = buyView

-- [[20: TextLabel "ItemNameLabel"]]
objects[20] = Instance.new("TextLabel")
objects[20].Name = "ItemNameLabel"
objects[20].Size = UDim2.new(0, 280, 0, 23)
objects[20].Position = UDim2.new(0, 112, 0, 80)
objects[20].ZIndex = 4
objects[20].BackgroundTransparency = 1
objects[20].BorderSizePixel = 0
objects[20].Text = "VIP"
objects[20].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[20].TextTransparency = 0
objects[20].TextSize = 16
objects[20].TextScaled = false
objects[20].TextWrapped = false
objects[20].TextXAlignment = Enum.TextXAlignment.Left
objects[20].TextYAlignment = Enum.TextYAlignment.Center
objects[20].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[20].TextTruncate = Enum.TextTruncate.AtEnd
objects[20].Parent = buyView

-- [[21: TextLabel "ItemPriceLabel"]]
objects[21] = Instance.new("TextLabel")
objects[21].Name = "ItemPriceLabel"
objects[21].Size = UDim2.new(0, 85, 0, 24)
objects[21].Position = UDim2.new(0, 140, 0, 105)
objects[21].ZIndex = 4
objects[21].BackgroundTransparency = 1
objects[21].BorderSizePixel = 0
objects[21].Text = "169"
objects[21].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[21].TextTransparency = 0
objects[21].TextSize = 16
objects[21].TextScaled = false
objects[21].TextWrapped = false
objects[21].TextXAlignment = Enum.TextXAlignment.Left
objects[21].TextYAlignment = Enum.TextYAlignment.Center
objects[21].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[21].TextTruncate = Enum.TextTruncate.AtEnd
objects[21].Parent = buyView

-- [[22: TextButton "BuyButton"]]
objects[22] = Instance.new("TextButton")
objects[22].Name = "BuyButton"
objects[22].AutoButtonColor = false
objects[22].Selectable = false
objects[22].ClipsDescendants = true
objects[22].Size = UDim2.new(0, 410, 0, 40)
objects[22].Position = UDim2.new(0, 20, 0, 165)
objects[22].ZIndex = 5
objects[22].BackgroundColor3 = Color3.fromRGB(57, 105, 252)
objects[22].BorderSizePixel = 0
objects[22].Text = "Buy"
objects[22].TextColor3 = Color3.fromRGB(255, 255, 255)
objects[22].TextTransparency = 0
objects[22].TextSize = 18
objects[22].TextScaled = false
objects[22].TextWrapped = false
objects[22].TextXAlignment = Enum.TextXAlignment.Center
objects[22].TextYAlignment = Enum.TextYAlignment.Center
objects[22].Font = Enum.Font.BuilderSansBold
objects[22].FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[22].Parent = buyView

objects[23] = Instance.new("UICorner")
objects[23].CornerRadius = UDim.new(0, 10)
objects[23].Parent = objects[22]

local buyButtonSizeConstraint = Instance.new("UISizeConstraint")
buyButtonSizeConstraint.MinSize = Vector2.new(410, 40)
buyButtonSizeConstraint.MaxSize = Vector2.new(410, 40)
buyButtonSizeConstraint.Parent = objects[22]

-- Buy Button Reveal Layer
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

-- [[24: Frame "MembershipBanner"]]
objects[24] = Instance.new("Frame")
objects[24].Name = "MembershipBanner"
objects[24].Size = UDim2.new(0, 410, 0, 41)
objects[24].Position = UDim2.new(0, 20, 0, 225)
objects[24].ZIndex = 4
objects[24].BackgroundColor3 = Color3.fromRGB(19, 21, 25)
objects[24].BorderSizePixel = 0
objects[24].Parent = buyView

objects[25] = Instance.new("UICorner")
objects[25].CornerRadius = UDim.new(0, 12)
objects[25].Parent = objects[24]

objects[26] = Instance.new("UIStroke")
objects[26].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
objects[26].Color = Color3.fromRGB(255, 255, 255)
objects[26].Transparency = 0.95
objects[26].Parent = objects[24]

objects[27] = Instance.new("TextLabel")
objects[27].Name = "MembershipText"
objects[27].Size = UDim2.new(0, 285, 0, 23)
objects[27].Position = UDim2.new(0, 39, 0, 9)
objects[27].ZIndex = 4
objects[27].BackgroundColor3 = Color3.fromRGB(246, 244, 249)
objects[27].BackgroundTransparency = 1
objects[27].BorderSizePixel = 0
objects[27].Text = "Get 10% off with Roblox Plus"
objects[27].TextColor3 = Color3.fromRGB(212, 212, 216)
objects[27].TextTransparency = 0
objects[27].TextSize = 16
objects[27].TextScaled = false
objects[27].TextWrapped = false
objects[27].TextXAlignment = Enum.TextXAlignment.Left
objects[27].TextYAlignment = Enum.TextYAlignment.Center
objects[27].FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
objects[27].TextTruncate = Enum.TextTruncate.AtEnd
objects[27].Parent = objects[24]

objects[28] = Instance.new("Frame")
objects[28].Name = "BadgeFrame"
objects[28].Size = UDim2.new(0, 41, 0, 21)
objects[28].Position = UDim2.new(0, 357, 0, 10)
objects[28].ZIndex = 5
objects[28].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
objects[28].BorderSizePixel = 0
objects[28].Parent = objects[24]

objects[29] = Instance.new("UICorner")
objects[29].CornerRadius = UDim.new(0, 12)
objects[29].Parent = objects[28]

objects[30] = Instance.new("TextLabel")
objects[30].Name = "BadgeText"
objects[30].Size = UDim2.new(1, 0, 1, 0)
objects[30].ZIndex = 6
objects[30].BackgroundTransparency = 1
objects[30].BorderSizePixel = 0
objects[30].Text = "New"
objects[30].TextColor3 = Color3.fromRGB(24, 24, 27)
objects[30].TextTransparency = 0
objects[30].TextSize = 11
objects[30].TextScaled = false
objects[30].TextWrapped = false
objects[30].TextXAlignment = Enum.TextXAlignment.Center
objects[30].TextYAlignment = Enum.TextYAlignment.Center
objects[30].Font = Enum.Font.GothamBold
objects[30].FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
objects[30].TextTruncate = Enum.TextTruncate.AtEnd
objects[30].Parent = objects[28]

objects[31] = Instance.new("ImageLabel")
objects[31].Name = "RobloxPlusLogo"
objects[31].Size = UDim2.new(0, 20, 0, 20)
objects[31].Position = UDim2.new(0.02439, 3, 0.243902, 1)
objects[31].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
objects[31].BackgroundTransparency = 1
objects[31].BorderSizePixel = 0
objects[31].Image = "rbxassetid://125746152594286"
objects[31].Parent = objects[24]

-- Robux Top Right Icon
objects[32] = Instance.new("ImageLabel")
objects[32].Name = "RobuxTopRightIcon"
objects[32].Size = UDim2.new(0, 24, 0, 24)
objects[32].Position = UDim2.new(0, 338, 0, 18)
objects[32].ZIndex = 4
objects[32].BackgroundTransparency = 1
objects[32].Image = "rbxassetid://16884178261"
objects[32].ImageRectOffset = Vector2.new(190, 152)
objects[32].ImageRectSize = Vector2.new(36, 36)
objects[32].Parent = buyView

-- Robux Item Icon
objects[33] = Instance.new("ImageLabel")
objects[33].Name = "RobuxItemIcon"
objects[33].Size = UDim2.new(0, 24, 0, 24)
objects[33].Position = UDim2.new(0, 112, 0, 105)
objects[33].ZIndex = 4
objects[33].BackgroundTransparency = 1
objects[33].Image = "rbxassetid://16884178261"
objects[33].ImageRectOffset = Vector2.new(190, 152)
objects[33].ImageRectSize = Vector2.new(36, 36)
objects[33].Parent = buyView

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

-- Success Header: "Purchase completed"
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
successDesc.Text = "You have successfully bought 1 Egg."
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

local function updateAmountDisplay(amountStr)
	local sanitized = tostring(amountStr)
	currentTotalAmount = sanitized
	objects[11].Text = sanitized

	-- Accurate text width calculation for 16px bold font
	local exactWidth = 0
	for i = 1, #sanitized do
		local c = sanitized:sub(i, i)
		if c == "," or c == "." then
			exactWidth = exactWidth + 4
		else
			exactWidth = exactWidth + 9.5
		end
	end
	exactWidth = math.max(14, math.ceil(exactWidth))

	-- TotalAmountLabel anchored with its right edge at 406 (right beside Close button at 412)
	local rightEdge = 406
	local labelX = rightEdge - exactWidth
	objects[11].Size = UDim2.new(0, exactWidth, 0, 27)
	objects[11].Position = UDim2.new(0, labelX, 0, 17)
	objects[11].TextXAlignment = Enum.TextXAlignment.Left

	-- Robux icon placed directly beside the amount text with a tight 3px gap
	local iconSize = 20
	objects[32].Size = UDim2.new(0, iconSize, 0, iconSize)
	objects[32].Position = UDim2.new(0, labelX - iconSize - 3, 0, 20)
end

updateAmountDisplay(currentTotalAmount)

-- ============================================================================
-- State & Animation Controller for Modal
-- ============================================================================

local isModalOpen = false
local isModalBusy = false
local isRevealRunning = false
local currentRevealTween = nil

local currentActiveItemName = "VIP"
local currentActivePriceStr = "169"
local currentActivePriceNum = 169
local isPendingBuy = false
local isProcessingPurchase = false

local activePriceLabel = nil
local activeOriginalPriceText = nil
local priceTextConn = nil
local isGiftPurchaseActive = false

-- ============================================================================
-- Pending Gift Animation System (Embedded from animation.lua)
-- ============================================================================

local currentGiftAnimationTweens = {}

local function stopPendingGiftAnimation(delaySeconds)
	task.spawn(function()
		if delaySeconds and delaySeconds > 0 then
			task.wait(delaySeconds)
		end
		for _, t in ipairs(currentGiftAnimationTweens) do
			pcall(function()
				t:Cancel()
				t:Destroy()
			end)
		end
		table.clear(currentGiftAnimationTweens)

		local existing = playerGui:FindFirstChild("PendingPurchaseGui")
		if existing then
			existing:Destroy()
		end
	end)
end

local function startPendingGiftAnimation()
	stopPendingGiftAnimation(0)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PendingPurchaseGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 95 -- Below VIP Buy modal (DisplayOrder 100), but above all game UI
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local pendingPurchase = Instance.new("Frame")
	pendingPurchase.Name = "PendingPurchase"
	pendingPurchase.Size = UDim2.fromScale(1, 1)
	pendingPurchase.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	pendingPurchase.BackgroundTransparency = 0.4
	pendingPurchase.Visible = true
	pendingPurchase.Parent = screenGui

	local gift = Instance.new("ImageLabel")
	gift.Name = "Gift"
	gift.Size = UDim2.fromScale(0.2, 0.2)
	gift.AnchorPoint = Vector2.new(0.5, 0.5)
	gift.Position = UDim2.fromScale(0.5, 0.5)
	gift.BackgroundTransparency = 1
	gift.Image = "rbxassetid://99174903737611"
	gift.Parent = pendingPurchase

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = gift

	local giftAspect = Instance.new("UIAspectRatioConstraint")
	giftAspect.AspectRatio = 1
	giftAspect.Parent = gift

	local spinner = Instance.new("ImageLabel")
	spinner.Name = "Spinner"
	spinner.Size = UDim2.fromScale(0.35, 0.35)
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.BackgroundTransparency = 1
	spinner.Image = "rbxassetid://2565668394"
	spinner.ImageColor3 = Color3.fromRGB(0, 170, 255)
	spinner.ImageTransparency = 0.2
	spinner.Parent = pendingPurchase

	local spinnerAspect = Instance.new("UIAspectRatioConstraint")
	spinnerAspect.AspectRatio = 1
	spinnerAspect.Parent = spinner

	local t1 = TweenService:Create(pendingPurchase, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 })
	local t2 = TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.3 })
	local t3 = TweenService:Create(spinner, TweenInfo.new(1.25, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })

	currentGiftAnimationTweens = {t1, t2, t3}
	for _, t in ipairs(currentGiftAnimationTweens) do
		t:Play()
	end
end

local function playReveal()
	if currentRevealTween then
		currentRevealTween:Cancel()
	end
	isRevealRunning = true
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
			isRevealRunning = false
		end
	end)
end

local function openModal()
	if isModalBusy or isModalOpen then return end
	isModalBusy = true
	isRevealRunning = true

	-- Always start with BuyView visible and SuccessView hidden
	buyView.Visible = true
	successView.Visible = false
	objects[6].Size = UDim2.new(0, 450, 0, 286)
	objects[3].Size = UDim2.new(0, 450, 0, 286)

	objects[2].Visible = true
	objects[2].BackgroundTransparency = 1
	objects[3].Position = UDim2.new(0.5, 0, 0.491261, 52)
	objects[3].BackgroundTransparency = 0.7
	objects[5].Scale = 1.0
	objects[6].Position = UDim2.new(0.5, 0, 0.5, 45)
	objects[6].GroupTransparency = 0.4
	objects[9].Scale = 1.0
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

local amountTextBox
local addLog

local function closeModal(isNormalClose)
	if isModalBusy or not isModalOpen then return end
	isModalBusy = true
	isModalOpen = false
	objects[1]:SetAttribute("IsOpen", false)

	if currentRevealTween then
		currentRevealTween:Cancel()
		currentRevealTween = nil
	end
	isRevealRunning = false

	if isNormalClose then
		local normalFadeInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tFadeModal = TweenService:Create(objects[6], normalFadeInfo, {GroupTransparency = 1})
		local tFadeShadow = TweenService:Create(objects[3], normalFadeInfo, {BackgroundTransparency = 1})
		local tFadeOverlay = TweenService:Create(objects[2], normalFadeInfo, {BackgroundTransparency = 1})

		tFadeModal:Play()
		tFadeShadow:Play()
		tFadeOverlay:Play()

		tFadeModal.Completed:Wait()
	else
		local closeMoveInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local closeFadeInfo = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		local tPosModal = TweenService:Create(objects[6], closeMoveInfo, {Position = UDim2.new(0.5, 0, 0.5, 40)})
		local tPosShadow = TweenService:Create(objects[3], closeMoveInfo, {Position = UDim2.new(0.5, 0, 0.491261, 47)})
		local tFadeModal = TweenService:Create(objects[6], closeFadeInfo, {GroupTransparency = 1})
		local tFadeShadow = TweenService:Create(objects[3], closeFadeInfo, {BackgroundTransparency = 1})
		local tFadeOverlay = TweenService:Create(objects[2], closeFadeInfo, {BackgroundTransparency = 1})

		tPosModal:Play()
		tPosShadow:Play()
		tFadeModal:Play()
		tFadeShadow:Play()
		tFadeOverlay:Play()

		tPosModal.Completed:Wait()
	end

	revealOverlay.Position = UDim2.new(0, 0, 0, 0)
	revealContainer.Visible = false
	objects[22].BackgroundColor3 = Color3.fromRGB(57, 105, 252)
	objects[6].Position = UDim2.new(0.5, 0, 0.5, 45)
	objects[3].Position = UDim2.new(0.5, 0, 0.491261, 52)
	objects[2].Visible = false
	isModalBusy = false

	-- POST-CLOSE LOGIC: Modal is now completely closed!
	-- 1. Deduct Robux balance ONLY after modal has fully closed
	if isPendingBuy then
		isPendingBuy = false
		local currentBalance = tonumber((currentTotalAmount:gsub(",", ""))) or 0
		local cost = currentActivePriceNum or 0
		local newBalance = math.max(0, currentBalance - cost)
		local newBalanceStr = tostring(newBalance)

		currentTotalAmount = newBalanceStr
		updateAmountDisplay(newBalanceStr)
		if amountTextBox then
			amountTextBox.Text = newBalanceStr
		end
		saveConfigToStorage()

		if addLog then
			addLog(string.format("Modal closed! Deducted %d R$ | New Total: %d R$", cost, newBalance), "POPUP")
		end
	end

	-- 2. Disconnect price text lock if active
	if priceTextConn then
		priceTextConn:Disconnect()
		priceTextConn = nil
	end

	-- 3. Restore price text on tracked button from "..." back to original price
	if activePriceLabel and activeOriginalPriceText then
		activePriceLabel.Text = activeOriginalPriceText
		if addLog then
			addLog(string.format("Restored price text for [%s] to '%s'", currentActiveItemName, activeOriginalPriceText), "TRACK")
		end
		activePriceLabel = nil
		activeOriginalPriceText = nil
	end

	-- 4. If gift purchase was active, close animation after 0.60s delay
	if isGiftPurchaseActive then
		isGiftPurchaseActive = false
		stopPendingGiftAnimation(0.60)
	else
		stopPendingGiftAnimation(0)
	end

	-- Reset view visibility and modal sizes for next run
	buyView.Visible = true
	successView.Visible = false
	objects[6].Size = UDim2.new(0, 450, 0, 286)
	objects[3].Size = UDim2.new(0, 450, 0, 286)
	isProcessingPurchase = false
end

-- ============================================================================
-- Left-Side Settings Menu UI System
-- ============================================================================

local isListeningForKey = false
local isMenuOpen = false
local isMenuAnimating = false

local function getTimestamp()
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

-- 1. Total Amount Card
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

-- 2. Popup Delay Card
local delayCard = Instance.new("Frame")
delayCard.Name = "DelayCard"
delayCard.LayoutOrder = 2
delayCard.Size = UDim2.new(1, 0, 0, 62)
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

local delayInputsRow = Instance.new("Frame")
delayInputsRow.Name = "DelayInputsRow"
delayInputsRow.Size = UDim2.new(1, -20, 0, 28)
delayInputsRow.Position = UDim2.new(0, 10, 0, 26)
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

local minDelayInput = Instance.new("TextBox")
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

local maxDelayInput = Instance.new("TextBox")
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

-- 3. Auto-Hide Card
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

local toggleSwitch = Instance.new("TextButton")
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

local toggleKnob = Instance.new("Frame")
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

-- 4. Keybind Card
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

local keybindButton = Instance.new("TextButton")
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

-- 5. Preview Modal Quick Trigger Button
local testButton = Instance.new("TextButton")
testButton.Name = "TestButton"
testButton.LayoutOrder = 5
testButton.AutoButtonColor = false
testButton.Size = UDim2.new(1, 0, 0, 30)
testButton.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
testButton.BorderSizePixel = 0
testButton.Text = "👁️ Preview Buy Popup"
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
		objects[17].Image = DEFAULT_SINGLE_LOGO
		objects[17].ScaleType = Enum.ScaleType.Fit
		objects[17].ImageRectOffset = Vector2.zero
		objects[17].ImageRectSize = Vector2.zero
		openModal()
	end
end)

-- 6. Activity & Connection Logs
local logsCard = Instance.new("Frame")
logsCard.Name = "LogsCard"
logsCard.LayoutOrder = 6
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

addLog = function(message, tag)
	logCounter = logCounter + 1
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
minDelayInput.FocusLost:Connect(function()
	local val = tonumber(minDelayInput.Text)
	if not val or val < 0 then val = 1.0 end
	minPopupDelay = val
	minDelayInput.Text = string.format("%.1f", val)
	saveConfigToStorage()
	addLog(string.format("Min popup delay set to: %.1fs", val), "CONFIG")
end)

maxDelayInput.FocusLost:Connect(function()
	local val = tonumber(maxDelayInput.Text)
	if not val or val < minPopupDelay then val = math.max(minPopupDelay, 2.0) end
	maxPopupDelay = val
	maxDelayInput.Text = string.format("%.1f", val)
	saveConfigToStorage()
	addLog(string.format("Max popup delay set to: %.1fs", val), "CONFIG")
end)

-- Toggle switch visual update
local function updateToggleVisual(animate)
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
local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local mobileToggleButton = nil

local function setMenuVisible(visible, instant)
	if isMenuAnimating and not instant then return end
	isMenuOpen = visible
	objects[1]:SetAttribute("IsMenuOpen", visible)

	if mobileToggleButton and isMobileDevice then
		if visible then
			mobileToggleButton.Visible = false
		else
			mobileToggleButton.Visible = true
		end
	end

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

if isMobileDevice then
	mobileToggleButton = Instance.new("ImageButton")
	mobileToggleButton.Name = "MobileMenuToggleCircle"
	mobileToggleButton.Size = UDim2.new(0, 52, 0, 52)
	mobileToggleButton.AnchorPoint = Vector2.new(1, 1)
	mobileToggleButton.Position = UDim2.new(1, -25, 1, -25)
	mobileToggleButton.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	mobileToggleButton.BackgroundTransparency = 0.1
	mobileToggleButton.BorderSizePixel = 0
	mobileToggleButton.ZIndex = 120
	mobileToggleButton.Active = true
	mobileToggleButton.AutoButtonColor = false
	mobileToggleButton.Visible = false
	mobileToggleButton.Parent = objects[1]

	local mobileCorner = Instance.new("UICorner")
	mobileCorner.CornerRadius = UDim.new(1, 0)
	mobileCorner.Parent = mobileToggleButton

	local mobileStroke = Instance.new("UIStroke")
	mobileStroke.Color = Color3.fromRGB(56, 189, 248)
	mobileStroke.Thickness = 2
	mobileStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mobileStroke.Parent = mobileToggleButton

	local mobileIcon = Instance.new("TextLabel")
	mobileIcon.Name = "Icon"
	mobileIcon.Size = UDim2.new(1, 0, 1, 0)
	mobileIcon.BackgroundTransparency = 1
	mobileIcon.Text = "☰"
	mobileIcon.TextColor3 = Color3.fromRGB(56, 189, 248)
	mobileIcon.Font = Enum.Font.GothamBold
	mobileIcon.TextSize = 24
	mobileIcon.ZIndex = 121
	mobileIcon.Parent = mobileToggleButton

	local mobileScale = Instance.new("UIScale")
	mobileScale.Scale = 1
	mobileScale.Parent = mobileToggleButton

	local isDragging = false
	local dragStart, startPos
	mobileToggleButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			dragStart = input.Position
			startPos = mobileToggleButton.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false
				end
			end)
		end
	end)
	mobileToggleButton.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - dragStart
			mobileToggleButton.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	mobileToggleButton.Activated:Connect(function()
		TweenService:Create(mobileScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.85}):Play()
		task.wait(0.1)
		TweenService:Create(mobileScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
		setMenuVisible(true)
	end)
end

local function toggleMenu()
	setMenuVisible(not isMenuOpen)
end

minimizeButton.Activated:Connect(function()
	setMenuVisible(false)
end)

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
-- Buy & Close Button Listeners (Transition to Purchase Completed Modal)
-- ============================================================================

local buyButton = objects[22]
local closeButton = objects[12]
local closeLine1 = objects[13]
local closeLine2 = objects[14]

local BUY_NORMAL_COLOR = Color3.fromRGB(57, 105, 252)

-- Hover effect disabled on buyButton and okButton as requested (stays normal blue)

buyButton.ChildAdded:Connect(function(child)
	if child:IsA("UIScale") then
		task.defer(function()
			child:Destroy()
		end)
	end
end)

-- Helper to open Purchase Completed Modal with the SAME entrance animation as Buy Item modal
local function openPurchaseCompletedModal()
	isModalBusy = true

	-- 1. Format clean item name for description
	local cleanName = currentActiveItemName
	if cleanName:match("^Purchase%s+") then
		cleanName = cleanName:gsub("^Purchase%s+", "")
	end
	successDesc.Text = "You have successfully bought " .. cleanName .. "."

	-- 2. Compact height (248px) with clean spacing below Title and snug at bottom
	objects[6].Size = UDim2.new(0, 450, 0, 248)
	objects[3].Size = UDim2.new(0, 450, 0, 248)

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

	addLog(string.format("Purchase completed modal opened for [%s]", cleanName), "POPUP")
end

-- Buy Button Click:
-- 1. Plays pressed layer sweep across button
-- 2. Waits 2 seconds
-- 3. Directly closes modal with NO animation
-- 4. Opens "Purchase completed" modal with same entrance animation
buyButton.Activated:Connect(function()
	if isModalBusy or not isModalOpen or isRevealRunning then return end
	isModalBusy = true
	isPendingBuy = true

	-- 1. Directly apply dark layer over Buy button (no left-to-right movement, stays stationary/darkened)
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

	-- 4. Open "Purchase completed" modal with the same entrance animation
	openPurchaseCompletedModal()
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
	closeModal(true)
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

objects[1]:GetAttributeChangedSignal("IsOpen"):Connect(function()
	local shouldOpen = objects[1]:GetAttribute("IsOpen")
	if shouldOpen and not isModalOpen and not isModalBusy then
		openModal()
	elseif shouldOpen == false and isModalOpen and not isModalBusy then
		closeModal(true)
	end
end)

-- ============================================================================
-- UI Tracking & RobuxShop / Multi-Category Button Interception System
-- ============================================================================

local function formatButtonTitle(rawName)
	local count, itemType = rawName:match("^Purchase(%d+)(.*)$")
	if count and itemType then
		return "Purchase " .. count .. " " .. itemType
	end
	local buyNum = rawName:match("^Buy(%d+)$")
	if buyNum then
		return "Buy " .. buyNum
	end
	return rawName
end

local function extractPriceFromButton(btn)
	local priceLabel = btn:FindFirstChild("Price", true)
	local priceRaw = ""

	if priceLabel then
		if priceLabel:IsA("TextLabel") or priceLabel:IsA("TextBox") or priceLabel:IsA("TextButton") then
			priceRaw = priceLabel.Text
		else
			local sub = priceLabel:FindFirstChildWhichIsA("TextLabel", true)
			if sub then priceRaw = sub.Text end
		end
	end

	if priceRaw == "" then
		for _, child in ipairs(btn:GetDescendants()) do
			if child:IsA("TextLabel") and child.Name ~= "OldPrice" and child.Name ~= "Amount" and child.Text:match("%d") then
				priceRaw = child.Text
				break
			end
		end
	end

	local clean = priceRaw:gsub("<[^>]+>", ""):gsub("%s+", "")
	local numStr = clean:match("%d[%d,%.]*") or "0"
	local num = tonumber((numStr:gsub(",", ""))) or 0

	return numStr, num
end

local function extractPriceFromButtonOrContext(btn)
	local str, num = extractPriceFromButton(btn)
	if num > 0 and str ~= "" and str ~= "..." then
		return str, num
	end

	if btn.Parent then
		local pStr, pNum = extractPriceFromButton(btn.Parent)
		if pNum > 0 and pStr ~= "" and pStr ~= "..." then
			return pStr, pNum
		end
		if btn.Parent.Parent then
			local ppStr, ppNum = extractPriceFromButton(btn.Parent.Parent)
			if ppNum > 0 and ppStr ~= "" and ppStr ~= "..." then
				return ppStr, ppNum
			end
		end
	end

	return str, num
end

local function cleanRichText(str)
	if type(str) ~= "string" then return "" end
	local clean = str:gsub("<[^>]+>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return clean
end

-- Checks if an instance is inside the main Shop ScrollingFrame (RobuxShop or legacy Shop)
local function isInsideShopScrollingFrame(inst)
	local cur = inst
	while cur and cur ~= playerGui do
		if cur:IsA("ScrollingFrame") then
			-- Ensure this ScrollingFrame is NOT inside GiftingPopUp / GiftPlayer
			if cur:FindFirstAncestor("GiftingPopUp") or cur:FindFirstAncestor("GiftPlayer") then
				return false
			end

			-- 1. New RobuxShop frame
			if cur:FindFirstAncestor("RobuxShop") then
				return true
			end

			-- 2. Legacy Shop frame
			local parent = cur.Parent
			if parent and (parent.Name == "Shop" or parent.Name == "Frame") then
				return true
			end
		end
		cur = cur.Parent
	end
	return false
end

-- Checks if a button is a purchase button (Buy, Buy1..Buy4, Robux, Purchase...)
local function isPurchaseButton(btn)
	if not btn:IsA("GuiButton") then return false end
	if not isInsideShopScrollingFrame(btn) then return false end
	if btn:FindFirstAncestor("GiftingPopUp") or btn:FindFirstAncestor("GiftPlayer") then return false end

	local name = btn.Name
	if name == "Buy" or name:match("^Buy%d+$") then
		return true
	end
	if name == "Robux" then
		return true
	end
	if name:match("Purchase") then
		return true
	end
	return false
end

-- Checks if a button is a shop gift button (Gift, Gift1..Gift4, GiftEggs...)
local function isGiftButton(btn)
	if not btn:IsA("GuiButton") then return false end
	if not isInsideShopScrollingFrame(btn) then return false end
	if btn:FindFirstAncestor("GiftingPopUp") or btn:FindFirstAncestor("GiftPlayer") then return false end

	local name = btn.Name
	if name == "Gift" or name:match("^Gift%d+$") or (name:match("^Gift") and not name:match("PopUp")) then
		return true
	end
	return false
end

-- Checks if a button is inside GiftingPopUp / GiftPlayer (PlayerTemplate.Select or PlayerTemplate.Gift)
local function isGiftingPopupButton(btn)
	if not btn:IsA("GuiButton") then return false end
	if btn.Name == "Close" then return false end

	-- 1. New GiftingPopUp inside RobuxShop or PlayerGui
	local popup = btn:FindFirstAncestor("GiftingPopUp")
	if popup then
		local template = btn:FindFirstAncestor("PlayerTemplate") or btn.Parent
		if template and (template.Name == "PlayerTemplate" or btn.Name == "Select" or btn.Name == "Gift") then
			return true
		end
	end

	-- 2. Legacy GiftPlayer
	local giftPlayer = btn:FindFirstAncestor("GiftPlayer")
	if giftPlayer then
		if btn.Name == "Select" or btn.Name == "Gift" then
			return true
		end
	end

	return false
end

-- Extracts dynamic item name, icon image, and spritesheet rects for any shop item
local function getItemDetails(btn)
	local iconImage = DEFAULT_SINGLE_LOGO
	local iconOffset = Vector2.zero
	local iconSize = Vector2.zero
	local itemName = btn.Name

	-- 1. Check for egg containers (LimitedEgg, OldLimitedEgg, or legacy EggsPack)
	local limitedEgg = btn:FindFirstAncestor("LimitedEgg") or btn:FindFirstAncestor("OldLimitedEgg")
	local legacyEgg = btn:FindFirstAncestor("EggsPack")

	if limitedEgg then
		local spacer = limitedEgg:FindFirstChild("Spacer") or limitedEgg
		local eggNameLabel = spacer:FindFirstChild("EggName") or spacer:FindFirstChild("Title")
		local rawEggName = "Extinction"
		if eggNameLabel and eggNameLabel:IsA("TextLabel") and eggNameLabel.Text ~= "" then
			rawEggName = cleanRichText(eggNameLabel.Text)
		end

		-- Strip "Egg" / "Eggs" if already included in EggName
		local baseEggName = rawEggName:gsub("%s*[Ee]gg[s]*%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if baseEggName == "" then baseEggName = "Extinction" end

		local sectionTitle = (limitedEgg.Name == "OldLimitedEgg") and "Old Limited Egg" or "Limited Egg"

		-- Extract Amount: check btn itself, or matching Buy button if btn is Gift
		local amountLabel = nil
		local amountObj = btn:FindFirstChild("Amount") or btn:FindFirstChild("Amount", true)
		if amountObj and amountObj:IsA("TextLabel") then
			amountLabel = amountObj
		else
			local num = btn.Name:match("%d+")
			if num and btn.Parent then
				local matchingBuy = btn.Parent:FindFirstChild("Buy" .. num)
				if matchingBuy then
					local subAmount = matchingBuy:FindFirstChild("Amount") or matchingBuy:FindFirstChild("Amount", true)
					if subAmount and subAmount:IsA("TextLabel") then
						amountLabel = subAmount
					end
				end
			end
		end

		local amountNum = "1"
		if amountLabel and amountLabel.Text ~= "" then
			amountNum = amountLabel.Text:match("%d+") or "1"
		else
			amountNum = btn.Name:match("%d+") or "1"
		end

		-- Format: (Extinction) Egg x(Amount)
		local formattedName = string.format("(%s) Egg x%s", baseEggName, amountNum)
		if btn.Name:match("^Gift") then
			itemName = "Gift " .. formattedName
		else
			itemName = formattedName
		end

		-- Extract egg icon from Spacer.bg: check MechanicalVersion first, then Icon, then any valid ImageLabel
		local bg = spacer:FindFirstChild("bg")
		local eggIcon = nil
		if bg then
			local mv = bg:FindFirstChild("MechanicalVersion")
			if mv and mv:IsA("ImageLabel") and mv.Image ~= "" then
				eggIcon = mv
			end
			if not eggIcon then
				local ic = bg:FindFirstChild("Icon")
				if ic and ic:IsA("ImageLabel") and ic.Image ~= "" then
					eggIcon = ic
				end
			end
			if not eggIcon then
				for _, desc in ipairs(bg:GetDescendants()) do
					if desc:IsA("ImageLabel") and desc.Image ~= "" and desc.Name ~= "Glow" and desc.Name ~= "Shadow" and desc.Name ~= "Stroke" then
						eggIcon = desc
						break
					end
				end
			end
		end

		if eggIcon and eggIcon.Image ~= "" then
			iconImage = eggIcon.Image
			iconOffset = eggIcon.ImageRectOffset
			iconSize = eggIcon.ImageRectSize
		else
			iconImage = DEFAULT_SINGLE_LOGO
		end

		return itemName, iconImage, iconOffset, iconSize
	elseif legacyEgg then
		local formatted = formatButtonTitle(btn.Name)
		return formatted, DEFAULT_SINGLE_LOGO, Vector2.zero, Vector2.zero
	end

	-- 2. Dedicated Passes section (Growth, Money)
	local passesSection = btn:FindFirstAncestor("Passes")
	if passesSection then
		local passCard = btn:FindFirstAncestorWhichIsA("ImageButton") or btn:FindFirstAncestorWhichIsA("Frame")
		if passCard and passCard.Name == "Btns" and passCard.Parent then
			passCard = passCard.Parent
		end

		if passCard then
			local titleLabel = passCard:FindFirstChild("Title")
			if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "" then
				itemName = cleanRichText(titleLabel.Text)
			else
				itemName = cleanRichText(passCard.Name)
			end

			local iconLabel = passCard:FindFirstChild("Icon")
			if not (iconLabel and iconLabel:IsA("ImageLabel") and iconLabel.Image ~= "") then
				for _, desc in ipairs(passCard:GetDescendants()) do
					if desc:IsA("ImageLabel") and desc.Name == "Icon" and desc.Image ~= "" then
						iconLabel = desc
						break
					end
				end
			end

			if iconLabel and iconLabel:IsA("ImageLabel") and iconLabel.Image ~= "" then
				iconImage = iconLabel.Image
				iconOffset = iconLabel.ImageRectOffset
				iconSize = iconLabel.ImageRectSize
			end
		end

		if btn.Name:match("^Gift") and not itemName:match("^Gift") then
			itemName = "Gift " .. itemName
		end
		return itemName, iconImage, iconOffset, iconSize
	end

	-- 3. Dedicated DoubleSpeed section
	local doubleSpeed = btn:FindFirstAncestor("DoubleSpeed")
	if doubleSpeed then
		local spacer = doubleSpeed:FindFirstChild("Spacer") or doubleSpeed
		local titleLabel = spacer:FindFirstChild("SectionTitle") or spacer:FindFirstChild("Title")
		if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "" then
			itemName = cleanRichText(titleLabel.Text)
		else
			itemName = "Double Speed"
		end

		local iconLabel = spacer:FindFirstChild("Icon") or spacer:FindFirstChildWhichIsA("ImageLabel", true)
		if iconLabel and iconLabel:IsA("ImageLabel") and iconLabel.Image ~= "" then
			iconImage = iconLabel.Image
			iconOffset = iconLabel.ImageRectOffset
			iconSize = iconLabel.ImageRectSize
		end

		if btn.Name:match("^Gift") and not itemName:match("^Gift") then
			itemName = "Gift " .. itemName
		end
		return itemName, iconImage, iconOffset, iconSize
	end

	-- 4. Dedicated UpgradeTreadmil section
	local upgradeTreadmill = btn:FindFirstAncestor("UpgradeTreadmil")
	if upgradeTreadmill then
		local spacer = upgradeTreadmill:FindFirstChild("Spacer") or upgradeTreadmill
		local label = spacer:FindFirstChild("Label1") or spacer:FindFirstChild("Label2")
		if label and label:IsA("TextLabel") and label.Text ~= "" then
			itemName = cleanRichText(label.Text)
		else
			itemName = "Upgrade Treadmill"
		end

		local iconLabel = spacer:FindFirstChild("NextTreadmill") or spacer:FindFirstChild("CurrentTreadmill") or spacer:FindFirstChild("Icon")
		if iconLabel and iconLabel:IsA("ImageLabel") and iconLabel.Image ~= "" then
			iconImage = iconLabel.Image
			iconOffset = iconLabel.ImageRectOffset
			iconSize = iconLabel.ImageRectSize
		end

		if btn.Name:match("^Gift") and not itemName:match("^Gift") then
			itemName = "Gift " .. itemName
		end
		return itemName, iconImage, iconOffset, iconSize
	end

	-- 5. Standard card containers: Money (c1..c5), Speed (c1..c6), Samples (c1..c4), Cards (StarBundle1..10)
	local card = btn:FindFirstAncestorWhichIsA("ImageLabel") or btn:FindFirstAncestorWhichIsA("ImageButton") or btn:FindFirstAncestorWhichIsA("Frame")
	if card and card.Name == "Btns" and card.Parent then
		card = card.Parent
	end

	if card then
		local titleLabel = card:FindFirstChild("Title") or card:FindFirstChild("Name") or card:FindFirstChildWhichIsA("TextLabel", true)
		if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "" and titleLabel.Name ~= "Price" and titleLabel.Name ~= "Amount" then
			itemName = cleanRichText(titleLabel.Text)
		elseif card.Name ~= "Frame" and card.Name ~= "Spacer" and card.Name ~= "Btns" and card.Name ~= "ButtonList" and card.Name ~= "Inner" then
			itemName = cleanRichText(card.Name)
		end

		local iconLabel = card:FindFirstChild("Icon")
		if not (iconLabel and iconLabel:IsA("ImageLabel")) then
			for _, desc in ipairs(card:GetDescendants()) do
				if desc:IsA("ImageLabel") and desc.Name == "Icon" and desc.Image ~= "" then
					iconLabel = desc
					break
				end
			end
		end
		if not iconLabel then
			local inner = card:FindFirstChild("Inner")
			if inner then
				iconLabel = inner:FindFirstChild("Icon") or inner:FindFirstChildWhichIsA("ImageLabel", true)
			end
		end

		if iconLabel and iconLabel:IsA("ImageLabel") and iconLabel.Image ~= "" then
			iconImage = iconLabel.Image
			iconOffset = iconLabel.ImageRectOffset
			iconSize = iconLabel.ImageRectSize
		end
	end

	if btn.Name:match("^Gift") and not itemName:match("^Gift") then
		itemName = "Gift " .. itemName
	end

	return itemName, iconImage, iconOffset, iconSize
end

-- Mappings for Gift prices in shop sections
local function getCorrespondingItemPrice(giftBtn)
	local container = giftBtn.Parent -- e.g. "Btns" or "ButtonList"
	if container then
		local rawName = giftBtn.Name

		-- 1. LimitedEgg / OldLimitedEgg: Gift1..Gift4 matches Buy1..Buy4
		local eggNum = rawName:match("^Gift(%d+)$")
		if eggNum then
			local buyBtn = container:FindFirstChild("Buy" .. eggNum)
			if buyBtn then
				local pStr, pNum = extractPriceFromButtonOrContext(buyBtn)
				if pNum > 0 and pStr ~= "" and pStr ~= "..." then
					return pStr, pNum
				end
			end
		end

		-- 2. Standard Gift button in Money, Speed, Passes, Samples -> matches sibling Buy button
		if rawName == "Gift" then
			local buyBtn = container:FindFirstChild("Buy") or container:FindFirstChild("Robux")
			if buyBtn then
				local pStr, pNum = extractPriceFromButtonOrContext(buyBtn)
				if pNum > 0 and pStr ~= "" and pStr ~= "..." then
					return pStr, pNum
				end
			end
		end

		-- 3. Legacy EggsPack e.g. Gift10Eggs -> Purchase10Eggs
		local count, itemType = rawName:match("^Gift(%d+)(.*)$")
		if count and itemType and itemType ~= "" then
			local matchingPurchaseName = "Purchase" .. count .. itemType
			local purchBtn = container:FindFirstChild(matchingPurchaseName)
			if purchBtn then
				local pStr, pNum = extractPriceFromButtonOrContext(purchBtn)
				if pNum > 0 and pStr ~= "" and pStr ~= "..." then
					return pStr, pNum
				end
			end
		end

		-- 4. Any purchase button sibling
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiButton") and (child.Name == "Buy" or child.Name:match("^Buy%d+$") or child.Name == "Robux" or child.Name:match("Purchase")) then
				local pStr, pNum = extractPriceFromButtonOrContext(child)
				if pNum > 0 and pStr ~= "" and pStr ~= "..." then
					return pStr, pNum
				end
			end
		end

		-- 5. Card context price
		local card = giftBtn:FindFirstAncestorWhichIsA("ImageLabel") or giftBtn:FindFirstAncestorWhichIsA("Frame")
		if card then
			local pStr, pNum = extractPriceFromButtonOrContext(card)
			if pNum > 0 and pStr ~= "" and pStr ~= "..." then
				return pStr, pNum
			end
		end
	end

	-- Fallback egg values
	local eggNum = giftBtn.Name:match("^Gift(%d+)")
	if eggNum then
		local fbTable = {
			["1"] = 39,
			["2"] = 109,
			["3"] = 349,
			["4"] = 1499,
		}
		local fb = fbTable[eggNum]
		if fb then return tostring(fb), fb end
	end

	return "39", 39
end

local function onPurchaseButtonClicked(btn)
	if isProcessingPurchase or isModalOpen or isModalBusy then return end
	isProcessingPurchase = true

	-- 1. Format Item Name and dynamic Icon
	local itemName, itemIcon, iconOffset, iconSize = getItemDetails(btn)
	currentActiveItemName = itemName
	objects[20].Text = itemName

	-- 2. Extract Price (e.g. 39, 499)
	local priceStr, priceNum = extractPriceFromButtonOrContext(btn)
	currentActivePriceStr = priceStr
	currentActivePriceNum = priceNum
	objects[21].Text = priceStr

	-- 3. Replace Button Price text with "..." while modal/delay is active
	local priceLabel = btn:FindFirstChild("Price", true)
	local targetTextLabel = nil
	if priceLabel then
		if priceLabel:IsA("TextLabel") or priceLabel:IsA("TextBox") or priceLabel:IsA("TextButton") then
			targetTextLabel = priceLabel
		else
			local sub = priceLabel:FindFirstChildWhichIsA("TextLabel", true)
			if sub then targetTextLabel = sub end
		end
	end
	if not targetTextLabel then
		for _, child in ipairs(btn:GetDescendants()) do
			if child:IsA("TextLabel") and child.Name ~= "Amount" and child.Name ~= "OldPrice" and child.Text:match("%d") then
				targetTextLabel = child
				break
			end
		end
	end
	if not targetTextLabel and btn.Parent then
		local parentPrice = btn.Parent:FindFirstChild("Price", true)
		if parentPrice and parentPrice:IsA("TextLabel") then
			targetTextLabel = parentPrice
		end
	end

	if targetTextLabel then
		activePriceLabel = targetTextLabel
		activeOriginalPriceText = targetTextLabel.Text
		targetTextLabel.Text = "..."

		-- Lock text to "..." so game scripts don't revert it while modal is active
		if priceTextConn then
			priceTextConn:Disconnect()
			priceTextConn = nil
		end
		priceTextConn = targetTextLabel:GetPropertyChangedSignal("Text"):Connect(function()
			if (isProcessingPurchase or isModalOpen) and targetTextLabel and targetTextLabel.Text ~= "..." then
				targetTextLabel.Text = "..."
			end
		end)
	end

	-- 4. Calculate random delay between minPopupDelay and maxPopupDelay (e.g. 1.0s to 2.0s)
	local minD = math.max(0, minPopupDelay)
	local maxD = math.max(minD, maxPopupDelay)
	local randomDelay = minD + (math.random() * (maxD - minD))
	randomDelay = math.floor(randomDelay * 100 + 0.5) / 100

	addLog(string.format("Tracked: %s | Price set to '...' | Delaying popup by %.2fs", itemName, randomDelay), "TRACK")

	-- 5. Open popup after random delay
	task.spawn(function()
		task.wait(randomDelay)

		objects[17].Image = itemIcon
		objects[17].ScaleType = Enum.ScaleType.Fit
		objects[17].ImageRectOffset = iconOffset
		objects[17].ImageRectSize = iconSize

		addLog(string.format("Opening modal for [%s] (Price: %s R$)", itemName, priceStr), "POPUP")
		openModal()
	end)
end

local function hookPurchaseButton(btn)
	if not btn:IsA("GuiButton") then return end
	if not isPurchaseButton(btn) then return end
	if btn:GetAttribute("CustomHooked") then return end
	btn:SetAttribute("CustomHooked", true)

	-- 1. Disable executor connections on the original button
	if type(getconnections) == "function" then
		for _, signal in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
			local s, conns = pcall(getconnections, signal)
			if s and type(conns) == "table" then
				for _, conn in ipairs(conns) do
					pcall(function() conn:Disable() end)
				end
			end
		end
	end

	-- 2. Create invisible Shield button overlay on top to absorb click
	local shield = btn:FindFirstChild("CustomPurchaseShield")
	if not shield then
		shield = Instance.new("TextButton")
		shield.Name = "CustomPurchaseShield"
		shield.Size = UDim2.new(1, 0, 1, 0)
		shield.Position = UDim2.new(0, 0, 0, 0)
		shield.BackgroundTransparency = 1
		shield.Text = ""
		shield.ZIndex = math.max(btn.ZIndex + 50, 100)
		shield.Active = true
		shield.Selectable = false
		shield.Parent = btn

		shield.Activated:Connect(function()
			onPurchaseButtonClicked(btn)
		end)
		shield.MouseButton1Click:Connect(function()
			onPurchaseButtonClicked(btn)
		end)
	end
end

-- ============================================================================
-- Gift Tracking & GiftingPopUp System
-- ============================================================================

local pendingGiftInfo = nil

local function onGiftButtonClicked(btn)
	local itemName, itemIcon, iconOffset, iconSize = getItemDetails(btn)
	local priceStr, priceNum = getCorrespondingItemPrice(btn)

	pendingGiftInfo = {
		name = itemName,
		rawName = btn.Name,
		icon = itemIcon,
		iconOffset = iconOffset,
		iconSize = iconSize,
		priceStr = priceStr,
		priceNum = priceNum,
	}

	addLog(string.format("Monitored Gift: %s | Mapped Price: %s R$", itemName, priceStr), "TRACK")
end

local function hookGiftButton(btn)
	if not btn:IsA("GuiButton") then return end
	if not isGiftButton(btn) then return end
	if btn:GetAttribute("GiftMonitored") then return end
	btn:SetAttribute("GiftMonitored", true)

	-- IMPORTANT: DO NOT place a shield or block clicks!
	-- Click must pass through to game so GiftingPopUp opens.
	btn.Activated:Connect(function()
		onGiftButtonClicked(btn)
	end)

	btn.MouseButton1Click:Connect(function()
		onGiftButtonClicked(btn)
	end)
end

-- Switches GiftingPopUp.Visible = false and Frame.Visible = true after a brief delay (<1s) without any auto-clickers
local function switchGiftingToShopFrame()
	task.spawn(function()
		-- Brief delay less than 1 second (0.25s) as requested
		task.wait(0.25)

		local rShop = playerGui:FindFirstChild("RobuxShop") or playerGui:FindFirstChild("RobuxShop", true)
		if rShop then
			local giftPopup = rShop:FindFirstChild("GiftingPopUp") or rShop:FindFirstChild("GiftingPopUp", true)
			local mainFrame = rShop:FindFirstChild("Frame") or rShop:FindFirstChild("Frame", true)

			if giftPopup and giftPopup:IsA("GuiObject") then
				giftPopup.Visible = false
			end
			if mainFrame and mainFrame:IsA("GuiObject") then
				mainFrame.Visible = true
			end
		end

		local legacyGiftPlayer = playerGui:FindFirstChild("GiftPlayer", true)
		if legacyGiftPlayer and legacyGiftPlayer:IsA("GuiObject") then
			legacyGiftPlayer.Visible = false
		end
	end)
end

local function onGiftSelectButtonClicked(selectBtn)
	if isProcessingPurchase or isModalOpen or isModalBusy then return end
	isProcessingPurchase = true
	isGiftPurchaseActive = true

	-- 1. Start the pending gift animation from animation.lua
	startPendingGiftAnimation()

	-- 2. Pure visibility switch: GiftingPopUp -> false, Frame -> true after brief delay
	switchGiftingToShopFrame()

	local giftName = pendingGiftInfo and pendingGiftInfo.name or "Gift Item"
	local priceStr = pendingGiftInfo and pendingGiftInfo.priceStr or "39"
	local priceNum = pendingGiftInfo and pendingGiftInfo.priceNum or 39
	local itemIcon = pendingGiftInfo and pendingGiftInfo.icon or DEFAULT_SINGLE_LOGO
	local iconOffset = pendingGiftInfo and pendingGiftInfo.iconOffset or Vector2.zero
	local iconSize = pendingGiftInfo and pendingGiftInfo.iconSize or Vector2.zero

	currentActiveItemName = giftName
	currentActivePriceStr = priceStr
	currentActivePriceNum = priceNum

	objects[20].Text = giftName
	objects[21].Text = priceStr

	local playerCard = selectBtn:FindFirstAncestor("PlayerTemplate") or selectBtn:FindFirstAncestorWhichIsA("Frame") or selectBtn.Parent
	local recipientName = "Player"
	if playerCard then
		local nameLabel = playerCard:FindFirstChild("PlayerName", true) or playerCard:FindFirstChild("PlayerNickName", true) or playerCard:FindFirstChild("Username", true)
		if nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text ~= "" then
			recipientName = cleanRichText(nameLabel.Text)
		else
			recipientName = playerCard.Name
		end
	end

	local minD = math.max(0, minPopupDelay)
	local maxD = math.max(minD, maxPopupDelay)
	local randomDelay = minD + (math.random() * (maxD - minD))
	randomDelay = math.floor(randomDelay * 100 + 0.5) / 100

	addLog(string.format("Gift recipient selected: [%s] for [%s] | Animation started | Delay: %.2fs", recipientName, giftName, randomDelay), "TRACK")

	task.spawn(function()
		-- Wait full delay while animation is playing, then open Buy modal
		task.wait(randomDelay)

		objects[17].Image = itemIcon
		objects[17].ScaleType = Enum.ScaleType.Fit
		objects[17].ImageRectOffset = iconOffset
		objects[17].ImageRectSize = iconSize

		addLog(string.format("Opening modal for [%s] (Price: %s R$)", giftName, priceStr), "POPUP")
		openModal()
	end)
end

local function hookGiftingPopupButton(btn)
	if not btn:IsA("GuiButton") then return end
	if not isGiftingPopupButton(btn) then return end
	if btn:GetAttribute("CustomHooked") then return end
	btn:SetAttribute("CustomHooked", true)

	-- 1. Disable executor connections on the original Select/Gift button
	if type(getconnections) == "function" then
		for _, signal in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
			local s, conns = pcall(getconnections, signal)
			if s and type(conns) == "table" then
				for _, conn in ipairs(conns) do
					pcall(function() conn:Disable() end)
				end
			end
		end
	end

	-- 2. Create invisible Shield overlay to absorb click and trigger our custom modal
	local shield = btn:FindFirstChild("CustomSelectShield")
	if not shield then
		shield = Instance.new("TextButton")
		shield.Name = "CustomSelectShield"
		shield.Size = UDim2.new(1, 0, 1, 0)
		shield.Position = UDim2.new(0, 0, 0, 0)
		shield.BackgroundTransparency = 1
		shield.Text = ""
		shield.ZIndex = math.max(btn.ZIndex + 50, 100)
		shield.Active = true
		shield.Selectable = false
		shield.Parent = btn

		shield.Activated:Connect(function()
			onGiftSelectButtonClicked(btn)
		end)
		shield.MouseButton1Click:Connect(function()
			onGiftSelectButtonClicked(btn)
		end)
	end
end

local function scanAndHookButtons()
	-- 1. New RobuxShop detection
	local rShop = playerGui:FindFirstChild("RobuxShop") or playerGui:FindFirstChild("RobuxShop", true)
	if rShop then
		-- Shop ScrollingFrame items
		local shopFrame = rShop:FindFirstChild("Frame")
		local sf = (shopFrame and shopFrame:FindFirstChild("ScrollingFrame")) or rShop:FindFirstChildWhichIsA("ScrollingFrame", true)
		if sf then
			for _, desc in ipairs(sf:GetDescendants()) do
				if desc:IsA("GuiButton") then
					if isPurchaseButton(desc) then
						hookPurchaseButton(desc)
					elseif isGiftButton(desc) then
						hookGiftButton(desc)
					end
				end
			end
		end

		-- GiftingPopUp items
		local giftingPopup = rShop:FindFirstChild("GiftingPopUp") or rShop:FindFirstChild("GiftingPopUp", true)
		if giftingPopup then
			for _, desc in ipairs(giftingPopup:GetDescendants()) do
				if desc:IsA("GuiButton") and isGiftingPopupButton(desc) then
					hookGiftingPopupButton(desc)
				end
			end
		end
	end

	-- 2. Legacy MainGUI.Frames.Shop fallback
	local success, oldShopScrolling = pcall(function()
		return playerGui:WaitForChild("MainGUI", 1)
			:WaitForChild("Frames", 1)
			:WaitForChild("Shop", 1)
			:WaitForChild("ScrollingFrame", 1)
	end)

	if success and oldShopScrolling then
		for _, desc in ipairs(oldShopScrolling:GetDescendants()) do
			if desc:IsA("GuiButton") then
				if isPurchaseButton(desc) then
					hookPurchaseButton(desc)
				elseif isGiftButton(desc) then
					hookGiftButton(desc)
				end
			end
		end
	end

	-- 3. Legacy GiftPlayer fallback
	local success2, oldGiftPlayer = pcall(function()
		return playerGui:WaitForChild("MainGUI", 1)
			:WaitForChild("Frames", 1)
			:WaitForChild("GiftPlayer", 1)
	end)

	if success2 and oldGiftPlayer then
		for _, desc in ipairs(oldGiftPlayer:GetDescendants()) do
			if desc:IsA("GuiButton") and isGiftingPopupButton(desc) then
				hookGiftingPopupButton(desc)
			end
		end
	end
end

task.spawn(scanAndHookButtons)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("GuiButton") then
		if isPurchaseButton(descendant) then
			task.defer(function() hookPurchaseButton(descendant) end)
		elseif isGiftButton(descendant) then
			task.defer(function() hookGiftButton(descendant) end)
		elseif isGiftingPopupButton(descendant) then
			task.defer(function() hookGiftingPopupButton(descendant) end)
		end
	elseif descendant.Name == "RobuxShop" or descendant.Name == "GiftingPopUp" or descendant.Name == "PlayerTemplate" or descendant.Name == "ScrollingFrame" or descendant.Name == "Btns" or descendant.Name == "ButtonList" then
		task.defer(scanAndHookButtons)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local mousePos = input.Position
		local objectsAtPos = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)

		for _, obj in ipairs(objectsAtPos) do
			if not obj:IsDescendantOf(objects[1]) and not (playerGui:FindFirstChild("PendingPurchaseGui") and obj:IsDescendantOf(playerGui.PendingPurchaseGui)) then
				local targetBtn = nil
				if obj:IsA("GuiButton") then
					targetBtn = obj
				else
					targetBtn = obj:FindFirstAncestorWhichIsA("GuiButton")
				end

				if targetBtn and targetBtn.Name == "CustomPurchaseShield" and targetBtn.Parent and targetBtn.Parent:IsA("GuiButton") then
					targetBtn = targetBtn.Parent
				elseif targetBtn and targetBtn.Name == "CustomSelectShield" and targetBtn.Parent and targetBtn.Parent:IsA("GuiButton") then
					targetBtn = targetBtn.Parent
				end

				if targetBtn then
					if isPurchaseButton(targetBtn) then
						onPurchaseButtonClicked(targetBtn)
						break
					elseif isGiftButton(targetBtn) then
						onGiftButtonClicked(targetBtn)
						break
					elseif isGiftingPopupButton(targetBtn) then
						onGiftSelectButtonClicked(targetBtn)
						break
					end
				end
			end
		end
	end
end)

-- ============================================================================
-- Exposed External API & Bindables for Future Connections
-- ============================================================================

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
	addLog("External connection set amount to: " .. str, "CONNECT")
end)
bindSetAmount.Parent = apiFolder

local bindToggle = Instance.new("BindableEvent")
bindToggle.Name = "ToggleMenu"
bindToggle.Event:Connect(function()
	toggleMenu()
end)
bindToggle.Parent = apiFolder

local bindClickShop = Instance.new("BindableEvent")
bindClickShop.Name = "ClickShop"
bindClickShop.Event:Connect(function()
	switchGiftingToShopFrame()
end)
bindClickShop.Parent = apiFolder

objects[1]:SetAttribute("TotalAmount", currentTotalAmount)
objects[1]:SetAttribute("AutoHideOnRun", autoHideOnRun)
objects[1]:SetAttribute("ToggleKey", currentKeybind.Name)
objects[1]:SetAttribute("MinDelay", minPopupDelay)
objects[1]:SetAttribute("MaxDelay", maxPopupDelay)
objects[1]:SetAttribute("IsMenuOpen", isMenuOpen)

-- Initial Startup sequence
addLog("Settings system initialized.", "SYSTEM")
addLog("Tracking active for RobuxShop (all sections) & GiftingPopUp.", "CONNECT")
addLog(string.format("Popup Delay set to [%.1fs - %.1fs].", minPopupDelay, maxPopupDelay), "CONFIG")
addLog("Loaded config (Amount: " .. currentTotalAmount .. ", AutoHide: " .. (autoHideOnRun and "ON" or "OFF") .. ", Key: [" .. currentKeybind.Name .. "]).", "CONFIG")
addLog("Ready for external connections.", "CONNECT")

if not autoHideOnRun then
	setMenuVisible(true, false)
else
	setMenuVisible(false, true)
end

return objects[1]