local RateLimiter = {}

function RateLimiter.New()
	return { Buckets = {} }
end

function RateLimiter.Allow(limiter, player, domain, intervalSeconds, maximumBurst)
	local now = os.clock()
	local playerBuckets = limiter.Buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		limiter.Buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[domain]
	if not bucket or now - bucket.StartedAt >= intervalSeconds then
		playerBuckets[domain] = { StartedAt = now, Count = 1 }
		return true
	end
	if bucket.Count >= maximumBurst then return false end
	bucket.Count += 1
	return true
end

function RateLimiter.Clear(limiter, player)
	limiter.Buckets[player] = nil
end

return RateLimiter
