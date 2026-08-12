using System;
using System.Threading;
using System.Threading.Tasks;
using BlazorDeployService.Models;

namespace BlazorDeployService.Services;

/// <summary>
/// مدیریت نشست در کلاینت:
/// - ذخیره SessionToken در localStorage (رمزنگاری‌شده)
/// - تایمر بیکاری: هر ۱۰ دقیقه بدون درخواست → انقضا → رویداد SessionExpired
/// - UI با شنیدن رویداد، صفحه لاگین را باز می‌کند
/// </summary>
public interface ISessionService
{
    SessionStatus Status { get; }
    string? SessionToken { get; }
    Guid? ProjectGuid { get; }
    ProjectInfo? Project { get; }

    event EventHandler<SessionExpiredEventArgs>? SessionExpired;

    /// <summary>ذخیره نشست فعال پس از لاگین موفق</summary>
    Task StartSessionAsync(LoginResponse response);

    /// <summary>بازیابی نشست از localStorage هنگام بالا آمدن برنامه</summary>
    Task<bool> RestoreSessionAsync();

    /// <summary>به‌روزرسانی LastActivity — بعد از هر درخواست موفق</summary>
    Task TouchAsync();

    /// <summary>پایان/باطل کردن نشست (لاگ‌اوت یا انقضا)</summary>
    Task EndSessionAsync(string reason = "logout");
}

/// <summary>پیاده‌سازی پیش‌فرض — با تایمر بیکاری</summary>
public sealed class SessionService : ISessionService, IAsyncDisposable
{
    private readonly IClientStorageService _storage;
    private readonly IEncryptionService _encryption;

    private const string TokenKey = "hermes:session-token";
    private const string ProjectKey = "hermes:session-project";
    private const string ExpiryKey = "hermes:session-expiry";

    private Timer? _idleTimer;
    private DateTime _lastActivityUtc = DateTime.UtcNow;
    private readonly object _lock = new();

    public SessionStatus Status { get; private set; } = SessionStatus.None;
    public string? SessionToken { get; private set; }
    public Guid? ProjectGuid { get; private set; }
    public ProjectInfo? Project { get; private set; }

    public event EventHandler<SessionExpiredEventArgs>? SessionExpired;

    public SessionService(IClientStorageService storage, IEncryptionService encryption)
    {
        _storage = storage;
        _encryption = encryption;
    }

    public async Task StartSessionAsync(LoginResponse response)
    {
        SessionToken = response.SessionToken;
        ProjectGuid = response.Project.ProjectGuid;
        Project = response.Project;
        Status = SessionStatus.Active;
        _lastActivityUtc = DateTime.UtcNow;

        // ذخیره امن در localStorage
        await _storage.SetLocalEncryptedAsync(TokenKey, response.SessionToken, response.SessionToken);
        await _storage.SetLocalEncryptedAsync(ProjectKey, response.Project, response.SessionToken);
        await _storage.SetLocalEncryptedAsync(ExpiryKey, DateTime.UtcNow.AddSeconds(response.ExpiresInSeconds).Ticks.ToString(), response.SessionToken);

        StartIdleTimer(response.ExpiresInSeconds);
    }

    public async Task<bool> RestoreSessionAsync()
    {
        try
        {
            var token = await _storage.GetLocalEncryptedAsync<string>(TokenKey, TokenKey);
            if (string.IsNullOrEmpty(token)) return false;

            var project = await _storage.GetLocalEncryptedAsync<ProjectInfo>(ProjectKey, token);
            if (project is null) return false;

            var expiryTicks = await _storage.GetLocalEncryptedAsync<string>(ExpiryKey, token);
            if (long.TryParse(expiryTicks, out var ticks) && DateTime.UtcNow > new DateTime(ticks))
            {
                await EndSessionAsync("restore-expired");
                return false;
            }

            SessionToken = token;
            ProjectGuid = project.ProjectGuid;
            Project = project;
            Status = SessionStatus.Active;
            _lastActivityUtc = DateTime.UtcNow;
            StartIdleTimer(project.SessionTimeoutSeconds > 0 ? project.SessionTimeoutSeconds : 600);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public Task TouchAsync()
    {
        lock (_lock) { _lastActivityUtc = DateTime.UtcNow; }
        return Task.CompletedTask;
    }

    public async Task EndSessionAsync(string reason = "logout")
    {
        Status = SessionStatus.Expired;
        SessionToken = null;
        ProjectGuid = null;
        Project = null;

        await _storage.RemoveLocalAsync(TokenKey);
        await _storage.RemoveLocalAsync(ProjectKey);
        await _storage.RemoveLocalAsync(ExpiryKey);

        StopIdleTimer();

        // اطلاع UI برای باز کردن صفحه لاگین
        SessionExpired?.Invoke(this, new SessionExpiredEventArgs { Reason = reason });
    }

    private void StartIdleTimer(int timeoutSeconds)
    {
        StopIdleTimer();
        _idleTimer = new Timer(_ => CheckIdle(), null, TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10));
    }

    /// <summary>
    /// هر ۱۰ ثانیه چک می‌کند: اگر بیش از timeout (۱۰ دقیقه) از آخرین فعالیت گذشته → انقضا.
    /// هر درخواست موفق Touch می‌شود، پس سکوت ۱۰ دقیقه‌ای = انقضا.
    /// </summary>
    private void CheckIdle()
    {
        lock (_lock)
        {
            var timeout = Project?.SessionTimeoutSeconds ?? 600;
            if (Status == SessionStatus.Active && (DateTime.UtcNow - _lastActivityUtc).TotalSeconds > timeout)
            {
                _ = EndSessionAsync("idle-timeout");
            }
        }
    }

    private void StopIdleTimer()
    {
        _idleTimer?.Dispose();
        _idleTimer = null;
    }

    public ValueTask DisposeAsync()
    {
        StopIdleTimer();
        return ValueTask.CompletedTask;
    }
}