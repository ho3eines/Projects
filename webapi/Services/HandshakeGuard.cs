using System.Collections.Concurrent;

namespace WebApi.Services;

/// <summary>Nonce anti-replay + per-IP handshake rate limit.</summary>
public sealed class HandshakeGuard
{
    private readonly ConcurrentDictionary<string, DateTimeOffset> _nonces = new();
    private readonly ConcurrentDictionary<string, TokenBucket> _buckets = new();

    public bool TryAcceptNonce(string nonce)
    {
        if (string.IsNullOrWhiteSpace(nonce) || nonce.Length < 8)
            return false;
        var added = _nonces.TryAdd(nonce, DateTimeOffset.UtcNow.AddMinutes(2));
        Sweep();
        return added;
    }

    public bool TryConsumeRate(string key)
    {
        var bucket = _buckets.GetOrAdd(key, _ => new TokenBucket(5, 1));
        return bucket.TryConsume();
    }

    public bool IsTimestampFresh(long unixSeconds, int windowSeconds)
    {
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        return Math.Abs(now - unixSeconds) <= windowSeconds;
    }

    private void Sweep()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var kv in _nonces)
        {
            if (kv.Value <= now)
                _nonces.TryRemove(kv.Key, out _);
        }
    }

    private sealed class TokenBucket
    {
        private readonly int _capacity;
        private readonly double _perSecond;
        private double _tokens;
        private DateTimeOffset _last;
        private readonly object _lock = new();

        public TokenBucket(int capacity, double perSecond)
        {
            _capacity = capacity;
            _perSecond = perSecond;
            _tokens = capacity;
            _last = DateTimeOffset.UtcNow;
        }

        public bool TryConsume()
        {
            lock (_lock)
            {
                var now = DateTimeOffset.UtcNow;
                _tokens = Math.Min(_capacity, _tokens + (now - _last).TotalSeconds * _perSecond);
                _last = now;
                if (_tokens < 1)
                    return false;
                _tokens -= 1;
                return true;
            }
        }
    }
}
