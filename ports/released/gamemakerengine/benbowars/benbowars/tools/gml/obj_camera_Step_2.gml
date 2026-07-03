depth = -999999999999;
var cameraW = global.base_res_x * cameraZoom;
var cameraH = global.base_res_y * cameraZoom;
if (global.hitstop)
{
    global.hitstop -= 1;
}
camera_set_view_size(view_camera[0], cameraW, cameraH);
camera_set_view_angle(view_camera[0], cameraAngle);
shakex = approach(shakex, 0, shakeT);
shakey = approach(shakey, 0, shakeT);
var sX = shakex * 10 * choose(-1, 1);
var sY = shakey * 10 * choose(-1, 1);
view_set_xport(view_camera[0], sX);
view_set_yport(view_camera[0], sY);
camera_set_view_pos(view_camera[0], x - (camera_get_view_width(view_camera[0]) / 2), y - (camera_get_view_height(view_camera[0]) / 2));
var _cam_x = camera_get_view_x(view_camera[0]);
var _cam_y = camera_get_view_y(view_camera[0]);
var _cam_w = camera_get_view_width(view_camera[0]);
var _cam_h = camera_get_view_height(view_camera[0]);
if (instance_exists(follow))
{
    var N = 0;
    if (follow == obj_player)
    {
        N = 10;
        x = lerp(x, follow.x + player_offX, 0.5);
        if (abs(obj_player.hspd) >= 1)
        {
            player_offX = approach(player_offX, 15 * obj_player.facing * abs(obj_player.hspd), 1);
        }
    }
    else
    {
        x = lerp(x, follow.x, 0.5);
    }
    if (!lock_bottom)
    {
        y = lerp(y, floor(follow.y - N), 0.15);
    }
    else if (follow == obj_player)
    {
        y = lerp(y, floor(lock_bottom.y - 67.5), 0.25);
    }
}
image_xscale = cameraZoom;
image_yscale = cameraZoom;
var camW = 320;
var camH = 180;
if (cameraZoom > 0)
{
    camW *= cameraZoom;
    camH *= cameraZoom;
}
// Deactivate wallback scenery far outside the view every 10 frames. The
// instance_activate_region call below is the game's own wake-up path, so
// anything scrolling back toward the screen reactivates automatically.
cull_timer += 1;
if (cull_timer >= 10)
{
    cull_timer = 0;
    var _cl = _cam_x - 300;
    var _ct = _cam_y - 300;
    var _cr = _cam_x + _cam_w + 300;
    var _cb = _cam_y + _cam_h + 300;
    with (prop_wallback)
    {
        if (bbox_right < _cl || bbox_bottom < _ct || bbox_left > _cr || bbox_top > _cb)
            instance_deactivate_object(id);
    }
    with (prop_wallback_2)
    {
        if (bbox_right < _cl || bbox_bottom < _ct || bbox_left > _cr || bbox_top > _cb)
            instance_deactivate_object(id);
    }
    with (prop_wallback_3)
    {
        if (bbox_right < _cl || bbox_bottom < _ct || bbox_left > _cr || bbox_top > _cb)
            instance_deactivate_object(id);
    }
}
instance_activate_region(_cam_x - 16, _cam_y, _cam_w + 16, _cam_h + 48, true);
window_set_size(global.base_res_x * global.base_res_mult, global.base_res_y * global.base_res_mult);
view_set_wport(0, global.base_res_x);
view_set_hport(0, global.base_res_y);
x = clamp(x, cameraW / 2, room_width - (cameraW / 2));
y = clamp(y, cameraH / 2, room_height - (cameraH / 2));
