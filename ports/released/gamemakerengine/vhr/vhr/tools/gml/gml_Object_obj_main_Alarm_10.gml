if (surface_exists(application_surface))
{
    if (!smooth)
    {
        try
        {
            surface_resize(application_surface, 512, 288);
        }
        catch (_exception)
        {
            show_debug_message(_exception.message);
            show_debug_message(_exception.longMessage);
            show_debug_message(_exception.script);
            show_debug_message(_exception.stacktrace);
            alarm[10] = 5;
        }
    }
    else
    {
        try
        {
            surface_resize(application_surface, display_get_width(), display_get_height());
        }
        catch (_exception)
        {
            show_debug_message(_exception.message);
            show_debug_message(_exception.longMessage);
            show_debug_message(_exception.script);
            show_debug_message(_exception.stacktrace);
            alarm[10] = 5;
        }
    }
}
