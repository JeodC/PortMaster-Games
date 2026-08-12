view_variables();

if (instance_exists(oPlr))
{
    plrx = oPlr.x;
    plry = oPlr.y;
    plrxspeed = oPlr.xspeed;
    plryspeed = oPlr.yspeed;
    plrGroundUnder = oPlr.ground_under;
    
    if (instance_exists(oPlr_lavapit_reset))
    {
        plrx = oPlr_lavapit_reset.x;
        plry = oPlr_lavapit_reset.y;
    }
    
    if (instance_exists(oCannon_boss) && (oCannon_boss.bossActive == 1 || oCannon_boss.active == 1))
    {
        plrx = oCannon_boss.x;
        plry = oCannon_boss.y;
    }
    
    if (instance_exists(oTrex_boss) && instance_exists(oPlr) && oPlr.state == "incannon" && collision_circle(oPlr.x, oPlr.y, 32, oCannon_nostop, true, true))
    {
        plrx = oPlr.x - 84;
        plry = oPlr.y;
    }
    
    if (instance_exists(oTank_boss))
    {
        tbDis = point_distance(oPlr.x, oPlr.y, oTank_boss.x, oTank_boss.y);
        tbDir = point_direction(oPlr.x, oPlr.y, oTank_boss.x, oTank_boss.y);
        plrx = oPlr.x + lengthdir_x(tbDis * 0.3, tbDir);
        plry = oPlr.y + lengthdir_y(tbDis * 0.3, tbDir);
    }
    
    if (instance_exists(oBomber_boss_puppet))
    {
        bossplrx = oPlr.x;
        bossplry = oPlr.y;
        
        if (instance_exists(oPlr_lavapit_reset))
        {
            bossplrx = oPlr_lavapit_reset.x;
            bossplry = oPlr_lavapit_reset.y;
        }
        
        tbDis = point_distance(bossplrx, bossplry, oBomber_boss_puppet.x, oBomber_boss_puppet.y);
        tbDir = point_direction(bossplrx, bossplry, oBomber_boss_puppet.x, oBomber_boss_puppet.y);
        plrx = bossplrx + lengthdir_x(tbDis * 0.2, tbDir);
        plry = bossplry + lengthdir_y(tbDis * 0.3, tbDir);
    }
    
    if (instance_exists(oMecha_puppet) && !instance_exists(oCamera_focus))
    {
        tbDis = point_distance(oPlr.x, oPlr.y, oMecha_puppet.x, oMecha_puppet.y);
        tbDir = point_direction(oPlr.x, oPlr.y, oMecha_puppet.x, oMecha_puppet.y);
        plrx = oPlr.x + lengthdir_x(tbDis * 0.4, tbDir);
        plry = oPlr.y + lengthdir_y(tbDis * 0.4, tbDir);
    }
    
    if (instance_exists(oNul_boss_object) && !instance_exists(oCamera_focus))
    {
        if (oNul_boss_object.y == oNul_boss_object.hurtY && oPlr.ground_under == 0)
            plry = oPlr.y - 64;
        
        if (oNul_boss_object.y > oNul_boss_object.hurtY)
            plrx = lerp(oPlr.x, oNul_boss_object.x, 0.3);
    }
}

rCam = -1;

if (collision_point(plrx, plry, oCamera_trigger, true, true))
{
    camTr = collision_point(plrx, plry, oCamera_trigger, true, true);
    cameraxMax = (camTr.x + (camTr.image_xscale * sprite_get_width(camTr.sprite_index))) - vw;
    camerayMax = (camTr.y + (camTr.image_yscale * sprite_get_height(camTr.sprite_index))) - vh;
    cameraxMin = camTr.x;
    camerayMin = camTr.y;
    camXFix = 0;
    camYFix = 0;
    camHLevel = 0;
    
    if (camTr.sprite_index == sCamera_xfix)
        camXFix = 1;
    
    if (camTr.sprite_index == sCamera_xfix)
        camFix_xpos = camTr.x + (sprite_get_width(camTr.sprite_index) / 2);
    
    if (camTr.sprite_index == sCamera_yfix)
        camYFix = 1;
    
    if (camTr.sprite_index == sCamera_yfix)
        camFix_ypos = camTr.y + (sprite_get_width(camTr.sprite_index) / 2);
}

if (collision_point(plrx, plry, oCamera_snap_parent, true, true))
{
    if (collision_point(plrx, plry, oCamera_snap_left, true, true))
        cameraxMin = collision_point(plrx, plry, oCamera_snap_left, true, true).x;
    
    if (collision_point(plrx, plry, oCamera_snap_up, true, true))
        camerayMin = collision_point(plrx, plry, oCamera_snap_up, true, true).y;
    
    if (collision_point(plrx, plry, oCamera_snap_right, true, true))
    {
        oCSR = collision_point(plrx, plry, oCamera_snap_right, true, true);
        cameraxMax = (oCSR.x + (oCSR.image_xscale * sprite_get_width(oCSR.sprite_index))) - vw;
    }
    
    if (collision_point(plrx, plry, oCamera_snap_down, true, true))
    {
        oCSD = collision_point(plrx, plry, oCamera_snap_down, true, true);
        camerayMax = (oCSD.y + (oCSD.image_yscale * sprite_get_height(oCSD.sprite_index))) - vh;
    }
}

if (collision_point(plrx, plry, oCamera_reset, true, true))
{
    cameraxMax = room_width;
    camerayMax = room_height;
    cameraxMin = 0;
    camerayMin = 0;
}

if (collision_point(plrx, plry, oCamera_reset_snap_parent, true, true))
{
    if (cameraxMin != 0 && collision_point(plrx, plry, oCamera_reset_snap_left, true, true))
        cameraxMin = 0;
    
    if (camerayMin != 0 && collision_point(plrx, plry, oCamera_reset_snap_up, true, true))
        camerayMin = 0;
    
    if (cameraxMax != room_width && collision_point(plrx, plry, oCamera_reset_snap_right, true, true))
        cameraxMax = room_width;
    
    if (camerayMax != room_height && collision_point(plrx, plry, oCamera_reset_snap_down, true, true))
        camerayMax = room_height;
}

if (camXFix == 1 && collision_point(plrx, plry, oCamera_cap, true, true))
    camXFix = 0;

if (camYFix == 1 && collision_point(plrx, plry, oCamera_cap, true, true))
    camYFix = 0;

if (camXFix == 1 && collision_point(plrx, plry, oCamera_snap_parent, true, true))
    camXFix = 0;

if (camYFix == 1 && collision_point(plrx, plry, oCamera_snap_parent, true, true))
    camYFix = 0;

if (camXFix == 0 && storyControl == 0)
    cameraxTarget = (plrx - (vw / 2)) + camXOffset;

if (camYFix == 0 && storyControl == 0 && camHLevel == 0)
    camerayTarget = plry - (vh / 2) - camOffset;

if (camXFix == 1)
    cameraxTarget = camFix_xpos;

if (camYFix == 1)
    camerayTarget = camFix_ypos;

if (camHLevel == 1)
    camerayTarget = camTr.y - hlvlCamOffset;

camObj[0] = 612;

for (i = 0; i < 1; i += 1)
{
    if (collision_point(plrx, plry, camObj[i], true, true))
    {
        camPoint = collision_point(plrx, plry, camObj[i], true, true);
        cameraxTarget = camPoint.x - (vw / 2);
        camerayTarget = camPoint.y - (vh / 2);
    }
}

if (instance_exists(oGoal_bell) && oGoal_bell.active == 1 && room != test_room_objects)
{
    cameraxTarget = oGoal_bell.x - (vw / 2);
    camerayTarget = oGoal_bell.y - (vh / 2);
}

if (instance_exists(oTutorial_chest) && instance_exists(oPlr))
{
    otc = collision_circle(oPlr.x, oPlr.y, 64, oTutorial_chest, true, true);
    
    if (otc != noone && otc.active == 0)
    {
        cameraxTarget = otc.x - (vw / 2);
        camerayTarget = (otc.y - (vh / 2)) + 100;
    }
}

if (instance_exists(oCamera_focus))
{
    cameraxTarget = oCamera_focus.x - (vw / 2);
    camerayTarget = oCamera_focus.y - (vh / 2) - camOffset;
}

if (instance_exists(oDragon_toni_plane) && oDragon_toni_plane.moving == 1)
{
    cameraxMax = room_width;
    camerayMax = room_height;
    cameraxMin = 0;
    camerayMin = 0;
}

cameraxTarget = clamp(cameraxTarget, cameraxMin, cameraxMax);
camerayTarget = clamp(camerayTarget, camerayMin, camerayMax);
camdis = point_distance(camerax, cameray, cameraxTarget, camerayTarget);
camdir = point_direction(camerax, cameray, cameraxTarget, camerayTarget);

if (camdis >= 100)
    camSpd = camdis / 64;

if (camdis < 100)
    camSpd = camdis / 2;

camerax += lengthdir_x(camdis / 4, camdir);
cameray += lengthdir_y(camdis / 4, camdir);
cameraxFinal = camerax;
camerayFinal = cameray;

if (global.screenshake_option == 1)
{
    cameraxFinal += global.screenshakeX;
    camerayFinal += global.screenshakeY;
}

cameraxFinal = clamp(cameraxFinal, 0, room_width - camera_get_view_width(view_camera));
camerayFinal = clamp(camerayFinal, 0, room_height - camera_get_view_height(view_camera));

if (introTimer <= 1)
    camera_set_view_pos(view_camera, cameraxFinal, camerayFinal);

if (introSkipDelay > 0)
    introSkipDelay -= 1;

if (introSkipDelay == 0 && introTimer > 1)
{
    if ((global.confirm_press || global.back_press) && introTimer > round(introMax * 0.25))
        introTimer = round(introMax * 0.25);
}

if (camTimer > 0)
    camTimer -= 1;

if (introTimer > 1)
{
    introTimer -= 1;
    
    if (instance_exists(oPlr))
    {
        global.controls_active = 0;
        global.drawHUD = 0;
        oPlr.yspeed = 0;
        oPlr.x = pstartx;
        oPlr.y = pstarty;
    }
    
    oMusic.SetMusicBlock(true);
    camera_set_view_pos(view_camera, introcamX, introcamY);
    
    if (instance_exists(oCamera_parent_intro1) || camTimer >= (introMax * 0.5))
    {
        camRatio = 1 - (camTimer / introMax);
        camDis = camRatio * introDistance;
        introcamX = oCamera_parent_intro1.x + lengthdir_x(camDis, introDir[0]);
        introcamY = oCamera_parent_intro1.y + lengthdir_y(camDis, introDir[0]);
    }
    
    if (instance_exists(oCamera_parent_intro2) && camTimer <= (introMax * 0.5))
    {
        camRatio = 1 - (camTimer / introMax);
        camDis = camRatio * introDistance;
        introcamX = oCamera_parent_intro2.x + lengthdir_x(camDis, introDir[1]);
        introcamY = oCamera_parent_intro2.y + lengthdir_y(camDis, introDir[1]);
        
        if (camTimer == (introMax * 0.5))
            oAudioSystem.SwapListener(introcamX, introcamY);
    }
    
    if (introTimer == 1)
    {
        oAudioSystem.SwapListener(plrx, plry);
        oMusic.SetMusicBlock(false);
    }
}

if (circleDraw[2] == circleMax)
{
    global.controls_active = 1;
    global.drawHUD = 1;
    introTimer = 0;
}

lastRCam = rCam;
