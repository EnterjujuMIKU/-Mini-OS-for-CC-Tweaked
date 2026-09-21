-- ====================================================
-- MiniOS pour ComputerCraft / CC:Tweaked (CraftOS)
-- ====================================================

local w, h = term.getSize()
local isColor = term.isColor()

-- Palette visuelle
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
    drawBar(h, " " .. (info or "[Flèches] Naviguer | [Entrée] Valider"), colors_header, colors_text)
end

local function clearScreen()
    term.setBackgroundColor(colors_bg)
    term.setTextColor(colors_text)
    term.clear()
end

-- ====================================================
-- 1. GESTIONNAIRE DE FICHIERS
-- ====================================================
local function fileManager()
    local selected = 1
    while true do
        clearScreen()
        drawHeader("Fichiers : /" .. currentPath)
        drawFooter("[N] Nouveau | [D] Suppr. | [E] Éditer | [Backspace] Retour | [Q] Quitter")

        local items = fs.list(currentPath)
        table.sort(items, function(a, b)
            local pA = fs.combine(currentPath, a)
            local pB = fs.combine(currentPath, b)
            if fs.isDir(pA) ~= fs.isDir(pB) then
                return fs.isDir(pA)
            end
            return a < b
        end)

        if #items == 0 then
            term.setCursorPos(3, 3)
            term.setTextColor(colors.lightGray)
            term.write("(Dossier vide)")
        else
            local maxDisplay = h - 3
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
                term.write(lineStr .. string.rep(" ", math.max(0, w - #lineStr - 3)))
            end
        end

        local _, key = os.pullEvent("key")
        
        if key == keys.up and selected > 1 then
            selected = selected - 1
        elseif key == keys.down and selected < #items then
            selected = selected + 1
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
                print("\n[Appuyez sur une touche pour revenir au MiniOS]")
                os.pullEvent("key")
            end
        elseif key == keys.backspace then
            if currentPath ~= "" then
                currentPath = fs.getDir(currentPath)
                selected = 1
            end
        elseif key == keys.e and #items > 0 then
            local target = fs.combine(currentPath, items[selected])
            if not fs.isDir(target) then
                shell.run("edit", target)
            end
        elseif key == keys.n then
            term.setCursorPos(1, h - 1)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.clearLine()
            term.write("Nom du fichier/dossier : ")
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
    end
end

-- ====================================================
-- 2. TERMINAL ET CONSOLE
-- ====================================================
local function miniTerminal()
    clearScreen()
    drawHeader("Terminal CraftOS")
    drawFooter("Tapez 'exit' pour revenir au menu MiniOS")
    
    term.setCursorPos(1, 3)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.green)
    print("MiniOS Shell — Compatible CraftOS")
    print("Éditer du code : edit <nom_fichier>")
    print("Exécuter Lua    : lua\n")
    
    shell.run("shell")
end

-- ====================================================
-- 3. INFORMATIONS SYSTÈME
-- ====================================================
local function systemInfo()
    clearScreen()
    drawHeader("Informations Système")
    drawFooter("Appuyez sur une touche pour revenir")

    term.setCursorPos(3, 3)
    term.setTextColor(colors_accent)
    term.write("--- PROPRIÉTÉS DU SYSTÈME ---")
    
    term.setTextColor(colors_text)
    term.setCursorPos(3, 5)
    term.write("ID Ordinateur : " .. os.computerID())
    term.setCursorPos(3, 6)
    term.write("Étiquette     : " .. (os.computerLabel() or "Aucune"))
    term.setCursorPos(3, 7)
    term.write("Espace libre  : " .. math.floor(fs.getFreeSpace("/") / 1024) .. " Ko")
    term.setCursorPos(3, 8)
    term.write("Affichage     : " .. (isColor and "Couleur (Avancé)" or "Monochrome (Standard)"))

    os.pullEvent("key")
end

-- ====================================================
-- MENU PRINCIPAL
-- ====================================================
local menuOptions = {
    { label = "Gestionnaire de Fichiers", action = fileManager },
    { label = "Terminal & Édition de Code", action = miniTerminal },
    { label = "Informations Système", action = systemInfo },
    { label = "Quitter vers CraftOS", action = function() return "exit" end }
}

local function mainMenu()
    local selected = 1
    while true do
        clearScreen()
        drawHeader("Menu Principal")
        drawFooter()

        for i, opt in ipairs(menuOptions) do
            term.setCursorPos(5, i + 3)
            if i == selected then
                term.setBackgroundColor(colors_sel)
                term.setTextColor(colors.black)
                term.write(" > " .. opt.label .. " ")
            else
                term.setBackgroundColor(colors_bg)
                term.setTextColor(colors_text)
                term.write("   " .. opt.label .. " ")
            end
        end

        local _, key = os.pullEvent("key")
        if key == keys.up and selected > 1 then
            selected = selected - 1
        elseif key == keys.down and selected < #menuOptions then
            selected = selected + 1
        elseif key == keys.enter then
            local res = menuOptions[selected].action()
            if res == "exit" then
                clearScreen()
                term.setCursorPos(1, 1)
                print("Retour au shell CraftOS d'origine.")
                break
            end
        end
    end
end

mainMenu()