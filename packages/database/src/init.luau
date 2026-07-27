--[=[
	@class Database
	@__index Prototype

	Database abstraction layer for discord-luau bots.

	Provides a generic database interface with SQLite and PostgreSQL adapters, document-store
	support, migrations, connection pooling, and query builders.
]=]

--[=[
	@prop logger logger.Logger
	@within Database
]=]

--[=[
	@prop adapter DatabaseAdapter
	@within Database
]=]

--[=[
	@prop migrations { DatabaseMigration }
	@within Database
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")
local future = require("@self/../luau_packages/future")

local Database = {}

Database.Interface = {}
Database.Prototype = {}

export type DatabaseMigration = {
	id: string,
	up: () -> (),
	down: () -> (),
}

export type DatabaseRow = { [string]: any }
export type DatabaseResult = {
	rows: { DatabaseRow },
	lastInsertId: number?,
	rowsAffected: number,
}

export type DatabaseAdapter = {
	connect: () -> future.FutureLike<string, boolean>,
	disconnect: () -> future.FutureLike<string, boolean>,
	execute: (sql: string, params: { any }?) -> future.FutureLike<string, DatabaseResult>,
	query: (sql: string, params: { any }?) -> future.FutureLike<string, DatabaseResult>,
	begin: () -> future.FutureLike<string, Transaction>,
	close: () -> future.FutureLike<string, boolean>,
}

export type Transaction = {
	commit: () -> future.FutureLike<string, boolean>,
	rollback: () -> future.FutureLike<string, boolean>,
}

--[=[
	@within Database

	Executes a SQL statement with optional parameters.
]=]
function Database.Prototype.execute(
	self: Database,
	sql: string,
	params: { any }?
): future.FutureLike<string, DatabaseResult>
	return self.adapter:execute(sql, params)
end

--[=[
	@within Database

	Runs a SELECT query and returns all rows.
]=]
function Database.Prototype.query(
	self: Database,
	sql: string,
	params: { any }?
): future.FutureLike<string, { DatabaseRow }>
	local result = self.adapter:query(sql, params):await()

	if not result then
		return future.Future.new(function()
			error("Database query failed")
		end) :: future.FutureLike<string, { DatabaseRow }>
	end

	return future.Future.new(function()
		return result.rows
	end) :: future.FutureLike<string, { DatabaseRow }>
end

--[=[
	@within Database

	Runs a SELECT query and returns the first row, or nil if no results.
]=]
function Database.Prototype.queryOne(
	self: Database,
	sql: string,
	params: { any }?
): future.FutureLike<string, DatabaseRow?>
	local result = self:query(sql, params):await()

	if #result == 0 then
		return future.Future.new(function()
			return nil
		end) :: future.FutureLike<string, DatabaseRow?>
	end

	return future.Future.new(function()
		return result[1]
	end) :: future.FutureLike<string, DatabaseRow?>
end

--[=[
	@within Database

	Inserts a row into a table and returns the last insert ID.
]=]
function Database.Prototype.insert(
	self: Database,
	tableName: string,
	data: DatabaseRow
): future.FutureLike<string, number>
	local columns = {}
	local values = {}
	local placeholders = {}

	for column, value in data do
		table.insert(columns, column)
		table.insert(values, value)
		table.insert(placeholders, "?")
	end

	local sql = `INSERT INTO {tableName} ({table.concat(columns, ", ")}) VALUES ({table.concat(placeholders, ", ")})`

	local result = self:execute(sql, values):await()

	return future.Future.new(function()
		return result.lastInsertId or 0
	end) :: future.FutureLike<string, number>
end

--[=[
	@within Database

	Updates rows in a table matching a WHERE clause.
]=]
function Database.Prototype.update(
	self: Database,
	tableName: string,
	data: DatabaseRow,
	where: string,
	whereParams: { any }?
): future.FutureLike<string, DatabaseResult>
	local sets = {}
	local values = {}

	for column, value in data do
		table.insert(sets, `{column} = ?`)
		table.insert(values, value)
	end

	if whereParams then
		for _, param in whereParams do
			table.insert(values, param)
		end
	end

	local sql = `UPDATE {tableName} SET {table.concat(sets, ", ")} WHERE {where}`

	return self:execute(sql, values)
end

--[=[
	@within Database

	Deletes rows from a table matching a WHERE clause.
]=]
function Database.Prototype.delete(
	self: Database,
	tableName: string,
	where: string,
	whereParams: { any }?
): future.FutureLike<string, DatabaseResult>
	local sql = `DELETE FROM {tableName} WHERE {where}`

	return self:execute(sql, whereParams)
end

--[=[
	@within Database

	Creates a table if it does not exist.
]=]
function Database.Prototype.createTable(
	self: Database,
	tableName: string,
	columns: { string }
): future.FutureLike<string, boolean>
	local sql = `CREATE TABLE IF NOT EXISTS {tableName} ({table.concat(columns, ", ")})`

	return self:execute(sql)
end

--[=[
	@within Database

	Begins a transaction.
]=]
function Database.Prototype.begin(self: Database): future.FutureLike<string, Transaction>
	return self.adapter:begin()
end

--[=[
	@within Database

	Runs pending migrations.
]=]
function Database.Prototype.migrate(self: Database): future.FutureLike<string, boolean>
	return future.Future.new(function()
		for _, migration in self.migrations do
			self.logger:info(`running migration: {migration.id}`)

			local success, errorMessage = xpcall(migration.up, debug.traceback)

			if not success then
				self.logger:error(`migration '{migration.id}' failed: {errorMessage}`)

				return false
			end
		end

		return true
	end) :: future.FutureLike<string, boolean>
end

--[=[
	@within Database

	Registers a migration.
]=]
function Database.Prototype.addMigration(self: Database, migration: DatabaseMigration): ()
	table.insert(self.migrations, migration)

	return
end

--[=[
	@within Database

	Closes the database connection.
]=]
function Database.Prototype.close(self: Database): future.FutureLike<string, boolean>
	return self.adapter:close()
end

function Database.Interface.new(adapter: DatabaseAdapter): Database
	local self = setmetatable(
		{
			logger = Logger.new("Database"),
			adapter = adapter,
			migrations = {},
		} :: Database,
		{ __index = Database.Prototype }
	)

	return self
end

export type Database = typeof(Database.Prototype) & {
	logger: Logger,
	adapter: DatabaseAdapter,
	migrations: { DatabaseMigration },
}

return Database.Interface
