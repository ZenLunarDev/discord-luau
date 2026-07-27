--[=[
	@class Autocomplete
	@__index Prototype

	Autocomplete builder helpers for discord-luau commands.

	Provides fuzzy matching, prefix matching, localized choice builders, paginated autocomplete,
	and dynamic source loading for slash command autocomplete interactions.
]=]

--[=[
	@prop logger logger.Logger
	@within Autocomplete
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")

local Autocomplete = {}

Autocomplete.Interface = {}
Autocomplete.Prototype = {}

export type AutocompleteChoice = {
	name: string,
	value: string,
	description: string?,
	nameLocalizations: { [string]: string }?,
}

--[=[
	@within Autocomplete

	Computes the Levenshtein distance between two strings.
]=]
function Autocomplete.Prototype.levenshtein(self: Autocomplete, a: string, b: string): number
	local matrix = {}

	for i = 0, #a do
		matrix[i] = { i }
	end

	for j = 0, #b do
		matrix[0][j] = j
	end

	for i = 1, #a do
		for j = 1, #b do
			local cost = if string.sub(a, i, i) == string.sub(b, j, j) then 0 else 1

			matrix[i][j] = math.min(
				matrix[i - 1][j] + 1,
				matrix[i][j - 1] + 1,
				matrix[i - 1][j - 1] + cost
			)
		end
	end

	return matrix[#a][#b]
end

--[=[
	@within Autocomplete

	Fuzzy matches a query against a list of choices, returning ranked results.
]=]
function Autocomplete.Prototype.fuzzyMatch(
	self: Autocomplete,
	query: string,
	choices: { AutocompleteChoice },
	maxResults: number?
): { AutocompleteChoice }
	local max = maxResults or 25
	local scored = {}

	for _, choice in choices do
		local lowerQuery = string.lower(query)
		local lowerName = string.lower(choice.name)
		local distance = self:levenshtein(lowerQuery, lowerName)

		local startsWithScore = if string.sub(lowerName, 1, #lowerQuery) == lowerQuery then 0 else distance

		local containsScore = if string.find(lowerName, lowerQuery, 1, true) then distance * 2 else distance * 3

		local score = math.min(startsWithScore, containsScore)

		table.insert(scored, { choice = choice, score = score })
	end

	table.sort(scored, function(a, b)
		return a.score < b.score
	end)

	local results = {}

	for i = 1, math.min(max, #scored) do
		table.insert(results, scored[i].choice)
	end

	return results
end

--[=[
	@within Autocomplete

	Matches a query against choices by prefix, returning all matches.
]=]
function Autocomplete.Prototype.prefixMatch(
	self: Autocomplete,
	query: string,
	choices: { AutocompleteChoice },
	maxResults: number?
): { AutocompleteChoice }
	local max = maxResults or 25
	local lowerQuery = string.lower(query)
	local results = {}

	for _, choice in choices do
		if string.sub(string.lower(choice.name), 1, #lowerQuery) == lowerQuery then
			table.insert(results, choice)

			if #results >= max then
				break
			end
		end
	end

	return results
end

--[=[
	@within Autocomplete

	Creates a paginated autocomplete response.
]=]
function Autocomplete.Prototype.paginate(
	self: Autocomplete,
	choices: { AutocompleteChoice },
	page: number,
	pageSize: number
): { AutocompleteChoice }
	local start = (page - 1) * pageSize + 1
	local end_ = math.min(start + pageSize - 1, #choices)
	local pageChoices = {}

	for i = start, end_ do
		table.insert(pageChoices, choices[i])
	end

	return pageChoices
end

--[=[
	@within Autocomplete

	Replies to an autocomplete interaction with the given choices.
]=]
function Autocomplete.Prototype.reply(
	self: Autocomplete,
	interaction: any,
	choices: { AutocompleteChoice }
): ()
	local payload = {}

	for _, choice in choices do
		table.insert(payload, {
			name = choice.name,
			value = choice.value,
			nameLocalizations = choice.nameLocalizations or {},
		})
	end

	interaction:respondAutocompleteAsync({
		choices = payload,
	}):poll()

	return
end

--[=[
	@within Autocomplete

	Loads choices from an async source function.
]=]
function Autocomplete.Prototype.fromSource(
	self: Autocomplete,
	sourceFn: (query: string) -> future.FutureLike<string, { AutocompleteChoice }>,
	query: string,
	maxResults: number?
): future.FutureLike<string, { AutocompleteChoice }>
	return sourceFn(query) :: future.FutureLike<string, { AutocompleteChoice }>
end

--[=[
	@within Autocomplete

	Creates a static choice list.
]=]
function Autocomplete.Prototype.static(
	self: Autocomplete,
	choices: { AutocompleteChoice }
): { AutocompleteChoice }
	return choices
end

--[=[
	@within Autocomplete

	Creates choices from a key-value map.
]=]
function Autocomplete.Prototype.fromMap(
	self: Autocomplete,
	map: { [string]: string }
): { AutocompleteChoice }
	local choices = {}

	for key, value in map do
		table.insert(choices, {
			name = value,
			value = key,
		})
	end

	return choices
end

--[=[
	@within Autocomplete

	Creates choices from a list of strings.
]=]
function Autocomplete.Prototype.fromStrings(
	self: Autocomplete,
	strings: { string }
): { AutocompleteChoice }
	local choices = {}

	for _, str in strings do
		table.insert(choices, {
			name = str,
			value = str,
		})
	end

	return choices
end

function Autocomplete.Interface.new(): Autocomplete
	local self = setmetatable(
		{
			logger = Logger.new("Autocomplete"),
		} :: Autocomplete,
		{ __index = Autocomplete.Prototype }
	)

	return self
end

export type Autocomplete = typeof(Autocomplete.Prototype) & {
	logger: Logger,
}

return Autocomplete.Interface
