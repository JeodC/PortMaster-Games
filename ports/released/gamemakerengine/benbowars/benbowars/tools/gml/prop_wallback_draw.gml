// Off-view early-out: dense rooms hold 700+ wallback instances, and the
// vanilla draw runs shake math plus a sprite submit for every one of them
// each frame. Skip everything when the instance is outside the camera.
var _vx = camera_get_view_x(view_camera[0]);
var _vy = camera_get_view_y(view_camera[0]);
if (bbox_right < _vx - 32 || bbox_bottom < _vy - 32 || bbox_left > _vx + camera_get_view_width(view_camera[0]) + 32 || bbox_top > _vy + camera_get_view_height(view_camera[0]) + 32)
    exit;
posnegx = choose(1, -1, 0);
posnegy = choose(1, -1, 0);
shakex = lerp(shakex, 0, 0.2);
shakey = lerp(shakey, 0, 0.2);
if (flashing)
{
    gpu_set_blendmode_ext(bm_inv_dest_color, bm_zero);
    draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c_white, c_white, c_white, c_white, false);
    gpu_set_blendmode(bm_normal);
    draw_sprite_ext(sprite_index, image_index, x + (shakex * posnegx), y + (shakey * posnegy), image_xscale, image_yscale, image_angle, c_black, image_alpha);
    gpu_set_blendmode_ext(bm_inv_dest_color, bm_zero);
    draw_rectangle_color(bbox_left, bbox_top, bbox_right, bbox_bottom, c_white, c_white, c_white, c_white, false);
    gpu_set_blendmode(bm_normal);
    flashing--;
}
else
{
    draw_sprite_ext(sprite_index, image_index, x + (shakex * posnegx), y + (shakey * posnegy), image_xscale, image_yscale, image_angle, c_white, image_alpha);
}
