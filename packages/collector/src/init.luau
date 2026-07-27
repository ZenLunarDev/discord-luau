--[=[
	@class Collector
	@__index Prototype

	Collectors and waitFor utilities for discord-luau interactions.

	Provides component collectors (buttons, selects, modals), reaction collectors,
	message collectors, and waitFor helpers with timeout and filter support.
]=]

--[=[
	@prop logger logger.Logger
	@within Collector
]=]

--[=[
	@prop collectors { CollectorInstance }
	@within Collector
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")
local future = require("@self/../luau_packages/future")

local Collector = {}

Collector.Interface = {}
Collector.Prototype = {}

export type CollectorInstance = {
	id: string,
	type: string,
	filter: (any) -> boolean,
	timeout: number,
	collected: { any },
	maxItems: number?,
	resolve: (any) -> (),
	reject: (string) -> (),
	timedOut: boolean,
	createdAt: number,
}

local collectorIdCounter = 0

local function generateId(): string
	collectorIdCounter += 1

	return `collector_{collectorIdCounter}_{os.time()}`
end

local function createCollector(
	collectors: { CollectorInstance },
	type: string,
	filter: (any) -> boolean,
	timeout: number,
	maxItems: number?
): CollectorInstance
	local id = generateId()
	local collected = {}
	local thread = coroutine.running()
	local settled = false

	local function resolve(item: any): ()
		if settled then
			return
		end

		settled = true

		table.insert(collected, item)

		if maxItems and #collected >= maxItems then
			for index, collector in collectors do
				if collector.id == id then
					table.remove(collectors, index)
					break
				end
			end
		end

		local status, response = coroutine.resume(thread, item)

		if not status then
			Logger.new("Collector"):warn(`collector resume failed: {response}`)
		end
	end

	local function reject(reason: string): ()
		if settled then
			return
		end

		settled = true

		for index, collector in collectors do
			if collector.id == id then
				table.remove(collectors, index)
				break
			end
		end

		local status, response = coroutine.resume(thread, nil, reason)

		if not status then
			Logger.new("Collector"):warn(`collector reject failed: {response}`)
		end
	end

	local collector: CollectorInstance = {
		id = id,
		type = type,
		filter = filter,
		timeout = timeout,
		collected = collected,
		maxItems = maxItems,
		resolve = resolve,
		reject = reject,
		timedOut = false,
		createdAt = os.time(),
	}

	table.insert(collectors, collector)

	if timeout then
		stdPolyfills.task.delay(timeout, function()
			if not settled then
				collector.timedOut = true
				reject("timeout")
			end
		end)
	end

	return collector
end

--[=[
	@within Collector

	Creates a component interaction collector that captures matching interactions.
]=]
function Collector.Prototype.newComponentCollector(
	self: Collector,
	options: {
		filter: ((interaction: any) -> boolean)?,
		timeout: number?,
		maxItems: number?,
	}
): future.FutureLike<any, string>
	local filter = options.filter or function()
		return true
	end
	local timeout = options.timeout or 30
	local maxItems = options.maxItems

	return future.Future.new(function()
		createCollector(self.collectors, "component", filter, timeout, maxItems)
		return coroutine.yield()
	end) :: future.FutureLike<any, string>
end

--[=[
	@within Collector

	Creates a modal submission collector that captures matching modal interactions.
]=]
function Collector.Prototype.newModalCollector(
	self: Collector,
	options: {
		filter: ((interaction: any) -> boolean)?,
		timeout: number?,
		maxItems: number?,
	}
): future.FutureLike<any, string>
	local filter = options.filter or function()
		return true
	end
	local timeout = options.timeout or 30
	local maxItems = options.maxItems

	return future.Future.new(function()
		createCollector(self.collectors, "modal", filter, timeout, maxItems)
		return coroutine.yield()
	end) :: future.FutureLike<any, string>
end

--[=[
	@within Collector

	Creates a reaction collector that captures matching reaction events.
]=]
function Collector.Prototype.newReactionCollector(
	self: Collector,
	options: {
		filter: ((reaction: any) -> boolean)?,
		timeout: number?,
		maxItems: number?,
	}
): future.FutureLike<any, string>
	local filter = options.filter or function()
		return true
	end
	local timeout = options.timeout or 30
	local maxItems = options.maxItems

	return future.Future.new(function()
		createCollector(self.collectors, "reaction", filter, timeout, maxItems)
		return coroutine.yield()
	end) :: future.FutureLike<any, string>
end

--[=[
	@within Collector

	Creates a message collector that captures matching messages.
]=]
function Collector.Prototype.newMessageCollector(
	self: Collector,
	options: {
		filter: ((message: any) -> boolean)?,
		timeout: number?,
		maxItems: number?,
	}
): future.FutureLike<any, string>
	local filter = options.filter or function()
		return true
	end
	local timeout = options.timeout or 30
	local maxItems = options.maxItems

	return future.Future.new(function()
		createCollector(self.collectors, "message", filter, timeout, maxItems)
		return coroutine.yield()
	end) :: future.FutureLike<any, string>
end

--[=[
	@within Collector

	Dispatches an interaction to the appropriate collector if a matching filter exists.
]=]
function Collector.Prototype.dispatchInteraction(
	self: Collector,
	interaction: any
): boolean
	for _, collector in self.collectors do
		if collector.type == "component" or collector.type == "modal" then
			if not collector.timedOut and collector.filter(interaction) then
				collector.resolve(interaction)

				return true
			end
		end
	end

	return false
end

--[=[
	@within Collector

	Dispatches a reaction event to the appropriate collector if a matching filter exists.
]=]
function Collector.Prototype.dispatchReaction(self: Collector, reaction: any): boolean
	for _, collector in self.collectors do
		if collector.type == "reaction" then
			if not collector.timedOut and collector.filter(reaction) then
				collector.resolve(reaction)

				return true
			end
		end
	end

	return false
end

--[=[
	@within Collector

	Dispatches a message event to the appropriate collector if a matching filter exists.
]=]
function Collector.Prototype.dispatchMessage(self: Collector, message: any): boolean
	for _, collector in self.collectors do
		if collector.type == "message" then
			if not collector.timedOut and collector.filter(message) then
				collector.resolve(message)

				return true
			end
		end
	end

	return false
end

--[=[
	@within Collector

	Stops all active collectors.
]=]
function Collector.Prototype.stopAll(self: Collector): ()
	for _, collector in self.collectors do
		collector.reject("stopped")
	end

	table.clear(self.collectors)

	return
end

function Collector.Interface.new(): Collector
	local self = setmetatable(
		{
			logger = Logger.new("Collector"),
			collectors = {},
		} :: Collector,
		{ __index = Collector.Prototype }
	)

	return self
end

export type Collector = typeof(Collector.Prototype) & {
	logger: Logger,
	collectors: { CollectorInstance },
}

return Collector.Interface
