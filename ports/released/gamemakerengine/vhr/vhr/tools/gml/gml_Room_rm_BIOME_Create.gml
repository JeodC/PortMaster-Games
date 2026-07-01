audio_stop_all();
display_set_gui_size(1024, 576);
if (obj_main.smooth)
{
    surface_resize(application_surface, display_get_width(), display_get_height());
}
else
{
    surface_resize(application_surface, 512, 288);
}
if (sprite_exists(spr_biomeroad))
{
    obj_track.road_texture = spr_biomeroad;
}
if (sprite_exists(spr_biomerail))
{
    obj_track.rail_texture = spr_biomerail;
}
obj_main.camera[0] = instance_create(0, 0, obj_camera);
obj_track.showtrack = true;
obj_main.camera[0].state = 0;
obj_main.state = 4;
obj_track.track_data = obj_main.arcade_course[0][obj_main.arcade_track_index];
if (!get_track_loaded())
{
    import_track(obj_track.track_data.track);
    set_track_loaded(obj_track.track_data);
}
with (obj_track)
{
    build_model(true);
}
with (obj_sprites)
{
    event_user(0);
}
show_debug_message(ds_list_size(obj_sprites.sprites));
