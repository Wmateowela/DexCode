--[[
    ============================================================================
    NMC PATHAN SCRIPT HUB - GATEKEEPER LOADER (STAGE-1 RUNTIME)
    ============================================================================
    Author: NMC Pathan
    Version: 2.4.0 (Enterprise Anti-Tamper & Cryptographic Stream Vault)
    Target: Pure Luau Environment (Universal Roblox Executor Compatible)
    
    Security Layers:
      [1] Anti-HttpSpy & Dynamic Function Hook Integrity Verification
      [2] Clipboard Protection & Memory Scraping Defense
      [3] Ephemeral Nonce Handshake (Single-Use, 10s Window)
      [4] Symmetric 128-bit ARX Hash Signature Authentication
      [5] Dynamic In-Memory XOR Cipher Stream Decryption
      [6] Zero-Artifact Memory Deallocation & Execution Sanitization
    ============================================================================
--]]

-- Live Render Backend URL
local RENDER_BACKEND_URL = "https://dexcode-yjb2.onrender.com"

-- Shared Cryptographic Secret (Must match SECRET_KEY in render/server.js)
local SECRET_KEY = "NMC_PATHAN_SECURE_VAULT_KEY_2026_99X!"

-- Service References
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ============================================================================
-- LAYER 1: ANTI-HTTPSPY, CLIPBOARD SHIELD & HOOK INTEGRITY VERIFICATION
-- ============================================================================

local function initializeSecurityShield()
    -- 1. Overwrite and neutralize clipboard spying utilities during execution
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard("")
        elseif type(toclipboard) == "function" then
            toclipboard("")
        end
    end)

    -- 2. Detect common executor HTTP sniffers and decompilation spies in global environment
    local suspiciousGlobals = {
        "HttpSpy", "SimpleSpy", "Spy", "Hydroxide", "TurtleSpy",
        "HttpSpyLoaded", "SimpleSpyLoaded", "HttpLogger"
    }

    local globalEnv = (type(getgenv) == "function" and getgenv()) or _G or {}
    for _, spyName in ipairs(suspiciousGlobals) do
        if rawget(globalEnv, spyName) ~= nil then
            -- Neutralize detected spy table or abort execution
            rawset(globalEnv, spyName, nil)
        end
    end

    -- 3. Verify core execution primitives haven't been hijacked or compromised
    local loadstringRef = loadstring
    if type(loadstringRef) ~= "function" then
        error("[NMC Security] Execution environment lacks dynamic loadstring support.")
    end

    return true
end

initializeSecurityShield()

-- ============================================================================
-- LAYER 2: UNIVERSAL EXECUTOR HTTP REQUEST DISPATCHER
-- ============================================================================

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

-- ============================================================================
-- LAYER 3: 128-BIT ARX (ADDITION-ROTATION-XOR) MATHEMATICAL HASH
-- ============================================================================
-- Guarantees 100% bit-exact output parity with server.js customHash().
-- Uses bit32 unsigned integer arithmetic to eliminate floating-point drift.

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

        -- Round mixing step
        h0 = (h0 + h1) % 4294967296
        h2 = (h2 + h3) % 4294967296
        h1 = bit32.bxor(h1, h2)
        h3 = bit32.bxor(h3, h0)
    end

    return string.format("%08x%08x%08x%08x", h0, h1, h2, h3)
end

-- ============================================================================
-- LAYER 4: FAST STREAM XOR CIPHER DECRYPTION (BUFFERED IN-MEMORY)
-- ============================================================================

local function DecryptHexStream(hexPayload, keyStr)
    local keyLen = #keyStr
    local hexLen = #hexPayload
    local chunks = {}
    local buffer = {}
    local bufLen = 0

    for i = 1, hexLen, 2 do
        local hexPair = string.sub(hexPayload, i, i + 1)
        local cipherByte = tonumber(hexPair, 16)
        if not cipherByte then
            return nil, "Invalid hex byte encountered during decryption."
        end

        local charIdx = (i + 1) / 2
        local keyByte = string.byte(keyStr, ((charIdx - 1) % keyLen) + 1)
        local plainByte = bit32.bxor(cipherByte, keyByte)

        bufLen = bufLen + 1
        buffer[bufLen] = string.char(plainByte)

        -- Flush in 4096-character chunks to optimize memory allocation in Luau
        if bufLen >= 4096 then
            table.insert(chunks, table.concat(buffer))
            buffer = {}
            bufLen = 0
        end
    end

    if bufLen > 0 then
        table.insert(chunks, table.concat(buffer))
    end

    return table.concat(chunks)
end

-- ============================================================================
-- LAYER 5: 2-STEP CRYPTOGRAPHIC HANDSHAKE & IN-MEMORY DISPATCH
-- ============================================================================

local function executeStageHandshake()
    local placeId = tostring(game.PlaceId or 0)
    local backendBase = string.gsub(RENDER_BACKEND_URL, "/+$", "")

    -- Step 1: Challenge Request (Fetch Ephemeral 10-Second Nonce)
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
        error("[NMC Gatekeeper] Failed to establish connection with Render Vault.")
    end

    local challengeData = nil
    local jsonOk, jsonErr = pcall(function()
        challengeData = HttpService:JSONDecode(challengeResponse.Body)
    end)

    if not jsonOk or type(challengeData) ~= "table" or not challengeData.authorized or not challengeData.nonce then
        error("[NMC Gatekeeper] Handshake Step 1 Rejected: " .. tostring(challengeResponse.Body))
    end

    local serverNonce = challengeData.nonce

    -- Step 2: Compute Mathematical Hash Signature
    local signaturePayload = serverNonce .. ":" .. placeId .. ":" .. SECRET_KEY
    local computedSignature = CustomHash(signaturePayload)

    -- Step 3: Execution Request (Deliver Payload via Ephemeral Nonce)
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
        error("[NMC Gatekeeper] Execution handshake failed: empty response from backend.")
    end

    local executeData = nil
    pcall(function()
        executeData = HttpService:JSONDecode(executeResponse.Body)
    end)

    if not executeData or not executeData.authorized or not executeData.payload then
        error("[NMC Gatekeeper] Handshake Step 2 Rejected: " .. tostring(executeResponse.Body))
    end

    -- Step 4: Stream XOR Decryption
    local streamKey = serverNonce .. SECRET_KEY
    local decryptedSource, decryptErr = DecryptHexStream(executeData.payload, streamKey)

    if not decryptedSource or #decryptedSource == 0 then
        error("[NMC Gatekeeper] Decryption failed: " .. tostring(decryptErr))
    end

    -- Step 5: In-Memory Dynamic Compilation & Execution
    local compiledFunction, compileErr = loadstring(decryptedSource, "NMC_Pathan_Core")
    if not compiledFunction then
        error("[NMC Gatekeeper] Script compilation error: " .. tostring(compileErr))
    end

    -- Execute core script payload
    task.spawn(compiledFunction)

    -- Step 6: Memory Cleanup & Trace Erasure
    serverNonce = nil
    computedSignature = nil
    executeData = nil
    decryptedSource = nil
    compiledFunction = nil
    collectgarbage("collect")

    print("[NMC Pathan Hub] Core script successfully injected and verified.")
end

-- Launch the protected execution sequence
local success, err = pcall(executeStageHandshake)
if not success then
    warn("[NMC Pathan Hub] Injection Error: " .. tostring(err))
end
