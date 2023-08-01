CNC_WEAPONS_INFO = true

local vter = mods.vertexutil.vter
local random_point_radius = mods.vertexutil.random_point_radius
local INT_MAX = 2147483647

-- Move nuke damage projectiles to their targets immediatly
script.on_game_event("LUA_MOVE_NUKE_SURGE", false, function()
    for proj in vter(Hyperspace.ships.player.superBarrage) do
        proj:EnterDestinationSpace()
        proj.position = proj.target
        proj:ComputeHeading()
    end
end)

-- Retarget the Banshee C MV Renegade's tiberium bomb to the room their fiends are in
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.iShipId == 1 and weapon.blueprint.name == "BOMB_TIBERIUM" then
        -- Find the room on the player ship with the most boarders
        local mostBoardersRoom = nil
        local mostBoarders = 0
        for currentRoom = 0, Hyperspace.ShipGraph.GetShipInfo(0):RoomCount() - 1 do
            local numBoarders = Hyperspace.ships.player:CountCrewShipId(currentRoom, 1)
            if numBoarders > mostBoarders then
                mostBoarders = numBoarders
                mostBoardersRoom = currentRoom
            end
        end
        
        -- Retarget the bomb to that room
        if mostBoardersRoom then
            projectile.target = Hyperspace.ships.player:GetRoomCenter(mostBoardersRoom)
            projectile:ComputeHeading()
        end
    end
end)

-- Turn the Mammoth Cannon's 3rd projectile into missiles
local mammothMissile = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("MAMMOTH_CANNON_TUSK")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "MAMMOTH_CANNON" then
        local ship = Hyperspace.Global.GetInstance():GetShipManager(weapon.iShipId)
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
                    
                    -- Create a missile
                    spaceManager:CreateMissile(mammothMissile, pos, projectile.currentSpace, projectile.ownerId, random_point_radius(projectile.target, 35), projectile.destinationSpace, projectile.heading).entryAngle = projectile.entryAngle
                end
                
                -- Play missile fire sound
                Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("missileMammoth", 0.4, false)
            end
            projectile:Kill()
        else
            -- Play normal fire sound
            local sound = "GB_cannonMedium"..(tostring(Hyperspace.random32()%3 + 1):sub(1, 1))
            Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(sound, 0.4, false)
        end
    end
end, INT_MAX)
