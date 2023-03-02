CNC_WEAPONS_INFO = true

local vter = mods.vertexutil.vter
local INT_MAX = 2147483647

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

-- Turn the Mammoth Cannon's 3rd projectile into missiles
local mammothMissile = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("MAMMOTH_CANNON_TUSK")
if mods.inferno then
    script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, function(ship, weapon, projectile)
        if Hyperspace.Get_Projectile_Extend(projectile).name == "MAMMOTH_CANNON" then
            if weapon.weaponVisual.anim.currentFrame > 12 then
                if ship.weaponSystem.missile_count > 0 then
                    -- Use a missile
                    if Hyperspace.random32()%100 >= ship:GetAugmentationValue("EXPLOSIVE_REPLICATOR")*100 then
                        ship:ModifyMissileCount(-1)
                    end
                    
                    -- Create the missiles
                    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
                    for vertOffset = 0, 6, 3 do
                        -- Calculate offset for the missile since its barrel doesn't line up with the autocannons
                        local pos = Hyperspace.Pointf()
                        local vertMod = -1
                        if weapon.mount.mirror then vertMod = 1 end
                        if weapon.mount.rotate then
                            pos.x = projectile.position.x - 20
                            pos.y = projectile.position.y + vertOffset*vertMod
                        else
                            pos.y = projectile.position.y + 20
                            pos.x = projectile.position.x + vertOffset*vertMod
                        end
                        
                        -- Calculate a random point within a 35px radius of the target
                        local r = 35*math.sqrt(Hyperspace.random32()/INT_MAX)
                        local theta = 2*math.pi*Hyperspace.random32()/INT_MAX
                        local target = Hyperspace.Pointf(projectile.target.x + r*math.cos(theta), projectile.target.y + r*math.sin(theta))
                        
                        -- Create a missile
                        spaceManager:CreateMissile(mammothMissile, pos, projectile.currentSpace, projectile.ownerId, target, projectile.destinationSpace, projectile.heading).entryAngle = projectile.entryAngle
                    end
                    
                    -- Play missile fire sound
                    Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("missileMammoth", 0.4, false)
                end
                projectile:Kill()
                return true
            else
                -- Play normal fire sound
                local sound = "GB_cannonMedium"..(tostring(Hyperspace.random32()%3 + 1):sub(1, 1))
                Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(sound, 0.4, false)
            end
        end
    end, INT_MAX)
end
