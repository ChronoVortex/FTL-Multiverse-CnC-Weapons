CNC_WEAPONS_INFO = true

local vter = mods.vertexutil.vter

-- Only set up the namespace if it hasn't already been set up
if not mods.cnconquer then mods.cnconquer = {} end

-- Move nuke damage projectiles to their targets immediatly
if not mods.cnconquer.MoveNukeSurge then
    function mods.cnconquer.MoveNukeSurge()
        for proj in vter(Hyperspace.ships.player.superBarrage) do
            proj:EnterDestinationSpace()
            proj.position = proj.target
            proj:ComputeHeading()
        end
    end
    script.on_game_event("LUA_MOVE_NUKE_SURGE", false, mods.cnconquer.MoveNukeSurge)
end

-- Retarget the Banshee C MV Renegade's tiberium bomb to the room their fiends are in
local function target_enemy_boarders(projectile)
    -- Find the room on the player ship with the most boarders
    local mostBoardersRoom = nil
    local mostBoarders = 0
    local currentRoom = 0
    while Hyperspace.ships.player:GetRoomCenter(currentRoom).x ~= -1 do -- Hacky way to check if currentRoom exists
        local numBoarders = Hyperspace.ships.player:CountCrewShipId(currentRoom, 1)
        if numBoarders > mostBoarders then
            mostBoarders = numBoarders
            mostBoardersRoom = currentRoom
        end
        currentRoom = currentRoom + 1
    end
    
    -- Retarget the bomb to that room
    if mostBoardersRoom then
        projectile.target = Hyperspace.ships.player:GetRoomCenter(mostBoardersRoom)
        projectile:ComputeHeading()
    end
end
if not mods.cnconquer.RetargetTibBomb then
    if mods.inferno then
        function mods.cnconquer.RetargetTibBomb(ship, weapon, projectile)
            if ship.iShipId == 1 and Hyperspace.Get_Projectile_Extend(projectile).name == "BOMB_TIBERIUM" then
                target_enemy_boarders(projectile)
            end
        end
        script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, mods.cnconquer.RetargetTibBomb)
    else
        function mods.cnconquer.RetargetTibBomb()
            -- We only need to do any of this if the game isn't paused
            if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
                -- Check for tiberium bomb
                local hasbomb = false
                pcall(function() hasbomb = Hyperspace.ships.enemy:HasEquipment("BOMB_TIBERIUM") > 0 end)
                
                -- Only retarget the bomb if it exists
                if hasbomb then
                    for weapon in vter(Hyperspace.ships.enemy.weaponSystem.weapons) do
                        -- Capture projectiles fired by tiberium bomb launcher
                        if weapon.name == "Tiberium Bomb" then
                            local projectile = weapon:GetProjectile()
                            if projectile then
                                Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                                target_enemy_boarders(projectile)
                            end
                        end
                    end
                end
            end
        end
        script.on_internal_event(Defines.InternalEvents.ON_TICK, mods.cnconquer.RetargetTibBomb)
    end
end
