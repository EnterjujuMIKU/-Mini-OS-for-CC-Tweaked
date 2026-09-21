local w, h = term.getSize()
local isColor = term.isColor()

local colors_bg = isColor and colors.gray or colors.black
local colors_header = isColor and colors.blue or colors.gray
local colors_text = colors.white
local colors_accent = isColor and colors.yellow or colors.white
local colors_sel = isColor and colors.lightBlue or colors.white

local currentPath = ""

local function drawBar(y, text, bg, fg)
    term.setCursorPos(1, y)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.clearLine()
    term.write(text)
end

local function drawHeader(title)
    local headerText = " [MiniOS] - " .. (title or "Accueil")
    drawBar(1, headerText, colors_header, colors_text)
    local clock = textutils.formatTime(os.time(), true)
    term.setCursorPos(w - #clock + 1, 1)
    term.write(clock)
end

local function drawFooter(info)
    drawBar(h, " " .. (info or "[Clic] Interagir | [Q] Quitter"), colors_header, colors_text)
end

local function clearScreen()
    term.setBackgroundColor(colors_bg)
    term.setTextColor(colors_text)
    term.clear()
end

local function fileManager()
    local selected = 1
    while true do
        clearScreen()
        drawHeader("Fichiers : /" .. currentPath)
        drawFooter("[N] Nouveau [D] Supprimer [E] Editer [Ret] Retour")

        local items = fs.list(currentPath)
        table.sort(items, function(a, b)
            local pA = fs.combine(currentPath, a)
            local pB = fs.combine(currentPath, b)
            if fs.isDir(pA) ~= fs.isDir(pB) then
                return fs.isDir(pA)
            end
            return a < b
        end)

        local maxDisplay = h - 3
        if #items == 0 then
            term.setCursorPos(3, 3)
            term.setTextColor(colors.lightGray)
            term.write("(Dossier vide)")
        else
            for i = 1, math.min(#items, maxDisplay) do
                term.setCursorPos(3, i + 2)
                local fullP = fs.combine(currentPath, items[i])
                local isDir = fs.isDir(fullP)
                
                if i == selected then
                    term.setBackgroundColor(colors_sel)
                    term.setTextColor(colors.black)
                else
                    term.setBackgroundColor(colors_bg)
                    term.setTextColor(isDir and colors_accent or colors_text)
                end
                
                local prefix = isDir and "[DIR] " or "      "
                local lineStr = prefix .. items[i]
                -- Remplissage pour rendre toute la ligne cliquable
                term.write(lineStr .. string.rep(" ", math.max(0, w - #lineStr - 2)))
            end
        end

        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            if key == keys.up and selected > 1 then selected = selected - 1
            elseif key == keys.down and selected < #items then selected = selected + 1
            elseif key == keys.enter and #items > 0 then
                local target = fs.combine(currentPath, items[selected])
                if fs.isDir(target) then
                    currentPath = target
                    selected = 1
                else
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                    term.clear()
                    term.setCursorPos(1, 1)
                    shell.run(target)
                    print("\n[Touche ou clic pour revenir]")
                    os.pullEvent()
                end
            elseif key == keys.backspace then
                if currentPath ~= "" then
                    currentPath = fs.getDir(currentPath)
                    selected = 1
                else
                    break
                end
            elseif key == keys.e and #items > 0 then
                local target = fs.combine(currentPath, items[selected])
                if not fs.isDir(target) then shell.run("edit", target) end
            elseif key == keys.n then
                term.setCursorPos(1, h - 1)
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.yellow)
                term.clearLine()
                term.write("Nom fichier/dossier : ")
                local name = read()
                if name and name ~= "" then
                    local newP = fs.combine(currentPath, name)
                    if not fs.exists(newP) then
                        local f = fs.open(newP, "w")
                        if f then f.close() end
                    end
                end
            elseif key == keys.d and #items > 0 then
                local target = fs.combine(currentPath, items[selected])
                fs.delete(target)
                if selected > 1 then selected = selected - 1 end
            elseif key == keys.q then
                break
            end
        elseif event == "mouse_click" then
            local my = p3
            local clickedIndex = my - 2
            
            if my >= 3 and my <= 2 + #items and clickedIndex <= maxDisplay then
                if selected == clickedIndex then
                    local target = fs.combine(currentPath, items[selected])
                    if fs.isDir(target) then
                        currentPath = target
                        selected = 1
                    else
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.white)
                        term.clear()
                        term.setCursorPos(1, 1)
                        shell.run(target)
                        print("\n[Touche ou clic pour revenir]")
                        os.pullEvent()
                    end
                else
                    selected = clickedIndex
                end
            end
        end
    end
end

local function miniTerminal()
    clearScreen()
    drawHeader("Terminal CraftOS")
    drawFooter("Tapez 'exit' pour revenir")
    
    term.setCursorPos(1, 3)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.green)
    print("MiniOS Shell")
    print("Editer le code : edit <nom>")
    print("Lancer script Lua : lua\n")
    
    shell.run("shell")
end

local function systemInfo()
    clearScreen()
    drawHeader("Informations Systeme")
    drawFooter("[Clic ou Touche] Retour")

    term.setCursorPos(3, 3)
    term.setTextColor(colors_accent)
    term.write("--- PROPRIETES ---")
    
    term.setTextColor(colors_text)
    term.setCursorPos(3, 5)
    term.write("ID Ordinateur : " .. os.computerID())
    term.setCursorPos(3, 6)
    term.write("Etiquette     : " .. (os.computerLabel() or "Aucune"))
    term.setCursorPos(3, 7)
    term.write("Espace libre  : " .. math.floor(fs.getFreeSpace("/") / 1024) .. " Ko")
    term.setCursorPos(3, 8)
    term.write("Affichage     : " .. (isColor and "Couleur" or "Monochrome"))

    os.pullEvent()
end

local menuOptions = {
    { label = "Gestionnaire de Fichiers", action = fileManager },
    { label = "Terminal & Edition de Code", action = miniTerminal },
    { label = "Informations Systeme", action = systemInfo },
    { label = "Quitter vers CraftOS", action = function() return "exit" end }
}

local function mainMenu()
    local selected = 1
    while true do
        clearScreen()
        drawHeader("Menu Principal")
        drawFooter("[Clic] Choisir | [Fleches] Naviguer")

        for i, opt in ipairs(menuOptions) do
            term.setCursorPos(5, i + 3)
            local padLength = math.max(0, 32 - #opt.label)
            if i == selected then
                term.setBackgroundColor(colors_sel)
                term.setTextColor(colors.black)
                term.write(" > " .. opt.label .. string.rep(" ", padLength))
            else
                term.setBackgroundColor(colors_bg)
                term.setTextColor(colors_text)
                term.write("   " .. opt.label .. string.rep(" ", padLength))
            end
        end

        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            if key == keys.up and selected > 1 then selected = selected - 1
            elseif key == keys.down and selected < #menuOptions then selected = selected + 1
            elseif key == keys.enter then
                local res = menuOptions[selected].action()
                if res == "exit" then break end
            end
        elseif event == "mouse_click" then
            local my = p3
            local clickedIndex = my - 3
            if clickedIndex >= 1 and clickedIndex <= #menuOptions then
                selected = clickedIndex
                local res = menuOptions[selected].action()
                if res == "exit" then break end
            end
        end
    end
    clearScreen()
    term.setCursorPos(1, 1)
    print("Retour au shell d'origine.")
end

mainMenu()
