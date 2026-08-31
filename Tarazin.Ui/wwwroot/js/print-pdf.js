// print-pdf.js — چاپ برگه و دانلود PDF از پیش‌نمایش چاپ
// مسیر چاپ: برگه در iframe/پنجرهٔ جدا با فقط همان HTML باز می‌شود تا والدهای
// صفحه (مثل فرم تنظیمات دیزاینر) فضای چاپ را اشغال نکنند (صفحات سفید اضافه نسازند)
// و @page تکی (A4/A5 عمودی/افقی) بدون تداخل اعمال شود.
window.tarazin = window.tarazin || {};

// HTMLِ واقعیِ برگه (با QR svgهای پر شده توسط tarazinQr.fillAll) را از DOM می‌گیرد.
// برگشتن به‌جای BuildHtml خام تضمین می‌کند QRCode و لوگو در چاپ هم دیده می‌شوند.
window.tarazin.getActiveSheetHtml = function () {
    var s = document.querySelector('.tpl-print-stage .tpl-sheet, .tpl-sheet, .gp-print-area, .cq-print-area');
    return s ? s.outerHTML : null;
};

// چاپ فقطِ HTML برگه در iframe جدا — هیچ عنصر دیگری از صفحهٔ مبدا در چاپ نمی‌آید.
// html: خروجی PrintSheetRenderer.BuildHtml (فقط .tpl-sheet)
// returns: true اگر پنجرهٔ چاپ باز شد
window.tarazin.printHtml = function (html, title) {
    try {
        const cssUrl = new URL('_content/Tarazin.Ui/css/app.css', window.location.href).href;
        const frame = document.createElement('iframe');
        frame.id = 'tarazin-print-frame';
        frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;';
        document.body.appendChild(frame);

        const doc = frame.contentWindow.document;
        doc.open();
        doc.write('<!DOCTYPE html><html dir="rtl" lang="fa"><head><meta charset="utf-8">');
        doc.write('<title>' + (title || 'چاپ') + '</title>');
        doc.write('<link rel="stylesheet" href="' + cssUrl + '">');
        doc.write('</head><body>' + html + '</body></html>');
        doc.close();

        // در iframe چاپ هر <qr-fill> placeholder مانده‌ای را هم پر کن تا QR حتماً روی کاغذ بیاید
        try {
            const qrScr = new URL('_content/Tarazin.Ui/js/qrcode.js', window.location.href).href;
            const brScr = new URL('_content/Tarazin.Ui/js/brand.js', window.location.href).href;
            var s = document.createElement('script'); s.src = qrScr; frame.contentWindow.document.head.appendChild(s);
            var b = document.createElement('script'); b.src = brScr; frame.contentWindow.document.head.appendChild(b);
            b.onload = function () {
                try { if (frame.contentWindow.tarazinQr) frame.contentWindow.tarazinQr.fillAll(); } catch (e) {}
            };
        } catch (e) {}

        // صبر تا فونت و CSS لود شوند، سپس چاپ
        const win = frame.contentWindow;
        const doPrint = function () {
            // در WebView/headless بدون دیالوگ چاپ، window.print مسدود می‌شود —
            // اگر صفحه از پیش اعلام کرده که print را هندل می‌کند (stub)، از آن استفاده کن.
            const fn = (typeof window.tarazinPrintOverride === 'function')
                ? window.tarazinPrintOverride
                : win.print.bind(win);
            try { fn(); } finally {
                setTimeout(function () { frame.remove(); }, 2000);
            }
        };
        if (doc.readyState === 'complete') doPrint();
        else win.addEventListener('load', doPrint);
        return true;
    } catch (e) {
        console.error('printHtml failed', e);
        return false;
    }
};

// دانلود بایت‌های PDF ساخته‌شده توسط PdfReportService (QuestPDF) به‌صورت بلاب —
// روی وب (Blazor Server) و WebView هر دو کار می‌کند؛ بدون دیالوگ پرینتر.
//
// ضد-تکرار: همهٔ درخواست‌های دانلود از یک صف سریالی می‌گذرند تا دو کلیک متوالی هم‌زمان
// (در WebView پیش‌نمایش یا مرورگر واقعی) بایکدیگر تداخل نکنند و نام فایل را خراب نکنند
// (مشکل «فایل فقط و.pdf می‌شود» که از race دو دانلود موازی ناشی بود).
// - اگر هم‌زمان دو دانلود با همان نام درخواست شود، دومی dedupe می‌شود (نادیده) چون
//   خروجی بایتی یکسانی دارد و فقط یک فایل برای همان نام کافی است.
// - در غیر این صورت درخواست صف می‌شود و پس از پایان قبلی اجرا می‌شود؛ برنگشت داده نمی‌شود.
window.tarazin._downloadQueue = window.tarazin._downloadQueue || Promise.resolve();
window.tarazin._lastDownloadName = null;
window.tarazin.downloadPdfBytes = async function (fileName, base64) {
    const file = fileName || 'document.pdf';
    // dedupe: همان نام هنوز در حال دانلود/در صف است — بیت‌ها یکسان‌اند، رد کن.
    if (window.tarazin._lastDownloadName === file) return true;

    const run = async function () {
        try {
            const binary = atob(base64);
            const bytes = new Uint8Array(binary.length);
            for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
            const blob = new Blob([bytes], { type: 'application/pdf' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = file;
            document.body.appendChild(a);
            a.click();
            setTimeout(function () { a.remove(); URL.revokeObjectURL(url); }, 3000);
            return true;
        } catch (e) {
            console.error('downloadPdfBytes failed', e);
            return false;
        }
    };

    // نام فعلی ثبت می‌شود تا dedupe همان کلیکِ الکی تکراری را بگیرد.
    window.tarazin._lastDownloadName = file;
    window.tarazin._downloadQueue = window.tarazin._downloadQueue.then(run, run);
    try { return await window.tarazin._downloadQueue; }
    finally { window.tarazin._lastDownloadName = null; }
};

// چاپ از همان بایت‌های PDF (QuestPDF) — ویوئر PDF مرورگر را در تب جدید باز می‌کند تا
// خروجی چاپ دقیقاً همان خروجی «دانلود PDF» باشد (بدون هیچ اختلاف HTML/PDF).
// روی دسکتاپ تب جدید باز می‌شود؛ در WebView/headless به iframe مخفی با window.print فالبک می‌کند.
window.tarazin.printPdfBytes = function (base64) {
    try {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        const blob = new Blob([bytes], { type: 'application/pdf' });
        const url = URL.createObjectURL(blob);
        const w = window.open(url, '_blank');
        if (w) {
            // تب جدید ویوئر PDF مرورگر را نشان می‌دهد؛ کاربر از همانجا چاپ می‌کند.
            setTimeout(() => URL.revokeObjectURL(url), 120000);
            return true;
        }
        // پاپ‌آپ مسدود شد (WebView/headless) — چاپ مستقیم از iframe مخفی.
        const frame = document.createElement('iframe');
        frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;';
        frame.src = url;
        document.body.appendChild(frame);
        frame.onload = function () {
            try { frame.contentWindow.print(); } catch (e) { console.error('iframe print failed', e); }
        };
        setTimeout(() => { try { frame.remove(); } catch (e) {} }, 60000);
        return true;
    } catch (e) {
        console.error('printPdfBytes failed', e);
        return false;
    }
};


// options: { fileName, paper: 'A4'|'A5', landscape: bool }
window.tarazin.downloadPdf = async function (element, options) {
    if (typeof html2pdf === 'undefined') {
        console.error('html2pdf not available');
        return false;
    }
    const opts = options || {};
    // برگهٔ پیش‌نمایش فعال (بالاترین دیالوگ دارای برگه)
    const sheet = element || (function () {
        const dialogs = Array.from(document.querySelectorAll('.mud-dialog'));
        for (let i = dialogs.length - 1; i >= 0; i--) {
            const s = dialogs[i].querySelector('.gp-preview-sheet, .cq-preview-sheet');
            if (s) return s;
        }
        return document.querySelector('.gp-preview-sheet, .cq-preview-sheet');
    })();

    if (!sheet) {
        console.error('no preview sheet found');
        return false;
    }

    // صبر تا فونت‌ها (Vazirmatn) لود شوند تا متن فارسی درست رندر شود
    try { await document.fonts.ready; } catch (e) { }

    const orientation = opts.landscape ? 'landscape' : 'portrait';
    const format = opts.paper === 'A5' ? 'a5' : 'a4';

    const worker = html2pdf()
        .set({
            margin: 0,
            filename: opts.fileName || 'report.pdf',
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: {
                scale: 2,
                useCORS: true,
                backgroundColor: '#ffffff',
                scrollX: 0,
                scrollY: 0,
                windowWidth: sheet.scrollWidth
            },
            jsPDF: { unit: 'mm', format: format, orientation: orientation },
            pagebreak: { mode: ['css', 'legacy'] }
        });
    await worker.from(sheet).save();
    return true;
};
