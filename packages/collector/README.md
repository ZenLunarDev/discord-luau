<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Collectors and waitFor utilities for discord-luau interactions. Collect components, modal submissions, reactions, and messages with timeout, filter, and max-items support.

**Source:** [packages/collector](https://github.com/DiscordLuau/discord-luau/tree/main/packages/collector)

## Installation

```bash
pesde add discord_luau/collector
```

## Example

```luau
local Collector = require("./luau_packages/collector")

local collector = Collector.Interface.new()

local componentFuture = collector:newComponentCollector({
  filter = function(interaction)
    return interaction.data.customId == "my_button"
  end,
  timeout = 30,
  maxItems = 1,
})

interaction:respondComponents({
  content = "Click the button!",
  components = { actionRow },
})

local result = componentFuture:await()
print(`Collected: {result}`)

local reactionFuture = collector:newReactionCollector({
  messageId = message.id,
  emoji = "👍",
  timeout = 60,
})

local reaction = reactionFuture:await()
print(`Reaction from: {reaction.userId}`)
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
