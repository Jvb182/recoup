local _, ns = ...

-- English food/drink tooltips. Rank the stated full serving's recovery,
-- not rarity, vendor price, or a well-fed stat bonus.
function ns.Recovery(lines, maxHealth, maxMana)
    local health, mana = 0, 0
    for _, raw in ipairs(lines or {}) do
        local text = raw:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", "")
        text = text:gsub(",", ""):gsub(" of your ", " "):gsub(" of ", " "):gsub("your ", "")
        -- Limit parsing to the recovery sentence so well-fed bonuses cannot win.
        local restore = text:match("restores? (.+)")
        if not restore then
            local healed = text:match("heals ([%d%.]+) damage") or text:match("heals ([%d%.]+) health")
            if healed then restore = healed .. " health" end
        end
        if restore then
            local h, hp = restore:match("([%d%.]+)(%%?) health")
            local m, mp = restore:match("([%d%.]+)(%%?) mana")
            if h and restore:find("health and mana", 1, true) then m, mp = h, hp end
            local duration = tonumber(restore:match("for (%d+) sec"))
            local interval = tonumber(restore:match("every (%d+) sec"))
            if restore:find("per second", 1, true) then interval = 1 end
            local ticks = duration and interval and math.max(1, duration / interval) or 1
            local function value(n, percent, maximum)
                return (tonumber(n) or 0) * (percent == "%" and (maximum or 0) / 100 or 1) * ticks
            end
            health = math.max(health, value(h, hp, maxHealth))
            mana = math.max(mana, value(m, mp, maxMana))
        end
    end
    return health, mana
end

function ns.Best(items, kind)
    local best
    for _, item in ipairs(items) do
        if item.count > 0 and (item[kind] or 0) > 0 then
            if not best or item[kind] > best[kind] or (item[kind] == best[kind] and item.id < best.id) then best = item end
        end
    end
    return best
end
