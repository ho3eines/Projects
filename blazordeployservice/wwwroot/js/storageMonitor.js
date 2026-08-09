// ============================================
// storageMonitor.js
// مدیریت localStorage و تشخیص پاک شدن آن
// ============================================

// نگهداری مقدار اصلی برای مقایسه
let originalClientId = null;
let dotNetReference = null;
let isMonitoring = false;

/**
 * راه‌اندازی مانیتورینگ storage
 * @param {DotNetObjectReference} dotNetRef - reference به .NET
 */
export function setupStorageMonitoring(dotNetRef) {
    if (isMonitoring) return;

    dotNetReference = dotNetRef;
    originalClientId = localStorage.getItem('clientId');

    // 1. گوش دادن به رویداد storage (کم‌هزینه)
    window.addEventListener('storage', handleStorageEvent);

    // 2. تشخیص پاک شدن localStorage در همین تب
    hijackLocalStorageMethods();

    // 3. چک هنگام بازگشت به تب
    document.addEventListener('visibilitychange', handleVisibilityChange);

    // 4. چک نهایی هنگام بسته شدن
    window.addEventListener('beforeunload', handleBeforeUnload);

    isMonitoring = true;
    console.log('Storage monitoring started');
}

/**
 * دریافت یا ایجاد شناسه کاربر
 * @returns {string} شناسه کاربر
 */
export function getOrCreateClientId() {
    let clientId = localStorage.getItem('clientId');

    if (!clientId) {
        // ایجاد شناسه جدید
        clientId = generateClientId();
        localStorage.setItem('clientId', clientId);
        console.log('New client ID created:', clientId);

        // ذخیره در sessionStorage به عنوان بکاپ
        sessionStorage.setItem('clientId_backup', clientId);

        // ذخیره در cookie به عنوان بکاپ دوم
        setCookie('clientId_backup', clientId, 365);

        // علامت‌گذاری که localStorage پاک شده بود
        sessionStorage.setItem('storage_was_cleared', 'true');
    } else {
        // بروزرسانی بکاپ‌ها
        sessionStorage.setItem('clientId_backup', clientId);
        setCookie('clientId_backup', clientId, 365);
    }

    originalClientId = clientId;
    return clientId;
}

/**
 * تولید شناسه یکتا برای کاربر
 * @returns {string}
 */
function generateClientId() {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substr(2, 9);
    const userAgent = navigator.userAgent.substr(0, 5).toLowerCase();

    return `cid-${userAgent}-${timestamp}-${random}`;
}

/**
 * هندل رویداد تغییرات storage
 */
function handleStorageEvent(event) {
    if (event.key === 'clientId') {
        if (event.newValue === null && event.oldValue !== null) {
            // localStorage پاک شده است
            notifyStorageCleared('storage_event');
        } else if (event.newValue !== event.oldValue) {
            // مقدار تغییر کرده
            originalClientId = event.newValue;
        }
    }
}

/**
 * هک متدهای localStorage برای تشخیص پاک شدن
 */
function hijackLocalStorageMethods() {
    const originalSetItem = localStorage.setItem;
    const originalRemoveItem = localStorage.removeItem;
    const originalClear = localStorage.clear;

    // رهگیری setItem
    localStorage.setItem = function (key, value) {
        if (key === 'clientId') {
            originalClientId = value;
        }
        return originalSetItem.apply(this, arguments);
    };

    // رهگیری removeItem
    localStorage.removeItem = function (key) {
        if (key === 'clientId' && originalClientId) {
            notifyStorageCleared('remove_item');
        }
        return originalRemoveItem.apply(this, arguments);
    };

    // رهگیری clear
    localStorage.clear = function () {
        if (originalClientId) {
            notifyStorageCleared('clear_method');
        }
        return originalClear.apply(this, arguments);
    };
}

/**
 * هنگام تغییر visibility صفحه
 */
function handleVisibilityChange() {
    if (!document.hidden) {
        // کاربر به تب برگشته
        setTimeout(() => {
            const currentClientId = localStorage.getItem('clientId');
            if (!currentClientId && originalClientId) {
                notifyStorageCleared('visibility_change');
            }
        }, 100);
    }
}

/**
 * هنگام بسته شدن پنجره
 */
function handleBeforeUnload() {
    const currentClientId = localStorage.getItem('clientId');

    if (!currentClientId && originalClientId) {
        // ارسال آخرین گزارش با Beacon API
        const data = JSON.stringify({
            clientId: originalClientId,
            timestamp: new Date().toISOString(),
            reason: 'before_unload'
        });

        navigator.sendBeacon('/api/client/storage-cleared', data);
    }
}

/**
 * اطلاع به .NET درباره پاک شدن storage
 */
function notifyStorageCleared(reason) {
    if (dotNetReference) {
        try {
            dotNetReference.invokeMethodAsync('OnStorageCleared', reason);
        } catch (error) {
            console.warn('Could not notify .NET:', error);
        }
    }

    // ذخیره در sessionStorage برای بازیابی بعدی
    sessionStorage.setItem('storage_cleared_reason', reason);
    sessionStorage.setItem('storage_cleared_time', Date.now());

    console.warn(`LocalStorage cleared detected! Reason: ${reason}`);
}

/**
 * تنظیم cookie
 */
function setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString();
    document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Lax`;
}

/**
 * دریافت cookie
 */
export function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    return parts.length === 2 ? decodeURIComponent(parts.pop().split(';').shift()) : null;
}

/**
 * توقف مانیتورینگ
 */
export function stopMonitoring() {
    if (!isMonitoring) return;

    window.removeEventListener('storage', handleStorageEvent);
    document.removeEventListener('visibilitychange', handleVisibilityChange);
    window.removeEventListener('beforeunload', handleBeforeUnload);

    isMonitoring = false;
    console.log('Storage monitoring stopped');
}