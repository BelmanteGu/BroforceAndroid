package io.github.belmantegu.broforceandroid;

import android.content.Context;
import android.content.SharedPreferences;

/** Overlay settings, kept in the app's SharedPreferences. */
final class Settings {
    static final int CONTROLS_AUTO = 0;   // shown while no gamepad is connected
    static final int CONTROLS_ON = 1;
    static final int CONTROLS_OFF = 2;

    static final int STICK_FLOATING = 0;  // appears where the thumb lands
    static final int STICK_DPAD = 1;      // fixed in the bottom-left corner

    static final int SCREEN_FULL = 0;           // edge to edge, under the camera cutout
    static final int SCREEN_AVOID_CUTOUT = 1;   // Android's default: the cutout's edge stays black
    static final int SCREEN_16_9 = 2;           // the game's original aspect ratio, centered

    int controls = CONTROLS_AUTO;
    int stick = STICK_FLOATING;
    int opacity = 55;   // percent
    int size = 100;     // percent
    int screen = SCREEN_FULL;
    boolean haptics = true;

    private final SharedPreferences prefs;

    Settings(Context context) {
        prefs = context.getSharedPreferences("broforce_android", Context.MODE_PRIVATE);
        controls = prefs.getInt("controls", controls);
        stick = prefs.getInt("stick", stick);
        opacity = prefs.getInt("opacity", opacity);
        size = prefs.getInt("size", size);
        screen = prefs.getInt("screen", screen);
        haptics = prefs.getBoolean("haptics", haptics);
    }

    void save() {
        prefs.edit()
            .putInt("controls", controls)
            .putInt("stick", stick)
            .putInt("opacity", opacity)
            .putInt("size", size)
            .putInt("screen", screen)
            .putBoolean("haptics", haptics)
            .apply();
    }
}
