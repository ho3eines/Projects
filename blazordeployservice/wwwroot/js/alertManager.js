// wwwroot/js/alertManager.js

class AlertManager {
    constructor() {
        this.container = null;
        this.stylesAdded = false;
    }

    initialize() {
        this.createContainer();
        this.addStyles();
        this.setupIntersectionObserver();
        this.setupDirectionObserver();
        return this;
    }

    createContainer() {
        this.container = document.createElement('div');
        this.container.className = 'blazor-alert-container';
        this.updateContainerPosition();
        document.body.appendChild(this.container);
    }

    updateContainerPosition() {
        const isRTL = document.documentElement.getAttribute('dir') === 'rtl';

        if (isRTL) {
            this.container.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                left: auto;
                z-index: 10000;
                max-width: 400px;
                width: 100%;
            `;
        } else {
            this.container.style.cssText = `
                position: fixed;
                top: 20px;
                left: 20px;
                right: auto;
                z-index: 10000;
                max-width: 400px;
                width: 100%;
            `;
        }
    }

    setupDirectionObserver() {
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.attributeName === 'dir') {
                    this.updateContainerPosition();
                    this.updateAlertsDirection();
                }
            });
        });

        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['dir']
        });
    }

    updateAlertsDirection() {
        const alerts = this.container.querySelectorAll('.blazor-alert');
        const isRTL = document.documentElement.getAttribute('dir') === 'rtl';

        alerts.forEach(alert => {
            alert.style.direction = isRTL ? 'rtl' : 'ltr';
            alert.style.textAlign = isRTL ? 'right' : 'left';

            if (isRTL) {
                alert.style.transform = alert.classList.contains('show') ? 'translateX(0)' : 'translateX(100%)';
                alert.style.borderLeft = '4px solid';
                alert.style.borderRight = 'none';
            } else {
                alert.style.transform = alert.classList.contains('show') ? 'translateX(0)' : 'translateX(-100%)';
                alert.style.borderRight = '4px solid';
                alert.style.borderLeft = 'none';
            }
        });
    }

    addStyles() {
        if (this.stylesAdded) return;

        const style = document.createElement('style');
        style.textContent = this.getStyles();
        document.head.appendChild(style);
        this.stylesAdded = true;
    }

    getStyles() {
        return `
            .blazor-alert-container {
                font-family: 'Vazirmatn', 'Vazir', 'Tahoma', 'Arial', sans-serif;
                transition: all 0.3s ease;
                z-index: 2147483000;
                pointer-events: none;
            }

            .blazor-alert {
                pointer-events: auto;
            }

            .blazor-alert {
                position: relative;
                padding: 20px;
                margin-bottom: 15px;
                border-radius: 16px;
                display: flex;
                align-items: center;
                gap: 15px;
                background: rgba(255, 255, 255, 0.05);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(255, 255, 255, 0.1);
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.1);
                opacity: 0;
                transition: all 0.6s cubic-bezier(0.68, -0.55, 0.265, 1.55);
                overflow: hidden;
                min-height: 80px;
            }

            [dir="rtl"] .blazor-alert {
                transform: translateX(100%);
                direction: rtl;
                text-align: right;
                border-left: 4px solid;
                border-right: none;
            }

            [dir="rtl"] .blazor-alert.show {
                transform: translateX(0);
            }

            [dir="rtl"] .blazor-alert.hide {
                transform: translateX(100%);
            }

            [dir="ltr"] .blazor-alert {
                transform: translateX(-100%);
                direction: ltr;
                text-align: left;
                border-right: 4px solid;
                border-left: none;
            }

            [dir="ltr"] .blazor-alert.show {
                transform: translateX(0);
            }

            [dir="ltr"] .blazor-alert.hide {
                transform: translateX(-100%);
            }

            .blazor-alert.show {
                opacity: 1;
            }

            .blazor-alert.hide {
                opacity: 0;
            }

            .blazor-alert-success {
                background: linear-gradient(135deg, rgba(16, 185, 129, 0.15), rgba(16, 185, 129, 0.05));
                color: #10b981;
            }

            .blazor-alert-warning {
                background: linear-gradient(135deg, rgba(251, 191, 36, 0.15), rgba(251, 191, 36, 0.05));
                color: #fbbf24;
            }

            .blazor-alert-error {
                background: linear-gradient(135deg, rgba(248, 113, 113, 0.15), rgba(248, 113, 113, 0.05));
                color: #f87171;
            }

            .blazor-alert-info {
                background: linear-gradient(135deg, rgba(96, 165, 250, 0.15), rgba(96, 165, 250, 0.05));
                color: #60a5fa;
            }

            .blazor-alert-icon {
                width: 24px;
                height: 24px;
                flex-shrink: 0;
            }

            .blazor-alert-icon svg {
                width: 100%;
                height: 100%;
                stroke-width: 2.5;
            }

            .blazor-alert-content {
                flex: 1;
                min-width: 0;
            }

            .blazor-alert-content h3 {
                font-size: 16px;
                font-weight: 600;
                margin-bottom: 4px;
                line-height: 1.3;
            }

            .blazor-alert-content p {
                font-size: 14px;
                opacity: 0.8;
                line-height: 1.4;
                margin: 0;
            }

            .blazor-alert-close {
                background: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
                font-size: 20px;
                cursor: pointer;
                color: inherit;
                opacity: 0.7;
                transition: all 0.3s ease;
                width: 32px;
                height: 32px;
                display: flex;
                align-items: center;
                justify-content: center;
                border-radius: 50%;
                backdrop-filter: blur(10px);
                flex-shrink: 0;
            }

            .blazor-alert-close:hover {
                opacity: 1;
                background: rgba(255, 255, 255, 0.2);
                transform: scale(1.1);
            }

            @keyframes ripple {
                to {
                    transform: scale(4);
                    opacity: 0;
                }
            }

            .blazor-alert-progress {
                position: absolute;
                bottom: 0;
                left: 0;
                right: 0;
                height: 3px;
                border-radius: 0 0 16px 16px;
                background: linear-gradient(90deg, currentColor, transparent);
                opacity: 0.45;
                transform-origin: right;
                animation: alert-progress linear forwards;
            }

            @keyframes alert-progress {
                from { transform: scaleX(1); }
                to   { transform: scaleX(0); }
            }

            @media (max-width: 768px) {
                .blazor-alert-container {
                    right: 10px !important;
                    left: 10px !important;
                    max-width: none !important;
                    top: 10px;
                }

                .blazor-alert {
                    padding: 16px;
                    gap: 12px;
                    margin-bottom: 12px;
                    min-height: 70px;
                }

                .blazor-alert-content h3 {
                    font-size: 15px;
                }

                .blazor-alert-content p {
                    font-size: 13px;
                }

                .blazor-alert-icon {
                    width: 20px;
                    height: 20px;
                }

                .blazor-alert-close {
                    width: 28px;
                    height: 28px;
                    font-size: 18px;
                }
            }

            @media (max-width: 480px) {
                .blazor-alert-container {
                    right: 8px !important;
                    left: 8px !important;
                    top: 8px;
                }

                .blazor-alert {
                    padding: 14px;
                    gap: 10px;
                    margin-bottom: 10px;
                    min-height: 65px;
                }

                .blazor-alert-content h3 {
                    font-size: 14px;
                }

                .blazor-alert-content p {
                    font-size: 12px;
                }

                .blazor-alert-close {
                    width: 26px;
                    height: 26px;
                    font-size: 16px;
                }
            }
        `;
    }

    setupIntersectionObserver() {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.willChange = 'transform, opacity';
                } else {
                    entry.target.style.willChange = 'auto';
                }
            });
        }, { threshold: 0.1 });
    }

    showAlert(type, title, message, duration = 5000) {
        const alert = this.createAlertElement(type, title, message);
        this.container.appendChild(alert);

        setTimeout(() => {
            alert.classList.add('show');
            this.addRippleEffect(alert);
        }, 100);

        if (duration > 0) {
            const bar = alert.querySelector('.blazor-alert-progress');
            if (bar) {
                bar.style.animationDuration = duration + 'ms';
            }
            setTimeout(() => {
                this.hideAlert(alert);
            }, duration);
        }

        return alert;
    }

    createAlertElement(type, title, message) {
        const alert = document.createElement('div');
        alert.className = `blazor-alert blazor-alert-${type}`;

        alert.setAttribute('role', 'status');
        alert.innerHTML = `
            <div class="blazor-alert-icon">
                ${this.getIconSVG(type)}
            </div>
            <div class="blazor-alert-content">
                <h3>${this.escapeHtml(title)}</h3>
                <p>${this.escapeHtml(message)}</p>
            </div>
            <button class="blazor-alert-close" aria-label="Close alert">&times;</button>
            <div class="blazor-alert-progress"></div>
        `;

        const closeBtn = alert.querySelector('.blazor-alert-close');
        closeBtn.addEventListener('click', () => this.hideAlert(alert));

        return alert;
    }

    hideAlert(alert) {
        alert.classList.remove('show');
        alert.classList.add('hide');

        setTimeout(() => {
            if (alert.parentNode) {
                alert.parentNode.removeChild(alert);
            }
        }, 600);
    }

    hideAllAlerts() {
        const alerts = this.container.querySelectorAll('.blazor-alert');
        alerts.forEach(alert => this.hideAlert(alert));
    }

    addRippleEffect(element) {
        const ripple = document.createElement('div');
        ripple.style.cssText = `
            position: absolute;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.3);
            transform: scale(0);
            animation: ripple 0.6s linear;
            pointer-events: none;
            top: 50%;
            left: 50%;
            width: 20px;
            height: 20px;
            margin-left: -10px;
            margin-top: -10px;
        `;

        element.style.position = 'relative';
        element.appendChild(ripple);

        setTimeout(() => {
            ripple.remove();
        }, 600);
    }

    getIconSVG(type) {
        const icons = {
            success: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 12l2 2 4-4"/>
                <circle cx="12" cy="12" r="10"/>
            </svg>`,
            warning: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                <line x1="12" y1="9" x2="12" y2="13"/>
                <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>`,
            error: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="15" y1="9" x2="9" y2="15"/>
                <line x1="9" y1="9" x2="15" y2="15"/>
            </svg>`,
            info: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="12" y1="16" x2="12" y2="12"/>
                <line x1="12" y1="8" x2="12.01" y2="8"/>
            </svg>`
        };
        return icons[type] || icons.info;
    }

    escapeHtml(unsafe) {
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }
}

// ایجاد و export یک نمونه از پیش مقداردهی شده
const alertManagerInstance = new AlertManager().initialize();

// Export توابع مورد نیاز
export function initialize() {
    return alertManagerInstance;
}

export function showAlert(type, title, message, duration = 5000) {
    return alertManagerInstance.showAlert(type, title, message, duration);
}

export function hideAllAlerts() {
    return alertManagerInstance.hideAllAlerts();
}

// Export مستقیم نمونه برای استفاده راحت‌تر
export default alertManagerInstance;