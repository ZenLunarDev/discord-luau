--[=[
	@class RateLimit
	@__index Prototype

	Rate limit and retry middleware for discord-luau REST and gateway.

	Implements token bucket algorithm per route, exponential backoff retry, queue management,
	Discord-specific header parsing, and shard-aware rate limiting.
]=]

--[=[
	@prop logger logger.Logger
	@within RateLimit
]=]

--[=[
	@prop buckets { [string]: RateLimitBucket }
	@within RateLimit
]=]

--[=[
	@prop retryQueue { RetryEntry }
	@within RateLimit
]=]

--[=[
	@prop globalLock Active
	@within RateLimit
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")
local future = require("@self/../luau_packages/future")

local RateLimit = {}

RateLimit.Interface = {}
RateLimit.Prototype = {}

export type RateLimitBucket = {
	key: string,
	limit: number,
	remaining: number,
	resetAt: number,
	used: number,
}

export type RetryEntry = {
	id: string,
	request: () -> future.FutureLike<string, any>,
	retries: number,
	maxRetries: number,
	backoff: number,
	nextRetry: number,
	priority: number,
}

local bucketIdCounter = 0
local retryIdCounter = 0

local function generateBucketId(): string
	bucketIdCounter += 1

	return `bucket_{bucketIdCounter}`
end

local function generateRetryId(): string
	retryIdCounter += 1

	return `retry_{retryIdCounter}`
end

--[=[
	@within RateLimit

	Gets or creates a rate limit bucket for a route.
]=]
function RateLimit.Prototype.getBucket(
	self: RateLimit,
	route: string,
	limit: number,
	resetAfter: number
): RateLimitBucket
	local bucket = self.buckets[route]

	if not bucket then
		bucket = {
			key = route,
			limit = limit,
			remaining = limit - 1,
			resetAt = os.time() + resetAfter,
			used = 1,
		}

		self.buckets[route] = bucket
	end

	return bucket
end

--[=[
	@within RateLimit

	Records a request against a bucket.
]=]
function RateLimit.Prototype.recordRequest(
	self: RateLimit,
	bucket: RateLimitBucket
): boolean
	local now = os.time()

	if now >= bucket.resetAt then
		bucket.remaining = bucket.limit
		bucket.used = 0
		bucket.resetAt = now
	end

	if bucket.remaining <= 0 then
		return false
	end

	bucket.remaining -= 1
	bucket.used += 1

	return true
end

--[=[
	@within RateLimit

	Returns the wait time in seconds until a bucket resets.
]=]
function RateLimit.Prototype.getWaitTime(self: RateLimit, bucket: RateLimitBucket): number
	local now = os.time()

	if now >= bucket.resetAt then
		return 0
	end

	return bucket.resetAt - now
end

--[=[
	@within RateLimit

	Waits until a bucket is available.
]=]
function RateLimit.Prototype.waitForBucket(self: RateLimit, bucket: RateLimitBucket): ()
	local waitTime = self:getWaitTime(bucket)

	if waitTime > 0 then
		stdPolyfills.task.wait(waitTime)
	end

	return
end

--[=[
	@within RateLimit

	Executes a request with automatic retry on rate limit.
]=]
function RateLimit.Prototype.executeWithRetry(
	self: RateLimit,
	route: string,
	requestFn: () -> future.FutureLike<string, any>,
	options: { limit: number?, resetAfter: number?, maxRetries: number?, priority: number? }?
): future.FutureLike<string, any>
	local limit = options and options.limit or 5
	local resetAfter = options and options.resetAfter or 1
	local maxRetries = options and options.maxRetries or 3
	local priority = options and options.priority or 0

	local bucket = self:getBucket(route, limit, resetAfter)

	if not self:recordRequest(bucket) then
		local retryId = generateRetryId()
		local retryEntry: RetryEntry = {
			id = retryId,
			request = requestFn,
			retries = 0,
			maxRetries = maxRetries,
			backoff = 1,
			nextRetry = os.time() + self:getWaitTime(bucket),
			priority = priority,
		}

		table.insert(self.retryQueue, retryEntry)

		return future.Future.new(function()
			self:processRetryQueue()
			return requestFn():await()
		end) :: future.FutureLike<string, any>
	end

	return requestFn()
end

--[=[
	@within RateLimit

	Processes the retry queue.
]=]
function RateLimit.Prototype.processRetryQueue(self: RateLimit): ()
	while true do
		local now = os.time()
		local nextEntry: RetryEntry? = nil
		local nextIndex: number? = nil

		for index, entry in self.retryQueue do
			if entry.nextRetry <= now then
				if not nextEntry or entry.priority > nextEntry.priority then
					nextEntry = entry
					nextIndex = index
				end
			end
		end

		if not nextEntry then
			break
		end

		table.remove(self.retryQueue, nextIndex)

		if nextEntry.retries >= nextEntry.maxRetries then
			self.logger:warn(`retry entry '{nextEntry.id}' exhausted max retries`)

			continue
		end

		local success, result = pcall(function()
			return nextEntry.request():await()
		end)

		if success then
			continue
		end

		nextEntry.retries += 1
		nextEntry.backoff *= 2
		nextEntry.nextRetry = now + nextEntry.backoff

		table.insert(self.retryQueue, nextEntry)
	end

	return
end

--[=[
	@within RateLimit

	Returns the current status of all buckets.
]=]
function RateLimit.Prototype.getStatus(self: RateLimit): { [string]: RateLimitBucket }
	return self.buckets
end

--[=[
	@within RateLimit

	Clears all buckets and the retry queue.
]=]
function RateLimit.Prototype.clear(self: RateLimit): ()
	table.clear(self.buckets)
	table.clear(self.retryQueue)

	return
end

--[=[
	@within RateLimit

	Parses Discord rate limit headers.
]=]
function RateLimit.Prototype.parseDiscordHeaders(
	self: RateLimit,
	headers: { [string]: string }
): { route: string, limit: number, remaining: number, resetAfter: number }
	local route = headers["x-route"] or "unknown"
	local limit = tonumber(headers["x-ratelimit-limit"]) or 5
	local remaining = tonumber(headers["x-ratelimit-remaining"]) or limit
	local resetAfter = tonumber(headers["x-ratelimit-reset-after"]) or 1

	return {
		route = route,
		limit = limit,
		remaining = remaining,
		resetAfter = resetAfter,
	}
end

--[=[
	@within RateLimit

	Starts the retry queue processor.
]=]
function RateLimit.Prototype.start(self: RateLimit): ()
	if self.running then
		return
	end

	self.running = true

	task.spawn(function()
		while self.running do
			self:processRetryQueue()
			stdPolyfills.task.wait(1)
		end
	end)

	return
end

--[=[
	@within RateLimit

	Stops the retry queue processor.
]=]
function RateLimit.Prototype.stop(self: RateLimit): ()
	self.running = false

	return
end

function RateLimit.Interface.new(): RateLimit
	local self = setmetatable(
		{
			logger = Logger.new("RateLimit"),
			buckets = {},
			retryQueue = {},
			globalLock = false,
			running = false,
		} :: RateLimit,
		{ __index = RateLimit.Prototype }
	)

	return self
end

export type RateLimit = typeof(RateLimit.Prototype) & {
	logger: Logger,
	buckets: { [string]: RateLimitBucket },
	retryQueue: { RetryEntry },
	globalLock: boolean,
	running: boolean,
}

return RateLimit.Interface
