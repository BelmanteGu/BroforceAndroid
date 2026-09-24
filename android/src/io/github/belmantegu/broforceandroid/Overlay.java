package io.github.belmantegu.broforceandroid;

import android.app.Activity;
import android.content.Context;
import android.graphics.Rect;
import android.hardware.input.InputManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.util.SparseIntArray;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;

/**
 * Native layer on top of the Unity view: on-screen controls, the quick settings panel
 * and the screen mode. Started from the game by Hooks.OnStartup.
 *
 * The on-screen controls inject the key events of the game's default keyboard layout
 * (arrows, Z, X, C, V, Left Shift, Esc) into the Unity player, exactly as a hardware
 * keyboard would, so the game itself needs no changes.
 */
public final class Overlay {
    static final String TAG = "BroforceAndroid";

    private static Overlay instance;

    /** Called from C# on the Unity thread; builds the overlay on the UI thread. */
    public static void attach(final Activity activity) {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                if (instance != null) return;
                try {
                    instance = new Overlay(activity);
                } catch (Throwable t) {
                    Log.e(TAG, "overlay failed to start", t);
                }
            }
        });
    }

    final Activity activity;
    final Settings settings;
    private final View unityView;
    private final Method injectEvent;
    private final FrameLayout root;
    private final TouchControlsView controls;
    private final SettingsPanel panel;
    private final SparseIntArray pressed = new SparseIntArray();
    private boolean gamepadConnected;

    private Overlay(Activity activity) throws Exception {
        this.activity = activity;
        settings = new Settings(activity);
        unityView = findUnityPlayer(activity);
        injectEvent = unityView.getClass().getMethod("injectEvent", InputEvent.class);
        root = (FrameLayout) activity.findViewById(android.R.id.content);
        root.setBackgroundColor(0xFF000000);   // the bars around the 16:9 view

        controls = new TouchControlsView(activity, this);
        root.addView(controls, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        panel = new SettingsPanel(activity, this);
        root.addView(panel, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        // The 16:9 mode sizes the Unity view from the root's size.
        root.addOnLayoutChangeListener(new View.OnLayoutChangeListener() {
            @Override public void onLayoutChange(View v, int l, int t, int r, int b,
                                                 int ol, int ot, int or, int ob) {
                if (r - l != or - ol || b - t != ob - ot) applyScreenSize();
            }
        });

        InputManager input = (InputManager) activity.getSystemService(Context.INPUT_SERVICE);
        input.registerInputDeviceListener(new InputManager.InputDeviceListener() {
            @Override public void onInputDeviceAdded(int id) { refreshGamepad(); }
            @Override public void onInputDeviceRemoved(int id) { refreshGamepad(); }
            @Override public void onInputDeviceChanged(int id) { refreshGamepad(); }
        }, new Handler(Looper.getMainLooper()));

        refreshGamepad();
        apply();
        Log.i(TAG, "overlay started");
    }

    // ------------------------------------------------------------------ keys

    /** Presses a key; the same key can be held by several controls (Up and Jump). */
    void press(int keyCode) {
        int count = pressed.get(keyCode);
        pressed.put(keyCode, count + 1);
        if (count == 0) sendKey(keyCode, KeyEvent.ACTION_DOWN);
    }

    void release(int keyCode) {
        int count = pressed.get(keyCode);
        if (count <= 0) return;
        pressed.put(keyCode, count - 1);
        if (count == 1) sendKey(keyCode, KeyEvent.ACTION_UP);
    }

    void releaseAll() {
        for (int i = 0; i < pressed.size(); i++)
            if (pressed.valueAt(i) > 0) sendKey(pressed.keyAt(i), KeyEvent.ACTION_UP);
        pressed.clear();
    }

    private void sendKey(int keyCode, int action) {
        long now = SystemClock.uptimeMillis();
        KeyEvent event = new KeyEvent(now, now, action, keyCode, 0, 0,
            KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD);
        try {
            injectEvent.invoke(unityView, event);
        } catch (Exception e) {
            activity.dispatchKeyEvent(event);
        }
    }

    // ------------------------------------------------------------------ settings

    /** Applies the current settings; called after every change in the panel. */
    void apply() {
        boolean show = settings.controls == Settings.CONTROLS_ON
            || (settings.controls == Settings.CONTROLS_AUTO && !gamepadConnected);
        if (!show) releaseAll();
        controls.setVisibility(show ? View.VISIBLE : View.GONE);
        controls.applySettings();
        applyCutout();
        applyScreenSize();
    }

    boolean isGamepadConnected() { return gamepadConnected; }

    void setPanelOpen(boolean open) {
        if (open) releaseAll();
    }

    private void applyCutout() {
        if (Build.VERSION.SDK_INT < 28) return;
        WindowManager.LayoutParams attrs = activity.getWindow().getAttributes();
        int mode = settings.screen == Settings.SCREEN_FULL
            ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;
        if (attrs.layoutInDisplayCutoutMode != mode) {
            attrs.layoutInDisplayCutoutMode = mode;
            activity.getWindow().setAttributes(attrs);
        }
    }

    private void applyScreenSize() {
        int width = ViewGroup.LayoutParams.MATCH_PARENT;
        if (settings.screen == Settings.SCREEN_16_9 && root.getWidth() > 0) {
            int fit = root.getHeight() * 16 / 9;
            if (fit < root.getWidth()) width = fit;
        }
        ViewGroup.LayoutParams current = unityView.getLayoutParams();
        if (current != null && current.width == width) return;
        unityView.setLayoutParams(new FrameLayout.LayoutParams(
            width, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.CENTER));
    }

    // ------------------------------------------------------------------ gamepads

    private void refreshGamepad() {
        boolean found = false;
        for (int id : InputDevice.getDeviceIds()) {
            InputDevice device = InputDevice.getDevice(id);
            if (device == null || device.isVirtual() || !isExternal(device)) continue;
            int sources = device.getSources();
            if ((sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
                || (sources & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK) {
                Log.i(TAG, "gamepad: " + device.getName());
                found = true;
            }
        }
        if (found != gamepadConnected) {
            gamepadConnected = found;
            Log.i(TAG, "gamepad connected: " + found);
            apply();
            panel.refresh();
        }
    }

    /** InputDevice.isExternal() is public from API 29; earlier, assume external. */
    private static boolean isExternal(InputDevice device) {
        try {
            return (Boolean) InputDevice.class.getMethod("isExternal").invoke(device);
        } catch (Exception e) {
            return true;
        }
    }

    /** View.setSystemGestureExclusionRects (API 29): keeps edge swipes for our controls. */
    static void excludeFromSystemGestures(View view, List<Rect> rects) {
        if (Build.VERSION.SDK_INT < 29) return;
        try {
            View.class.getMethod("setSystemGestureExclusionRects", List.class).invoke(view, rects);
        } catch (Exception ignored) {
        }
    }

    private static View findUnityPlayer(Activity activity) throws Exception {
        for (Class<?> c = activity.getClass(); c != null; c = c.getSuperclass()) {
            try {
                Field field = c.getDeclaredField("mUnityPlayer");
                field.setAccessible(true);
                return (View) field.get(activity);
            } catch (NoSuchFieldException ignored) {
            }
        }
        throw new IllegalStateException("UnityPlayer not found in " + activity.getClass());
    }
}
