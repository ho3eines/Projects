/* subnav.js — نشانگر کشویی زیر تب‌های زیرمنوی ماژول (tz-subnav__indicator)
   Measure-and-move: Blazor پس از هر رندر `tarazinSubnav.sync()` را صدا می‌زند؛
   این تابع تبِ فعال را اندازه می‌گیرد و نوار را با transform می‌برد زیر آن.
   هیچ وابستگی به MudBlazor ندارد و در RTL هم درست کار می‌کند (فقط مختصات هندسی). */
(function (global) {
    'use strict';

    function findActive(container) {
        return container.querySelector('.tz-subnav__tab.is-active');
    }

    /* مختصات نوار نسبت به خودِ .tz-subnav__tabs (مرجعِ absolute نوار) */
    function measure(tabsEl, active) {
        var tr = tabsEl.getBoundingClientRect();
        var ar = active.getBoundingClientRect();
        /* getBoundingClientRect خودش direction را حل می‌کند؛ پس در RTL هم
           left/width نسبت به viewport سالم است و نیازی به scrollLeft نیست. */
        return { left: ar.left - tr.left, width: ar.width };
    }

    function apply(tabsEl, indicator, active) {
        var m = measure(tabsEl, active);
        /* max(0) برای گاردهای مقاوم به zoomهای غیرعددی (۱۲۵٪ ویندوز و …) */
        indicator.style.width = Math.max(0, m.width) + 'px';
        indicator.style.transform = 'translateX(' + m.left + 'px)';
        indicator.style.opacity = '1';
        indicator.dataset.ready = '1';
        return m;
    }

    /* رصد تغییر اندازهٔ نوار تب‌ها: بارگذاری دیرهنگام فونت، زوم یا تغییر
       بریک‌پوینت جای تب‌ها را عوض می‌کند بی‌آنکه Blazor رندر کند —
       پس خودمان نشانگر را دوباره می‌بریم زیر تب فعال. */
    var ro = typeof ResizeObserver === 'function' ? new ResizeObserver(function (entries) {
        for (var i = 0; i < entries.length; i++) {
            var tabsEl = entries[i].target;
            var container = tabsEl.closest ? tabsEl.closest('.tz-subnav') : null;
            if (container) sync(container);
        }
    }) : null;

    function sync(container) {
        if (!container) return false;
        var tabsEl = container.querySelector('.tz-subnav__tabs');
        if (!tabsEl) return false;
        if (ro && tabsEl.dataset.observed !== '1') {
            tabsEl.dataset.observed = '1';
            ro.observe(tabsEl);
        }
        var indicator = tabsEl.querySelector('.tz-subnav__indicator');
        if (!indicator) return false;
        var active = findActive(container);
        if (!active) {
            /* این ماژول هیچ زیرصفحهٔ مجازی برای کاربر ندارد → نوار پنهان بماند */
            indicator.style.opacity = '0';
            indicator.dataset.ready = '0';
            return false;
        }
        apply(tabsEl, indicator, active);
        return true;
    }

    global.tarazinSubnav = { sync: sync, apply: apply };
})(window);
