local RENDER_BACKEND_URL = "https://dexcode-yjb2.onrender.com"
local SECRET_KEY = "NMC_PATHAN_SECURE_VAULT_KEY_2026_99X!"

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui", 5)

pcall(function()
    if type(setclipboard) == "function" then
        setclipboard("")
    elseif type(toclipboard) == "function" then
        toclipboard("")
    end
end)

local suspiciousGlobals = {
    "HttpSpy", "SimpleSpy", "Spy", "Hydroxide", "TurtleSpy",
    "HttpSpyLoaded", "SimpleSpyLoaded", "HttpLogger"
}
local globalEnv = (type(getgenv) == "function" and getgenv()) or _G or {}
for _, spyName in ipairs(suspiciousGlobals) do
    if rawget(globalEnv, spyName) ~= nil then
        rawset(globalEnv, spyName, nil)
    end
end

local loadstringRef = loadstring
if type(loadstringRef) ~= "function" then
    error("[NMC Security] Execution environment lacks dynamic loadstring support.")
end

local function getExecutorRequestFunction()
    if type(syn) == "table" and type(syn.request) == "function" then
        return syn.request
    elseif type(http) == "table" and type(http.request) == "function" then
        return http.request
    elseif type(http_request) == "function" then
        return http_request
    elseif type(request) == "function" then
        return request
    elseif type(fluxus) == "table" and type(fluxus.request) == "function" then
        return fluxus.request
    end
    return nil
end

local executeHttpRequest = getExecutorRequestFunction()
if not executeHttpRequest then
    error("[NMC Security] Critical: Executor does not support standard HTTP request libraries.")
end

local function getSafeGuiParent()
    if gethui then
        local s, h = pcall(gethui)
        if s and h then return h end
    end
    if type(syn) == "table" and syn.protect_gui then
        return CoreGui
    end
    local s, _ = pcall(function() return CoreGui.Name end)
    if s then return CoreGui end
    return playerGui or CoreGui
end

local safeParent = getSafeGuiParent()
local existing = safeParent:FindFirstChild("NMC_PATHAN_Loader")
if existing then
    existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NMC_PATHAN_Loader"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
end)
screenGui.Parent = safeParent

local overlay = Instance.new("Frame")
overlay.Name = "DimOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(4, 6, 12)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local mainCard = Instance.new("Frame")
mainCard.Name = "MainCard"
mainCard.AnchorPoint = Vector2.new(0.5, 0.5)
mainCard.Position = UDim2.new(0.5, 0, 0.52, 0)
mainCard.Size = UDim2.new(0, 430, 0, 215)
mainCard.BackgroundColor3 = Color3.fromRGB(11, 14, 23)
mainCard.BackgroundTransparency = 1
mainCard.BorderSizePixel = 0
mainCard.ClipsDescendants = true
mainCard.Parent = screenGui

local cardScale = Instance.new("UIScale")
cardScale.Scale = 0.88
cardScale.Parent = mainCard

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = mainCard

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(56, 189, 248)
cardStroke.Thickness = 1.6
cardStroke.Transparency = 1
cardStroke.Parent = mainCard

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 189, 248)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(168, 85, 247)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 189, 248))
})
strokeGradient.Parent = cardStroke

local headerIconBox = Instance.new("Frame")
headerIconBox.Name = "HeaderIconBox"
headerIconBox.Size = UDim2.new(0, 42, 0, 42)
headerIconBox.Position = UDim2.new(0, 24, 0, 20)
headerIconBox.BackgroundColor3 = Color3.fromRGB(19, 25, 41)
headerIconBox.BorderSizePixel = 0
headerIconBox.Parent = mainCard

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 10)
iconCorner.Parent = headerIconBox

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(56, 189, 248)
iconStroke.Thickness = 1.2
iconStroke.Transparency = 0.4
iconStroke.Parent = headerIconBox

local iconGlyph = Instance.new("TextLabel")
iconGlyph.Size = UDim2.new(1, 0, 1, 0)
iconGlyph.BackgroundTransparency = 1
iconGlyph.Text = "⚡"
iconGlyph.TextColor3 = Color3.fromRGB(56, 189, 248)
iconGlyph.Font = Enum.Font.GothamBold
iconGlyph.TextSize = 20
iconGlyph.Parent = headerIconBox

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0, 220, 0, 24)
titleLabel.Position = UDim2.new(0, 78, 0, 20)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "NMC_PATHAN"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 21
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainCard

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(186, 230, 253))
})
titleGradient.Parent = titleLabel

local subLabel = Instance.new("TextLabel")
subLabel.Name = "SubLabel"
subLabel.Size = UDim2.new(0, 250, 0, 16)
subLabel.Position = UDim2.new(0, 78, 0, 44)
subLabel.BackgroundTransparency = 1
subLabel.Text = "PREMIUM SCRIPT HUB • SECURE GATEWAY"
subLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
subLabel.Font = Enum.Font.GothamMedium
subLabel.TextSize = 9.5
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Parent = mainCard

local tagBadge = Instance.new("Frame")
tagBadge.Name = "TagBadge"
tagBadge.Size = UDim2.new(0, 88, 0, 24)
tagBadge.Position = UDim2.new(1, -112, 0, 20)
tagBadge.BackgroundColor3 = Color3.fromRGB(17, 24, 39)
tagBadge.BorderSizePixel = 0
tagBadge.Parent = mainCard

local tagCorner = Instance.new("UICorner")
tagCorner.CornerRadius = UDim.new(1, 0)
tagCorner.Parent = tagBadge

local tagStroke = Instance.new("UIStroke")
tagStroke.Color = Color3.fromRGB(52, 211, 153)
tagStroke.Thickness = 1
tagStroke.Transparency = 0.5
tagStroke.Parent = tagBadge

local tagDot = Instance.new("Frame")
tagDot.Size = UDim2.new(0, 6, 0, 6)
tagDot.Position = UDim2.new(0, 8, 0.5, -3)
tagDot.BackgroundColor3 = Color3.fromRGB(52, 211, 153)
tagDot.BorderSizePixel = 0
tagDot.Parent = tagBadge

local tagDotCorner = Instance.new("UICorner")
tagDotCorner.CornerRadius = UDim.new(1, 0)
tagDotCorner.Parent = tagDot

local tagText = Instance.new("TextLabel")
tagText.Size = UDim2.new(1, -20, 1, 0)
tagText.Position = UDim2.new(0, 18, 0, 0)
tagText.BackgroundTransparency = 1
tagText.Text = "v2.4 LIVE"
tagText.TextColor3 = Color3.fromRGB(52, 211, 153)
tagText.Font = Enum.Font.GothamBold
tagText.TextSize = 9.5
tagText.TextXAlignment = Enum.TextXAlignment.Left
tagText.Parent = tagBadge

local spinnerContainer = Instance.new("Frame")
spinnerContainer.Name = "SpinnerContainer"
spinnerContainer.Size = UDim2.new(0, 36, 0, 36)
spinnerContainer.Position = UDim2.new(0, 26, 0, 86)
spinnerContainer.BackgroundTransparency = 1
spinnerContainer.Parent = mainCard

local spinnerOuter = Instance.new("Frame")
spinnerOuter.Name = "SpinnerOuter"
spinnerOuter.Size = UDim2.new(1, 0, 1, 0)
spinnerOuter.BackgroundTransparency = 1
spinnerOuter.Parent = spinnerContainer

local spinnerCorner = Instance.new("UICorner")
spinnerCorner.CornerRadius = UDim.new(1, 0)
spinnerCorner.Parent = spinnerOuter

local spinnerStroke = Instance.new("UIStroke")
spinnerStroke.Color = Color3.fromRGB(56, 189, 248)
spinnerStroke.Thickness = 2.5
spinnerStroke.Parent = spinnerOuter

local spinnerGradient = Instance.new("UIGradient")
spinnerGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.65, 0.2),
    NumberSequenceKeypoint.new(1, 1)
})
spinnerGradient.Parent = spinnerStroke

local spinnerCoreDot = Instance.new("Frame")
spinnerCoreDot.AnchorPoint = Vector2.new(0.5, 0.5)
spinnerCoreDot.Size = UDim2.new(0, 8, 0, 8)
spinnerCoreDot.Position = UDim2.new(0.5, 0, 0.5, 0)
spinnerCoreDot.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
spinnerCoreDot.BorderSizePixel = 0
spinnerCoreDot.Parent = spinnerContainer

local coreCorner = Instance.new("UICorner")
coreCorner.CornerRadius = UDim.new(1, 0)
coreCorner.Parent = spinnerCoreDot

local spinTween = TweenService:Create(
    spinnerOuter,
    TweenInfo.new(1.0, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
    {Rotation = 360}
)
spinTween:Play()

local pulseCoreTween = TweenService:Create(
    spinnerCoreDot,
    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Color3.fromRGB(56, 189, 248)}
)
pulseCoreTween:Play()

local infoBox = Instance.new("Frame")
infoBox.Name = "InfoBox"
infoBox.Size = UDim2.new(1, -95, 0, 36)
infoBox.Position = UDim2.new(0, 75, 0, 86)
infoBox.BackgroundTransparency = 1
infoBox.Parent = mainCard

local protoLabel = Instance.new("TextLabel")
protoLabel.Size = UDim2.new(1, 0, 0, 13)
protoLabel.BackgroundTransparency = 1
protoLabel.Text = "SECURITY PROTOCOL VERIFICATION"
protoLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
protoLabel.Font = Enum.Font.GothamBold
protoLabel.TextSize = 8.5
protoLabel.TextXAlignment = Enum.TextXAlignment.Left
protoLabel.Parent = infoBox

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 19)
statusLabel.Position = UDim2.new(0, 0, 0, 15)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Initiating Runtime Handshake..."
statusLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12.5
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = infoBox

local progressTrack = Instance.new("Frame")
progressTrack.Name = "ProgressTrack"
progressTrack.Size = UDim2.new(1, -48, 0, 6)
progressTrack.Position = UDim2.new(0, 24, 0, 148)
progressTrack.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
progressTrack.BorderSizePixel = 0
progressTrack.Parent = mainCard

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = progressTrack

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0.12, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressTrack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = progressFill

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 189, 248)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247))
})
fillGradient.Parent = progressFill

local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "PercentLabel"
percentLabel.Size = UDim2.new(0, 60, 0, 16)
percentLabel.Position = UDim2.new(1, -84, 0, 160)
percentLabel.BackgroundTransparency = 1
percentLabel.Text = "12%"
percentLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 11.5
percentLabel.TextXAlignment = Enum.TextXAlignment.Right
percentLabel.Parent = mainCard

local footerMeta = Instance.new("TextLabel")
footerMeta.Size = UDim2.new(1, -120, 0, 16)
footerMeta.Position = UDim2.new(0, 24, 0, 160)
footerMeta.BackgroundTransparency = 1
footerMeta.Text = "Zero-Artifact Ephemeral Decryption Engine"
footerMeta.TextColor3 = Color3.fromRGB(71, 85, 105)
footerMeta.Font = Enum.Font.Gotham
footerMeta.TextSize = 9.5
footerMeta.TextXAlignment = Enum.TextXAlignment.Left
footerMeta.Parent = mainCard

TweenService:Create(overlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()
TweenService:Create(mainCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundTransparency = 0.05
}):Play()
TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
TweenService:Create(cardStroke, TweenInfo.new(0.35), {Transparency = 0.25}):Play()

local function setProgress(pct, statusText)
    pct = math.clamp(pct, 0, 1)
    statusLabel.Text = statusText or statusLabel.Text
    percentLabel.Text = string.format("%d%%", math.floor(pct * 100))
    TweenService:Create(
        progressFill,
        TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(pct, 0, 1, 0)}
    ):Play()
end

local function closeLoader()
    spinTween:Cancel()
    pulseCoreTween:Cancel()
    statusLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
    percentLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
    tagBadge.BackgroundColor3 = Color3.fromRGB(6, 78, 59)
    TweenService:Create(progressFill, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(52, 211, 153)}):Play()
    task.wait(0.28)
    TweenService:Create(overlay, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
    TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0.82}):Play()
    local exitTween = TweenService:Create(mainCard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.47, 0),
        BackgroundTransparency = 1
    })
    for _, obj in ipairs(mainCard:GetDescendants()) do
        if obj:IsA("TextLabel") then
            TweenService:Create(obj, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
        elseif obj:IsA("Frame") then
            TweenService:Create(obj, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
        elseif obj:IsA("UIStroke") then
            TweenService:Create(obj, TweenInfo.new(0.25), {Transparency = 1}):Play()
        end
    end
    exitTween:Play()
    exitTween.Completed:Connect(function()
        screenGui:Destroy()
    end)
end

local function CustomHash(str)
    local h0 = 0x6a09e667
    local h1 = 0xbb67ae85
    local h2 = 0x3c6ef372
    local h3 = 0xa54ff53a

    local strLen = #str
    for i = 1, strLen do
        local c = string.byte(str, i)
        local rotH1 = bit32.lrotate(h1, 7)
        h0 = bit32.bxor((h0 + c) % 4294967296, rotH1)

        local rotH2 = bit32.lrotate(h2, 13)
        local idxByte = bit32.band(i - 1, 0xFF)
        h1 = bit32.bxor((h1 + bit32.bxor(c, idxByte)) % 4294967296, rotH2)

        local rotH3 = bit32.lrotate(h3, 17)
        h2 = bit32.bxor((h2 + bit32.rshift(h0, 3)) % 4294967296, rotH3)

        local rotH0 = bit32.lrotate(h0, 11)
        h3 = bit32.bxor((h3 + bit32.rshift(h1, 5)) % 4294967296, rotH0)

        h0 = (h0 + h1) % 4294967296
        h2 = (h2 + h3) % 4294967296
        h1 = bit32.bxor(h1, h2)
        h3 = bit32.bxor(h3, h0)
    end

    return string.format("%08x%08x%08x%08x", h0, h1, h2, h3)
end

local nibble = {}
for c = 48, 57 do nibble[c] = c - 48 end
for c = 65, 70 do nibble[c] = c - 55 end
for c = 97, 102 do nibble[c] = c - 87 end

local function DecryptHexStream(hexPayload, keyStr)
    local keyLen = #keyStr
    local hexLen = #hexPayload
    local chunks = {}
    local buffer = {}
    local bufLen = 0
    local stepCounter = 0

    for i = 1, hexLen, 2 do
        local b1 = string.byte(hexPayload, i)
        local b2 = string.byte(hexPayload, i + 1)
        local n1 = nibble[b1] or 0
        local n2 = nibble[b2] or 0
        local cipherByte = bit32.bor(bit32.lshift(n1, 4), n2)

        local charIdx = (i + 1) / 2
        local keyByte = string.byte(keyStr, ((charIdx - 1) % keyLen) + 1)
        local plainByte = bit32.bxor(cipherByte, keyByte)

        bufLen = bufLen + 1
        buffer[bufLen] = string.char(plainByte)

        if bufLen >= 4096 then
            table.insert(chunks, table.concat(buffer))
            buffer = {}
            bufLen = 0
        end

        stepCounter = stepCounter + 1
        if stepCounter % 16000 == 0 then
            local decProgress = 0.68 + ((charIdx / (hexLen / 2)) * 0.24)
            setProgress(decProgress, "Decrypting Protected Core Stream...")
            task.wait()
        end
    end

    if bufLen > 0 then
        table.insert(chunks, table.concat(buffer))
    end

    return table.concat(chunks)
end

local function executeStageHandshake()
    setProgress(0.20, "Connecting to Render Vault...")
    task.wait(0.12)

    local placeId = tostring(game.PlaceId or 0)
    local backendBase = string.gsub(RENDER_BACKEND_URL, "/+$", "")

    local challengeHeaders = {
        ["Content-Type"] = "application/json",
        ["X-NMC-Client"] = "Roblox-Executor",
        ["X-Place-Id"] = placeId
    }

    local challengeResponse = executeHttpRequest({
        Url = backendBase .. "/api/challenge",
        Method = "POST",
        Headers = challengeHeaders,
        Body = "{}"
    })

    if not challengeResponse or not challengeResponse.Body then
        statusLabel.Text = "Connection to Vault Failed!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Failed to establish connection with Render Vault.")
    end

    local challengeData = nil
    local jsonOk = pcall(function()
        challengeData = HttpService:JSONDecode(challengeResponse.Body)
    end)

    if not jsonOk or type(challengeData) ~= "table" or not challengeData.authorized or not challengeData.nonce then
        statusLabel.Text = "Handshake Step 1 Rejected!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Handshake Step 1 Rejected: " .. tostring(challengeResponse.Body))
    end

    setProgress(0.45, "Authenticating Cryptographic Nonce...")
    task.wait(0.1)

    local serverNonce = challengeData.nonce
    local signaturePayload = serverNonce .. ":" .. placeId .. ":" .. SECRET_KEY
    local computedSignature = CustomHash(signaturePayload)

    setProgress(0.60, "Requesting Encrypted Payload...")
    task.wait(0.08)

    local executeBody = HttpService:JSONEncode({
        nonce = serverNonce,
        signature = computedSignature
    })

    local executeResponse = executeHttpRequest({
        Url = backendBase .. "/api/execute",
        Method = "POST",
        Headers = challengeHeaders,
        Body = executeBody
    })

    if not executeResponse or not executeResponse.Body then
        statusLabel.Text = "Handshake Step 2 Failed!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Execution handshake failed: empty response from backend.")
    end

    local executeData = nil
    pcall(function()
        executeData = HttpService:JSONDecode(executeResponse.Body)
    end)

    if not executeData or not executeData.authorized or not executeData.payload then
        statusLabel.Text = "Payload Authorization Failed!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Handshake Step 2 Rejected: " .. tostring(executeResponse.Body))
    end

    setProgress(0.68, "Decrypting Protected Core Stream...")
    task.wait(0.05)

    local streamKey = serverNonce .. SECRET_KEY
    local decryptedSource, decryptErr = DecryptHexStream(executeData.payload, streamKey)

    if not decryptedSource or #decryptedSource == 0 then
        statusLabel.Text = "Decryption Failed!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Decryption failed: " .. tostring(decryptErr))
    end

    setProgress(0.95, "Compiling Core Engine...")
    task.wait(0.06)

    local compiledFunction, compileErr = loadstring(decryptedSource, "NMC_Pathan_Core")
    if not compiledFunction then
        statusLabel.Text = "Core Compilation Error!"
        task.wait(1.5)
        closeLoader()
        error("[NMC Gatekeeper] Script compilation error: " .. tostring(compileErr))
    end

    setProgress(1.0, "Verified. Launching NMC Hub...")
    task.wait(0.35)

    task.spawn(compiledFunction)

    closeLoader()

    serverNonce = nil
    computedSignature = nil
    executeData = nil
    decryptedSource = nil
    compiledFunction = nil
    collectgarbage("collect")
end

task.spawn(function()
    local success, err = pcall(executeStageHandshake)
    if not success then
        warn("[NMC Pathan Hub] Injection Error: " .. tostring(err))
    end
end)
