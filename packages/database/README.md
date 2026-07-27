<p align="center">
  <img src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" alt="discord-luau" width="96" />
</p>

Database abstraction layer for discord-luau with migrations, query builder, transactions, and adapter support. Includes SQLite, PostgreSQL, and in-memory adapter stubs for future implementation.

**Source:** [packages/database](https://github.com/DiscordLuau/discord-luau/tree/main/packages/database)

## Installation

```bash
pesde add discord_luau/database
```

## Example

```luau
local Database = require("./luau_packages/database")

local db = Database.Interface.new({
  connect = function()
    return future.Future.new(function()
      -- implement connection logic
      return {}
    end)
  end,
  disconnect = function()
    return future.Future.new(function()
      return nil
    end)
  end,
  execute = function(sql, params)
    return future.Future.new(function()
      return { rows = {}, rowsAffected = 0 }
    end)
  end,
  query = function(sql, params)
    return future.Future.new(function()
      return { { id = 1, name = "test" } }
    end)
  end,
  begin = function()
    return future.Future.new(function()
      return { commit = function() end, rollback = function() end }
    end)
  end,
  close = function()
    return future.Future.new(function()
      return nil
    end)
  end,
})

db:createTable("users", {
  id = "TEXT PRIMARY KEY",
  name = "TEXT NOT NULL",
  created_at = "TEXT",
})

db:insert("users", {
  id = "123",
  name = "Alice",
  created_at = "2024-01-01T00:00:00Z",
}):await()

local users = db:query("SELECT * FROM users WHERE name = ?", { "Alice" }):await()
print(`Found {#users} users`)
```

Full documentation at [discordluau-docs.devcomp.workers.dev](https://discordluau-docs.devcomp.workers.dev/).

## Contributing

See the [main repository](https://github.com/DiscordLuau/discord-luau) for contribution guidelines.
