import CryptoJS from './crypto-js-wrapper.js';

export function encryptData(plaintext, key) {
    try {
        if (!plaintext || !key) throw new Error('Plaintext and key are required');

        const keyHash = CryptoJS.SHA256(CryptoJS.enc.Utf8.parse(key));
        const iv = CryptoJS.lib.WordArray.random(16);

        const encrypted = CryptoJS.AES.encrypt(
            CryptoJS.enc.Utf8.parse(plaintext),
            keyHash,
            {
                iv: iv,
                mode: CryptoJS.mode.CBC,
                padding: CryptoJS.pad.Pkcs7
            }
        );

        return iv.concat(encrypted.ciphertext).toString(CryptoJS.enc.Base64);
    }
    catch (err) {
        console.error("Encryption error", err);
        throw err;
    }
}

export function decryptData(ciphertext, key) {
    try {
        if (!ciphertext || !key) throw new Error("Ciphertext and key are required");

        const keyHash = CryptoJS.SHA256(CryptoJS.enc.Utf8.parse(key));

        const encryptedData = CryptoJS.enc.Base64.parse(ciphertext);

        const iv = CryptoJS.lib.WordArray.create(encryptedData.words.slice(0, 4));
        const ciphertextBytes = CryptoJS.lib.WordArray.create(encryptedData.words.slice(4));

        const cipherParams = CryptoJS.lib.CipherParams.create({
            ciphertext: ciphertextBytes
        });

        const decrypted = CryptoJS.AES.decrypt(
            cipherParams,
            keyHash,
            {
                iv: iv,
                mode: CryptoJS.mode.CBC,
                padding: CryptoJS.pad.Pkcs7
            }
        );

        const result = decrypted.toString(CryptoJS.enc.Utf8);
        if (!result) throw new Error("Decryption failed");

        return result;
    }
    catch (err) {
        console.error("Decryption error", err);
        throw err;
    }
}

export function generateRandomKey(length = 32) {
    const randomKey = CryptoJS.lib.WordArray.random(length);
    return CryptoJS.enc.Base64.stringify(randomKey);
}

export function scrollToRow(id) {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
}

export function setFocus(elementId) {
    const element = document.getElementById(elementId);
    if (element) element.focus();
}

export function addRippleEffect() {
    const activator = document.querySelector('.language-activator');
    if (!activator) return;

    activator.style.transform = 'scale(0.95)';
    setTimeout(() => activator.style.transform = 'scale(1)', 200);
}

export function applyDirection(isRtl) {
    const dir = isRtl ? 'rtl' : 'ltr';

    document.documentElement.setAttribute('dir', dir);
    document.documentElement.setAttribute('lang', document.documentElement.lang || 'fa-IR');

    if (isRtl) {
        document.body.classList.add('mud-rtl');
        document.body.classList.remove('mud-ltr');
    } else {
        document.body.classList.add('mud-ltr');
        document.body.classList.remove('mud-rtl');
    }
}

if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', event => {
        if (event.data?.type === 'NEW_VERSION_AVAILABLE') {
            console.log('🔄 New version detected, reloading...');
            window.location.reload(true);
        }
    });
}

export function changeLang(newLang) {
    try {
        const htmlElement = document.documentElement;
        htmlElement.lang = newLang;
        console.log(`✅ زبان به ${newLang} تغییر یافت`);
        return true;
    } catch (error) {
        console.error("❌ خطا در تغییر زبان:", error);
        return false;
    }
}

export function changeDir(newDir) {
    try {
        const htmlElement = document.documentElement;

        if (newDir === "rtl" || newDir === "ltr") {
            htmlElement.dir = newDir;
            console.log(`✅ جهت به ${newDir} تغییر یافت`);
            return true;
        } else {
            throw new Error("مقدار dir باید 'rtl' یا 'ltr' باشد");
        }
    } catch (error) {
        console.error("❌ خطا در تغییر جهت:", error.message);
        return false;
    }
}

export function changeTheme(newTheme) {
    try {
        const htmlElement = document.documentElement;
        const validThemes = ["light", "dark", "auto"];

        if (validThemes.includes(newTheme)) {
            htmlElement.setAttribute('data-bs-theme', newTheme);
            console.log(`✅ تم به ${newTheme} تغییر یافت`);
            return true;
        } else {
            throw new Error("مقدار theme باید 'light', 'dark' یا 'auto' باشد");
        }
    } catch (error) {
        console.error("❌ خطا در تغییر تم:", error.message);
        return false;
    }
}
