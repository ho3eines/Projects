using WebApi.Models;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;

namespace WebApi.Services
{
    public interface IModalService
    {
        event Action<ModalModel> OnShow;
        event Action<string> OnClose;

        Task<object?> Show<TComponent>(string title, Dictionary<string, object>? parameters = null, bool closebutton = true, string? modalSize = null) where TComponent : ComponentBase;
        Task CloseAsync(object? result = null, string? modalId = null);
        void CloseAll();
    }

    public class ModalService : IModalService, IAsyncDisposable
    {
        public event Action<ModalModel> OnShow = delegate { };
        public event Action<string> OnClose = delegate { };

        private TaskCompletionSource<object?>? _tcs;
        private string? _currentModalId;
        private readonly IJSRuntime _jsRuntime;
        private DotNetObjectReference<ModalService>? _dotNetHelper;

        public ModalService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
            _dotNetHelper = DotNetObjectReference.Create(this);
        }

        public async Task<object?> Show<TComponent>(string title, Dictionary<string, object>? parameters = null, bool closebutton = true, string? modalSize = null) where TComponent : ComponentBase
        {
            _tcs = new TaskCompletionSource<object?>();

            var modal = new ModalModel
            {
                ComponentType = typeof(TComponent),
                Title = title,
                Parameters = parameters ?? new Dictionary<string, object>(),
                Show = true,
                ModalSize = modalSize ?? "modal-lg",
                CloseButton = closebutton
            };

            _currentModalId = modal.Id;
            OnShow?.Invoke(modal);

            await Task.Delay(100); // Let rendering catch up before attaching JS events

            var script = $@"
if (window.blazorModal && window.blazorModal.setupModalEvents) {{
    window.blazorModal.setupModalEvents('{modal.Id}');
}}";
            await _jsRuntime.InvokeVoidAsync("eval", script);

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
            var removed = _activeModals.Remove(modalId);
            OnClose?.Invoke(modalId);

            var cleanupScript = $@"
if (window.blazorModal && window.blazorModal.removeModalEvents) {{
    window.blazorModal.removeModalEvents('{modalId}');
}}";
            await _jsRuntime.InvokeVoidAsync("eval", cleanupScript);

            if (removed)
            {
                _tcs?.TrySetResult(null);
            }
        }

        public async Task CloseAsync(object? result = null, string? modalId = null)
        {
            var targetModalId = modalId ?? _currentModalId;

            if (!string.IsNullOrEmpty(targetModalId))
            {
                await CloseModal(targetModalId!);
            }
            else
            {
                _tcs?.TrySetResult(result);
                OnClose?.Invoke("all");
            }

            _currentModalId = null;
        }

        public void CloseAll()
        {
            foreach (var id in _activeModals.Keys.ToList())
            {
                OnClose?.Invoke(id);
            }
            _activeModals.Clear();
            _tcs?.TrySetResult(null);
            _currentModalId = null;
        }

        private Dictionary<string, ModalModel> _activeModals = new();

        public async ValueTask DisposeAsync()
        {
            _dotNetHelper?.Dispose();
        }
    }
}