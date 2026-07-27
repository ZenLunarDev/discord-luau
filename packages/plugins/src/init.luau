--[=[
	@class Plugins
	@__index Prototype

	Plugin and extension system for discord-luau bots.

	Supports loading, unloading, reloading plugins with lifecycle hooks, dependency resolution,
	event hooking, and per-plugin configuration.
]=]

--[=[
	@prop logger logger.Logger
	@within Plugins
]=]

--[=[
	@prop plugins { [string]: Plugin }
	@within Plugins
]=]

--[=[
	@prop hooks { [string]: { (any) -> () } }
	@within Plugins
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")

local Plugins = {}

Plugins.Interface = {}
Plugins.Prototype = {}

export type Plugin = {
	name: string,
	version: string?,
	description: string?,
	author: string?,
	dependencies: { string }?,
	config: { [string]: any }?,
	setup: (Plugins, any) -> (() -> ())?,
}

export type HookHandler = (data: any) -> ()

--[=[
	@within Plugins

	Registers a global event hook that all plugins can subscribe to.
]=]
function Plugins.Prototype.registerHook(self: Plugins, name: string): ()
	self.hooks[name] = self.hooks[name] or {}

	return
end

--[=[
	@within Plugins

	Subscribes to a registered hook. Returns a function that unsubscribes when called.
]=]
function Plugins.Prototype.subscribe(self: Plugins, name: string, callback: HookHandler): () -> ()
	if not self.hooks[name] then
		self.hooks[name] = {}
	end

	table.insert(self.hooks[name], callback)

	return function()
		local index = table.find(self.hooks[name], callback)

		if index then
			table.remove(self.hooks[name], index)
		end
	end
end

--[=[
	@within Plugins

	Invokes all subscribers of a named hook.
]=]
function Plugins.Prototype.invokeHook(self: Plugins, name: string, data: any?): ()
		local hookHandlers = self.hooks[name]

	if hookHandlers then
		for _, callback in hookHandlers do
			stdPolyfills.task.spawn(callback, data)
		end
	end

	return
end

--[=[
	@within Plugins

	Loads a plugin by name, resolving dependencies first.
]=]
function Plugins.Prototype.load(self: Plugins, plugin: Plugin, context: any?): boolean
	if self.plugins[plugin.name] then
		self.logger:warn(`plugin '{plugin.name}' is already loaded`)
		return false
	end

	if plugin.dependencies then
		for _, dependency in plugin.dependencies do
			if not self.plugins[dependency] then
				self.logger:error(`plugin '{plugin.name}' requires '{dependency}' which is not loaded`)
				return false
			end
		end
	end

	local teardown: (() -> ())? = nil

	local success, errorMessage = xpcall(function()
		if plugin.setup then
			teardown = (plugin.setup :: (any, any) -> (() -> ()))(self, context)
		end
	end, debug.traceback)

	if not success then
		self.logger:error(`plugin '{plugin.name}' setup failed:\n{errorMessage}`)
		return false
	end

	self.plugins[plugin.name] = {
		definition = plugin,
		teardown = teardown or function() end,
		loadedAt = os.time(),
	}

	self.logger:info(`loaded plugin '{plugin.name}'`)
	self:invokeHook("pluginLoaded", { name = plugin.name })

	return true
end

--[=[
	@within Plugins

	Unloads a plugin by name, calling its teardown function.
]=]
function Plugins.Prototype.unload(self: Plugins, name: string): boolean
	local pluginData = self.plugins[name]

	if not pluginData then
		self.logger:warn(`plugin '{name}' is not loaded`)
		return false
	end

	local success, errorMessage = xpcall(function()
		(pluginData.teardown :: () -> ())()
	end, debug.traceback)

	if not success then
		self.logger:warn(`plugin '{name}' teardown threw:\n{errorMessage}`)
	end

	self.plugins[name] = nil

	self.logger:info(`unloaded plugin '{name}'`)
	self:invokeHook("pluginUnloaded", { name = name })

	return true
end

--[=[
	@within Plugins

	Reloads a plugin by unloading and loading it again.
]=]
function Plugins.Prototype.reload(self: Plugins, name: string, context: any?): boolean
	local pluginData = self.plugins[name]

	if not pluginData then
		self.logger:warn(`plugin '{name}' is not loaded`)
		return false
	end

	local definition = pluginData.definition
	local unloaded = self:unload(name)

	if not unloaded then
		return false
	end

	return self:load(definition, context)
end

--[=[
	@within Plugins

	Returns a list of all loaded plugin names.
]=]
function Plugins.Prototype.getLoaded(self: Plugins): { string }
	local names = {}

	for name, _ in self.plugins do
		table.insert(names, name)
	end

	return names
end

--[=[
	@within Plugins

	Returns the plugin definition for a loaded plugin.
]=]
function Plugins.Prototype.get(self: Plugins, name: string): Plugin?
	local pluginData = self.plugins[name]

	if pluginData then
		return pluginData.definition
	end

	return nil
end

function Plugins.Interface.new(): Plugins
	local self = setmetatable(
		{
			logger = Logger.new("Plugins"),
			plugins = {},
			hooks = {},
		} :: Plugins,
		{ __index = Plugins.Prototype }
	)

	return self
end

export type Plugins = typeof(Plugins.Prototype) & {
	logger: Logger,
	plugins: { [string]: { definition: Plugin, teardown: (() -> ())?, loadedAt: number } },
	hooks: { [string]: { HookHandler } },
}

return Plugins.Interface
