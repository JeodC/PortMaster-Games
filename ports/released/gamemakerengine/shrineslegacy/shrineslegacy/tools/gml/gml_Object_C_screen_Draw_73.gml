if (global.menu_open == false && global.game_paused == false && instance_number(C_weather) > 0)
{
    with (C_weather)
    {
        if (instance_exists(C_weather_leaves))
        {
            part_system_drawit(ps_weather_1);
        }
        else
        {
            if (!surface_exists(ps_surf))
            {
                ps_surf = surface_create(320, 180);
            }
            draw_set_alpha(1);
            surface_set_target(ps_surf);
            draw_clear_alpha(c_white, 0);
            part_system_drawit(ps_weather_1);
            part_system_drawit(ps_weather_2);
            surface_reset_target();
            if (instance_exists(C_weather_snow))
            {
                gpu_set_blendmode(bm_add);
            }
            draw_set_alpha(image_alpha);
            draw_surface_tiled(ps_surf, 0, 0);
            draw_set_alpha(1);
            gpu_set_blendmode(bm_normal);
        }
    }
}
if (global.menu_open == 0 && !global.game_paused && global.debug_draw_fog == true)
{
    for (var i = 0; i < 4; i += 1)
    {
        if (fog[i] >= 0)
        {
            draw_sprite_tiled_ext(fog[i], 0, floor(fog_x[i]), floor(fog_y[i]), fog_xscale[i], fog_yscale[i], fog_color[i], fog_alpha[i]);
        }
    }
}
var xx = floor(camera_get_view_x(global.camera));
var yy = floor(camera_get_view_y(global.camera));
var w = floor(camera_get_view_width(global.camera));
var h = floor(camera_get_view_height(global.camera));
set_font_normal();
if (((global.menu_open == 0 || global.menu_open == 3) && (!global.game_paused || global.menu_open > 0)) || room == room_title)
{
    if (blend_strength != 0 && (!global.menu_open || room == room_title))
    {
        gpu_set_blendmode(bm_add);
        draw_set_color(blend_color);
        draw_set_alpha(blend_strength / 255);
        draw_rectangle_sprite(xx, yy, xx + w, yy + h, false);
        gpu_set_blendmode(bm_normal);
    }
}
if (global.menu_open == 0 && (!global.game_paused || global.menu_open > 0))
{
    if (flashing > 0)
    {
        draw_set_color(flash_color);
        draw_set_alpha(flash_strength / 255);
        draw_rectangle_sprite(xx, yy, xx + w, yy + h, false);
    }
}
draw_set_color(c_white);
draw_set_alpha(1);
if (!surface_exists(global.gui_surface))
{
    global.gui_surface = surface_create(w * global.gui_scale, h * global.gui_scale);
    surface_set_target(global.gui_surface);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
}
else if (surface_get_width(global.gui_surface) != (w * global.gui_scale))
{
    surface_resize(global.gui_surface, w * global.gui_scale, h * global.gui_scale);
    surface_set_target(global.gui_surface);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
}
if ((global.menu_open == 0 || global.menu_open == 1) && (!global.game_paused || global.menu_open > 0) && (fading == false || C_master.gameover == true) && (global.draw_gui && !gui_override) && global.debug_hide_gui == 0 && global.gvar[111] != true)
{
    var SCALE = global.gui_scale;
    surface_set_target(global.gui_surface);
    draw_clear_alpha(c_black, 0);
    set_font_normal();
    var FSCALE = SCALE;
    draw_set_color(c_white);
    draw_set_alpha(1);
    if (global.menu_current == 1 || global.menu_current == 3 || global.menu_current == 9999 || global.menu_current == 11 || global.menu_current == 23 || global.menu_current == 28 || global.menu_current == 9999)
    {
        var TOP = 0 * SCALE;
        for (var i = 0; i <= 1; i += 1)
        {
            if (global.char_slot[!i] == 3)
            {
                continue;
            }
            var C, mult, x_portrait, y_portrait, XSCL, x_hp, y_hp, x_mp, y_mp, x_hp_text, y_hp_text;
            if (i == 0)
            {
                C = global.MAIN[1];
                var CENTER = (camera_get_view_width(global.camera) * SCALE) - (4 * SCALE);
                var BOUNCE;
                if (C.flash_color == 255)
                {
                    BOUNCE = max(C.flash_amount - 5, 0) * 0.075;
                }
                else
                {
                    BOUNCE = 0;
                }
                var NAME = global.char[global.char_slot[C.slot]][0];
                yy = (TOP + (10 * SCALE)) - (floor(BOUNCE) * SCALE);
                x_mp = CENTER - (18 * SCALE);
                y_mp = yy + (11 * SCALE);
                x_portrait = x_mp - (27 * SCALE);
                y_portrait = y_mp - (7 * SCALE);
                x_hp = x_portrait + (16 * SCALE);
                y_hp = y_portrait + (14 * SCALE);
                x_hp_text = x_hp + (3 * SCALE);
                y_hp_text = y_hp - (7 * SCALE);
                x_hp_text -= (4 * SCALE);
                mult[0] = -1;
                mult[1] = -1;
                XSCL = 1 * SCALE;
            }
            if (i == 1)
            {
                C = global.MAIN[0];
                var CENTER = (0 * SCALE) + (4 * SCALE);
                var BOUNCE;
                if (C.flash_color == 255)
                {
                    BOUNCE = max(C.flash_amount - 5, 0) * 0.075;
                }
                else
                {
                    BOUNCE = 0;
                }
                var NAME = global.char[global.char_slot[C.slot]][0];
                yy = (TOP + (10 * SCALE)) - (floor(BOUNCE) * SCALE);
                x_mp = CENTER + (18 * SCALE);
                y_mp = yy + (11 * SCALE);
                x_portrait = CENTER + (29 * SCALE);
                y_portrait = y_mp - (7 * SCALE);
                x_hp = x_portrait;
                y_hp = y_portrait + (14 * SCALE);
                x_hp_text = x_hp + (2 * SCALE);
                y_hp_text = y_hp - (7 * SCALE);
                x_hp_text -= (2 * SCALE);
                mult[0] = 1;
                mult[1] = 1;
                XSCL = -1 * SCALE;
            }
            var HPFRAC = C.stat[0] / C.stat[2];
            var len;
            len[0] = ceil((C.stat[2] + 1) * mult[0] * SCALE);
            len[1] = ceil((C.stat[0] + 1) * mult[0] * SCALE);
            var C2 = global.char_slot[C.slot];
            if (C.stat[1] >= C.stat[3])
            {
                mp_gui_flash(16777215, 0.2, 0.3, C2);
            }
            var XXX = x_portrait;
            if (i == 0)
            {
                XXX += (16 * SCALE);
            }
            draw_sprite_ext(spr_UI_portrait_holder, 1, XXX, y_portrait, -XSCL, SCALE, 0, c_white, 1);
            draw_sprite_part_ext(spr_UI_hpbar, 1, 0, 0, abs(len[0] / SCALE), 128, x_hp + (-3 * -XSCL), y_hp, -XSCL, SCALE, c_white, 1);
            draw_sprite_ext(spr_UI_hpbar, 0, x_hp + (-7 * -XSCL), y_hp, -XSCL, SCALE, 0, c_white, 1);
            draw_sprite_ext(spr_UI_hpbar, 2, x_hp + (-4 * -XSCL) + len[0], y_hp, -XSCL, SCALE, 0, c_white, 1);
            if (global.char_slot[C.slot] == 0)
            {
                pal_swap_set(spr_GUI_mp_palette, 0, false);
            }
            else if (global.char_slot[C.slot] == 1)
            {
                pal_swap_set(spr_GUI_mp_palette, 1, false);
            }
            else if (global.char_slot[C.slot] == 2)
            {
                pal_swap_set(spr_GUI_mp_palette, 2, false);
            }
            draw_sprite_ext(spr_UI_portrait_holder, 0, XXX, y_portrait, -XSCL, SCALE, 0, c_white, 1);
            if (C.sprite_flicker == true && shader_is_compiled(shd_redscale))
            {
                shader_set(shd_redscale);
            }
            else if (C.palette_surface_index >= 1 && surface_exists(C.palette_surface))
            {
                pal_swap_set(C.palette_surface, C.palette_surface_index, true);
            }
            else
            {
                pal_swap_set(C.palette_sprite, C.palette_index, false);
            }
            var P_ADD = 0;
            var P_MAX = 4;
            if (C.nearfatal == true)
            {
                P_ADD = 1;
            }
            if (C.pose == 3)
            {
                P_ADD = 2;
            }
            if (C.down == true)
            {
                P_ADD = 3;
            }
            draw_sprite_ext(spr_UI_portraits, (global.char_slot[C.slot] * P_MAX) + P_ADD, x_portrait, y_portrait - (6 * SCALE), SCALE, SCALE, 0, c_white, 1);
            pal_swap_reset();
            var MP_spr = spr_GUI_mp;
            mp_palette_surface_index[C2] = clamp(1 + (mp_flash_amount[C2] / 55), 1, 2);
            if (!surface_exists(mp_palette_surface[C2]))
            {
                mp_palette_surface[C2] = surface_create(3, sprite_get_height(mp_palette_sprite));
            }
            surface_set_target(mp_palette_surface[C2]);
            draw_sprite(mp_palette_sprite, 0, 0, 0);
            pal_swap_draw_palette(mp_palette_sprite, mp_palette_index[C2], 1, 0);
            draw_set_color(mp_flash_color[C2]);
            draw_line_sprite(2, -1, 2, sprite_get_height(mp_palette_sprite));
            surface_reset_target();
            pal_swap_set(mp_palette_surface[C2], mp_palette_surface_index[C2], true);
            draw_sprite_ext(MP_spr, min(floor(C.stat[3] - 1), 7), x_mp, y_mp, XSCL, SCALE, 0, c_white, 1);
            for (var ii = 0; ii < ceil(C.stat[1]); ii += 1)
            {
                var FRM, ANG;
                if (ii == 0 || ii == 2 || ii == 4 || ii == 6)
                {
                    FRM = 8;
                    ANG = -90 * (ii / 2) * sign(XSCL);
                }
                else
                {
                    FRM = 18;
                    ANG = -90 * floor(ii / 2) * sign(XSCL);
                }
                var MP = min(C.stat[1] - ii, 1);
                if (MP < 1)
                {
                    FRM += floor(MP * 10);
                }
                else
                {
                    FRM = 28 + ii;
                    ANG = 0;
                }
                draw_sprite_ext(MP_spr, FRM, x_mp, y_mp, XSCL, SCALE, ANG, c_white, 1);
            }
            pal_swap_reset();
            var EXPFRAC;
            if (global.char[global.char_slot[i]][5] < 30)
            {
                EXPFRAC = (global.char[global.char_slot[C.slot]][32] - global.char[global.char_slot[C.slot]][33]) / (global.char[global.char_slot[C.slot]][34] - global.char[global.char_slot[C.slot]][33]);
                if (global.menu_open == 0)
                {
                    expshow[!i] = clamp(expshow[!i] + expspeed, 0, EXPFRAC);
                }
            }
            else
            {
                EXPFRAC = 1;
                expshow[!i] = EXPFRAC;
            }
            var BAR_WIDTH = floor(30 * SCALE);
            var XOFF = -17 * SCALE;
            var YYY = y_hp + (6 * SCALE);
            if (i == 0)
            {
                draw_set_color(#140F0F);
                draw_rectangle_sprite(x_hp - XOFF, YYY, x_hp - BAR_WIDTH - XOFF, YYY + (1 * SCALE), false);
                draw_set_alpha(0.7);
                draw_set_color(#645A4B);
                draw_rectangle_sprite(x_hp - XOFF, YYY, x_hp - floor(EXPFRAC * BAR_WIDTH) - XOFF, YYY + (1 * SCALE), false);
                draw_set_alpha(1);
                draw_set_color(#D3CDAA);
                if (expshow[!i] == EXPFRAC && EXPFRAC != 1)
                {
                    var WW = floor(EXPFRAC * BAR_WIDTH);
                    draw_rectangle_sprite(x_hp - XOFF, YYY, x_hp - WW - XOFF, YYY + (1 * SCALE), false);
                    var PERCENT = (EXPFRAC * BAR_WIDTH) % 1;
                    draw_set_color(merge_color(c_black, #D3CDAA, PERCENT));
                    draw_rectangle_sprite(x_hp - WW - XOFF, YYY, x_hp - WW - 1 - XOFF, YYY + (1 * SCALE), false);
                }
                else
                {
                    draw_rectangle_sprite(x_hp - XOFF, YYY, x_hp - floor(expshow[!i] * BAR_WIDTH) - XOFF, YYY + (1 * SCALE), false);
                }
            }
            else if (i == 1)
            {
                draw_set_color(#140F0F);
                draw_rectangle_sprite(x_hp + XOFF, YYY, x_hp + BAR_WIDTH + XOFF, YYY + (1 * SCALE), false);
                draw_set_alpha(0.7);
                draw_set_color(#645A4B);
                draw_rectangle_sprite(x_hp + XOFF, YYY, x_hp + floor(EXPFRAC * BAR_WIDTH) + XOFF, YYY + (1 * SCALE), false);
                draw_set_alpha(1);
                draw_set_color(#D3CDAA);
                if (expshow[!i] == EXPFRAC && EXPFRAC != 1)
                {
                    var WW = floor(EXPFRAC * BAR_WIDTH);
                    draw_rectangle_sprite(x_hp + XOFF, YYY, x_hp + WW + XOFF, YYY + (1 * SCALE), false);
                    var PERCENT = (EXPFRAC * BAR_WIDTH) % 1;
                    draw_set_color(merge_color(c_black, #D3CDAA, PERCENT));
                    draw_rectangle_sprite(x_hp + WW + XOFF, YYY, x_hp + WW + 1 + XOFF, YYY + (1 * SCALE), false);
                }
                else
                {
                    draw_rectangle_sprite(x_hp + XOFF, YYY, x_hp + floor(expshow[!i] * BAR_WIDTH) + XOFF, YYY + (1 * SCALE), false);
                }
            }
            if (!ds_list_empty(global.player_spell_list))
            {
                draw_sprite_ext(spr_icons, 7 + ds_list_find_value(global.player_spell_list, array_get(global.element_current, C.slot)), x_mp - (4 * SCALE), y_mp - (4 * SCALE), SCALE, SCALE, 0, c_white, draw_get_alpha());
            }
            var col = 986900;
            var col1 = 986900;
            var col2 = 986900;
            var HP_XOFF = 1 * -XSCL;
            var POISONED = status_get_inflicted(C, 14);
            var BURNED = status_get_inflicted(C, 19);
            if (POISONED || BURNED || C.condition == 2 || C.condition == 3 || C.condition == 4)
            {
                var BRIGHT = 80;
                var AMOUNT = C.flash_amount * 4;
                var ADD = (dsin(AMOUNT % 360) * BRIGHT) + BRIGHT;
                if (C.condition == 3)
                {
                    col1 = make_color_rgb(color_get_red(col) + ADD, color_get_green(col) + ADD, color_get_blue(col) + ADD);
                    col2 = make_color_rgb(color_get_red(col) + (ADD / 2), color_get_green(col) + (ADD / 2), color_get_blue(col) + (ADD / 2));
                }
                else if (C.condition == 4)
                {
                    col1 = make_color_rgb(color_get_red(col) + ADD, color_get_green(col) + ADD, color_get_blue(col) + ADD);
                    col2 = make_color_rgb(color_get_red(col) + (ADD / 2), color_get_green(col) + (ADD / 2), color_get_blue(col) + (ADD / 2));
                }
                else if (POISONED)
                {
                    col1 = make_color_rgb(color_get_red(col), color_get_green(col) + ADD, color_get_blue(col));
                    col2 = make_color_rgb(color_get_red(col), color_get_green(col) + (ADD / 2), color_get_blue(col));
                }
                else if (BURNED)
                {
                    col1 = make_color_rgb(color_get_red(col) + ADD, color_get_green(col), color_get_blue(col));
                    col2 = make_color_rgb(color_get_red(col) + (ADD / 2), color_get_green(col), color_get_blue(col));
                }
                if (C.condition == 2)
                {
                    BRIGHT = 127;
                    ADD = (dsin(AMOUNT % 360) * BRIGHT) + BRIGHT;
                    col1 = make_color_rgb(color_get_red(col1) + ADD, color_get_green(col1), color_get_blue(col1));
                    col2 = make_color_rgb(color_get_red(col2) + (ADD / 2), color_get_green(col2), color_get_blue(col2));
                }
            }
            draw_rectangle_sprite(x_hp + len[0] + (-3 * -XSCL) + HP_XOFF, y_hp + (2 * SCALE), x_hp + (-3 * -XSCL) + HP_XOFF + len[1], y_hp + (3 * SCALE), false, SCALE, col2, 1);
            draw_rectangle_sprite(x_hp + len[0] + (-4 * -XSCL) + HP_XOFF, y_hp + (3 * SCALE), x_hp + (-4 * -XSCL) + HP_XOFF + len[1], y_hp + (4 * SCALE), false, SCALE, col1, 1);
            col1 = 58910;
            col2 = 2017280;
            with (C)
            {
                hp_trail_operate_player(HPFRAC);
            }
            if (HPFRAC > 0)
            {
                draw_rectangle_sprite(x_hp + (-2 * -XSCL) + HP_XOFF, y_hp + (2 * SCALE), x_hp + (-3 * -XSCL) + HP_XOFF + (ceil((len[0] * C.player_hp_bakfrac) / SCALE) * SCALE), y_hp + (3 * SCALE), false, SCALE, 255, draw_get_alpha());
                draw_rectangle_sprite(x_hp + (-3 * -XSCL) + HP_XOFF, y_hp + (3 * SCALE), x_hp + (-4 * -XSCL) + HP_XOFF + (ceil((len[0] * C.player_hp_bakfrac) / SCALE) * SCALE), y_hp + (4 * SCALE), false, SCALE, 255, draw_get_alpha());
            }
            draw_rectangle_sprite(x_hp + (-2 * -XSCL) + HP_XOFF, y_hp + (2 * SCALE), x_hp + (-3 * -XSCL) + HP_XOFF + len[1], y_hp + (3 * SCALE), false, SCALE, col2, draw_get_alpha());
            draw_rectangle_sprite(x_hp + (-3 * -XSCL) + HP_XOFF, y_hp + (3 * SCALE), x_hp + (-4 * -XSCL) + HP_XOFF + len[1], y_hp + (4 * SCALE), false, SCALE, col1, draw_get_alpha());
            draw_set_color(c_white);
            if (i == 0)
            {
                draw_set_halign(fa_right);
            }
            if (i == 1)
            {
                draw_set_halign(fa_left);
            }
            draw_set_font(global.fnt_numbers_tiny_pui);
            draw_set_color(c_white);
            draw_text_transformed(x_hp_text, y_hp_text, string_hash_to_newline(string(C.stat[0]) + "/" + string(C.stat[2])), FSCALE, FSCALE, 0);
            draw_set_halign(fa_left);
            if (C.light_effect_time > 0)
            {
                var YY = y_mp + (19 * SCALE);
                var XX = x_hp;
                XOFF = 6 * SCALE;
                if (i == 0)
                {
                    XX += (19 * SCALE);
                    XOFF -= (2 * SCALE);
                }
                else
                {
                    XX -= (20 * SCALE);
                }
                var IMG;
                if (C.light_effect_active == 1)
                {
                    IMG = 9;
                }
                else
                {
                    IMG = 12;
                }
                draw_sprite_ext(spr_icons, IMG, XX - (3 * SCALE), YY - (3 * SCALE), SCALE, SCALE, 0, c_white, draw_get_alpha());
                BAR_WIDTH = 40 * SCALE * (C.light_effect_time_max / 720);
                if (C.light_effect_active >= 1)
                {
                    AMOUNT = C.light_effect_time / C.light_effect_time_max;
                }
                var AMOUNT = round(AMOUNT * BAR_WIDTH);
                if (i == 0)
                {
                    draw_set_color(c_black);
                    draw_rectangle_sprite(XX - XOFF, YY, XX - BAR_WIDTH - XOFF, YY + (1 * SCALE), false);
                    draw_set_color(c_white);
                    draw_rectangle_sprite(XX - XOFF, YY, XX - AMOUNT - XOFF, YY + (1 * SCALE), false);
                }
                else if (i == 1)
                {
                    draw_set_color(c_black);
                    draw_rectangle_sprite(XX + XOFF, YY, XX + BAR_WIDTH + XOFF, YY + (1 * SCALE), false);
                    draw_set_color(c_white);
                    draw_rectangle_sprite(XX + XOFF, YY, XX + AMOUNT + XOFF, YY + (1 * SCALE), false);
                }
            }
        }
    }
    set_font_normal();
    FSCALE = SCALE;
    var _length = array_length(global.boss_current);
    if (_length > 0 && global.menu_open == false)
    {
        if (boss_hp_fillfrac < boss_hp_fillfrac_max)
        {
            if ((global.timing % 4) == 0)
            {
                var SND = SFX_play(snd_blip1, -1, 1);
                audio_sound_pitch(SND, 0.5);
            }
            boss_hp_fillfrac = clamp(boss_hp_fillfrac + 0.01, 0, boss_hp_fillfrac_max);
        }
        var HPFRAC = 0;
        for (var i = 0; i < _length; i++)
        {
            var _obj = global.boss_current[i];
            with (_obj)
            {
                HPFRAC += (stat[0] / stat[2]);
            }
        }
        HPFRAC /= _length;
        HPFRAC = min(HPFRAC, other.boss_hp_fillfrac);
        hp_trail_operate_boss(HPFRAC);
        var W = 148 * SCALE;
        var XOFFSET = 2 * SCALE;
        var YOFFSET = 2 * SCALE;
        var H = 11 * SCALE;
        xx = ((camera_get_view_width(global.camera) / 2) * SCALE) - (W / 2) - (1 * SCALE);
        yy = (camera_get_view_height(global.camera) * SCALE) - H - (8 * SCALE);
        draw_set_alpha(1);
        draw_set_color(c_white);
        draw_sprite_ext(spr_menu_boss_healthbar, 0, xx, yy, SCALE, SCALE, 0, c_white, draw_get_alpha());
        if (HPFRAC > 0)
        {
            var W2 = sprite_get_width(spr_menu_boss_healthbar_bar);
            if (boss_hp_fillfrac_max <= 1)
            {
                draw_sprite_part_ext(spr_menu_boss_healthbar_bar, 1, 0, 0, ceil(W2 * boss_hp_bakfrac), sprite_get_height(spr_menu_boss_healthbar_bar), xx + XOFFSET, yy + YOFFSET, SCALE, SCALE, c_white, draw_get_alpha() * 0.85);
                draw_sprite_part_ext(spr_menu_boss_healthbar_bar, 0, 0, 0, ceil(W2 * HPFRAC), sprite_get_height(spr_menu_boss_healthbar_bar), xx + XOFFSET, yy + YOFFSET, SCALE, SCALE, c_white, draw_get_alpha());
            }
            else
            {
                draw_sprite_part_ext(spr_menu_boss_healthbar_bar_joke, 1, 0, 0, ceil(W2 * boss_hp_bakfrac), sprite_get_height(spr_menu_boss_healthbar_bar), xx + XOFFSET, yy + YOFFSET, SCALE, SCALE, c_white, draw_get_alpha() * 0.85);
                draw_sprite_part_ext(spr_menu_boss_healthbar_bar_joke, 0, 0, 0, ceil(W2 * HPFRAC), sprite_get_height(spr_menu_boss_healthbar_bar), xx + XOFFSET, yy + YOFFSET, SCALE, SCALE, c_white, draw_get_alpha());
            }
        }
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text_transformed(xx + (W / 2), yy - (8 * SCALE), "-" + global.boss_name + "-", FSCALE, FSCALE, 0);
        draw_set_halign(fa_left);
        draw_set_color(c_white);
    }
    if (room != room_title && (global.game_paused == false || global.text_talking == false))
    {
        var DRAW = 1;
        if (global.text_talking == true)
        {
            with (global.text_talk_target)
            {
                if (object_type != 37)
                {
                    DRAW = false;
                }
                else
                {
                    DRAW = 2;
                }
            }
        }
        if (DRAW > 0)
        {
            draw_set_halign(fa_right);
            draw_set_font(global.fnt_numbers_tiny);
            var xminus = 0;
            var yminus = 0;
            if (DRAW == 2)
            {
                yminus = 48 * SCALE;
            }
            if (global.dungeon >= 0 && global.game_state != 2 && global.game_state != 1 && (global.MAIN[0].jewel_effect_minimap == true || global.MAIN[1].jewel_effect_minimap == true))
            {
                xminus = 62 * SCALE;
            }
            else
            {
                xminus = 18 * SCALE;
            }
            yy = (floor(camera_get_view_height(global.camera) - 16) * SCALE) - yminus;
            if (DRAW == 1)
            {
                xx = (floor(camera_get_view_width(global.camera)) * SCALE) - xminus;
            }
            else if (DRAW == 2)
            {
                var OFFSET = ((320 - camera_get_view_width(global.camera)) / 2) * SCALE;
                xx = floor(-OFFSET + (108 * SCALE));
            }
            draw_sprite_ext(spr_pickup_icons3, 0, (xx + (6 * SCALE)) - (string_width(global.money) * SCALE), yy + (4 * SCALE), SCALE, SCALE, 0, c_white, draw_get_alpha());
            draw_set_color(c_white);
            draw_text_transformed(xx + (9 * SCALE), yy, string(global.money), FSCALE, FSCALE, 0);
            if (global.dungeon >= 0 && DRAW == 1 && (global.menu_open == false || global.screen_ratio >= 1.7777777777777777))
            {
                xx += (7 * SCALE);
                yy -= (8 * SCALE);
                var R = global.dungeon_key[global.dungeon];
                for (var i = 0; i < R; i += 1)
                {
                    draw_sprite_ext(spr_pickup_icons5, global.dungeon, xx - (9 * i * SCALE), yy, SCALE, SCALE, 0, c_white, draw_get_alpha());
                }
            }
        }
        set_font_normal();
        FSCALE = SCALE;
    }
    with (fx_battle_money_numerals)
    {
        draw_set_halign(fa_right);
        draw_set_alpha(image_alpha);
        draw_set_color(image_blend);
        draw_set_font(global.fnt_numbers_tiny);
        var xminus = 9 * SCALE;
        if (global.dungeon >= 0 && global.game_state != 2 && global.game_state != 1 && (global.MAIN[0].jewel_effect_minimap == true || global.MAIN[1].jewel_effect_minimap == true))
        {
            xminus = 53 * SCALE;
        }
        x = (floor(camera_get_view_width(global.camera)) * SCALE) - xminus;
        y = (floor(camera_get_view_height(global.camera) - 20) - (life / 3)) * SCALE;
        draw_set_color(image_blend);
        var _sign_text = "+";
        if (number < 0)
        {
            _sign_text = "-";
        }
        draw_text_transformed(floor(x), floor(y), _sign_text + string(abs(number)), FSCALE, FSCALE, 0);
        draw_set_color(c_white);
    }
    if (global.text_talking == false)
    {
        if (global.potion_effect_current >= 0 && global.potion_effect_time_current > 0)
        {
            var PAUSED = true;
            if (global.menu_open == false && global.cutscene_playing == false && global.game_paused == false && global.game_state != 1)
            {
                global.potion_effect_time_current -= 1;
                PAUSED = false;
            }
            var YY = floor(camera_get_view_height(global.camera) - 5) * SCALE;
            var XX = floor(camera_get_view_width(global.camera) - 52) * SCALE;
            var XOFF = 4 * SCALE;
            var IMG = 18;
            draw_set_alpha(1);
            if (!PAUSED)
            {
                if (global.potion_effect_time_current <= 300 && (floor(life / 15) % 2) == 0)
                {
                    draw_set_alpha(0.75);
                }
            }
            else
            {
                draw_set_alpha(0.75);
            }
            draw_sprite_ext(spr_buff_text, 0, XX - (5 * SCALE) - (sprite_get_width(spr_buff_text) * SCALE), YY - (3 * SCALE), SCALE, SCALE, 0, c_white, draw_get_alpha());
            draw_sprite_ext(spr_icons, IMG, XX - (3 * SCALE), YY - (3 * SCALE), SCALE, SCALE, 0, c_white, draw_get_alpha());
            var BAR_WIDTH = 40 * SCALE;
            var AMOUNT = global.potion_effect_time_current / global.potion_effect_time_max;
            AMOUNT = floor(AMOUNT * BAR_WIDTH);
            draw_set_color(c_black);
            draw_rectangle_sprite(XX + XOFF, YY, XX + BAR_WIDTH + XOFF, YY + (1 * SCALE), false);
            draw_set_color(c_white);
            draw_rectangle_sprite(XX + XOFF, YY, XX + AMOUNT + XOFF, YY + (1 * SCALE), false);
            if (PAUSED)
            {
            }
            draw_set_alpha(1);
        }
        else if (global.potion_effect_current != -4)
        {
            global.potion_effect_current = -4;
            global.potion_effect_time_current = -1;
            global.potion_effect_time_max = -1;
        }
    }
    surface_reset_target();
    set_font_normal();
}
else
{
    surface_set_target(global.gui_surface);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
}
draw_set_color(c_white);
draw_set_alpha(1);
with (C_master)
{
    if (global.menu_open == false && global.dungeon >= 0 && global.text_talking == false && global.draw_gui && global.debug_hide_gui == 0 && (global.MAIN[0].jewel_effect_minimap == true || global.MAIN[1].jewel_effect_minimap == true) && array_length(global.boss_current) == 0)
    {
        var W = 5;
        var H = 5;
        var SPR = spr_minimap;
        var SCALE = 1;
        var OFFSETX = (global.map_room_x + (global.map_player_position[0] % global.map_room_width)) - 2;
        var OFFSETY = (global.map_room_y + (global.map_player_position[0] div global.map_room_width)) - 2;
        var COLOR1 = 16755455;
        if (visible == true)
        {
            var XX = (camera_get_view_x(global.camera) + camera_get_view_width(global.camera)) - 48;
            var YY = (camera_get_view_y(global.camera) + camera_get_view_height(global.camera)) - 48;
            var ALPHA = 0.75;
            var FLOOR_DISPLAY = global.map_floor_index;
            var GRID = global.map_size[SCALE - 1];
            draw_sprite_ext(SPR, 0, XX, YY, 1, 1, 0, c_white, ALPHA);
            draw_set_color(c_white);
            for (var i = 0; i < floor(W / SCALE); i += 1)
            {
                if (FLOOR_DISPLAY > 0)
                {
                    for (var t = 0; t < floor(H / SCALE); t += 1)
                    {
                        var ii = i + OFFSETX;
                        var tt = t + OFFSETY;
                        if (ii < 0 || tt < 0 || ii >= global.map_width || tt >= global.map_height)
                        {
                            continue;
                        }
                        var IMAGE = global.map_draw2[ii][tt];
                        var OVERLAY = global.map_draw_room_overlay2[ii][tt];
                        var DOOR = global.map_draw_room_door2[ii][tt];
                        var SECRET = global.map_draw_room_secret2[ii][tt];
                        var SECRET_FOUND = map_get_secret(global.map_index, FLOOR_DISPLAY - 1, global.map_draw_room2[ii][tt], global.map_draw_position2[ii][tt]);
                        ALPHA = 0.24;
                        var COLOR = COLOR1;
                        if (global.map_draw_room2[ii][tt] == -1)
                        {
                            continue;
                        }
                        var EXPLORED = map_get_explored(global.map_index, FLOOR_DISPLAY - 1, global.map_draw_room2[ii][tt], global.map_draw_position2[ii][tt]);
                        if (EXPLORED == 0)
                        {
                            continue;
                        }
                        if (OVERLAY != 10)
                        {
                            draw_sprite_ext(global.map_sprite[SCALE - 1], IMAGE, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                        }
                        if (OVERLAY > 0 && OVERLAY != 10 && (SECRET_FOUND >= 16 || SECRET < 16))
                        {
                            draw_sprite_ext(global.map_sprite[SCALE - 1], map_overlay_start + OVERLAY, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                            if (SECRET_FOUND >= 16)
                            {
                                SECRET_FOUND -= 16;
                            }
                        }
                        for (var D = 3; D >= 0; D -= 1)
                        {
                            if ((DOOR & power(2, D)) == power(2, D) && ((SECRET_FOUND & power(2, D)) == power(2, D) || (SECRET & power(2, D)) != power(2, D)))
                            {
                                draw_sprite_ext(global.map_sprite[SCALE - 1], map_overlay_start + 1 + D, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                                if (DOOR >= power(2, D))
                                {
                                    DOOR -= power(2, D);
                                }
                            }
                        }
                    }
                }
                for (var t = 0; t < floor(H / SCALE); t += 1)
                {
                    var ii = i + OFFSETX;
                    var tt = t + OFFSETY;
                    if (ii < 0 || tt < 0 || ii >= global.map_width || tt >= global.map_height)
                    {
                        continue;
                    }
                    var IMAGE = global.map_draw[ii][tt];
                    var OVERLAY = global.map_draw_room_overlay[ii][tt];
                    var DOOR = global.map_draw_room_door[ii][tt];
                    var SECRET = global.map_draw_room_secret[ii][tt];
                    var SECRET_FOUND = map_get_secret(global.map_index, FLOOR_DISPLAY, global.map_draw_room[ii][tt], global.map_draw_position[ii][tt]);
                    ALPHA = 0.75;
                    var COLOR = image_blend;
                    if (global.map_draw_room[ii][tt] == -1)
                    {
                        continue;
                    }
                    var EXPLORED = map_get_explored(global.map_index, FLOOR_DISPLAY, global.map_draw_room[ii][tt], global.map_draw_position[ii][tt]);
                    if (EXPLORED == 0)
                    {
                        continue;
                    }
                    if (EXPLORED == 2)
                    {
                        COLOR = COLOR1;
                        ALPHA *= 0.75;
                    }
                    if (OVERLAY != 10)
                    {
                        draw_sprite_ext(global.map_sprite[SCALE - 1], IMAGE, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                    }
                    if (OVERLAY > 0 && OVERLAY != 10 && (SECRET_FOUND >= 16 || SECRET < 16))
                    {
                        draw_sprite_ext(global.map_sprite[SCALE - 1], map_overlay_start + OVERLAY, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                        if (SECRET_FOUND >= 16)
                        {
                            SECRET_FOUND -= 16;
                        }
                    }
                    for (var D = 3; D >= 0; D -= 1)
                    {
                        if ((DOOR & power(2, D)) == power(2, D) && ((SECRET_FOUND & power(2, D)) == power(2, D) || (SECRET & power(2, D)) != power(2, D)))
                        {
                            draw_sprite_ext(global.map_sprite[SCALE - 1], map_overlay_start + 1 + D, XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, COLOR, ALPHA);
                            if (DOOR >= power(2, D))
                            {
                                DOOR -= power(2, D);
                            }
                        }
                    }
                }
            }
            for (var p = 0; p <= 1; p += 1)
            {
                if (p == 0 || ((global.p2_activated || global.MAIN[1].down) && (global.room_ground_level + global.MAIN[p].elevation) == global.map_floor_index))
                {
                    var i, t;
                    if (p == 0)
                    {
                        i = 2;
                        t = 2;
                    }
                    if (p == 1)
                    {
                        i = global.map_player_position[1] % global.map_room_width;
                        t = global.map_player_position[1] div global.map_room_width;
                        i = (i - (global.map_player_position[0] % global.map_room_width)) + 2;
                        t = (t - (global.map_player_position[0] div global.map_room_width)) + 2;
                    }
                    var ALPH = 0.65;
                    if ((life % 32) < 16 && i >= 0 && t >= 0 && i < W && t < H)
                    {
                        if (p == 1 && i == 2 && t == 2)
                        {
                            break;
                        }
                        draw_sprite_ext(global.map_sprite[SCALE - 1], 49 + global.char_slot[p], XX + (i * GRID), YY + (t * GRID), 1, 1, image_angle, image_blend, ALPH);
                    }
                }
            }
        }
    }
}
