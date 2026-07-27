<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Task scheduler with cron expressions, one-shot timers, pause/resume, and execution history. Ideal for scheduling periodic bot tasks like reminders, cleanups, and recurring announcements.

**Source:** [packages/scheduler](https://github.com/DiscordLuau/discord-luau/tree/main/packages/scheduler)

## Installation

```bash
pesde add discord_luau/scheduler
```

## Example

```luau
local Scheduler = require("./luau_packages/scheduler")

local scheduler = Scheduler.Interface.new()

scheduler:start()

local taskId = scheduler:addCron("remind-me", "0 9 * * *", function()
  print("Good morning!")
end)

local timerId = scheduler:addTimer("cleanup", 3600, function()
  print("Cleaning up old data")
end)

print(`Next run: {scheduler:getNextRun(taskId)}`)
print(`History: {scheduler:getHistory({ limit = 10 })}`)

scheduler:pause(taskId)
scheduler:resume(taskId)
scheduler:remove(timerId)

scheduler:stop()
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
