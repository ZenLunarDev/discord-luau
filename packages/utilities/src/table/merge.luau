--[=[
	Deep merge and patch utilities for nested table updates.
]=]

local tableReflect = require("@self/table/reflect")

local Table = {}

--[=[
	Shallow merges source tables into a base table.
]=]
function Table.merge(base: { [string]: any }, ...: { [string]: any }): { [string]: any }
	local result = table.clone(base)

	for _, source in { ... } do
		for key, value in source do
			result[key] = value
		end
	end

	return result
end

--[=[
	Deep merges source tables into a base table. Tables are merged recursively instead of overwritten.
]=]
function Table.deepMerge(base: { [string]: any }, ...: { [string]: any }): { [string]: any }
	local result = table.clone(base)

	for _, source in { ... } do
		for key, value in source do
			if type(value) == "table" and type(result[key]) == "table" then
				result[key] = Table.deepMerge(result[key], value)
			else
				result[key] = value
			end
		end
	end

	return result
end

--[=[
	Applies a patch to a target table, returning a new table with the patch applied.
]=]
function Table.patch(target: { [string]: any }, patch: { [string]: any }): { [string]: any }
	return Table.deepMerge(target, patch)
end

--[=[
	Applies a patch directly to the target table (mutates in-place).
]=]
function Table.apply(target: { [string]: any }, patch: { [string]: any }): ()
	for key, value in patch do
		if type(value) == "table" and type(target[key]) == "table" then
			Table.apply(target[key], value)
		else
			target[key] = value
		end
	end

	return
end

--[=[
	Returns a diff between two tables, useful for generating patch objects.
]=]
function Table.diff(base: { [string]: any }, updated: { [string]: any }): { [string]: any }
	local diff = {}

	for key, value in updated do
		if base[key] ~= value then
			if type(value) == "table" and type(base[key]) == "table" then
				local nestedDiff = Table.diff(base[key], value)

				if next(nestedDiff) then
					diff[key] = nestedDiff
				end
			else
				diff[key] = value
			end
		end
	end

	return diff
end

--[=[
	Returns only the specified keys from a table.
]=]
function Table.pick(source: { [string]: any }, keys: { string }): { [string]: any }
	local picked = {}

	for _, key in keys do
		if source[key] ~= nil then
			picked[key] = source[key]
		end
	end

	return picked
end

--[=[
	Returns all keys from a table except the specified ones.
]=]
function Table.omit(source: { [string]: any }, keys: { string }): { [string]: any }
	local omitted = table.clone(source)

	for _, key in keys do
		omitted[key] = nil
	end

	return omitted
end

--[=[
	Creates a new table from a constructor function and arguments.
]=]
function Table.from(constructor: (string, any) -> any, pairs: { [string]: any }): { [string]: any }
	local result = {}

	for key, value in pairs do
		result[key] = constructor(key, value)
	end

	return result
end

--[=[
	Maps a function over a table's values, returning a new table.
]=]
function Table.map(source: { [string]: any }, mapper: (any, string) -> any): { [string]: any }
	local mapped = {}

	for key, value in source do
		mapped[key] = mapper(value, key)
	end

	return mapped
end

--[=[
	Filters a table by a predicate, returning a new table.
]=]
function Table.filter(source: { [string]: any }, predicate: (any, string) -> boolean): { [string]: any }
	local filtered = {}

	for key, value in source do
		if predicate(value, key) then
			filtered[key] = value
		end
	end

	return filtered
end

--[=[
	Checks if a table contains a specific value.
]=]
function Table.includes(source: { [string]: any }, value: any): boolean
	for _, v in source do
		if v == value then
			return true
		end
	end

	return false
end

return Table
