/* tarazinBrandLogo — آپلود لوگوی شرکت به base64 */
(function (global) {
    var currentDataUrl = null;

    global.tarazinBrandLogo = {
        read: function (input) {
            if (!input || !input.files || !input.files[0]) return;
            var f = input.files[0];
            var r = new FileReader();
            r.onload = function (e) {
                currentDataUrl = e.target.result;
                var h = document.getElementById('logoPathInput');
                if (h) h.value = currentDataUrl;
            };
            r.readAsDataURL(f);
        },
        takeCurrent: function () {
            var v = currentDataUrl;
            var h = document.getElementById('logoPathInput');
            if (h && h.value) v = h.value;
            return v || null;
        }
    };

    /* tarazinQr — تولید تصویر QRCode داخل <qr-fill> (با کتابخانهٔ qrcode.js) */
    function svgFromQr(qr, size) {
        var n = qr.getModuleCount(), cell = 2, m = 2;
        var dim = n * cell + m * 2;
        var s = '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size +
            '" viewBox="0 0 ' + dim + ' ' + dim + '" shape-rendering="crispEdges">' +
            '<rect width="100%" height="100%" fill="#ffffff"/>';
        for (var row = 0; row < n; row++) {
            for (var col = 0; col < n; col++) {
                if (qr.isDark(row, col)) {
                    s += '<rect x="' + (col * cell + m) + '" y="' + (row * cell + m) +
                        '" width="' + cell + '" height="' + cell + '" fill="#1a1a1a"/>';
                }
            }
        }
        return s + '</svg>';
    }

    function fillQrElement(el) {
        var text = el.getAttribute('data-payload') || '';
        var size = parseInt(el.getAttribute('data-size') || '110', 10);
        if (typeof global.qrcode === 'function') {
            try {
                var qr = global.qrcode(0, 'M');
                qr.addData(text);
                qr.make();
                el.innerHTML = svgFromQr(qr, size);
            } catch (e) {
                el.innerHTML = '<span style="color:#999;font-size:9pt">QR</span>';
            }
        } else {
            el.innerHTML = '<span style="color:#999;font-size:9pt">QR</span>';
        }
    }

    global.tarazinQr = {
        fillAll: function () {
            var els = document.querySelectorAll('qr-fill');
            for (var i = 0; i < els.length; i++) fillQrElement(els[i]);
        },
        fill: fillQrElement
    };

    // پر کردن خودکار پس از هر رندر
    if (document.readyState !== 'loading') global.tarazinQr.fillAll();
    document.addEventListener('DOMContentLoaded', function () { global.tarazinQr.fillAll(); });
    // Blazor بعد از هر render مجدداً فراخوانی می‌کند:
    if (typeof Blazor !== 'undefined' && Blazor.addInitializer) {
        Blazor.addInitializer(function () {
            document.addEventListener('blazor:end', function () { global.tarazinQr.fillAll(); });
        });
    }
})(window);

/* هشدار: برای اینکه بعد از هر رندر Blazor هم QRها دوباره پر شوند،
   صفحه‌های چاپ باید afterRender را روی این تابع صدا بزنند یا رویداد
   blazor:end در ریشه باشد. در دیالوگ‌های بازشونده (MudDialog) بهتر است
   خودِ دیالوگ در OnAfterRender برچسب را دوباره پر کند. */