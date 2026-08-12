depth = -100;

if (no_wall_slide == 0)
    depth = -350;

if (state == "grapple")
    depth = -350;

if (barkDelay > 0)
    barkDelay -= 1;

ground_under = 0;

if (place_meeting(x, y + 1, oSolid))
    ground_under = 1;

if ((place_meeting(x, y + 1, oCloud_platform) && yspeed >= 0) && !place_meeting(x, y, oCloud_platform))
    ground_under = 1;

if (ground_under == 1 && room != boss_3_Face)
{
    lastExcept = 0;
    
    if (instance_exists(oCrumble_block1) && collision_circle(x, y, 32, oCrumble_block1, true, true))
        lastExcept = 1;
    
    if (instance_exists(oOneWay) && collision_circle(x, y, 32, oOneWay, true, true))
        lastExcept = 1;
    
    if (instance_exists(oSpike_emerge1) && collision_circle(x, y, 32, oSpike_emerge1, true, true))
        lastExcept = 1;
    
    if (instance_exists(oFireball_cannon_right) && collision_circle(x, y, 32, oFireball_cannon_right, true, true))
        lastExcept = 1;
    
    if (instance_exists(oSolid_countdown) && collision_circle(x, y, 32, oSolid_countdown, true, true))
        lastExcept = 1;
    
    if (instance_exists(oMove_grapple) && collision_circle(x, y, 32, oMove_grapple, true, true))
        lastExcept = 1;
    
    if (instance_exists(oMove_solid) && collision_circle(x, y, 32, oMove_solid, true, true))
        lastExcept = 1;
    
    if (instance_exists(oSeeing_parent) && collision_circle(x, y, 32, oSeeing_parent, true, true))
        lastExcept = 1;
    
    if (instance_exists(oMove_grapple) && collision_circle(x, y, 32, oMove_grapple, true, true))
        lastExcept = 1;
    
    if (instance_exists(oPatrol_grapple_horizontal) && collision_circle(x, y, 32, oPatrol_grapple_horizontal, true, true))
        lastExcept = 1;
    
    if (instance_exists(oPatrol_grapple_vertical) && collision_circle(x, y, 32, oPatrol_grapple_vertical, true, true))
        lastExcept = 1;
    
    if (instance_exists(oSpike) && collision_circle(x, y, 16, oSpike, true, true))
        lastExcept = 1;
    
    if (room == boss_3_Face)
        lastExcept = 1;
    
    lastSolidCheck = 0;
    lastSolidXDis = 40;
    
    if (collision_point(x - lastSolidXDis, y + 12, oSolid, true, true))
        lastSolidCheck += 1;
    
    if (collision_point(x, y + 12, oSolid, true, true))
        lastSolidCheck += 1;
    
    if (collision_point(x + lastSolidXDis, y + 12, oSolid, true, true))
        lastSolidCheck += 1;
    
    if (collision_point(x - lastSolidXDis, y + 12, oCloud_platform, true, true))
        lastSolidCheck += 1;
    
    if (collision_point(x, y + 12, oCloud_platform, true, true))
        lastSolidCheck += 1;
    
    if (collision_point(x + lastSolidXDis, y + 12, oCloud_platform, true, true))
        lastSolidCheck += 1;
    
    if (lastExcept == 0 && lastSolidCheck >= 3)
    {
        lastSolidX = x;
        lastSolidY = y;
    }
}

if (state == "incannon" && instance_exists(oCannon_parent))
{
    ocp = instance_place(x, y, oCannon_parent);
    if (ocp != noone)
    {
        lastSolidX = ocp.x;
        lastSolidY = ocp.y + 8;
    }
}

if (instance_exists(oWater_circle))
{
    wc = instance_place(x, y, oWater_circle);
    if (wc != noone)
    {
        lastSolidX = round(wc.centerX);
        lastSolidY = round(wc.centerY);
    }
}

in_water = 0;

if (collision_point(x, y, oWater, true, true))
    in_water = 1;

climb_wall = 0;

if (wall_slide_left && collision_point(x - 9, y, oClimb_wall, true, true) && jump_delay == 0)
    climb_wall = 1;

if (wall_slide_right && collision_point(x + 9, y, oClimb_wall, true, true) && jump_delay == 0)
    climb_wall = 1;

conveyor_wall = 0;

if (wall_slide_left && collision_point(x - 9, y, oConveyor_up, true, true) && jump_delay == 0)
    conveyor_wall = 1;

if (wall_slide_right && collision_point(x + 9, y, oConveyor_up, true, true) && jump_delay == 0)
    conveyor_wall = 1;

climbSlideSoundSpeed = 0;
meetWind = 0;

if (instance_exists(oWind) && place_meeting(x, y, oWind))
    meetWind = 1;

meetSpike = 0;

if (instance_exists(oSpike) && place_meeting(x, y, oSpike))
    meetSpike = 1;

if (state == "normal")
{
    runintoWall = 0;
    
    if (global.left_check && place_meeting(x - 1, y, oSolid))
        runintoWall = 1;
    
    if (global.right_check && place_meeting(x + 1, y, oSolid))
        runintoWall = 1;
    
    if (((!global.left_check && !global.right_check) || runintoWall == 1) && runFastNoPress > 0 && slamRunFast == 0)
        runFastNoPress -= 1;
    
    if ((global.left_check || global.right_check) && runintoWall == 0)
        runFastNoPress = runFastNoPressMax;
    
    if (no_wall_slide == 0)
        runFastNoPress = runFastNoPressMax;
}

if (runFastAlarm > 0)
    runEffectDo = 0;

if (state == "grapple")
{
    runFastNoPress = runFastNoPressMax;
    rfaRopeAngle = 45;
    
    if ((!global.left_check && !global.right_check) && is_between(ropeAngle, 270 - rfaRopeAngle, 270 + rfaRopeAngle) && abs(xspeed) < 0.5)
        runFastAlarm = runFastAlarmMax;
    
    if ((global.left_check || global.right_check) && !is_between(ropeAngle, 270 - rfaRopeAngle, 270 + rfaRopeAngle) && abs(xspeed) > 3)
        runFastAlarm = 0;
}

if (state == "normal" && !instance_exists(oTransition))
{
    if (ground_under == 1 && (global.left_check || global.right_check) && runFastAlarm > 0 && runintoWall == 0 && meetSpike == 0 && global.canRun)
        runFastAlarm -= 1;
    
    if (runFastAlarm == 0 && runEffectDo == 0 && ground_under == 1 && global.controls_active)
    {
        if (runFastAlarm == 0 && xspeed > 0)
            effect_create_control(x - 28, y + 6, 191, 0.2, 1, 1, 0, 16777215, 1, 0, 0, 0);
        
        if (runFastAlarm == 0 && xspeed < 0)
            effect_create_control(x + 28, y + 6, 193, 0.2, 1, 1, 0, 16777215, 1, 0, 0, 0);
        
        if (runFastAlarm == 0)
        {
            gamepad_vibrate(0.1, 10);
            global.screenshake = 2;
            oAudioSystem.PlayOneShot3D(boostSoundPath, x, y);
        }
        
        runEffectDo = 1;
    }
    
    if (ground_under == 1 && runFastNoPress == 0 && no_wall_slide == 1 && slam == 0)
        runFastAlarm = runFastAlarmMax;
}

if (state == "grapple" && runFastNoPress == 0)
    runFastAlarm = runFastAlarmMax;

stateControl = 1;

if (state == "zipline")
    stateControl = 0;

if (state == "cannon")
    stateControl = 0;

if (state == "ceiling_climb")
    stateControl = 0;

if (air_control_alarm > 0)
    air_control_alarm -= 1;

if (jumpBuffer > 0)
    jumpBuffer -= 1;

if (global.jump_press && ground_under == 0 && state != "grapple" && state != "swim")
    jumpBuffer = jumpBufferMax;

if (state != "grapple")
    grappleJumpDelay = 5;

if (slamSquash > 0)
    slamSquash -= 1;

if (slamWait > 0)
    slamWait -= 1;

if (slamRunFast > 0)
    slamRunFast -= 1;

if (state != "normal" && state != "grapple")
    slam = 0;

if (((global.slam_press || global.jump_press) && slamWait == 0) && slam == 1)
{
    slam = 0;
    
    if (animDirection == 1)
        hitSpin = -30;
    
    if (animDirection == -1)
        hitSpin = 30;
}

canSlam = 1;

if (state != "grapple" && state != "normal")
    canSlam = 0;

if (no_wall_slide == 0)
    canSlam = 0;

if (state != "grapple" && jump_delay > 0)
    canSlam = 0;

if (ground_under == 1)
    canSlam = 0;

if (slamWait > 0)
    canSlam = 0;

if (ground_under == 0 && state == "normal" && collision_line(x, y, x, y + 12, oSolid, true, true))
    canSlam = 0;

if (visible == 0)
    canSlam = 0;

if (global.slam_press && canSlam == 1)
{
    if (state == "grapple")
        state = "normal";
    
    if (instance_exists(oHook))
    {
        with (oHook)
        {
            active = 0;
            plr_return = 1;
        }
    }
    
    slam_delay = 6;
    slam = 1;
    slamWait = 15;
    slamRunFast = 60;
    oAudioSystem.PlayOneShot3D(slamSoundPath, x, y);
}

if (slamWait > 0)
    jumpCanCancel = 0;

if (slam_delay > 0)
    slam_delay -= 1;

if (slam_delay == 1)
{
    rang = 45 + random_range(-10, 10);
    
    for (i = 0; i < 4; i += 1)
    {
        slampuffAngle = (90 * i) + rang;
        slampuffX = x + lengthdir_x(24, slampuffAngle);
        slampuffY = y + lengthdir_y(24, slampuffAngle);
        effect_create_control(slampuffX, slampuffY, random_puff(), 0.4, 1, 1, 0, 16777215, 1, 0, 0, 0);
    }
    
    oAudioSystem.PlayOneShot3D(slamZoomSoundPath, x, y);
}

if (ground_under == 1 && slam == 1)
{
    move_contact_all(270, 0);
    
    if (!global.right_check && !global.left_check)
        player_bounce(-5);
    else
        player_bounce(-4);
    
    oAudioSystem.PlayOneShotWithSurfaceDown3D(slamHitSoundPath, x, y);
    jumpCanCancel = 0;
    
    if (!global.right_check)
        effect_create_control(x + 20, y + 6, 193, 0.3, 1, 1, 0, 16777215, 1, 0, 0, 0);
    
    if (!global.left_check)
        effect_create_control(x - 20, y + 6, 191, 0.3, 1, 1, 0, 16777215, 1, 0, 0, 0);
    
    gamepad_vibrate(0.2, 20);
    global.screenshake = 3;
    global.playerHasSlammed = 3;
    slam = 0;
}

if (grappleDelay > 0)
    grappleDelay -= 1;

if (!instance_exists(oHook) && (state == "normal" || state == "swim"))
{
    hook_dis = 0;
    grapple_dir = 90;
    
    if (hookDelay > 0)
        hookDelay -= 1;
    
    if (global.left_check)
        grapple_dir = 135;
    
    if (global.right_check)
        grapple_dir = 45;
}

if (global.grapple_press && hookDelay == 0 && global.player_die == 0 && state == "normal" && global.canGrapple && slam_delay == 0)
{
    if (instance_exists(oHook))
        instance_destroy(oHook);
    
    oAudioSystem.PlayOneShot3D(grappleShootSoundPath, x, y);
    grapple = instance_create_depth(x, y, depth + 1, oHook);
    grapple.x = x;
    grapple.y = y;
    hook_dis = 8;
    hookDelay = 3;
    hookAngle = 0;
    
    if (global.left_check)
        hookAngle = 45;
    
    if (global.right_check)
        hookAngle = -45;
    
    if (slam == 1)
        slam = 0;
    
    if (ground_under == 1 && isPoint == 1 && hookAngle != 0)
    {
        y = ceil(y);
        yspeed = -6;
        jump_delay = 5;
        jumpAir = 0;
        jumpBuffer = 0;
    }
}

if (instance_exists(oHook) && oHook.active == 0 && oHook.plr_return == 0 && state != "zip")
{
    if (zipTarget == -1)
    {
        hook_dis += hook_speed;
        hook_dis_ease = ease_out_quad(hook_dis, 0, 128, 128);
        grapple.x = x + lengthdir_x(hook_dis_ease, grapple_dir);
        grapple.y = y + lengthdir_y(hook_dis_ease, grapple_dir);
        grapple.image_angle = grapple_dir;
    }
    
    if (zipTarget != -1 && instance_exists(zipTarget))
    {
        zipHookDir = point_direction(grapple.x, grapple.y, zipTarget.x, zipTarget.y);
        zipHookDis = point_distance(grapple.x, grapple.y, zipTarget.x, zipTarget.y);
        zipHookSpd = clamp(zipHookDis / 5, 1, 100);
        grapple.x += lengthdir_x(zipHookSpd, zipHookDir);
        grapple.y += lengthdir_y(zipHookSpd, zipHookDir);
        grapple.image_angle = zipHookDir;
        jump_draw = 1;
    }
}

hook_pause = 0;

if (instance_exists(oHook) && state == "normal" && oHook.plr_return == 0)
    hook_pause = 1;

if (state == "normal" || (state == "swim" && !instance_exists(oHook)))
    grapEffect = 0;

if (instance_exists(oHook) && oHook.active == 1 && grapEffect == 0)
{
    effect_create_control(oHook.x, oHook.y, 929, 0.6, 1, 1, 0, 16777215, 1, 0, 0, 0);
    isSolidGrapple = collision_circle(oHook.x, oHook.y, 4, oSolid_grapple, true, true);
    
    if (isSolidGrapple)
        debris_speed(729, round(random_range(3, 6)), oHook.x, oHook.y, 2, 2, 2, 4);
    
    gamepad_vibrate(0.1, 10);
    instance_create_depth(oHook.x, oHook.y, 10, oHook_wave);
    oAudioSystem.PlayOneShotWithParam3D(grappleConnectSoundPath, grappleSolidSoundParam, isSolidGrapple, x, y);
    grappleX = oHook.x;
    grappleY = oHook.y;
    ropeX = x;
    ropeY = y;
    ropeAngleVelocity = xspeed / 2;
    
    if (hookAngle == 45)
        grappleBoost = -0.6;
    
    if (hookAngle == -45)
        grappleBoost = 0.6;
    
    if (slam == 1)
    {
        if (hookAngle == 45)
            grappleBoost = -2;
        
        if (hookAngle == -45)
            grappleBoost = 2;
    }
    
    ropeAngle = point_direction(grappleX, grappleY, x, y);
    ropeLength = round(point_distance(grappleX, grappleY, x, y));
    ropeLengthTarget = ropeLength;
    
    if (place_meeting(x, y + 1, oSolid) && grapple_dir != 90)
        ropeLengthTarget = ropeLength - 32;
    
    if (oHook.inWater == 0)
        state = "grapple";
    
    grappleJustPressed = 1;
    grapEffect = 1;
}

switch (state)
{
    case "normal":
        if (jump_delay > 0)
            jump_delay -= 1;
        
        if (air_control_alarm == 0 && hook_pause == 0 && global.player_die == 0)
        {
            speedLimit = 2;
            
            if (runFastAlarm == 0)
                speedLimit = 2.5;
            
            if (meetSpike == 1)
                speedLimit = 1;
            
            if (in_water == 1)
                speedLimit *= 0.8;
            
            if (ground_under == 1)
            {
                if (runFastAlarm == 0)
                {
                    xchange_spd = 0.3;
                    
                    if (skid > 0)
                        xchange_spd = 0.4;
                }
                
                if (runFastAlarm != 0)
                    xchange_spd = 0.4;
                
                if (!global.left_check && !global.right_check)
                {
                    if (is_between(xspeed, -speedLimit, speedLimit))
                        xspeed = difference(xspeed, 0, xchange_spd / 2);
                    
                    if (!is_between(xspeed, -speedLimit, speedLimit) || xspeed == abs(speedLimit))
                        xspeed = difference(xspeed, 0, xchange_spd);
                }
                
                if (abs(xspeed) <= speedLimit)
                {
                    if (global.left_check && !place_meeting(x - 1, y, oSolid))
                        xspeed = difference(xspeed, -speedLimit, xchange_spd);
                    
                    if (global.right_check && !place_meeting(x + 1, y, oSolid))
                        xspeed = difference(xspeed, speedLimit, xchange_spd);
                }
                
                if (abs(xspeed) > speedLimit)
                    xspeed = difference(xspeed, 0, 0.15);
                
                if (place_meeting(x + xspeed, y, oSolid))
                    xspeed = 0;
                
                xspeed = round(xspeed * 10000) / 10000;
            }
            
            wallSlideMoveMax = 15;
            
            if (no_wall_slide == 1)
                wallSlideMove = 0;
            
            if (no_wall_slide == 0 && wallSlideMove == 0)
                wallSlideMove = wallSlideMoveMax;
            
            if (no_wall_slide == 0 && wallSlideMove > 0 && (!global.left_check && !global.right_check))
                wallSlideMove = wallSlideMoveMax;
            
            if (wall_slide_left && global.right_check && wallSlideMove > 0)
                wallSlideMove -= 1;
            
            if (wall_slide_right && global.left_check && wallSlideMove > 0)
                wallSlideMove -= 1;
            
            if (ground_under == 0 && wallSlideMove == 0 && slam == 0)
            {
                if (is_between(xspeed, -2, 2))
                    xchange_spd = 1;
                else
                    xchange_spd = 0.04;
                
                if (meetWind == 1)
                {
                    if (!global.left_check && !global.right_check)
                        xspeed = difference(xspeed, 0, 0.05);
                    
                    if (global.left_check)
                        xspeed = difference(xspeed, -2.5, 0.2);
                    
                    if (global.right_check)
                        xspeed = difference(xspeed, 2.5, 0.2);
                }
                
                if (meetWind == 0)
                {
                    if (!global.left_check && !global.right_check)
                    {
                        if (xspeed < -2)
                            xspeed = difference(xspeed, -speedLimit, xchange_spd);
                        
                        if (xspeed > 2)
                            xspeed = difference(xspeed, speedLimit, xchange_spd);
                    }
                    
                    if (xspeed > 0 && global.left_check)
                        xchange_spd = 0.15;
                    
                    if (xspeed < 0 && global.right_check)
                        xchange_spd = 0.15;
                    
                    if (in_water == 1)
                        xchange_spd = 0.075;
                    
                    if (global.left_check)
                        xspeed = difference(xspeed, -speedLimit, xchange_spd);
                    
                    if (global.right_check)
                        xspeed = difference(xspeed, speedLimit, xchange_spd);
                }
                
                if (place_meeting(x + xspeed, y, oSolid))
                    xspeed = 0;
            }
            
            if (abs(xspeed) < 1 && !global.left_press && !global.right_press)
                xspeed = difference(xspeed, 0, 0.01);
        }
        
        if (ground_under == 1)
            jumpAir = jumpAirMax;
        
        if (ground_under == 1)
            jumpCanCancel = 1;
        
        if (ground_under == 0 && jumpAir > 0)
            jumpAir -= 1;
        
        jumpTrigger = 0;
        
        if (jump_delay == 0 && !place_meeting(x, y - 1, oSolid) && global.player_die == 0)
        {
            if (global.jump_press && jumpAir > 0)
                jumpTrigger = 1;
            
            if (global.jump_press && jumpAir < 6 && ground_under == 1)
                jumpTrigger = 1;
            
            if (jumpBuffer > 0 && ground_under == 1)
                jumpTrigger = 1;
            
            if (global.jump_press && global.infinitejump_option == 1 && ground_under == 0 && no_wall_slide == 1 && !instance_exists(oHook))
            {
                view_variables();
                
                if (y > vy && x > vx && y < (vy + vh) && x < (vx + vw))
                    jumpTrigger = 1;
            }
        }
        
        if (jumpTrigger == 1)
        {
            y = ceil(y);
            yspeed = -5.5;
            xspeed += movePlatformXspeed;
            
            if (movePlatformYspeed < 0)
                yspeed += movePlatformYspeed;
            
            oAudioSystem.PlayOneShotWithParam3D(jumpSoundPath, speedAudioParam, xspeed / 2.5, x, y);
            effect_create_control(x + 12, y + 4, random_puff(), 0.4, 1, 1, 0, 16777215, 1, 0, 0.2, 0);
            effect_create_control(x - 12, y + 4, random_puff(), 0.4, 1, 1, 0, 16777215, 1, 180, 0.2, 0);
            jumpLineDir = point_direction(x, y, x + (xspeed * 2), y + yspeed);
            effect_create_control(x, y, 881, 0.5, 1, 1, jumpLineDir, 16777215, 1, jumpLineDir, 0.2, 0);
            jump_delay = 5;
            jumpAir = 0;
            jumpBuffer = 0;
        }
        
        if (ground_under == 0 && yspeed < -2 && !global.jump_check && jumpCanCancel == 1 && air_control_alarm == 0)
        {
            yspeed *= 0.6;
            jumpCanCancel = 0;
        }
        
        if (slam == 1)
        {
            xspeed = 0;
            
            if (global.left_check)
                xspeed = -0.25;
            
            if (global.right_check)
                xspeed = 0.25;
            
            yspeed = 0;
        }
        
        if (slam == 1 && slam_delay == 0)
        {
            xspeed = 0;
            
            if (meetWind == 1)
                yspeed = 3;
            
            if (meetWind == 0)
                yspeed = 7;
            
            jumpBuffer = 0;
            jump_delay = 5;
        }
        
        if (no_wall_slide == 0 && climb_wall == 0)
        {
            if (slam == 1)
                slam = 0;
            
            if (conveyor_wall == 0)
                yspeed = difference(yspeed, 1, 0.25);
            
            if (conveyor_wall == 1)
                yspeed = difference(yspeed, -1, 0.5);
            
            if (global.slam_press && yspeed <= 1)
            {
                yspeed += 6;
                oAudioSystem.PlayOneShot3D(slideSlamSoundPath, x, y);
                mainSound.setParameterById(slideSlamAudioParamID, 1);
            }
        }
        
        if (no_wall_slide == 1)
        {
            change_spd = 0.25;
            
            if (ground_under == 0 && slam == 0)
            {
                if (meetWind == 1)
                {
                    if (!global.up_check && !global.down_check)
                        yspeed = difference(yspeed, -1.5, change_spd);
                    
                    if (global.up_check)
                        yspeed = difference(yspeed, -3, change_spd);
                    
                    if (global.down_check)
                        yspeed = difference(yspeed, -0.5, change_spd);
                }
                
                if (meetWind == 0)
                    yspeed = difference(yspeed, 4, change_spd);
            }
            
            if (ground_under == 1 && yspeed > 0)
                yspeed = 0;
            
            if (hook_pause == 1 && yspeed > 0)
                yspeed = clamp(yspeed, -4, 1.5);
        }
        
        if (meetWind == 1 && ground_under == 1)
            yspeed = -1;
        
        if (climb_wall == 1)
        {
            if (!global.up_check && !global.down_check)
            {
                yspd_change = 0.2;
                
                if (yspeed > 1)
                    yspd_change = 0.4;
                
                yspeed = difference(yspeed, 0, yspd_change);
                
                if (yspeed == 0)
                    y = difference(y, round(y / 4) * 4, 2);
            }
            
            if (global.up_check)
            {
                if (yspeed <= 1)
                    yspeed = difference(yspeed, -1.75, 0.1);
                
                if (yspeed > 1)
                    yspeed = difference(yspeed, -1.75, 0.3);
            }
            
            if (global.down_check)
            {
                yspeed = difference(yspeed, 2.25, 0.2);
                climbSlideSoundSpeed = abs(yspeed) / 2;
            }
            
            if (global.slam_press && yspeed < 3)
            {
                yspeed += 4;
                oAudioSystem.PlayOneShotWithSurface3D(climbSlamSoundPath, x, y, animDirection * 16, 0);
            }
        }
        
        if (slam == 0)
            yspeed = clamp(yspeed, -10, 400);
        
        solid_col_line = 0;
        
        if (collision_line(x - 9, y, x + 9, y, oSolid, true, true))
            solid_col_line = 1;
        
        no_wall_slide = 0;
        wall_slide_left = 0;
        wall_slide_right = 0;
        
        if (ground_under == 0 && place_meeting(x + 1, y, oSolid) && !place_meeting(x + 1, y, oSolid_noWS) && meetSpike == 0 && meetWind == 0 && solid_col_line == 1)
            wall_slide_right = 1;
        
        if (ground_under == 0 && place_meeting(x - 1, y, oSolid) && !place_meeting(x - 1, y, oSolid_noWS) && meetSpike == 0 && meetWind == 0 && solid_col_line == 1)
            wall_slide_left = 1;
        
        if (wall_slide_left && xspeed < 0)
            xspeed = 0;
        
        if (wall_slide_right && xspeed > 0)
            xspeed = 0;
        
        if (wall_slide_left == 0 && wall_slide_right == 0)
            no_wall_slide = 1;
        
        if ((global.jump_press && jump_delay == 0 && no_wall_slide == 0) || (jumpBuffer > 0 && no_wall_slide == 0 && jump_delay == 0))
        {
            view_variables();
            plrOnscreen = 1;
            
            if (y < (vy + 16))
                plrOnscreen = 0;
            
            if (plrOnscreen == 1)
            {
                air_control_alarm = air_control_alarm_max;
                
                if (wall_slide_right == 1)
                    xspeed -= 2;
                
                if (wall_slide_left == 1)
                    xspeed += 2;
                
                if (in_water == 0)
                    yspeed = -5;
                
                if (in_water == 1)
                    yspeed = -3;
                
                oAudioSystem.PlayOneShotWithParam3D(jumpSoundPath, speedAudioParam, xspeed / 2.5, x, y);
                
                if (wall_slide_right == 1)
                    wallPuffX = 4;
                
                if (wall_slide_left == 1)
                    wallPuffX = -4;
                
                if (wall_slide_right == 1 && movePlatformXspeed < 0)
                    xspeed += movePlatformXspeed;
                
                if (wall_slide_left == 1 && movePlatformXspeed > 0)
                    xspeed += movePlatformXspeed;
                
                if (wall_slide_right == 1)
                    wallPuffX = 4;
                
                if (wall_slide_left == 1)
                    wallPuffX = -4;
                
                effect_create_control(x + wallPuffX, y - 12, random_puff(), 0.4, 1, 1, 0, 16777215, 1, 90, 0.2, 0);
                effect_create_control(x + wallPuffX, y + 12, random_puff(), 0.4, 1, 1, 0, 16777215, 1, 270, 0.2, 0);
                jumpLineDir = point_direction(x, y, x + (xspeed * 2), y + yspeed);
                effect_create_control(x, y, 881, 0.4, 1, 1, jumpLineDir, 16777215, 1, jumpLineDir, 0.2, 0);
                jumpBuffer = 0;
                jump_delay = clamp(jump_delay, 5, 100);
            }
        }
        
        if (place_meeting(x, y + 1, oSolid))
            air_control_alarm = 0;
        
        break;
    
    case "grapple":
        if (instance_exists(oHook))
        {
            grappleX = oHook.x;
            grappleY = oHook.y;
            ropeAngleAcceleration = -0.2 * dcos(ropeAngle);
            ropeAngleAcceleration += ((global.right_check - global.left_check) * 0.09);
            ropeAngleAcceleration += grappleBoost;
            ropeAngleVelocity += ropeAngleAcceleration;
            ropeVelocityCap = 4;
            ropeAngleVelocity = clamp(ropeAngleVelocity, -ropeVelocityCap, ropeVelocityCap);
            ropeAngle += ropeAngleVelocity;
            ropeAngle += grappleBoost;
            grappleBoost = difference(grappleBoost, 0, 0.5);
            ropeVelocityDecrease = 0.99;
            
            if (!global.right_check && !global.left_check)
                ropeVelocityDecrease = 0.98;
            
            ropeAngleVelocity *= ropeVelocityDecrease;
            xspeed = difference(xspeed, ropeX - x, 1);
            yspeed = ropeY - y;
            
            if (ropeLength < ropeLengthMin)
                ropeLengthTarget = ropeLengthMin;
            
            if (ropeLength > ropeLengthMax)
                ropeLengthTarget = ropeLengthMax;
            
            grapple.image_angle = point_direction(x, y, grappleX, grappleY);
            ropeSolidAbove = 0;
            ropeSolidBelow = 0;
            
            if (collision_point(grappleX + lengthdir_x(ropeLength - 16, ropeAngle), grappleY + lengthdir_y(ropeLength - 16, ropeAngle), oSolid, true, true))
                ropeSolidAbove = 1;
            
            if (collision_point(grappleX + lengthdir_x(ropeLength + 16, ropeAngle), grappleY + lengthdir_y(ropeLength + 16, ropeAngle), oSolid, true, true))
                ropeSolidBelow = 1;
            
            if (!global.up_check && !global.down_check)
                ropeClimbDelay = ropeClimbDelayMax;
            
            if (ropeClimbDelay > 0 && (global.up_check || global.down_check))
                ropeClimbDelay -= 1;
            
            if (ropeClimbDelay == 0 && (global.up_check || global.down_check))
                ropeClimbSpd = difference(ropeClimbSpd, 2, 0.25);
            else
                ropeClimbSpd = difference(ropeClimbSpd, 0, 0.25);
            
            if (global.up_check && ropeLength <= ropeLengthMin)
                ropeClimbSpd = 0;
            
            if (global.down_check && ropeLength >= ropeLengthMax)
                ropeClimbSpd = 0;
            
            if (global.up_check && ropeLengthTarget > (ropeLengthMin - 6) && !place_meeting(x, y - 1, oSolid) && ropeSolidAbove == 0)
                ropeLengthTarget -= ropeClimbSpd;
            
            if (global.down_check && ropeLengthTarget < ropeLengthMax && !place_meeting(x, y - 1, oSolid) && ropeSolidBelow == 0)
                ropeLengthTarget += ropeClimbSpd;
            
            if (place_meeting(x, y + 2, oSolid))
            {
                ropeLength -= 2;
                ropeLengthTarget -= 2;
            }
            
            ropeLength = difference(ropeLength, ropeLengthTarget, 4);
            ropeX = grappleX + lengthdir_x(ropeLength, ropeAngle);
            ropeY = grappleY + lengthdir_y(ropeLength, ropeAngle);
            
            if (grappleJumpDelay > 0)
                grappleJumpDelay -= 1;
            
            if (global.jump_press && global.canJumpOff && grappleJumpDelay == 0)
            {
                state = "normal";
                oAudioSystem.PlayOneShotWithParam3D(grappleJumpSoundPath, speedAudioParam, xspeed / 2.5, x, y);
                yspeed -= 2.5;
                
                if (abs(ropeAngleVelocity) < 1)
                    yspeed -= 3;
                
                spdCheckAngle = abs(ropeAngle - 270);
                
                if (spdCheckAngle > yAdjustAngle)
                    yspeed -= 6;
                
                yspeed = clamp(yspeed, -7, 10);
                xspeed *= 0.95;
                jump_delay = 5;
                air_control_alarm = 12;
                
                with (grapple)
                {
                    active = 0;
                    plr_return = 1;
                }
            }
            
            slamWait = 0;
            slam_delay = 0;
        }
        
        break;
}

if (state != "zip")
{
    zipSpd = 1;
    zipPause = 3;
}

zipObj[0] = 779;
zipObj[1] = 668;
zipObj[2] = 699;
zipObj[3] = 675;

if (!instance_exists(oHook) && !place_meeting(x, y, oEnemy) && state == "normal")
{
    zipTarget = -1;
    zipMinDis = 16;
    zipMaxDis = 128;
    zipDir = grapple_dir;
    zipRange = 24;
    
    for (h = 0; h < 4; h += 1)
    {
        if (instance_exists(zipObj[h]))
        {
            if (collision_circle(x, y, zipMaxDis, zipObj[h], true, true) != noone)
            {
                i = -(zipRange / 3);
                
                while (i < (zipRange / 3))
                {
                    zipHit = collision_line(x, y, x + lengthdir_x(zipMaxDis, zipDir + (i * 3)), y + lengthdir_y(zipMaxDis, zipDir + (i * 3)), zipObj[h], true, true);
                    
                    if (zipHit != noone)
                    {
                        zipTarget = zipHit;
                        
                        if (zipTarget != -1 && zipTarget.canZip == 0)
                            zipTarget = -1;
                        
                        if (zipTarget != -1 && zipTarget.y > y)
                            zipTarget = -1;
                        
                        if (zipTarget != -1 && point_distance(x, y, zipTarget.x, zipTarget.y) < zipMinDis)
                            zipTarget = -1;
                        
                        if (zipTarget != -1 && collision_line(x, y, zipTarget.x, zipTarget.y, oSolid, true, true))
                            zipTarget = -1;
                    }
                    
                    i += 1;
                }
            }
        }
    }
}

if (zipTarget != -1 && instance_exists(zipTarget) && instance_exists(oHook) && state == "normal")
{
    if (collision_circle(oHook.x, oHook.y, 16, zipTarget, true, true))
    {
        oHook.x = zipTarget.x;
        oHook.y = zipTarget.y;
        effect_create_control(oHook.x, oHook.y, 890, 0.1, 1, 1, 0, 16777215, 1, 0, 0, 0);
        gamepad_vibrate(0.2, 10);
        oAudioSystem.PlayOneShot3D(grappleZipSoundPath, x, y);
        state = "zip";
    }
}

if (state == "zip")
{
    if (zipTarget != -1 && instance_exists(zipTarget))
    {
        zipX = zipTarget.x;
        zipY = zipTarget.y;
    }
    
    hitStun = 2;
    xspeed = 0;
    yspeed = 0;
    zipDir = point_direction(x, y, zipX, zipY);
    zipDis = point_distance(x, y, zipX, zipY);
    
    if (zipPause > 0)
        zipPause -= 1;
    
    if (zipPause == 0)
    {
        zipSpd = difference(zipSpd, 8, 0.5);
        x += lengthdir_x(zipSpd, zipDir);
        y += lengthdir_y(zipSpd, zipDir);
    }
    
    if (instance_exists(oHook))
    {
        oHook.x = zipX;
        oHook.y = zipY;
    }
    
    if (!instance_exists(zipTarget))
    {
        state = "normal";
        
        if (instance_exists(oHook))
            instance_destroy(oHook);
    }
    
    if (zipDis < 8)
    {
        x = zipX;
        y = zipY - 1;
        
        if (instance_exists(oHook))
        {
            with (oHook)
                instance_destroy();
        }
        
        state = "normal";
        
        if (place_meeting(x, y, oSolid))
            move_contact_solid(270, 0);
        
        if (place_meeting(x, y, oSolid))
        {
            if (collision_point(x + 7, y, oSolid, true, true))
                x -= 2;
            
            if (collision_point(x - 7, y, oSolid, true, true))
                x += 2;
        }
    }
}

if (throwDraw == 1 && instance_exists(oHook) && oHook.x == oHook.xprevious && oHook.y == oHook.yprevious)
{
    anything = 0;
    
    if (collision_circle(oHook.x, oHook.y, 6, oGrapple_point, true, true))
        anything = 1;
    
    if (collision_circle(oHook.x, oHook.y, 6, oSolid_grapple, true, true))
        anything = 1;
    
    if (collision_circle(oHook.x, oHook.y, 6, oEnemy, true, true))
        anything = 1;
    
    if (collision_circle(oHook.x, oHook.y, 6, oBalloon_blue, true, true))
        anything = 1;
    
    if (collision_circle(oHook.x, oHook.y, 6, oBomb, true, true))
        anything = 1;
    
    if (collision_circle(oHook.x, oHook.y, 6, oCannon_zip, true, true))
        anything = 1;
    
    if (anything == 0)
    {
        oHook.zipTarget = -1;
        oHook.active = 0;
        oHook.plr_return = 1;
    }
}

if (oPlr.state == "grapple" && !instance_exists(oHook))
    state = "normal";

if (in_water == 1 && state != "swim")
{
    state = "swim";
    swimDir = point_direction(x, y, x + xspeed, y + yspeed);
    swimSpd = point_distance(x, y, x + xspeed, y + (yspeed * 0.8));
    swimBoost = 0;
    swimControl = 12;
    swimSpinDraw = 0;
    swimFlipDelay = swimFlipDelayMax;
    
    if (xspeed <= 0)
    {
        swimFlipDraw = -1;
        swimFlipDir = -1;
        swimFlipImg = flipNum;
    }
    
    if (xspeed > 0)
    {
        swimFlipDraw = 1;
        swimFlipDir = 1;
        swimFlipImg = 0;
    }
    
    if (swimSpd > 2)
        swimSpd -= 0.6;
    
    if (instance_exists(oHook))
    {
        oHook.active = 0;
        oHook.plr_return = 1;
    }
}

swimSoundSpeed = 0;

if (state == "swim")
{
    jump_draw = 0;
    swimInput = 0;
    
    if (global.left_check)
        swimInput = 1;
    
    if (global.right_check)
        swimInput = 1;
    
    if (global.up_check)
        swimInput = 1;
    
    if (global.down_check)
        swimInput = 1;
    
    swimBoost = difference(swimBoost, 0, 0.1);
    
    if (global.jump_press && swimBoost == 0 && swimInput == 1 && swimSpd > 0.2 && swimSpd < 3.5)
    {
        runFastAlarm = 0;
        
        if (swimSpd < 4)
            swimBoost = 4;
        
        swimSpinDraw = swimSpinDrawMax;
        
        if (instance_exists(oHook) && oHook.active == 1)
        {
            oHook.active = 0;
            oHook.plr_return = 1;
        }
        
        if (xspeed <= 0)
        {
            swimFlipDraw = -1;
            swimFlipDir = -1;
            swimFlipImg = flipNum;
        }
        
        if (xspeed > 0)
        {
            swimFlipDraw = 1;
            swimFlipDir = 1;
            swimFlipImg = 0;
        }
        
        effect_create_control(x, y, 1484, 0.5, 1, 1, swimDir, 16777215, 1, 0, 0, 0);
    }
    
    if (global.grapple_press && instance_exists(oHook) && oHook.active == 1)
    {
        oHook.active = 0;
        oHook.plr_return = 1;
    }
    
    if (swimInput == 1 && swimSpd < 2)
        swimSpd = difference(swimSpd, 2, 0.05);
    
    if (swimInput == 0)
        swimSpd = difference(swimSpd, 0, 0.03);
    
    if (swimSpd > 2)
        swimSpd -= 0.05;
    
    stickInput = 0;
    
    if (global.leftstick_move_option == 1 && global.gpaxis_now_left_dis > 0.1)
        stickInput = 1;
    
    if (global.rightstick_move_option == 1 && global.gpaxis_now_right_dis > 0.1)
        stickInput = 1;
    
    if (stickInput == 0)
        swimDirTarget = point_direction(x, y, x + (global.right_check - global.left_check), y + (global.down_check - global.up_check));
    
    if (global.rightstick_move_option == 1 && global.gpaxis_now_right_dis > 0.1)
        swimDirTarget = global.gpaxis_now_right_dir;
    
    if (global.leftstick_move_option == 1 && global.gpaxis_now_left_dis > 0.1)
        swimDirTarget = global.gpaxis_now_left_dir;
    
    if (swimControl > 0)
        swimControl -= 1;
    
    if (swimInput == 1 && swimControl == 0)
    {
        swimTurn = abs(angle_difference(swimDir, swimDirTarget)) / 10;
        
        if (swimSpd > 3)
            swimTurn += 3;
        
        swimDir = difference_angle(swimDir, swimDirTarget, swimTurn);
        swimDir = wrap(swimDir, 0, 360);
        
        if (xspeed > 0)
            swimFlipDir = 1;
        
        if (xspeed < 0)
            swimFlipDir = -1;
    }
    
    totalSwimSpd = swimSpd + swimBoost;
    xspeed = lengthdir_x(totalSwimSpd, swimDir);
    yspeed = lengthdir_y(totalSwimSpd, swimDir);
    swimSoundSpeed = totalSwimSpd / 6;
    roundSwimDir = round(swimDir / 45);
    
    if (in_water == 0)
    {
        if (roundSwimDir == 8)
            roundSwimDir = 0;
        
        swimJump = 0;
        
        if (roundSwimDir == 2 || roundSwimDir == 1 || roundSwimDir == 3)
            swimJump = 2;
        
        if (roundSwimDir == 0)
            swimJump = 2;
        
        if (roundSwimDir == 4)
            swimJump = 2;
        
        state = "normal";
        yspeed -= swimJump;
    }
}

mainSound.setParameterById(swimAudioParamID, swimSoundSpeed);

if (place_meeting(x + xspeed, y, oSolid))
{
    spdCheckAngle = abs(ropeAngle - 270);
    
    if (state == "grapple")
    {
        ropeAngle = point_direction(grappleX, grappleY, x, y);
        ropeAngleVelocity *= 0.8;
    }
    
    if (xspeed > 0 && place_meeting(x + 1, y, oSolid))
        xspeed *= 0.9;
    
    if (xspeed < 0 && place_meeting(x - 1, y, oSolid))
        xspeed *= 0.9;
    
    if (ground_under == 0 && xspeed > 0)
        move_contact_solid(0, 0);
    
    if (ground_under == 0 && xspeed < 0)
        move_contact_solid(180, 0);
}

if (place_meeting(x, y + yspeed, oSolid) && state == "grapple")
{
    if (yspeed >= 0)
        move_contact_solid(270, 0);
    
    if (yspeed < 0)
        move_contact_solid(90, 0);
    
    yspeed *= 0.8;
    
    if (state == "grapple")
    {
        ropeAngle = point_direction(grappleX, grappleY, x, y);
        ropeAngleVelocity *= 0.8;
    }
}

if (global.player_die == 1 && yspeed < 0)
    yspeed = 1;

boostXspeed = difference(boostXspeed, 0, 0.01);

if (skid > (skidMax * 0.3))
    boostXspeed = 0;

xspeed_actual = xspeed + movePlatformXspeed + boostXspeed;
yspeed_actual = yspeed + movePlatformYspeed;

if (stateControl == 1 && !place_meeting(x + xspeed_actual, y, oSolid))
    x += xspeed_actual;

if (stateControl == 1 && !place_meeting(x, y + yspeed_actual, oSolid))
    y += yspeed_actual;

dead = 0;

if (hitStun > 0)
    hitStun -= 1;

if (place_meeting(x, y, oKill_player))
    hurt = 1;

if (state != "zip" && enHurtZip > 0)
    enHurtZip -= 1;

if (state == "zip")
    enHurtZip = 4;

if (enHurtZip == 0)
{
    enMeet = instance_place(x, y, oEnemy);
    
    if (enMeet != noone)
    {
        if (jump_draw == 0)
            hurt = 1;
        
        if (jump_draw == 1 && enMeet.canBop == 0)
            hurt = 1;
        
        if (slam == 1)
            hurt = 0;
    }
}

if (hitStun != 0)
    hurt = 0;

if (hurt == 1 && hitStun == 0)
{
    if (global.tempHP > 0)
        global.tempHP -= 1;
    else
        global.player_HP -= 1;
    
    if (global.nodamage_option == 1)
        global.player_HP = 4;
    
    global.hitstop = 12;
    global.screenshake = 8;
    gamepad_vibrate(0.2, 10);
    
    if (instance_exists(oUI_inlevel))
    {
        oUI_inlevel.HPShake = oUI_inlevel.HPShake_max;
        oUI_inlevel.HPpulse = 2;
    }
    
    if (global.player_HP > 0)
        oAudioSystem.PlayOneShot3D(hurtSoundPath, x, y);
    
    effect_create_player(x, y, 926, 3, 16777215, depth + 10);
    hitStun = hitStunMax;
    runFastAlarm = runFastAlarmMax;
    hurt = 0;
}

if (global.player_HP == 0)
    dead = 1;

if (y > room_height && global.player_die == 0)
    dead = 1;

if (collision_circle(x, y, 2, oPurple_liquid, true, true) && state != "zip" && !instance_exists(oPlr_lavapit_reset))
{
    if (global.nodamage_option == 0)
        global.player_HP -= 1;
    
    if (global.player_HP == 0)
    {
        dead = 1;
    }
    else
    {
        plpr = instance_create_depth(x, y, depth, oPlr_lavapit_reset);
        plpr.move_targetx = lastSolidX;
        plpr.move_targety = lastSolidY - 4;
    }
}

if (collision_circle(x, y, 4, oSolid, true, true) && !collision_circle(x, y, 2, oPatrol_grapple_horizontal, true, true) && state != "zip")
    dead = 1;

if (instance_exists(oDragon_toni_plane) && oDragon_toni_plane.moving == 1)
    dead = 0;

if (dead == 1)
{
    global.Deaths += 1;
    instance_create_depth(x, y, depth, oPlr_death);
    gamepad_vibrate(0.2, 10);
    oAudioSystem.PlayOneShot(deathSoundPath);
    oAudioSystem.StopAndReleaseInstance(mainSound);
    instance_destroy();
}

footstepDelay = difference(footstepDelay, 0, 1);

if (ground_under == 0)
    landSound = 1;

if (ground_under == 1)
{
    doStep = 0;
    
    if (xspeed != 0 && footstepDelay == 0 && runFastAlarm > 0 && skid == 0 && (round(animRunImg) == 1 || round(animRunImg) == 9))
        doStep = 1;
    
    if (xspeed != 0 && footstepDelay == 0 && runFastAlarm == 0 && skid == 0 && (round(animRunFastImg) == 0 || round(animRunFastImg) == 6))
        doStep = 1;
    
    if (landSound == 1)
    {
        if (visible == 1 && !instance_exists(oPlr_intro) && state == "normal")
        {
            oAudioSystem.PlayOneShotWithSurfaceDown3D(landSoundPath, x, y);
            landSound = 0;
        }
    }
    
    if (doStep == 1)
    {
        if (visible == 1 && !instance_exists(oPlr_intro) && state == "normal")
            oAudioSystem.PlayOneShotWithSurfaceDown3D(stepSoundPath, x, y);
        
        footstepDelay = 6;
    }
}

mainSound.setParameterById(climbSlideAudioParamID, climbSlideSoundSpeed);
mainSound.setParameterById(moveSpeedAudioParamID, max(abs(xspeed), abs(yspeed)) / 2.5);
oAudioSystem.SetInstancePosition(mainSound, x, y);

if (global.debugInputs == 1 && mouse_check_button_pressed(mb_right) && os_type != os_android && os_type != os_ios)
{
    x = mouse_x;
    y = mouse_y;
}
