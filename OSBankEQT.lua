-- ====================================================
-- CraftBank OS - Multi-Ecrans & Inscription Intégrée
-- ====================================================

-- ====================================================
-- 1. BASE DE DONNEES (Par Nom de Compte)
-- ====================================================
local dataFile = "bank_data.txt"
local bankData = {
    accounts = {
        ["Twilight"] = { pin = "1234", balance = 1500 },
        ["Admin"] = { pin = "0000", balance = 9999 }
    },
    globalHistory = {}
}

local function saveData()
    local f = fs.open(dataFile, "w")
    if f then
        f.write(textutils.serialize(bankData))
        f.close()
    end
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

local function getAccountByName(name)
    for k, v in pairs(bankData.accounts) do
        if string.lower(k) == string.lower(name) then
            return k -- Retourne le vrai nom avec la bonne casse
        end
    end
    return nil
end

local function logTransaction(accountName, actionText)
    local entry = string.format("[%s] %s: %s", textutils.formatTime(os.time(), true), accountName, actionText)
    table.insert(bankData.globalHistory, entry)
    if #bankData.globalHistory > 50 then table.remove(bankData.globalHistory, 1) end
    saveData()
end

-- ====================================================
-- 2. MOTEUR D'INTERFACE ISOLE
-- ====================================================
local function createContext(target_term, target_name)
    local ctx = { t = target_term, name = target_name, buttons = {}, isColor = target_term.isColor() }
    ctx.w, ctx.h = ctx.t.getSize()
    return ctx
end

local function clearButtons(ctx) ctx.buttons = {} end

local function addButton(ctx, id, label, x, y, bw, bh, bg, fg, callback)
    table.insert(ctx.buttons, {
        id = id, label = label, x = x, y = y, w = bw, h = bh, bg = bg, fg = fg, cb = callback
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
                ctx.t.write(string.rep(" ", padL) .. lbl .. string.rep(" ", b.w - #lbl - padL))
            else
                ctx.t.write(string.rep(" ", b.w))
            end
        end
    end
end

local function handleTouch(ctx, mx, my)
    for _, b in ipairs(ctx.buttons) do
        if mx >= b.x and mx <= b.x + b.w - 1 and my >= b.y and my <= b.y + b.h - 1 then return b.cb end
    end
    return nil
end

local function pullCtxEvent(ctx)
    while true do
        local ev = {os.pullEvent()}
        local type = ev[1]
        
        if type == "bank_tick" then
            return "tick"
        elseif type == "mouse_click" and ctx.name == "computer" then
            return "touch", ev[3], ev[4]
        elseif type == "monitor_touch" and ctx.name == ev[2] then
            return "touch", ev[3], ev[4]
        elseif (type == "key" or type == "char") and ctx.name == "computer" then
            return table.unpack(ev)
        end
    end
end

local function clr(ctx)
    ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black)
    ctx.t.setTextColor(colors.white)
    ctx.t.clear()
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

-- ====================================================
-- 3. CLAVIER AZERTY (LETTRES POUR NOM)
-- ====================================================
local function getAzertyInput(ctx, title, allowCancel)
    local value, errorMsg = "", ""
    local kb = {
        {"A","Z","E","R","T","Y","U","I","O","P"},
        {"Q","S","D","F","G","H","J","K","L","M"},
        {"W","X","C","V","B","N","-","_"}
    }
    clr(ctx); clearButtons(ctx)

    local bH = 1
    local gapY = (ctx.h < 16) and 0 or 1
    local startY = 5

    for r, row in ipairs(kb) do
        local startX = math.max(1, math.floor((ctx.w - #row) / 2) + 1)
        for c, keyText in ipairs(row) do
            addButton(ctx, "k"..keyText, keyText, startX + c - 1, startY + (r-1)*(bH+gapY), 1, bH, (ctx.isColor and colors.cyan or colors.white), colors.black, function() return keyText end)
        end
    end

    local lastY = startY + 3 * (bH + gapY)
    addButton(ctx, "DEL", "DEL", 2, lastY, 4, bH, (ctx.isColor and colors.orange or colors.white), colors.black, function() return "DEL" end)
    addButton(ctx, "SPC", "ESP", 7, lastY, ctx.w - 12, bH, colors.gray, colors.white, function() return " " end)
    addButton(ctx, "OK", "OK", ctx.w - 4, lastY, 4, bH, (ctx.isColor and colors.green or colors.white), colors.black, function() return "OK" end)
    
    if allowCancel then
        addButton(ctx, "cancel", "Annuler", 2, lastY + bH + gapY, ctx.w - 3, 1, (ctx.isColor and colors.red or colors.white), colors.white, function() return "CANCEL" end)
    end

    drawButtons(ctx); drawFooter(ctx, "Saisir Identifiant")

    local function drawField()
        ctx.t.setCursorPos(2, 3)
        ctx.t.setBackgroundColor(colors.black); ctx.t.setTextColor(colors.yellow)
        ctx.t.write(string.sub(" " .. value .. string.rep(" ", math.max(0, ctx.w - 2 - #value - 1)), 1, ctx.w - 2))
        ctx.t.setCursorPos(2, 4)
        if errorMsg ~= "" then
            ctx.t.setTextColor(ctx.isColor and colors.red or colors.white); ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black)
            ctx.t.write(string.sub(errorMsg .. string.rep(" ", ctx.w), 1, ctx.w - 2))
        else
            ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black); ctx.t.write(string.rep(" ", ctx.w - 2))
        end
    end

    drawHeader(ctx, title); drawField()

    while true do
        local evType, p1, p2 = pullCtxEvent(ctx)
        local pressedKey = nil
        if evType == "tick" then drawHeader(ctx, title)
        elseif evType == "touch" then local cb = handleTouch(ctx, p1, p2); if cb then pressedKey = cb() end
        elseif evType == "char" and string.match(p1, "[a-zA-Z0-9%-_ ]") then pressedKey = string.upper(p1)
        elseif evType == "key" then
            if p1 == keys.backspace then pressedKey = "DEL" elseif p1 == keys.enter then pressedKey = "OK" end
        end

        if pressedKey then
            if pressedKey == "DEL" then value = string.sub(value, 1, math.max(0, #value - 1)); errorMsg = ""; drawField()
            elseif pressedKey == "OK" then if #value > 0 then return value else errorMsg = "Entrez un nom!"; drawField() end
            elseif pressedKey == "CANCEL" then return nil
            elseif #value < 12 then value = value .. pressedKey; errorMsg = ""; drawField() end
        end
    end
end

-- ====================================================
-- 4. PAVE NUMERIQUE (PIN ET MONTANTS)
-- ====================================================
local function getNumpadInput(ctx, title, isMasked, allowCancel)
    local value, errorMsg = "", ""
    clr(ctx); clearButtons(ctx)

    local btnW = math.floor((ctx.w - 4) / 3)
    local bH, gapY, startY = (ctx.h < 18) and 1 or 2, (ctx.h < 18) and 0 or 1, 5
    local padKeys = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"DEL","0","OK"}}

    for r, row in ipairs(padKeys) do
        for c, keyText in ipairs(row) do
            local bg = (ctx.isColor and colors.cyan or colors.white)
            if keyText == "DEL" then bg = (ctx.isColor and colors.orange or colors.white)
            elseif keyText == "OK" then bg = (ctx.isColor and colors.green or colors.white) end
            addButton(ctx, "k"..keyText, keyText, 2 + (c - 1) * (btnW + 1), startY + (r - 1) * (bH + gapY), btnW, bH, bg, colors.black, function() return keyText end)
        end
    end
    if allowCancel then
        local cancelY = startY + 4 * (bH + gapY)
        if cancelY < ctx.h then addButton(ctx, "cancel", "Annuler", 2, cancelY, ctx.w - 3, 1, (ctx.isColor and colors.red or colors.white), colors.white, function() return "CANCEL" end) end
    end

    drawButtons(ctx); drawFooter(ctx, "Saisir Montant/PIN")

    local function drawField()
        ctx.t.setCursorPos(2, 3); ctx.t.setBackgroundColor(colors.black); ctx.t.setTextColor(colors.yellow)
        local dVal = isMasked and string.rep("*", #value) or value
        ctx.t.write(string.sub(" " .. dVal .. string.rep(" ", math.max(0, ctx.w - 2 - #dVal - 1)), 1, ctx.w - 2))
        ctx.t.setCursorPos(2, 4)
        if errorMsg ~= "" then
            ctx.t.setTextColor(ctx.isColor and colors.red or colors.white); ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black)
            ctx.t.write(string.sub(errorMsg .. string.rep(" ", ctx.w), 1, ctx.w - 2))
        else
            ctx.t.setBackgroundColor(ctx.isColor and colors.gray or colors.black); ctx.t.write(string.rep(" ", ctx.w - 2))
        end
    end

    drawHeader(ctx, title); drawField()

    while true do
        local evType, p1, p2 = pullCtxEvent(ctx)
        local pressedKey = nil
        if evType == "tick" then drawHeader(ctx, title)
        elseif evType == "touch" then local cb = handleTouch(ctx, p1, p2); if cb then pressedKey = cb() end
        elseif evType == "char" and string.match(p1, "[0-9]") then pressedKey = p1
        elseif evType == "key" then
            if p1 == keys.backspace then pressedKey = "DEL" elseif p1 == keys.enter or p1 == keys.numPadEnter then pressedKey = "OK" end
        end

        if pressedKey then
            if pressedKey == "DEL" then value = string.sub(value, 1, math.max(0, #value - 1)); errorMsg = ""; drawField()
            elseif pressedKey == "OK" then if #value > 0 then return value else errorMsg = "Valeur vide!"; drawField() end
            elseif pressedKey == "CANCEL" then return nil
            elseif #value < 8 then value = value .. pressedKey; errorMsg = ""; drawField() end
        end
    end
end

-- ====================================================
-- 5. LOGIQUE DE TERMINAL INDIVIDUEL
-- ====================================================
local function runAtmTerminal(target_term, target_name)
    local ctx = createContext(target_term, target_name)

    while true do
        local currentAccountName = nil
        
        while not currentAccountName do
            -- ECRAN D'ACCUEIL : CONNEXION OU INSCRIPTION
            clr(ctx); clearButtons(ctx)
            drawHeader(ctx, "CraftBank")
            drawFooter(ctx, "Choisissez une action")

            local btnW = ctx.w - 2
            local midY = math.floor(ctx.h / 2)
            
            addButton(ctx, "btn_log", "Se Connecter", 2, midY - 2, btnW, 2, (ctx.isColor and colors.green or colors.white), colors.black, function() return "login" end)
            addButton(ctx, "btn_reg", "S'inscrire", 2, midY + 1, btnW, 2, (ctx.isColor and colors.cyan or colors.white), colors.black, function() return "register" end)
            
            drawButtons(ctx)
            
            local action = nil
            while not action do
                local evType, p1, p2 = pullCtxEvent(ctx)
                if evType == "tick" then drawHeader(ctx, "CraftBank")
                elseif evType == "touch" then
                    local cb = handleTouch(ctx, p1, p2)
                    if cb then action = cb() end
                end
            end

            -- LOGIQUE DE CONNEXION
            if action == "login" then
                local nameInput = getAzertyInput(ctx, "ID Compte", true)
                if nameInput then
                    local realAccountName = getAccountByName(nameInput)
                    if realAccountName then
                        local pinInput = getNumpadInput(ctx, "Code PIN", true, true)
                        if pinInput == bankData.accounts[realAccountName].pin then
                            currentAccountName = realAccountName
                        elseif pinInput then
                            clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Code PIN Incorrect"); sleep(1.5)
                        end
                    else
                        clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Compte Inconnu"); sleep(1.5)
                    end
                end
                
            -- LOGIQUE D'INSCRIPTION
            elseif action == "register" then
                local nameInput = getAzertyInput(ctx, "Nouveau Nom", true)
                if nameInput then
                    if getAccountByName(nameInput) then
                        clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Ce nom existe deja"); sleep(1.5)
                    else
                        local pinInput = getNumpadInput(ctx, "Nouveau PIN", true, true)
                        if pinInput then
                            -- Création et sauvegarde du compte
                            bankData.accounts[nameInput] = { pin = pinInput, balance = 0 }
                            saveData()
                            logTransaction("SYSTEME", "Creation compte: " .. nameInput)
                            
                            clr(ctx); drawHeader(ctx, "Succes"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.lime); ctx.t.write("Compte cree !"); sleep(1.5)
                            currentAccountName = nameInput -- Connecte le joueur directement
                        end
                    end
                end
            end
        end

        local function runDashboard()
            while true do
                local acc = bankData.accounts[currentAccountName]
                clr(ctx); clearButtons(ctx)
                
                local btnW = ctx.w - 3
                addButton(ctx, "dep", "+ Depot", 2, 6, btnW, 2, (ctx.isColor and colors.green or colors.white), colors.black, function() return "depot" end)
                addButton(ctx, "ret", "- Retrait", 2, 9, btnW, 2, (ctx.isColor and colors.orange or colors.white), colors.black, function() return "retrait" end)
                addButton(ctx, "quit", "Deconnexion", 2, 13, btnW, 1, (ctx.isColor and colors.red or colors.white), colors.white, function() return "logout" end)
                
                drawButtons(ctx); drawFooter(ctx, "Action ?")

                ctx.t.setBackgroundColor(colors.black)
                for y = 3, 4 do ctx.t.setCursorPos(2, y); ctx.t.write(string.rep(" ", ctx.w - 2)) end
                ctx.t.setCursorPos(3, 3); ctx.t.setTextColor(colors.lightGray); ctx.t.write("Solde :")
                ctx.t.setCursorPos(3, 4); ctx.t.setTextColor(colors.green); ctx.t.write("$" .. string.format("%.2f", acc.balance))

                while true do
                    drawHeader(ctx, acc.name or currentAccountName)
                    local evType, p1, p2 = pullCtxEvent(ctx)
                    if evType == "tick" then
                        drawHeader(ctx, acc.name or currentAccountName)
                    elseif evType == "touch" then
                        local cb = handleTouch(ctx, p1, p2)
                        if cb then
                            local a = cb()
                            if a == "logout" then return end
                            if a == "depot" then
                                local val = getNumpadInput(ctx, "Montant Depot", false, true)
                                local amt = tonumber(val)
                                if amt and amt > 0 then
                                    bankData.accounts[currentAccountName].balance = acc.balance + amt
                                    logTransaction(currentAccountName, "+$"..amt.." (Depot)")
                                end
                                break 
                            elseif a == "retrait" then
                                local val = getNumpadInput(ctx, "Montant Retrait", false, true)
                                local amt = tonumber(val)
                                if amt and amt > 0 then
                                    if acc.balance >= amt then
                                        bankData.accounts[currentAccountName].balance = acc.balance - amt
                                        logTransaction(currentAccountName, "-$"..amt.." (Retrait)")
                                    else
                                        clr(ctx); drawHeader(ctx, "Erreur"); ctx.t.setCursorPos(2,3); ctx.t.setTextColor(colors.red); ctx.t.write("Fonds insuffisants"); sleep(1.5)
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
        
        runDashboard()
    end
end

-- ====================================================
-- 6. ECRAN DE LOG SERVEUR (ORDINATEUR CENTRAL)
-- ====================================================
local function runServerLog()
    term.redirect(term.native())
    local w, h = term.getSize()
    
    local function drawLogs()
        term.setBackgroundColor(colors.black); term.clear()
        term.setCursorPos(1,1); term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); term.clearLine()
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

-- Horloge asynchrone pour mettre a jour les en-tetes (Daemon)
table.insert(tasks, function()
    while true do
        sleep(1)
        os.queueEvent("bank_tick")
    end
end)

if #monitors == 0 then
    table.insert(tasks, function() runAtmTerminal(term.native(), "computer") end)
else
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

parallel.waitForAll(table.unpack(tasks))
