# pdd.ir Deep-Dive — Hand-Verified Implementation Details

Extracted from /d/pdd.ir (Pdd.ir.Client) by reading every service, component, CSS and JS file. These are the EXACT patterns — implement them as-is, not paraphrased.

## Dates = Unix Timestamp (long seconds), NOT .NET Ticks

`Pdd.ir.Client/Helpers/DateHelper.cs`:

```csharp
public static class DateHelper
{
    private static readonly PersianCalendar pc = new();

    // Unix → DateTime
    public static DateTime ToMiladi(long unixTimestamp)
        => DateTimeOffset.FromUnixTimeSeconds(unixTimestamp).UtcDateTime;

    // DateTime → Unix
    public static long ToUnix(DateTime dateTime)
        => new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(dateTime)).ToUnixTimeSeconds();

    // Unix → "1402/01/15" (uses .ToLocalTime()!)
    public static string ToShamsi(long unixTimestamp)
    {
        var dt = ToMiladi(unixTimestamp).ToLocalTime();
        return $"{pc.GetYear(dt):0000}/{pc.GetMonth(dt):00}/{pc.GetDayOfMonth(dt):00}";
    }

    // "1402/01/15 14:30" → Unix (supports optional time part)
    public static long FromShamsi(string shamsiDate) { ... pc.ToDateTime(y, m, d, h, min, 0, 0) ... }

    public static long Now() => ToUnix(DateTime.Now);
}
```

DB column type: **BIGINT** (Unix seconds). PersianDatePicker/PersianCalendarModal pass `long?` through `Modal.Close(timestamp)`.

PersianCalendarModal grid math:
- `startDayOfWeek = ((int)firstOfMonth.DayOfWeek + 1) % 7` — Saturday-first week (شنبه).
- Weeks built as `List<List<long?>>`, null = empty cell.
- Month nav: increment/decrement Persian month via `_pc.ToDateTime(y, m, 1, ...)`.

## ModalService (Services/ModalService.cs)

- Implements `IModalService, IAsyncDisposable`; **injects IJSRuntime**; `InitializeAsync()` injects CSS + JS once via `InvokeVoidAsync("eval", ...)`:
  - CSS injected as a `<style id="pdd-modal-styles">` — glassmorphism (rgba(15,20,30,0.85) + blur(24px)), `.modal-sm{max-width:420px}`, `.modal-lg{max-width:800px}`, `.modal-xl{max-width:1140px}`, `[data-theme="light"]` overrides, dropdown-menu position fix.
  - JS: `window.modal = { dotNetHelper, setupModalEvents(id), removeModalEvents(id) }` — wires backdrop `.modal-backdrop[data-modal-id]` onclick and `.btn-close-rtl` onclick to `invokeMethodAsync('HandleBackdropClick'/'HandleCloseClick', id)`.
- `_tcs = new TaskCompletionSource<object?>()` per Show; `await _tcs.Task` returns result.
- `ShowAsync<TResult, TComponent>` → awaits Show then `result is TResult typed ? typed : default`.
- `Close(result, modalId)` → `_tcs?.TrySetResult(result)` + `OnClose?.Invoke(targetModalId)`.
- `CloseAll()` → resolves TCS + `OnClose?.Invoke("all")`.
- Modal.razor host: `_activeModals` dict, 50ms delay then add `show` class (CSS transition), 300ms delay on close before removing from dict.

## AlertService (Task-based, not void events)

`IAlertService`:
```csharp
Task ShowSuccessAsync(string title, string message, int duration = 5000);
Task ShowWarningAsync(string title, string message, int duration = 5000);
Task ShowErrorAsync(string title, string message, int duration = 5000);
Task ShowInfoAsync(string title, string message, int duration = 5000);
Task ShowCustomAsync(string type, string title, string message, int duration = 5000);
Task HideAllAsync();
```
Implementation fires `event Action<string,string,string,int>? OnShow` (type,title,message,ms). Toast.razor subscribes; auto-hide via `CancellationTokenSource` + `Task.Delay(ms, token)`.

## SearchableListRegistry (passing typed data into DynamicComponent modals)

```csharp
public static class SearchableListRegistry
{
    private static readonly Dictionary<string, ListData> _store = new();
    public static string Register(object items, Func<object,string> textSelector, object? currentValue = null) // key = Guid[..8]
    public static ListData? Get(string key)
    public static void Remove(string key)
    public class ListData { object Items; Func<object,string> TextSelector; object? CurrentValue; }
}
```
SearchableList.razor: displays selected text, registers data, opens `SearchableListModal` with `RegistryKey` param, gets result string back, matches item, fires ValueChanged/SelectedItemChanged.
SearchableListModal: keyboard nav ArrowUp/ArrowDown/Enter/Escape, pagination pageSize=20, auto-focus input, `JS.InvokeVoidAsync("slmScrollToItem", idx)` scroll-into-view.

## Keyboard shortcuts (found in JS, not razor!)

- `splash.js`: ESC / Enter / Space → `splash.skip()` (keydown listener, cleaned up after).
- `SearchableListModal.razor`: ArrowUp/ArrowDown/Enter/Escape.
- CKEditor: its own rich editing keybindings internally.
- App-wide custom hotkeys (e.g. Ctrl+Shift+D) would follow: JS `window.addEventListener('keydown')` → `dotNet.invokeMethodAsync('HandleShortcut', action)` on a `DotNetObjectReference` from a singleton scoped component registered in MainLayout.

## splash.js structure (splash-подобные intro)

`window.splash = { shouldShow(), start(dotNetRef), skip(), completed(), reset() }`; GSAP timeline with 4 phases (~3.2s): entrance (orb/corner marks/light ring) → logo formation → completion (brand text, loading bar with onUpdate percent, pulse waves, light sweep) → exit. Stored key `pdd_splash_completed`. Calls `_dotNetRef.invokeMethodAsync("OnAnimationComplete")` on finish.

## wwwroot inventory (pdd.ir)

- js/: alertManager.js, animations.js, ckeditor.js (1MB, CKEditor), CKEditorInterop.js, clickOutside.js, crypto-js.min.js, gsap-animations.js, interop.js, splash.js — plus `theme.js` NOT present here (comes from blazor-translate-theme-service skill).
- lib/: bootstrap 5.3 full dist (incl. bootstrap.rtl.min.css), bootstrap-icons.min.css, gsap.min.js + ScrollTrigger + TextPlugin, lenis.min.js, splash.css.
- css/app.css — 96KB, contains project CSS variables + component styles.

## File encoding pitfall (Windows)

read_file returned "Binary file" for ModalService.cs and app.css — they are UTF-8 **with BOM** (`\xef\xbb\xbf`). Read via:
```bash
python3 -c "print(open(r'path','rb').read().decode('utf-8-sig'))"  # or decode('utf-16') if BOM ff fe
```
Or `iconv -f UTF-8 -t UTF-8 file` for stripped BOM.