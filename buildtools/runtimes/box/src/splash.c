/*
 * Minimal SDL2 loading-screen helper for the box runtime.
 *
 * Usage: splash <sprite_path> <splash_delay_ms>
 *
 * Opens a fullscreen window at the display's current resolution, draws the
 * given image scaled to fill, holds it for <splash_delay_ms>, then exits.
 * Box ports fire it in the background while box64 spins up the game.
 *
 */
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    if (argc != 3) {
        printf("Usage: %s <sprite_path> <splash_delay>\n", argv[0]);
        return 1;
    }

    const char *sprite_path = argv[1];
    int splash_delay = atoi(argv[2]);

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        printf("Unable to initialize SDL: %s\n", SDL_GetError());
        return 1;
    }

    if (!(IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG)) {
        printf("SDL_image could not initialize! IMG_Error: %s\n", IMG_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_DisplayMode mode;
    if (SDL_GetCurrentDisplayMode(0, &mode) != 0) {
        printf("Unable to get display mode for display %d: %s\n", 0, SDL_GetError());
        IMG_Quit();
        SDL_Quit();
        return 1;
    }

    printf("Splash: Detected Resolution is %dx%d\n", mode.w, mode.h);
    printf("Splash: Delay set to %d ms\n", splash_delay);

    SDL_Window *window = SDL_CreateWindow("Splash",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        mode.w, mode.h, SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (!window) {
        printf("Unable to create window: %s\n", SDL_GetError());
        IMG_Quit();
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) {
        printf("Unable to create renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        IMG_Quit();
        SDL_Quit();
        return 1;
    }

    SDL_Surface *surface = IMG_Load(sprite_path);
    if (!surface) {
        printf("Unable to load image: %s\n", IMG_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        IMG_Quit();
        SDL_Quit();
        return 1;
    }

    SDL_Texture *texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_FreeSurface(surface);
    if (!texture) {
        printf("Unable to create texture: %s\n", SDL_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        IMG_Quit();
        SDL_Quit();
        return 1;
    }

    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);

    SDL_Delay(splash_delay);

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    IMG_Quit();
    SDL_Quit();
    return 0;
}
