mods.chronoutil = {}

-- Generic iterator for C vectors
function mods.chronoutil.vter(cvec)
    local i = -1 --so the first returned value is indexed at zero
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Tutorial arrow manager
local tutArrowAlphaInterval = 0.38
local tutArrowSpr1 = Hyperspace.Resources:GetImageId("tutorial/arrow.png")
local tutArrowSpr2 = Hyperspace.Resources:GetImageId("tutorial/arrow2.png")
local tutArrow = {
    visible = false,
    dir = 0,
    x = 0,
    y = 0,
    timer = 0
}
function mods.chronoutil.ShowTutorialArrow(dir, x, y)
    tutArrow.visible = true
    tutArrow.dir = dir
    tutArrow.x = x
    tutArrow.y = y
    tutArrow.timer = 0
end
function mods.chronoutil.HideTutorialArrow()
    tutArrow.visible = false
end
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
    if tutArrow.visible then
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr1,
            tutArrow.x, tutArrow.y,
            tutArrowSpr1.width, tutArrowSpr1.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1), false
        )
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr2,
            tutArrow.x, tutArrow.y,
            tutArrowSpr2.width, tutArrowSpr2.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1 - math.abs(tutArrow.timer - tutArrowAlphaInterval)/tutArrowAlphaInterval), false
        )
        tutArrow.timer = (tutArrow.timer + Hyperspace.FPS.SpeedFactor/16)%(2*tutArrowAlphaInterval)
    end
end)
