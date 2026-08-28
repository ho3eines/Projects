// print-pdf.js — دانلود PDF از برگهٔ پیش‌نمایش چاپ بدون دیالوگ پرینتر
// وابسته به html2pdf.bundle.min.js (html2canvas + jsPDF) — مسیر قدیمی html2pdf
// برای دانلود PDF ساخته‌شده توسط QuestPDF (سمت سرور / بومی) همچنان از همین فایل
// استفاده می‌شود (تابع downloadPdfBytes).
window.tarazin = window.tarazin || {};

// دانلود بایت‌های PDF ساخته‌شده توسط PdfReportService (QuestPDF) به‌صورت بلاب —
// روی وب (Blazor Server) و WebView هر دو کار می‌کند؛ بدون دیالوگ پرینتر.
window.tarazin.downloadPdfBytes = async function (fileName, base64) {
    try {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        const blob = new Blob([bytes], { type: 'application/pdf' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 4000);
        return true;
    } catch (e) {
        console.error('downloadPdfBytes failed', e);
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
