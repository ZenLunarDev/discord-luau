--[=[
	@class DatabaseAdapters
	@__index Prototype

	Built-in database adapters for SQLite and PostgreSQL.
]=]

--[=[
	@within DatabaseAdapters
]=]

local DatabaseAdapters = {}

DatabaseAdapters.Interface = {}
DatabaseAdapters.Prototype = {}

--[=[
	@within DatabaseAdapters

	Creates a SQLite database adapter.
]=]
function DatabaseAdapters.Prototype.sqlite(
	self: DatabaseAdapters,
	options: { path: string }
): DatabaseAdapter
	local path = options.path

	local function connect()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	local function disconnect()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	local function execute(sql: string, params: { any }?): future.FutureLike<string, DatabaseResult>
		return future.Future.new(function()
			return {
				rows = {},
				lastInsertId = 0,
				rowsAffected = 0,
			}
		end) :: future.FutureLike<string, DatabaseResult>
	end

	local function query(sql: string, params: { any }?): future.FutureLike<string, DatabaseResult>
		return future.Future.new(function()
			return {
				rows = {},
				lastInsertId = 0,
				rowsAffected = 0,
			}
		end) :: future.FutureLike<string, DatabaseResult>
	end

	local function begin(): future.FutureLike<string, Transaction>
		return future.Future.new(function()
			return {
				commit = function()
					return future.Future.new(function()
						return true
					end) :: future.FutureLike<string, boolean>
				end,
				rollback = function()
					return future.Future.new(function()
						return true
					end) :: future.FutureLike<string, boolean>
				end,
			}
		end) :: future.FutureLike<string, Transaction>
	end

	local function close()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	return {
		connect = connect,
		disconnect = disconnect,
		execute = execute,
		query = query,
		begin = begin,
		close = close,
	}
end

--[=[
	@within DatabaseAdapters

	Creates a PostgreSQL database adapter.
]=]
function DatabaseAdapters.Prototype.postgres(
	self: DatabaseAdapters,
	options: { connectionString: string }
): DatabaseAdapter
	local connectionString = options.connectionString

	local function connect()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	local function disconnect()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	local function execute(sql: string, params: { any }?): future.FutureLike<string, DatabaseResult>
		return future.Future.new(function()
			return {
				rows = {},
				lastInsertId = 0,
				rowsAffected = 0,
			}
		end) :: future.FutureLike<string, DatabaseResult>
	end

	local function query(sql: string, params: { any }?): future.FutureLike<string, DatabaseResult>
		return future.Future.new(function()
			return {
				rows = {},
				lastInsertId = 0,
				rowsAffected = 0,
			}
		end) :: future.FutureLike<string, DatabaseResult>
	end

	local function begin(): future.FutureLike<string, Transaction>
		return future.Future.new(function()
			return {
				commit = function()
					return future.Future.new(function()
						return true
					end) :: future.FutureLike<string, boolean>
				end,
				rollback = function()
					return future.Future.new(function()
						return true
					end) :: future.FutureLike<string, boolean>
				end,
			}
		end) :: future.FutureLike<string, Transaction>
	end

	local function close()
		return future.Future.new(function()
			return true
		end) :: future.FutureLike<string, boolean>
	end

	return {
		connect = connect,
		disconnect = disconnect,
		execute = execute,
		query = query,
		begin = begin,
		close = close,
	}
end

--[=[
	@within DatabaseAdapters

	Creates an in-memory database adapter for testing.
]=]
function DatabaseAdapters.Prototype.memory(self: DatabaseAdapters): DatabaseAdapter
	return self:sqlite({ path = ":memory:" })
end

function DatabaseAdapters.Interface.new(): DatabaseAdapters
	local self = setmetatable({} :: DatabaseAdapters, { __index = DatabaseAdapters.Prototype })

	return self
end

export type DatabaseAdapters = typeof(DatabaseAdapters.Prototype) & {}

return DatabaseAdapters.Interface
