-- ====================================================
-- CraftBank OS - Multi-Ecrans & Multi-Comptes
-- ====================================================

-- ====================================================
-- 1. BASE DE DONNEES
-- ====================================================
local dataFile = "bank_data.txt"
local bankData = {
    accounts = {
        ["1001"] = { name = "Twilight", pin = "1234", balance = 1500 },
        ["2002"] = { name = "Joueur2", pin = "0000", balance = 500 }
    },
    globalHistory = {}
}

local function saveData()
    local f = fs.open(dataFile, "w")
    if f then
        f.write(textutils.serialize(bankData))
        f.close()
    end
    -- Notifier tous les ecrans qu'une mise a jour a eu lieu
    os.queueEvent("bank_update")
end

local function loadData()
    if fs.exists(dataFile) then
        local f = fs.open(dataFile, "r")
        if f then
            local parsed = textutils.unserialize(f.readAll())
            f.close()
            if parsed and parsed.accounts then bankData = parsed end
        end
    else
        saveData()
    end
end

local function logTransaction(accountName, actionText)
    local entry = string.format("[%s] %s: %s", textutils.formatTime(os.time(), true), accountName, actionText)
    table.insert(bankData.globalHistory, entry)
    if #bankData.globalHistory > 50 then table.remove(bankData.globalHistory, 1) end
    saveData()
end

-- ====================================================
-- 2. MOTEUR D'INTERFACE ISOLE (POUR MULTI-ECRANS)
-- ====================================================
-- Permet à chaque écran de fonctionner indépendamment
local function createContext(target_term, target_name)
    local ctx = {
        t = target_term,
        name = target_name,
        buttons = {},
        isColor = target_term.isColor()
    }
    ctx.w, ctx.h = ctx.t.getSize()
    return ctx
end

local function clearButtons(ctx) ctx.buttons = {} end

local function addButton(ctx, id, label, x, y, bw, bh, bg, fg, callback)
    table.insert(ctx.buttons, {
        id = id, label = label,
        x = x, y = y, w = bw, h = bh,
        bg = bg, fg = fg, cb = callback
    })
end

local function drawButtons(ctx)
    for _, b in ipairs(ctx.buttons) do
        for row = 0, b.h - 1 do
            ctx.t.setCursorPos(b.x, b.y + row)
            ctx.t.setBackgroundColor(b.bg)
            ctx.t.setTextColor(b.fg)
            if row == math.floor(b.h / 2) then
                local lbl = string.sub(b.label, 1, b.w)
                local padL = math.floor((b.w - #lbl) / 2)
                local padR = b.w - #lbl - padL
                ctx.t.write(string.rep(" ", padL) .. lbl .. string.rep(" ", padR))
            else
                ctx.t.write(string.rep(" ", b.w))
            end
        end
    end
end

local function handleTouch(ctx, mx, my)
    for _, b in ipairs(ctx.buttons) do
        if mx >= b.x and mx <= b.x + b.w - 1 and my >= b.y and my <= b.y + b.h - 1 then
            return b.cb
        end
    end
    return nil
end

-- Filtre d'events pour eviter qu'un ecran controle l'autre
local function pullCtxEvent(ctx)
    while true do
        local ev = {os.pullEvent()}
        local type = ev[1]
        
        if type == "mouse_click" and ctx.name == "computer" then
            return "touch", ev[3], ev[4]
        elseif type == "monitor_touch" and ctx.name == ev[2] then
            return "touch", ev[3], ev[4]
        elseif (type == "key" or type == "char") and ctx.name == "computer" then
            return table.unpack(ev)
        end
    end
end

local function drawHeader(ctx, title)
    ctx.t.setCursorPos(1, 1)
    ctx.t.setBackgroundColor(ctx.isColor and colors.blue or colors.gray)
    ctx.t.setTextColor(colors.white)
    ctx.t.clearLine()
    local clock = textutils.formatTime(os.time(), true)
    local maxT = ctx.w - #clock - 2
    if maxT > 0 then ctx.t.write(" " .. string.sub(title, 1, maxT)) end
    ctx.t.setCursorPos(ctx.w - #clock + 1, 1)
    ctx.t.write(clock)
end

local function drawFooter(ctx, info)
    ctx.t.setCursorPos(1, ctx.h)
    ctx.t.setBackgroundColor(ctx.isColor and colors.blue or colors.gray)
    ctx.t.setTextColor(colors.white)
    ctx.t.clearLine()
    ctx.t.write(string.sub(" " .. (info or ""), 1, ctx.w))
end

local function clr(ctx)
    ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black)
    ctx.t.setTextColor(colors.white)
    ctx.t.clear()
end

-- ====================================================
-- 3. NUMPAD TACTILE
-- ====================================================
local function getNumpadInput(ctx, title, isMasked, allowCancel)
    local value = ""
    local errorMsg = ""
    local maxLen = 8

    while true do
        clr(ctx)
        clearButtons(ctx)
        drawHeader(ctx, title)
        drawFooter(ctx, "DEL: Effacer | OK: Valider")

        ctx.t.setCursorPos(2, 3)
        ctx.t.setBackgroundColor(colors.black)
        ctx.t.setTextColor(colors.yellow)
        local dVal = isMasked and string.rep("*", #value) or value
        local inputStr = " " .. dVal
        local padded = inputStr .. string.rep(" ", math.max(0, ctx.w - 2 - #inputStr))
        ctx.t.write(string.sub(padded, 1, ctx.w - 2))

        if errorMsg ~= "" then
            ctx.t.setCursorPos(2, 4)
            ctx.t.setTextColor(ctx.isColor and colors.red or colors.white)
            ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black)
            ctx.t.write(string.sub(errorMsg, 1, ctx.w - 2))
        end

        local btnW = math.floor((ctx.w - 4) / 3)
        local bH = (ctx.h < 18) and 1 or 2
        local gapY = (ctx.h < 18) and 0 or 1
        local startY = 5
        local padKeys = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"DEL","0","OK"}}

        for r, row in ipairs(padKeys) do
            for c, keyText in ipairs(row) do
                local x = 2 + (c - 1) * (btnW + 1)
                local y = startY + (r - 1) * (bH + gapY)
                local bg = (ctx.isColor and colors.cyan or colors.white)
                if keyText == "DEL" then bg = (ctx.isColor and colors.orange or colors.white)
                elseif keyText == "OK" then bg = (ctx.isColor and colors.green or colors.white) end

                addButton(ctx, "k"..keyText, keyText, x, y, btnW, bH, bg, colors.black, function() return keyText end)
            end
        end

        if allowCancel then
            local cancelY = startY + 4 * (bH + gapY)
            if cancelY < ctx.h then
                addButton(ctx, "cancel", "Annuler", 2, cancelY, ctx.w - 3, 1, (ctx.isColor and colors.red or colors.white), colors.white, function() return "CANCEL" end)
            end
        end

        drawButtons(ctx)

        local evType, p1, p2 = pullCtxEvent(ctx)
        local pressedKey = nil

        if evType == "touch" then
            local cb = handleTouch(ctx, p1, p2)
            if cb then pressedKey = cb() end
        elseif evType == "char" and string.match(p1, "[0-9]") then
            pressedKey = p1
        elseif evType == "key" then
            if p1 == keys.backspace then pressedKey = "DEL"
            elseif p1 == keys.enter or p1 == keys.numPadEnter then pressedKey = "OK" end
        end

        if pressedKey then
            if pressedKey == "DEL" then value = string.sub(value, 1, math.max(0, #value - 1)); errorMsg = ""
            elseif pressedKey == "OK" then
                if #value > 0 then return value else errorMsg = "Saisissez un chiffre!" end
            elseif pressedKey == "CANCEL" then return nil
            elseif #value < maxLen then value = value .. pressedKey; errorMsg = "" end
        end
    end
end

-- ====================================================
-- 4. LOGIQUE DE TERMINAL (BOUCLE PAR ECRAN)
-- ====================================================
local function runAtmTerminal(target_term, target_name)
    local ctx = createContext(target_term, target_name)

    while true do
        local currentAccountId = nil
        
        -- ECRAN DE CONNEXION
        while not currentAccountId do
            local idInput = getNumpadInput(ctx, "ID Compte", false, false)
            if bankData.accounts[idInput] then
                local pinInput = getNumpadInput(ctx, "Code PIN", true, true)
                if pinInput == bankData.accounts[idInput].pin then
                    currentAccountId = idInput
                else
                    clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Code PIN Incorrect")
                    sleep(1.5)
                end
            else
                clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Compte Inconnu")
                sleep(1.5)
            end
        end

        -- DASHBOARD PRINCIPAL
        local running = true
        while running do
            local acc = bankData.accounts[currentAccountId]
            clr(ctx); clearButtons(ctx)
            drawHeader(ctx, acc.name)
            drawFooter(ctx, "Que voulez-vous faire ?")

            ctx.t.setBackgroundColor(colors.black)
            for y = 3, 4 do ctx.t.setCursorPos(2, y); ctx.t.write(string.rep(" ", ctx.w - 2)) end
            ctx.t.setCursorPos(3, 3); ctx.t.setTextColor(colors.lightGray); ctx.t.write("Solde :")
            ctx.t.setCursorPos(3, 4); ctx.t.setTextColor(colors.green); ctx.t.write("$" .. string.format("%.2f", acc.balance))

            local btnW = ctx.w - 3
            addButton(ctx, "dep", "+ Depot", 2, 6, btnW, 2, (ctx.isColor and colors.green or colors.white), colors.black, function()
                local val = getNumpadInput(ctx, "Montant Depot", false, true)
                local amt = tonumber(val)
                if amt and amt > 0 then
                    bankData.accounts[currentAccountId].balance = acc.balance + amt
                    logTransaction(acc.name, "+$"..amt.." (Depot)")
                end
            end)

            addButton(ctx, "ret", "- Retrait", 2, 9, btnW, 2, (ctx.isColor and colors.orange or colors.white), colors.black, function()
                local val = getNumpadInput(ctx, "Montant Retrait", false, true)
                local amt = tonumber(val)
                if amt and amt > 0 then
                    if acc.balance >= amt then
                        bankData.accounts[currentAccountId].balance = acc.balance - amt
                        logTransaction(acc.name, "-$"..amt.." (Retrait)")
                    else
                        clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Fonds insuffisants"); sleep(1.5)
                    end
                end
            end)

            addButton(ctx, "quit", "Deconnexion", 2, 13, btnW, 1, (ctx.isColor and colors.red or colors.white), colors.white, function()
                return "logout"
            end)

            drawButtons(ctx)

            local evType, p1, p2 = pullCtxEvent(ctx)
            if evType == "touch" then
                local cb = handleTouch(ctx, p1, p2)
                if cb and cb() == "logout" then running = false end
            end
        end
    end
end

-- ====================================================
-- 5. ECRAN DE LOG SERVEUR (ORDINATEUR CENTRAL)
-- ====================================================
local function runServerLog()
    local oldTerm = term.redirect(term.native())
    local w, h = term.getSize()
    
    local function drawLogs()
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.clearLine()
        term.write(" LOGS SERVEUR BANCAIRE - EN DIRECT")
        
        term.setBackgroundColor(colors.black)
        local startY = 3
        for i = #bankData.globalHistory, math.max(1, #bankData.globalHistory - (h - 4)), -1 do
            term.setCursorPos(2, startY)
            local log = bankData.globalHistory[i]
            if string.find(log, "%+") then term.setTextColor(colors.lime)
            elseif string.find(log, "%-") then term.setTextColor(colors.red)
            else term.setTextColor(colors.lightGray) end
            term.write(log)
            startY = startY + 1
        end
    end

    drawLogs()
    while true do
        local ev = os.pullEvent()
        if ev == "bank_update" then drawLogs() end
    end
end

-- ====================================================
-- LANCEMENT DU SYSTEME PARALLELE
-- ====================================================
loadData()

local monitors = {peripheral.find("monitor")}
local tasks = {}

if #monitors == 0 then
    -- Si 0 ecran externe : L'ordinateur principal devient le distributeur
    table.insert(tasks, function() runAtmTerminal(term.native(), "computer") end)
else
    -- Si 1 ou plusieurs ecrans : Ordi = Logs, Ecrans = Distributeurs
    table.insert(tasks, runServerLog)
    
    local names = peripheral.getNames()
    for _, name in ipairs(names) do
        if peripheral.getType(name) == "monitor" then
            local m = peripheral.wrap(name)
            m.setTextScale(0.5)
            table.insert(tasks, function() runAtmTerminal(m, name) end)
        end
    end
end

-- Lancement de tous les ecrans en meme temps (Multitâche)
parallel.waitForAll(table.unpack(tasks))
