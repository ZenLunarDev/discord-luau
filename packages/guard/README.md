<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Permission guards and authorization system for discord-luau commands. Validate permissions, roles, channel types, guild/DM context, custom conditions, and rate limits with audit logging.

**Source:** [packages/guard](https://github.com/DiscordLuau/discord-luau/tree/main/packages/guard)

## Installation

```bash
pesde add discord_luau/guard
```

## Example

```luau
local Guard = require("./luau_packages/guard")

local guard = Guard.Interface.new()

local result = guard:runGuards({
  {
    type = "permissions",
    required = "SendMessages",
  },
  {
    type = "roles",
    roleIds = { "123456789", "987654321" },
  },
  {
    type = "guildOnly",
  },
}, {
  interaction = interaction,
  member = member,
  channel = channel,
  guild = guild,
  user = user,
})

if not result.passed then
  interaction:respond({
    content = result.reason or "You do not have permission to use this command.",
    flags = 1 << 6,
  })
  return
end

print(`Guard passed with action: {result.action}`)
print(`Audit log: {guard:getAuditLog()}`)
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
