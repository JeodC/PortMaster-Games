// gmloader-next: the occluder-silhouette system (shd_juju_mask -> sur_silhouette,
// applied via shd_juju_silhouette) renders as flickering garbage on Mali/Panfrost
// GLES. Force the engine's own "no occluders present" state: silhouetteActive stays
// false, so both the surface build (C_screen_Draw_72) and the draw pass
// (C_draw_elevation_Draw_0) skip. This is a state the game runs normally wherever
// there are no occluders, so it is safe everywhere.
global.silhouetteActive = false;
prevViewX = camera_get_view_x(global.camera);
prevViewY = camera_get_view_y(global.camera);
for (var i = 0; i < 4; i += 1)
{
    sur_silhouette[i] = -4;
    vbf_silhouette[i] = -4;
}
