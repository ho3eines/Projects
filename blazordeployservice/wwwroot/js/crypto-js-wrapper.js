// crypto-js-wrapper.js  (ES module)
if (typeof window === "undefined") {
    // server-side (Blazor Server) — no-op
    throw new Error("crypto-js-wrapper requires a browser environment");
}

async function ensureLoaded() {
    if (window.CryptoJS) return window.CryptoJS;

    await new Promise((resolve, reject) => {
        const script = document.createElement("script");
        // relative to this module's URL
        script.src = new URL("./crypto-js.min.js", import.meta.url).href;
        script.onload = () => resolve();
        script.onerror = (e) => reject(new Error("Failed to load crypto-js.min.js: " + e));
        document.head.appendChild(script);
    });

    if (!window.CryptoJS) throw new Error("crypto-js loaded but window.CryptoJS is not available");
    return window.CryptoJS;
}

const CryptoJS = await ensureLoaded();
export default CryptoJS;
