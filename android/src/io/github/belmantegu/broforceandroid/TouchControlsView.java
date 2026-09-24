package io.github.belmantegu.broforceandroid;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Build;
import android.util.SparseArray;
import android.view.DisplayCutout;
import android.view.HapticFeedbackConstants;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowInsets;

import java.util.ArrayList;
import java.util.List;

/**
 * The on-screen gamepad: movement on the left (fixed D-pad or floating joystick),
 * action buttons on the right. Multitouch; a finger can slide from one button to
 * another without lifting.
 */
final class TouchControlsView extends View {
    // The game's default keyboard layout for player 1 (PlayerOptions).
    static final int KEY_LEFT = KeyEvent.KEYCODE_DPAD_LEFT;
    static final int KEY_RIGHT = KeyEvent.KEYCODE_DPAD_RIGHT;
    static final int KEY_UP = KeyEvent.KEYCODE_DPAD_UP;       // also Jump
    static final int KEY_DOWN = KeyEvent.KEYCODE_DPAD_DOWN;
    static final int KEY_FIRE = KeyEvent.KEYCODE_Z;           // also confirm in menus
    static final int KEY_SPECIAL = KeyEvent.KEYCODE_X;
    static final int KEY_MELEE = KeyEvent.KEYCODE_C;          // high five / melee / use
    static final int KEY_FLEX = KeyEvent.KEYCODE_V;
    static final int KEY_DASH = KeyEvent.KEYCODE_SHIFT_LEFT;
    static final int KEY_PAUSE = KeyEvent.KEYCODE_ESCAPE;     // also back in menus

    private static final int DIR_LEFT = 1, DIR_RIGHT = 2, DIR_UP = 4, DIR_DOWN = 8;

    private static final class Button {
        final int key;
        final String label;
        final boolean small;
        float x, y, r;
        int holders;

        Button(int key, String label, boolean small) {
            this.key = key;
            this.label = label;
            this.small = small;
        }
    }

    private final Overlay overlay;
    private final Button fire = new Button(KEY_FIRE, "FIRE", false);
    private final Button jump = new Button(KEY_UP, "JUMP", false);
    private final Button special = new Button(KEY_SPECIAL, "SPECIAL", false);
    private final Button melee = new Button(KEY_MELEE, "MELEE", false);
    private final Button dash = new Button(KEY_DASH, "DASH", true);
    private final Button flex = new Button(KEY_FLEX, "FLEX", true);
    private final Button pause = new Button(KEY_PAUSE, "", true);
    private final Button[] buttons = { fire, jump, special, melee, dash, flex, pause };

    private final SparseArray<Button> pointerButtons = new SparseArray<Button>();
    private int stickPointer = -1;
    private float baseX, baseY, knobX, knobY;   // floating joystick
    private float dpadX, dpadY;                 // fixed D-pad / idle joystick hint
    private int stickDirs;
    private float stickRadius, deadZone, stickZoneRight;

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path arrow = new Path();
    private int alpha;
    private float dp;

    TouchControlsView(Context context, Overlay overlay) {
        super(context);
        this.overlay = overlay;
        setFocusable(false);
        stroke.setStyle(Paint.Style.STROKE);
        text.setTextAlign(Paint.Align.CENTER);
        text.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
        text.setLetterSpacing(0.05f);
    }

    void applySettings() {
        releaseAllControls();
        alpha = Math.round(255 * overlay.settings.opacity / 100f);
        layoutControls(getWidth(), getHeight());
        invalidate();
    }

    // ------------------------------------------------------------------ layout

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        layoutControls(w, h);
    }

    private void layoutControls(int w, int h) {
        if (w == 0 || h == 0) return;
        dp = getResources().getDisplayMetrics().density * overlay.settings.size / 100f;
        int insetLeft = 0, insetRight = 0;
        WindowInsets insets = Build.VERSION.SDK_INT >= 23 ? getRootWindowInsets() : null;
        if (insets != null && Build.VERSION.SDK_INT >= 28) {
            DisplayCutout cutout = insets.getDisplayCutout();
            if (cutout != null) {
                insetLeft = cutout.getSafeInsetLeft();
                insetRight = cutout.getSafeInsetRight();
            }
        }

        stickRadius = 62 * dp;
        deadZone = 14 * dp;
        stickZoneRight = w * 0.42f;
        dpadX = insetLeft + 118 * dp;
        dpadY = h - 118 * dp;

        // Action buttons in a gamepad diamond: Fire left, Special top, Melee right, Jump bottom.
        float cx = w - insetRight - 148 * dp, cy = h - 142 * dp, gap = 74 * dp;
        place(fire, cx - gap, cy, 34);
        place(special, cx, cy - gap, 34);
        place(melee, cx + gap, cy, 34);
        place(jump, cx, cy + gap, 34);
        place(dash, cx - gap - 6 * dp, cy + 86 * dp, 25);
        place(flex, cx + gap + 6 * dp, cy - 86 * dp, 25);
        place(pause, w - insetRight - 44 * dp, 40 * dp, 22);

        List<Rect> exclusion = new ArrayList<Rect>();
        exclusion.add(new Rect(0, (int) (h - 200 * dp), (int) (w * 0.3f), h));
        exclusion.add(new Rect((int) (w - 260 * dp), (int) (h - 200 * dp), w, h));
        Overlay.excludeFromSystemGestures(this, exclusion);
    }

    private void place(Button b, float x, float y, float radiusDp) {
        b.x = x;
        b.y = y;
        b.r = radiusDp * dp;
    }

    // ------------------------------------------------------------------ touch

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        int action = e.getActionMasked();
        switch (action) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_POINTER_DOWN: {
                int i = e.getActionIndex();
                pointerDown(e.getPointerId(i), e.getX(i), e.getY(i));
                break;
            }
            case MotionEvent.ACTION_MOVE:
                for (int i = 0; i < e.getPointerCount(); i++)
                    pointerMove(e.getPointerId(i), e.getX(i), e.getY(i));
                break;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_POINTER_UP: {
                pointerUp(e.getPointerId(e.getActionIndex()));
                break;
            }
            case MotionEvent.ACTION_CANCEL:
                releaseAllControls();
                break;
        }
        invalidate();
        return true;   // all touches belong to the controls while they're shown
    }

    private void pointerDown(int id, float x, float y) {
        Button b = hit(x, y);
        if (b == null && x < stickZoneRight && stickPointer == -1) {
            stickPointer = id;
            boolean floating = overlay.settings.stick == Settings.STICK_FLOATING;
            baseX = floating ? x : dpadX;
            baseY = floating ? y : dpadY;
            updateStick(x, y);
            return;
        }
        pointerButtons.put(id, b);
        if (b != null) pressButton(b);
    }

    private void pointerMove(int id, float x, float y) {
        if (id == stickPointer) {
            updateStick(x, y);
            return;
        }
        if (pointerButtons.indexOfKey(id) < 0) return;
        Button old = pointerButtons.get(id);
        Button now = hit(x, y);
        if (now == old) return;
        if (old != null) releaseButton(old);
        if (now != null) pressButton(now);
        pointerButtons.put(id, now);
    }

    private void pointerUp(int id) {
        if (id == stickPointer) {
            stickPointer = -1;
            setStickDirs(0);
            return;
        }
        Button b = pointerButtons.get(id);
        pointerButtons.remove(id);
        if (b != null) releaseButton(b);
    }

    private Button hit(float x, float y) {
        Button best = null;
        float bestDist = Float.MAX_VALUE;
        for (Button b : buttons) {
            float dx = x - b.x, dy = y - b.y;
            float dist = (float) Math.sqrt(dx * dx + dy * dy);
            if (dist < b.r * 1.3f && dist < bestDist) {
                best = b;
                bestDist = dist;
            }
        }
        return best;
    }

    private void pressButton(Button b) {
        if (b.holders++ == 0) {
            overlay.press(b.key);
            if (overlay.settings.haptics) performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
        }
    }

    private void releaseButton(Button b) {
        if (b.holders > 0 && --b.holders == 0) overlay.release(b.key);
    }

    private void updateStick(float x, float y) {
        float dx = x - baseX, dy = y - baseY;
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        // The floating base follows a finger that goes past the edge, so reversing is quick.
        if (overlay.settings.stick == Settings.STICK_FLOATING && len > stickRadius) {
            baseX = x - dx / len * stickRadius;
            baseY = y - dy / len * stickRadius;
            dx = x - baseX;
            dy = y - baseY;
            len = stickRadius;
        }
        knobX = baseX + (len > stickRadius ? dx / len * stickRadius : dx);
        knobY = baseY + (len > stickRadius ? dy / len * stickRadius : dy);
        int dirs = 0;
        if (len > deadZone) {
            float nx = dx / len, ny = -dy / len;
            if (nx > 0.38f) dirs |= DIR_RIGHT;
            if (nx < -0.38f) dirs |= DIR_LEFT;
            // Up is also Jump in the game's keyboard layout: only near-vertical counts.
            if (ny > 0.6f) dirs |= DIR_UP;
            if (ny < -0.38f) dirs |= DIR_DOWN;
        }
        setStickDirs(dirs);
    }

    private void setStickDirs(int dirs) {
        int changed = dirs ^ stickDirs;
        if (changed == 0) return;
        toggle(changed, dirs, DIR_LEFT, KEY_LEFT);
        toggle(changed, dirs, DIR_RIGHT, KEY_RIGHT);
        toggle(changed, dirs, DIR_UP, KEY_UP);
        toggle(changed, dirs, DIR_DOWN, KEY_DOWN);
        stickDirs = dirs;
    }

    private void toggle(int changed, int dirs, int dir, int key) {
        if ((changed & dir) == 0) return;
        if ((dirs & dir) != 0) overlay.press(key);
        else overlay.release(key);
    }

    void releaseAllControls() {
        stickPointer = -1;
        setStickDirs(0);
        for (int i = 0; i < pointerButtons.size(); i++) {
            Button b = pointerButtons.valueAt(i);
            if (b != null) releaseButton(b);
        }
        pointerButtons.clear();
        invalidate();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (!hasFocus) releaseAllControls();
    }

    @Override
    protected void onVisibilityChanged(View changedView, int visibility) {
        super.onVisibilityChanged(changedView, visibility);
        if (visibility != VISIBLE) releaseAllControls();
    }

    // ------------------------------------------------------------------ drawing

    @Override
    protected void onDraw(Canvas canvas) {
        if (dp == 0) return;
        stroke.setStrokeWidth(2 * dp);
        drawStick(canvas);
        for (Button b : buttons) drawButton(canvas, b);
    }

    private void drawButton(Canvas canvas, Button b) {
        boolean down = b.holders > 0;
        fill.setColor(down ? 0xFFFFFFFF : 0xFF000000);
        fill.setAlpha(down ? alpha * 3 / 4 : alpha / 2);
        canvas.drawCircle(b.x, b.y, b.r, fill);
        stroke.setColor(0xFFFFFFFF);
        stroke.setAlpha(alpha);
        canvas.drawCircle(b.x, b.y, b.r, stroke);

        int ink = down ? 0xFF000000 : 0xFFFFFFFF;
        if (b == pause) {
            fill.setColor(ink);
            fill.setAlpha(alpha);
            float w = 3.5f * dp, h = 8 * dp, g = 3 * dp;
            canvas.drawRect(b.x - g - w, b.y - h, b.x - g, b.y + h, fill);
            canvas.drawRect(b.x + g, b.y - h, b.x + g + w, b.y + h, fill);
            return;
        }
        text.setColor(ink);
        text.setAlpha(alpha);
        text.setTextSize((b.small ? 10 : 12) * dp);
        canvas.drawText(b.label, b.x, b.y - (text.ascent() + text.descent()) / 2, text);
    }

    private void drawStick(Canvas canvas) {
        boolean floating = overlay.settings.stick == Settings.STICK_FLOATING;
        boolean active = stickPointer != -1;
        float cx = floating && active ? baseX : dpadX;
        float cy = floating && active ? baseY : dpadY;

        fill.setColor(0xFF000000);
        fill.setAlpha(floating && !active ? alpha / 4 : alpha / 2);
        canvas.drawCircle(cx, cy, stickRadius, fill);
        stroke.setColor(0xFFFFFFFF);
        stroke.setAlpha(floating && !active ? alpha / 2 : alpha);
        canvas.drawCircle(cx, cy, stickRadius, stroke);

        // Direction arrows, lit while held.
        drawArrow(canvas, cx, cy, 0, (stickDirs & DIR_RIGHT) != 0);
        drawArrow(canvas, cx, cy, 90, (stickDirs & DIR_DOWN) != 0);
        drawArrow(canvas, cx, cy, 180, (stickDirs & DIR_LEFT) != 0);
        drawArrow(canvas, cx, cy, 270, (stickDirs & DIR_UP) != 0);

        if (floating && active) {
            fill.setColor(0xFFFFFFFF);
            fill.setAlpha(alpha * 3 / 4);
            canvas.drawCircle(knobX, knobY, 26 * dp, fill);
        }
    }

    private void drawArrow(Canvas canvas, float cx, float cy, float degrees, boolean lit) {
        float tip = stickRadius * 0.82f, back = stickRadius * 0.55f, half = 11 * dp;
        arrow.reset();
        arrow.moveTo(tip, 0);
        arrow.lineTo(back, -half);
        arrow.lineTo(back, half);
        arrow.close();
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(degrees);
        fill.setColor(lit ? 0xFFE8342A : 0xFFFFFFFF);
        fill.setAlpha(lit ? Math.max(alpha, 200) : alpha * 2 / 3);
        canvas.drawPath(arrow, fill);
        canvas.restore();
    }
}
