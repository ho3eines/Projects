let clickOutsideHandler = null;

export function addClickListener(rootElement, dotNetHelper) {
    // اگر قبلاً لیستری وجود داشت، آن را حذف کن
    if (clickOutsideHandler) {
        removeClickListener();
    }

    clickOutsideHandler = (event) => {
        // بررسی کن که آیا کلیک خارج از المان اصلی کامپوننت بوده است یا نه
        if (!rootElement.contains(event.target)) {
            // اگر خارج بود، متد C# را برای بستن dropdown فراخوانی کن
            dotNetHelper.invokeMethodAsync('CloseDropdown');
        }
    };

    // اضافه کردن لیستنر به کل صفحه
    document.addEventListener('click', clickOutsideHandler);
}

export function removeClickListener() {
    if (clickOutsideHandler) {
        document.removeEventListener('click', clickOutsideHandler);
        clickOutsideHandler = null;
    }
}