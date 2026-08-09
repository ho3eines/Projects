using BlazorDeployService.Models;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;

namespace BlazorDeployService.Services
{
    // Services/IModalService.cs


    public interface IModalService
    {
        event Action<ModalModel> OnShow;
        event Action<string> OnClose;

        Task<object?> Show<TComponent>(string title, Dictionary<string, object>? parameters = null,bool closebutton=true, string? modalSize = null) where TComponent : ComponentBase;
        void Close(object? result = null, string? modalId = null);
        void CloseAll();
        Task InitializeAsync();
    }

    public class ModalService : IModalService, IAsyncDisposable
    {
        public event Action<ModalModel> OnShow = delegate { };
        public event Action<string> OnClose = delegate { };

        private TaskCompletionSource<object?>? _tcs;
        private string? _currentModalId;
        private readonly IJSRuntime _jsRuntime;
        private bool _isInitialized = false;
        private DotNetObjectReference<ModalService>? _dotNetHelper;

        public ModalService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        public async Task InitializeAsync()
        {
            if (!_isInitialized)
            {
                _dotNetHelper = DotNetObjectReference.Create(this);
                await InjectStyles();
                await InjectScripts();
                _isInitialized = true;
            }
        }

        private async Task InjectStyles()
        {
            var css = @"
            .modal-container {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                z-index: 1050;
                display: flex;
                align-items: center;
                justify-content: center;
            }

            .modal-backdrop {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.5);
                backdrop-filter: blur(5px);
                -webkit-backdrop-filter: blur(5px);
                opacity: 0;
                transition: opacity 0.3s ease;
            }

            .modal-backdrop.show {
                opacity: 1;
            }

            .modal-dialog {
                transform: scale(0.7) translateY(-50px);
                opacity: 0;
                transition: all 0.3s ease;
                max-width: 90%;
                margin: 1.75rem auto;
                z-index: 1060;
            }

            .modal-dialog.show {
                transform: scale(1) translateY(0);
                opacity: 1;
            }

            .modal-content {
                border: none;
                border-radius: 12px;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
                background: white;
            }

            .modal-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 1rem 1.5rem;
                border-bottom: 1px solid #dee2e6;
                border-top-left-radius: 12px;
                border-top-right-radius: 12px;
                background: #f8f9fa;
            }

            .modal-title {
                margin: 0;
                font-weight: 600;
                flex: 1;
            }

            .btn-close-rtl {
                background: transparent url(""data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23000'%3e%3cpath d='M.293.293a1 1 0 0 1 1.414 0L8 6.586 14.293.293a1 1 0 1 1 1.414 1.414L9.414 8l6.293 6.293a1 1 0 0 1-1.414 1.414L8 9.414l-6.293 6.293a1 1 0 0 1-1.414-1.414L6.586 8 .293 1.707a1 1 0 0 1 0-1.414z'/%3e%3c/svg%3e"") center/1em auto no-repeat;
                border: none;
                width: 1.5em;
                height: 1.5em;
                opacity: 0.5;
                cursor: pointer;
                margin-left: auto;
            }

            .btn-close-rtl:hover {
                opacity: 0.75;
            }

            .modal-sm {
                max-width: 400px;
            }

            .modal-lg {
                max-width: 800px;
            }

            .modal-xl {
                max-width: 1140px;
            }
        ";

            await _jsRuntime.InvokeVoidAsync("eval",
                $@"if (!document.getElementById('blazor-modal-styles')) {{
                var style = document.createElement('style');
                style.id = 'blazor-modal-styles';
                style.textContent = `{css}`;
                document.head.appendChild(style);
            }}");
        }

        private async Task InjectScripts()
        {
            var script = @"
            window.blazorModal = {
                dotNetHelper: null,
                
                initialize: function(dotNetHelper) {
                    this.dotNetHelper = dotNetHelper;
                },

                setupModalEvents: function(modalId) {
                    // Backdrop click
                    const backdrop = document.querySelector('.modal-backdrop[data-modal-id=""' + modalId + '""]');
                    if (backdrop) {
                        backdrop.onclick = function() {
                            dotNetHelper.invokeMethodAsync('HandleBackdropClick', modalId);
                        };
                    }

                    // Close button click
                    const closeBtn = document.querySelector('.btn-close-rtl[data-modal-id=""' + modalId + '""]');
                    if (closeBtn) {
                        closeBtn.onclick = function() {
                            dotNetHelper.invokeMethodAsync('HandleCloseClick', modalId);
                        };
                    }
                },

                removeModalEvents: function(modalId) {
                    const backdrop = document.querySelector('.modal-backdrop[data-modal-id=""' + modalId + '""]');
                    if (backdrop) {
                        backdrop.onclick = null;
                    }

                    const closeBtn = document.querySelector('.btn-close-rtl[data-modal-id=""' + modalId + '""]');
                    if (closeBtn) {
                        closeBtn.onclick = null;
                    }
                }
            };
        ";

            await _jsRuntime.InvokeVoidAsync("eval", script);
            await _jsRuntime.InvokeVoidAsync("blazorModal.initialize", _dotNetHelper);
        }

        public async Task<object?> Show<TComponent>(string title, Dictionary<string, object>? parameters = null,bool closebutton=true, string? modalSize = null) where TComponent : ComponentBase
        {
            if (!_isInitialized)
            {
                await InitializeAsync();
            }

            _tcs = new TaskCompletionSource<object?>();

            var modal = new ModalModel
            {
                ComponentType = typeof(TComponent),
                Title = title,
                Parameters = parameters ?? new Dictionary<string, object>(),
                Show = true,
                ModalSize = modalSize ?? "modal-lg",
                CloseButton= closebutton

            };

            _currentModalId = modal.Id;
            OnShow?.Invoke(modal);

            // کمی تاخیر برای اطمینان از رندر شدن مودال
            await Task.Delay(50);

            // تنظیم event listeners
            await _jsRuntime.InvokeVoidAsync("blazorModal.setupModalEvents", modal.Id);

            return await _tcs.Task;
        }

        [JSInvokable]
        public async Task HandleBackdropClick(string modalId)
        {
            await CloseModal(modalId);
        }

        [JSInvokable]
        public async Task HandleCloseClick(string modalId)
        {
            await CloseModal(modalId);
        }

        private async Task CloseModal(string modalId)
        {
            if (_activeModals.ContainsKey(modalId))
            {
                // حذف event listeners
                await _jsRuntime.InvokeVoidAsync("blazorModal.removeModalEvents", modalId);

                _activeModals.Remove(modalId);
                OnClose?.Invoke(modalId);
            }
        }

        public void Close(object? result = null, string? modalId = null)
        {
            _tcs?.TrySetResult(result);
            var targetModalId = modalId ?? _currentModalId;
            if (targetModalId != null)
            {
                OnClose?.Invoke(targetModalId);
            }
            _currentModalId = null;
        }

        public void CloseAll()
        {
            _tcs?.TrySetResult(null);
            OnClose?.Invoke("all");
            _currentModalId = null;
        }

        private Dictionary<string, ModalModel> _activeModals = new();

        public async ValueTask DisposeAsync()
        {
            _dotNetHelper?.Dispose();
        }
    }
}
