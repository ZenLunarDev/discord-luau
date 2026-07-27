<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Plugin and extension system for discord-luau bots. Load, unload, and reload plugins with dependency resolution, lifecycle hooks, and event subscription.

**Source:** [packages/plugins](https://github.com/DiscordLuau/discord-luau/tree/main/packages/plugins)

## Installation

```bash
pesde add discord_luau/plugins
```

## Example

```luau
local Plugins = require("./luau_packages/plugins")

local pluginManager = Plugins.Interface.new()

pluginManager:registerHook("onCommand")

pluginManager:subscribe("onCommand", function(data)
  print(`Command received: {data.command.name}`)
end)

pluginManager:load({
  name = "my-plugin",
  version = "1.0.0",
  description = "My first plugin",
  setup = function(plugins, config)
    plugins:subscribe("onCommand", function(data)
      print(`Plugin handled: {data.command.name}`)
    end)

    return function()
      print("Plugin cleanup")
    end
  end,
})
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
