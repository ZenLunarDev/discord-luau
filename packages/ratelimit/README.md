<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Rate limiting utilities for discord-luau REST and gateway requests. Implements token bucket algorithm, per-route bucketing, retry queue with exponential backoff, and Discord header parsing.

**Source:** [packages/ratelimit](https://github.com/DiscordLuau/discord-luau/tree/main/packages/ratelimit)

## Installation

```bash
pesde add discord_luau/ratelimit
```

## Example

```luau
local RateLimit = require("./luau_packages/ratelimit")

local rateLimit = RateLimit.Interface.new()

local bucket = rateLimit:getBucket("channels/123/messages", 5, 2)

rateLimit:start()

local success = rateLimit:recordRequest(bucket)
if not success then
  local waitTime = rateLimit:getWaitTime(bucket)
  print(`Rate limited, wait {waitTime}s`)
  rateLimit:waitForBucket(bucket)
end

local response = rateLimit:executeWithRetry("channels/123/messages", function()
  return future.Future.new(function()
    -- make HTTP request
    return { ok = true, body = {} }
  end)
end, {
  maxRetries = 3,
  backoff = 1.5,
}):await()

print(`Status: {rateLimit:getStatus()}`)
rateLimit:clear()
rateLimit:stop()
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
