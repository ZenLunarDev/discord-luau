<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Autocomplete utilities for discord-luau slash commands. Provides fuzzy matching, prefix matching, pagination, static choice lists, and async source-based choices.

**Source:** [packages/autocomplete](https://github.com/DiscordLuau/discord-luau/tree/main/packages/autocomplete)

## Installation

```bash
pesde add discord_luau/autocomplete
```

## Example

```luau
local Autocomplete = require("./luau_packages/autocomplete")

local autocomplete = Autocomplete.Interface.new()

local staticChoices = autocomplete:static({
  { name = "Apple", value = "apple" },
  { name = "Banana", value = "banana" },
  { name = "Cherry", value = "cherry" },
})

local fuzzyResults = autocomplete:fuzzyMatch("app", staticChoices, 5)
print(`Fuzzy matches: {#fuzzyResults}`)

local prefixResults = autocomplete:prefixMatch("ba", staticChoices, 5)
print(`Prefix matches: {#prefixResults}`)

local paged = autocomplete:paginate(staticChoices, 1, 10)
print(`Page 1 has {#paged} choices`)

autocomplete:reply(interaction, fuzzyResults)

local asyncResults = autocomplete:fromSource(function(query)
  return future.Future.new(function()
    local results = {}
    for _, item in ipairs(database:search(query)) do
      table.insert(results, { name = item.name, value = item.id })
    end
    return results
  end)
end, "search-term"):await()
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
