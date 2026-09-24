package bitter.jnibridge;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

/**
 * Drop-in replacement for the JNIBridge class in Unity 2017.4's Android player
 * (classes.jar), which backs AndroidJavaProxy and the engine's own Java callbacks.
 * Same class, method and field signatures as the original, because libunity.so
 * calls them through JNI.
 *
 * The fix: newer Android versions add default methods to framework interfaces, e.g.
 * Android 16's ServiceConnection.onServiceConnected(ComponentName, IBinder,
 * IBinderSession). The platform calls the new overload on our proxy; the original
 * bridge forwards it to native code, which doesn't know it and throws
 * NoSuchMethodError, killing the app. Here, when that happens on a default method,
 * we do what the interface's default body does: call the overload with the same
 * name and the leading arguments. If there is none, the callback is dropped.
 *
 * Installed by scripts/patch-unity-player.ps1.
 */
public class JNIBridge {
    static native Object invoke(long ptr, Class clazz, Method method, Object[] args);

    static native void delete(long ptr);

    static Object newInterfaceProxy(long ptr, Class[] interfaces) {
        return Proxy.newProxyInstance(JNIBridge.class.getClassLoader(), interfaces, new a(ptr));
    }

    static void disableInterfaceProxy(Object proxy) {
        ((a) Proxy.getInvocationHandler(proxy)).a();
    }

    static final class a implements InvocationHandler {
        private Object a = new Object[0];   // lock
        private long b;                     // native proxy pointer, 0 once disabled

        public a(long ptr) {
            b = ptr;
        }

        public final Object invoke(Object proxy, Method method, Object[] args) {
            synchronized (a) {
                if (b == 0L) {
                    return null;
                }
                try {
                    return JNIBridge.invoke(b, method.getDeclaringClass(), method, args);
                } catch (NoSuchMethodError e) {
                    if (!isDefault(method)) {
                        throw e;
                    }
                    Method target = shorterOverload(method, args);
                    if (target == null) {
                        return null;
                    }
                    Object[] shorter = new Object[target.getParameterTypes().length];
                    System.arraycopy(args, 0, shorter, 0, shorter.length);
                    return JNIBridge.invoke(b, target.getDeclaringClass(), target, shorter);
                }
            }
        }

        public final void finalize() {
            synchronized (a) {
                if (b == 0L) {
                    return;
                }
                JNIBridge.delete(b);
            }
        }

        public final void a() {
            synchronized (a) {
                b = 0L;
            }
        }

        private static boolean isDefault(Method method) {
            try {
                return method.isDefault();
            } catch (Throwable t) {   // Method.isDefault() only exists on API 24+
                return false;
            }
        }

        /** The longest overload whose parameters are a strict prefix of method's. */
        private static Method shorterOverload(Method method, Object[] args) {
            Class<?>[] params = method.getParameterTypes();
            Method best = null;
            for (Method m : method.getDeclaringClass().getMethods()) {
                if (!m.getName().equals(method.getName()) || isDefault(m)) {
                    continue;
                }
                Class<?>[] p = m.getParameterTypes();
                if (p.length >= params.length || args == null || p.length > args.length) {
                    continue;
                }
                boolean prefix = true;
                for (int i = 0; i < p.length && prefix; i++) {
                    prefix = p[i] == params[i];
                }
                if (prefix && (best == null || p.length > best.getParameterTypes().length)) {
                    best = m;
                }
            }
            return best;
        }
    }
}
