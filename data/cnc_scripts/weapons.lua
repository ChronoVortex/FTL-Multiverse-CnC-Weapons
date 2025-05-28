CNC_WEAPONS_INFO = true

local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local random_point_radius = mods.vertexutil.random_point_radius
local INT_MAX = 2147483647
local function check_paused()
    return Hyperspace.App.gui.bPaused or Hyperspace.App.gui.menu_pause or Hyperspace.App.gui.event_pause
end

-- Create projectiles and flash for nuke
do
    local nukeFlash = 0.3
    local nukeFlashCurrent = 0
    local nukeDamageBp = Hyperspace.Blueprints:GetWeaponBlueprint("WEAPON_NUKE_SURGE_DAMAGE")
    local function check_proj_nuke(projectile)
        return projectile and projectile.extend and projectile.extend.name == "WEAPON_NUKE_SURGE_INITIAL" and projectile.currentSpace == 1
    end
    local doShieldFlash = false
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(ship, projectile, damage, response)
        doShieldFlash = check_proj_nuke(projectile) and ship.shieldSystem and ship.shieldSystem.shields.power.super.first > 0
    end)
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(ship, projectile, damage, response)
        if doShieldFlash then
            nukeFlashCurrent = nukeFlash
            doShieldFlash = false
        end
    end)
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_COLLISION, function(projectile1, projectile2)
        if check_proj_nuke(projectile1) or check_proj_nuke(projectile2) then
            nukeFlashCurrent = nukeFlash
        end
    end)
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, location, damage, shipFriendlyFire)
        if check_proj_nuke(projectile) then
            nukeFlashCurrent = nukeFlash
            for i = 1, 7 do
                local pos = ship:GetRandomRoomCenter()
                Hyperspace.App.world.space:CreateLaserBlast(nukeDamageBp, pos, 1, 0, pos, 1, 0)
            end
        end
    end)
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        if not check_paused() and nukeFlashCurrent > 0 then
            nukeFlashCurrent = nukeFlashCurrent - time_increment()
        end
    end)
    script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
        if ship.iShipId == 1 and nukeFlashCurrent > 0 then
            local halfTime = nukeFlash/2
            local alpha = 1 - math.abs((nukeFlashCurrent - halfTime)/halfTime)
            Graphics.CSurface.GL_DrawRect(-500, -500, 1000, 1000, Graphics.GL_Color(1, 1, 1, alpha))
        end
    end)
end

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
local mammothMissile = Hyperspace.Blueprints:GetWeaponBlueprint("MAMMOTH_CANNON_TUSK")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "MAMMOTH_CANNON" then
        local ship = Hyperspace.ships(weapon.iShipId)
        if weapon.weaponVisual.anim.currentFrame > 12 then
            if ship.weaponSystem.missile_count > 0 then
                -- Use a missile
                if math.random(100) > ship:GetAugmentationValue("EXPLOSIVE_REPLICATOR")*100 then
                    ship:ModifyMissileCount(-1)
                end
                
                -- Create the missiles
                local spaceManager = Hyperspace.App.world.space
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
                Hyperspace.Sounds:PlaySoundMix("missileMammoth", -1, false)
            end
            projectile:Kill()
        else
            -- Play normal fire sound
            local sound = "GB_cannonMedium"..(tostring(math.random(3)):sub(1, 1))
            Hyperspace.Sounds:PlaySoundMix(sound, -1, false)
        end
    end
end, INT_MAX)

-- Handle frost splitter beam
local frostPinpoint = Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_FROST_SHOTGUN_PROJECTILE")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "BEAM_FROST_SHOTGUN" then
        local spaceManager = Hyperspace.App.world.space
        local beam = spaceManager:CreateBeam(
            frostPinpoint,
            projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        if (math.random() > 0.5) then beam.damage.iSystemDamage = beam.damage.iSystemDamage + 1 end
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
    end
end, INT_MAX)

-- Handle prismatic scatter beam
local prismBeams = mods.cnconquer.prismBeams
prismScatterRefractions = {
    refractions = 3,
    blueprints = {
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_FIRE"),
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_PART"),
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_BREACH"),
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_ENERGY"),
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_ION"),
        Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_REFRACT_BIO")
    }
}
prismBeams["BEAM_PRISM_SCATTER_PROJ_NORMAL"] = prismScatterRefractions
prismBeams["BEAM_PRISM_SCATTER_PROJ_ENERGY"] = prismScatterRefractions
prismBeams["BEAM_PRISM_SCATTER_PROJ_ION"]    = prismScatterRefractions
prismBeams["BEAM_PRISM_SCATTER_PROJ_PHASE"]  = prismScatterRefractions
local prismScatterBeams = {
    Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_PROJ_NORMAL"),
    Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_PROJ_ENERGY"),
    Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_PROJ_ION"),
    Hyperspace.Blueprints:GetWeaponBlueprint("BEAM_PRISM_SCATTER_PROJ_PHASE")
}
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint.name == "BEAM_PRISM_SCATTER" then
        local spaceManager = Hyperspace.App.world.space
        local beam = spaceManager:CreateBeam(
            prismScatterBeams[math.random(#prismScatterBeams)],
            projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
    end
end, INT_MAX)
