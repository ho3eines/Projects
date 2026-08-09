window.keyboardShortcutService = (function () {
    let shortcuts = [];
    let dotNetHelper = null;

    function handleKeyDown(e) {
        if (!shortcuts || shortcuts.length === 0) return;

        const key = e.key.toLowerCase();
        const ctrl = e.ctrlKey;
        const alt = e.altKey;
        const shift = e.shiftKey;

        const matched = shortcuts.find(s =>
            s.code.toLowerCase() === key &&
            s.ctrl === ctrl &&
            s.alt === alt &&
            s.shift === shift
        );

        if (matched && dotNetHelper) {
            console.log("🔑 Shortcut matched:", matched);
            e.preventDefault();
            dotNetHelper.invokeMethodAsync("HandleShortcut", matched.func);
        }
    }

    function register(dotnetRef, loadedShortcuts) {
        unregister();

        if (!Array.isArray(loadedShortcuts)) {
            console.error("❌ Invalid shortcuts received:", loadedShortcuts);
            return;
        }

        console.log("✅ Registering keyboard shortcuts:");
        loadedShortcuts.forEach((s, i) => {
            console.log(`(${i}) Func: ${s.func}, Code: ${s.code}, Ctrl: ${s.ctrl}, Alt: ${s.alt}, Shift: ${s.shift}`);
        });

        dotNetHelper = dotnetRef;
        shortcuts = loadedShortcuts;

        window.addEventListener("keydown", handleKeyDown);
    }

    function unregister() {
        window.removeEventListener("keydown", handleKeyDown);
        dotNetHelper = null;
        shortcuts = [];
    }

    return {
        register,
        unregister
    };
})();

window.ensureShortcutBarInBody = function (barId) {
    const bar = document.getElementById(barId);
    if (bar) {
        if (bar.parentNode !== document.body) {
            document.body.appendChild(bar);
        }

        // فعال کردن حالت "show"
        setTimeout(() => {
            bar.classList.add("show");
        }, 10);
    }
};

window.removeShortcutBarFromBody = function (barId) {
    const bar = document.getElementById(barId);
    if (bar && bar.parentNode === document.body) {
        bar.classList.remove("show");
        //setTimeout(() => {
        //    if (bar.parentNode === document.body) {
        //        bar.remove();
        //    }
        //}, 400);
    }
};


window.shortcutKeyInput = {
    listenOnce: function (element, dotNetRef) {
        if (!element) return;

        const handler = (e) => {
            // اگر فقط کلیدهای ترکیبی بود، صبر کن
            if (["Control", "Shift", "Alt"].includes(e.key)) return;

            e.preventDefault();
            e.stopPropagation();

            const shortcut = {
                key: e.key.length === 1 ? e.key.toUpperCase() : e.key,
                ctrl: e.ctrlKey,
                alt: e.altKey,
                shift: e.shiftKey
            };

            dotNetRef.invokeMethodAsync("SetShortcut", shortcut);

            element.removeEventListener("keydown", handler);
        };

        setTimeout(() => {
            element.focus();
            element.addEventListener("keydown", handler);
        }, 50);
    }
};

window.deviceHelper = {
    isMobile: function () {
        return window.matchMedia("(max-width: 768px)").matches;
    },
    getWidth: function () {
        return window.innerWidth;
    }
};

setTimeout(() => window.ensureShortcutBarInBody(), 300);