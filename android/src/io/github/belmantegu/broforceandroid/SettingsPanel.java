package io.github.belmantegu.broforceandroid;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Quick settings, sliding in from the right edge. A small handle on the edge opens it
 * (drag it left, or tap it); tapping outside the panel or CLOSE closes it.
 */
final class SettingsPanel extends FrameLayout {
    private static final int ACCENT = 0xFFE8342A;
    private static final int PANEL_BG = 0xF0141414;

    private final Overlay overlay;
    private final Settings settings;
    private final float dp;
    private final View scrim;
    private final ScrollView panel;
    private final Handle handle;
    private final List<Runnable> refreshers = new ArrayList<Runnable>();
    private TextView gamepadStatus;
    private boolean open;

    SettingsPanel(Context context, Overlay overlay) {
        super(context);
        this.overlay = overlay;
        this.settings = overlay.settings;
        dp = context.getResources().getDisplayMetrics().density;

        scrim = new View(context);
        scrim.setBackgroundColor(0x66000000);
        scrim.setVisibility(GONE);
        scrim.setOnClickListener(new OnClickListener() {
            @Override public void onClick(View v) { setOpen(false); }
        });
        addView(scrim, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

        panel = new ScrollView(context);
        panel.setBackgroundColor(PANEL_BG);
        panel.setVisibility(GONE);
        panel.addView(buildContent(context));
        addView(panel, new LayoutParams(px(330), LayoutParams.MATCH_PARENT, Gravity.END));

        handle = new Handle(context);
        LayoutParams hp = new LayoutParams(px(26), px(64), Gravity.END | Gravity.TOP);
        hp.topMargin = px(84);
        addView(handle, hp);
    }

    private int px(float dips) { return Math.round(dips * dp); }

    // ------------------------------------------------------------------ open / close

    void setOpen(boolean value) {
        if (open == value) return;
        open = value;
        overlay.setPanelOpen(value);
        if (value) {
            refresh();
            scrim.setVisibility(VISIBLE);
            panel.setVisibility(VISIBLE);
            panel.setTranslationX(px(330));
            panel.animate().translationX(0).setDuration(160).start();
            handle.setVisibility(GONE);
        } else {
            panel.animate().translationX(px(330)).setDuration(140).withEndAction(new Runnable() {
                @Override public void run() {
                    panel.setVisibility(GONE);
                    scrim.setVisibility(GONE);
                    handle.setVisibility(VISIBLE);
                }
            }).start();
        }
    }

    /** Re-reads the settings and the gamepad state into the widgets. */
    void refresh() {
        for (Runnable r : refreshers) r.run();
        if (gamepadStatus != null)
            gamepadStatus.setText(overlay.isGamepadConnected() ? "Gamepad connected" : "No gamepad connected");
    }

    private void changed() {
        settings.save();
        overlay.apply();
        refresh();
    }

    // ------------------------------------------------------------------ content

    private View buildContent(Context context) {
        LinearLayout box = new LinearLayout(context);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(px(20), px(18), px(20), px(20));

        TextView title = label(context, "BROFORCE ANDROID", 18, true);
        title.setTextColor(ACCENT);
        box.addView(title);
        gamepadStatus = label(context, "", 12, false);
        gamepadStatus.setTextColor(0xFFAAAAAA);
        box.addView(gamepadStatus);

        section(box, context, "On-screen controls");
        box.addView(choice(context, new String[] { "Auto", "On", "Off" }, new Choice() {
            @Override public int get() { return settings.controls; }
            @Override public void set(int v) { settings.controls = v; }
        }));
        TextView hint = label(context, "Auto hides them while a gamepad is connected.", 11, false);
        hint.setTextColor(0xFF888888);
        box.addView(hint);

        section(box, context, "Movement");
        box.addView(choice(context, new String[] { "Floating stick", "D-pad" }, new Choice() {
            @Override public int get() { return settings.stick; }
            @Override public void set(int v) { settings.stick = v; }
        }));

        section(box, context, "Opacity");
        box.addView(slider(context, 20, 100, new Choice() {
            @Override public int get() { return settings.opacity; }
            @Override public void set(int v) { settings.opacity = v; }
        }));

        section(box, context, "Size");
        box.addView(slider(context, 60, 150, new Choice() {
            @Override public int get() { return settings.size; }
            @Override public void set(int v) { settings.size = v; }
        }));

        section(box, context, "Screen");
        box.addView(choice(context, new String[] { "Full", "Avoid cutout", "16:9" }, new Choice() {
            @Override public int get() { return settings.screen; }
            @Override public void set(int v) { settings.screen = v; }
        }));

        section(box, context, "Vibration");
        box.addView(choice(context, new String[] { "On", "Off" }, new Choice() {
            @Override public int get() { return settings.haptics ? 0 : 1; }
            @Override public void set(int v) { settings.haptics = v == 0; }
        }));

        TextView close = label(context, "CLOSE", 14, true);
        close.setGravity(Gravity.CENTER);
        close.setPadding(0, px(12), 0, px(12));
        close.setBackground(rounded(ACCENT, 0));
        close.setOnClickListener(new OnClickListener() {
            @Override public void onClick(View v) { setOpen(false); }
        });
        LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        cp.topMargin = px(22);
        box.addView(close, cp);
        return box;
    }

    private interface Choice {
        int get();
        void set(int value);
    }

    private TextView label(Context context, String s, int sp, boolean bold) {
        TextView t = new TextView(context);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(0xFFFFFFFF);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    private void section(LinearLayout box, Context context, String name) {
        TextView t = label(context, name.toUpperCase(), 12, true);
        t.setTextColor(0xFFCCCCCC);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = px(16);
        lp.bottomMargin = px(6);
        box.addView(t, lp);
    }

    private GradientDrawable rounded(int color, int strokeColor) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(px(6));
        if (strokeColor != 0) d.setStroke(px(1), strokeColor);
        return d;
    }

    /** A row of mutually exclusive options. */
    private View choice(Context context, String[] options, final Choice choice) {
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        final TextView[] views = new TextView[options.length];
        for (int i = 0; i < options.length; i++) {
            final int value = i;
            TextView t = label(context, options[i], 13, true);
            t.setGravity(Gravity.CENTER);
            t.setPadding(px(6), px(9), px(6), px(9));
            t.setOnClickListener(new OnClickListener() {
                @Override public void onClick(View v) {
                    choice.set(value);
                    changed();
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            if (i > 0) lp.leftMargin = px(6);
            row.addView(t, lp);
            views[i] = t;
        }
        refreshers.add(new Runnable() {
            @Override public void run() {
                for (int i = 0; i < views.length; i++) {
                    boolean on = choice.get() == i;
                    views[i].setBackground(on ? rounded(ACCENT, 0) : rounded(0xFF2A2A2A, 0xFF444444));
                    views[i].setTextColor(on ? 0xFFFFFFFF : 0xFFBBBBBB);
                }
            }
        });
        return row;
    }

    /** A slider with its value in percent. */
    private View slider(Context context, final int min, int max, final Choice choice) {
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        final SeekBar bar = new SeekBar(context);
        bar.setMax(max - min);
        bar.setProgressTintList(ColorStateList.valueOf(ACCENT));
        bar.setThumbTintList(ColorStateList.valueOf(ACCENT));
        final TextView value = label(context, "", 13, true);
        value.setGravity(Gravity.END);
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int progress, boolean fromUser) {
                value.setText((progress + min) + "%");
                if (fromUser) {
                    choice.set(progress + min);
                    settings.save();
                    overlay.apply();
                }
            }
            @Override public void onStartTrackingTouch(SeekBar s) { }
            @Override public void onStopTrackingTouch(SeekBar s) { }
        });
        row.addView(bar, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        row.addView(value, new LinearLayout.LayoutParams(px(48), ViewGroup.LayoutParams.WRAP_CONTENT));
        refreshers.add(new Runnable() {
            @Override public void run() {
                bar.setProgress(choice.get() - min);
                value.setText(choice.get() + "%");
            }
        });
        return row;
    }

    // ------------------------------------------------------------------ handle

    /** The tab on the right edge: drag it left or tap it to open the panel. */
    private final class Handle extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF shape = new RectF();
        private float downX;

        Handle(Context context) {
            super(context);
        }

        @Override
        protected void onLayout(boolean changed, int l, int t, int r, int b) {
            super.onLayout(changed, l, t, r, b);
            Overlay.excludeFromSystemGestures(this,
                Collections.singletonList(new Rect(0, 0, r - l, b - t)));
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float w = getWidth(), h = getHeight(), r = px(8);
            paint.setColor(0x99000000);
            shape.set(0, 0, w + r, h);
            canvas.drawRoundRect(shape, r, r, paint);
            paint.setColor(0xCCFFFFFF);
            float x = w * 0.5f, dot = px(2.2f);
            for (int i = -1; i <= 1; i++) canvas.drawCircle(x, h / 2 + i * px(8), dot, paint);
        }

        @Override
        public boolean onTouchEvent(MotionEvent e) {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX = e.getRawX();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    if (downX - e.getRawX() > px(24)) setOpen(true);
                    return true;
                case MotionEvent.ACTION_UP:
                    if (Math.abs(downX - e.getRawX()) < px(10)) setOpen(true);
                    return true;
            }
            return true;
        }
    }
}
