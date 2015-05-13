#!/usr/bin/lua

-- Read all from stdin and parse, then write it all out and append extra stuff.

function calculate_superiority(class, a1, a2)
    local largest_army, smallest_army
    if (a1.strengths[class] or 0) > (a2.strengths[class] or 0) then
        largest_army = a1
        smallest_army = a2
    else
        largest_army = a2
        smallest_army = a1
    end
    local ratio
    local largest_strength = largest_army.strengths[class] or 0
    local smallest_strength = (smallest_army.strengths[class] or 0) + (smallest_army.neutralize[class] or 0)
    if smallest_strength == 0 then
        ratio = 5
    else
        ratio = largest_strength / smallest_strength
    end
    if largest_strength < (smallest_army.strengths.troop / 100) then
        ratio = 0 -- superiority only applies if it's at least 1% of enemy's total strength
    end
    if class == "troop" then
        if ratio >= 50 then
            largest_army.superiorities.troop = 20
        elseif ratio >= 30 then
            largest_army.superiorities.troop = 18
        elseif ratio >= 20 then
            largest_army.superiorities.troop = 16
        elseif ratio >= 15 then
            largest_army.superiorities.troop = 14
        elseif ratio >= 10 then
            largest_army.superiorities.troop = 12
        elseif ratio >= 7 then
            largest_army.superiorities.troop = 10
        elseif ratio >= 5 then
            largest_army.superiorities.troop = 8
        elseif ratio >= 3 then
            largest_army.superiorities.troop = 6
        elseif ratio >= 2 then
            largest_army.superiorities.troop = 4
        elseif ratio >= 1.5 then
            largest_army.superiorities.troop = 2
        end
    else
        if ratio >= 5 then
            largest_army.superiorities[class] = 3
        elseif ratio >= 3 then
            largest_army.superiorities[class] = 2
        elseif ratio >= 2 then
            largest_army.superiorities[class] = 1
        end
    end
end

-- 'troops' is a table of name to TS, Class, WT and Mob
local writeback = true
local troops = {}
local armies = {}
local line = io.read()
local mode

if arg[1] then
    if arg[1] == "no" then
        writeback = false
    end
end

while line ~= nil do
    local potential_mode
    local match
    potential_mode = line:match("^#%s*(.+)%s*$")
    if potential_mode then
        mode = string.lower(potential_mode)
    elseif mode == "troops" then
        -- 'troops' mode, every entry is a new type of troop
        local name, ts, classes, wt, mob = line:match("^([^:]+):%s+TS%s*=%s*(%(?%d+%.?%d*%)?)%s+Class%s*=%s*(%S+)%s+WT%s*=%s*(%d+%.?%d*)%s+Mob%s*=%s*(%w+)")
        if name then
            troops[name] = {name=name, ts=ts, classes={}, wt=wt, mob=mob}
            if ts:match("%((%d+)%)") then
                troops[name].ts = ts:match("%((%d+)%)")
                troops[name].support = true
            end
            class = string.lower(classes)
            for class in classes:gmatch("[^,]+") do
                if class:match("-") then
                elseif class:match("%b()") then
                    troops[name].classes[class:match("%((%w+)%)")] = "neutralize"
                else
                    troops[name].classes[class] = "normal"
                end
            end
        end
    else
        -- any other mode, is an army.
        local type, qty = line:match("^([^:]+):%s+(%d+)")
        if type then
            local troop = troops[type]
            if troop then
                local army
                if armies[mode] then
                    army = armies[mode]
                else
                    army = {name=mode, troops = {}}
                    armies[mode] = army
                end
                if not army.troops[troop] then army.troops[troop] = 0 end
                army.troops[troop] = army.troops[troop] + qty
            end
        end
    end
    if writeback then
        print(line)
    end
    line = io.read()
end

for _,army in pairs(armies) do
    army.strengths = {}
    army.neutralize = {}
    for troop,qty in pairs(army.troops) do
        if army.strengths.troop == nil then army.strengths.troop = 0 end
        -- if class is support, don't add to total troop strength
        local troop_add
        if troop.support then
            troop_add = troop.ts * qty / 10
        else
            troop_add = troop.ts * qty
        end
        if not troop.support then
            army.strengths.troop = army.strengths.troop + troop_add
        end
        -- if class is parenthetical, it neutralizes that class
        for class,type in pairs(troop.classes) do
            if type == "neutralize" then
                army.neutralize[class] = (army.neutralize[class] or 0) + troop.ts * qty
            else
                army.strengths[class] = (army.strengths[class] or 0) + troop.ts * qty
            end
        end
    end
end

local army1
local army2
local armycount = 0
for _,v in pairs(armies) do
    armycount = armycount + 1
    if armycount == 1 then
        army1 = v
    elseif armycount == 2 then
        army2 = v
    end
end

if armycount == 2 then
    local classes = {}
    army1.superiorities = {}
    army2.superiorities = {}
    for class,_ in pairs(army1.strengths) do
        classes[class] = true
    end
    for class,_ in pairs(army1.neutralize) do
        classes[class] = true
    end
    for class,_ in pairs(army2.strengths) do
        classes[class] = true
    end
    for class,_ in pairs(army2.neutralize) do
        classes[class] = true
    end

    calculate_superiority("troop", army1, army2)
    for class,_ in pairs(classes) do
        if class ~= "troop" then
            calculate_superiority(class, army1, army2)
        end
    end
end

for _,army in pairs(armies) do
    print("")
    print("# Army "..army.name)

    print("Strengths:")
    for class,str in pairs(army.strengths) do
        print("- "..class..": "..str)
    end
    print("Neutralizes:")
    for class,neut in pairs(army.neutralize) do
        print("- "..class..": "..neut)
    end
    if army.superiorities then
        print("Superiorities:")
        for class,sup in pairs(army.superiorities) do
            print("- "..class..": "..sup)
        end
    end
    print("")
end
