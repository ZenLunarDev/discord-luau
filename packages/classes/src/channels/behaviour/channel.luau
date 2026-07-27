--[=[
	@class Classes.Channels.Channel
	@__index Prototype

	Implementation of the Discord Channel class in Luau. Responsible for implementing the various properties, and methods
	for a generic channel object.
]=]

--[=[
	@prop type string
	@within Classes.Channels.Channel
	The type of the channel, indicating its functionality and behavior.
]=]

--[=[
	@prop id string
	@within Classes.Channels.Channel
	The unique identifier for this channel.
]=]

--[=[
	@prop name string?
	@within Classes.Channels.Channel
	The name of the channel.
]=]

--[=[
	@prop flags Classes.Channels.ChannelBitflag?
	@within Classes.Channels.Channel
	The flags that indicate various properties and states of the channel.
]=]

local apiTypes = require("../../../luau_packages/api_types")
local future = require("../../../luau_packages/future")
local rest = require("../../../luau_packages/rest")
local state = require("../../../luau_packages/state")
local builders = require("../../../luau_packages/builders")

local channelBitflags = require("../../bitflags/channel")

local ChannelBehaviour = {}

ChannelBehaviour.Interface = {}
ChannelBehaviour.Prototype = {}

--[=[
	@within Classes.Channels.Channel

	Delete a channel, or close a private message. Requires the MANAGE_CHANNELS permission for the guild, or MANAGE_THREADS
	if the channel is a thread. Deleting a category does not delete its child channels; they will have their parent_id
	removed and a Channel Update Gateway event will fire for each of them.
]=]
function ChannelBehaviour.Prototype.deleteChannelAsync<T>(self: Channel<T>): future.FutureLike<string, Channel<T>>
	return future.Future.new(function()
		local request = self.state.rest:newRequest()

		local response = rest.channel.deleteOrCloseChannelAsync(request, self.id):await()

		assert(response:isOk(), `{response:unwrapErr()}`)

		self:sync(response:unwrapOk())

		return self
	end) :: future.FutureLike<string, Channel<T>>
end

--[=[
	@within Classes.Channels.Channel

	Post a typing indicator for the specified channel, which expires after 10 seconds.

	Generally bots should not use this route. However, if a bot is responding to a command and expects the computation to
	take a few seconds, this endpoint may be called to let the user know that the bot is processing their message.
]=]
function ChannelBehaviour.Prototype.triggerTypingIndicatorAsync<T>(self: Channel<T>): future.FutureLike<string, nil>
	return future.Future.new(function()
		local request = self.state.rest:newRequest()

		local response = rest.channel.triggerTypingIndicatorAsync(request, self.id):await()

		assert(response:isOk(), `{response:unwrapErr()}`)

		return nil
	end) :: future.FutureLike<string, nil>
end

--[=[
	@within Classes.Channels.Channel

	Modifies the channel's settings using the provided JSON data. Optionally accepts an audit log reason.
]=]
function ChannelBehaviour.Prototype.modifyAsync<T>(
	self: Channel<T>,
	json: builders.channelJSON,
	reason: string?
): future.FutureLike<string, Channel<T>>
	return future.Future.new(function()
		local request = self.state.rest:newRequest()

		local response = rest.channel.modifyChannelAsync(request, self.id, json, reason):await()

		assert(response:isOk(), `{response:unwrapErr()}`)

		self:sync(response:unwrapOk())

		return self
	end) :: future.FutureLike<string, Channel<T>>
end

function ChannelBehaviour.Prototype.toJSON<T>(self: Channel<T>): apiTypes.ChannelObject
	local json: apiTypes.ChannelObject = {
		id = self.id,
		type = self.type and apiTypes.channel.ChannelTypes[self.type],
		name = self.name,
		flags = self.flags and self.flags:toNumber(),
	}

	return json
end

function ChannelBehaviour.Prototype.patch<T>(self: Channel<T>, patch: { [string]: any }): Channel<T>
	local util = require("../../../luau_packages/util")
	local merged = util.tableMerge.deepMerge(table.clone(self), patch)

	for key, value in merged do
		self[key] = value
	end

	return self
end

function ChannelBehaviour.Prototype.merge<T>(self: Channel<T>, ...: { [string]: any }): Channel<T>
	local util = require("../../../luau_packages/util")

	for _, source in { ... } do
		for key, value in source do
			if type(value) == "table" and type(self[key]) == "table" then
				self[key] = util.tableMerge.deepMerge(self[key], value)
			else
				self[key] = value
			end
		end
	end

	return self
end

function ChannelBehaviour.Prototype.patchAsync<T>(
	self: Channel<T>,
	patch: { [string]: any }
): future.FutureLike<string, Channel<T>>
	return future.Future.new(function()
		local util = require("../../../luau_packages/util")
		local current = self:toJSON()
		local merged = util.tableMerge.deepMerge(current, patch)

		local request = self.state.rest:newRequest()
		local response = rest.channel.modifyChannelAsync(request, self.id, merged :: any):await()

		assert(response:isOk(), `{response:unwrapErr()}`)

		self:sync(response:unwrapOk())

		return self
	end) :: future.FutureLike<string, Channel<T>>
end

function ChannelBehaviour.Prototype.mergeAsync<T>(
	self: Channel<T>,
	...: { [string]: any }
): future.FutureLike<string, Channel<T>>
	return future.Future.new(function()
		local util = require("../../../luau_packages/util")
		local current = self:toJSON()

		for _, source in { ... } do
			current = util.tableMerge.deepMerge(current, source)
		end

		local request = self.state.rest:newRequest()
		local response = rest.channel.modifyChannelAsync(request, self.id, current :: any):await()

		assert(response:isOk(), `{response:unwrapErr()}`)

		self:sync(response:unwrapOk())

		return self
	end) :: future.FutureLike<string, Channel<T>>
end

function ChannelBehaviour.Interface.inheritProperties(class: any, channelData: apiTypes.ChannelObject)
	class.type = apiTypes.channel.ChannelTypes[channelData.type]

	class.id = channelData.id

	class.name = channelData.name

	class.flags = channelData.flags and channelBitflags.new(channelData.flags)
end

--[=[
	@within Classes.Channels.Channel
]=]
function ChannelBehaviour.Interface.inheritMethods(class: any)
	for key, value in ChannelBehaviour.Prototype do
		class[key] = value
	end
end

type Channel<T> = T & ChannelBehaviour & {
	state: state.State,

	sync: (...any) -> (),
}

export type ChannelBehaviourMethods = typeof(ChannelBehaviour.Prototype)
export type ChannelBehaviourProperties = {
	id: apiTypes.Snowflake,
	type: apiTypes.ChannelType,
	name: string?,
	flags: channelBitflags.ChannelBitflag?,
}

export type ChannelBehaviour = ChannelBehaviourMethods & ChannelBehaviourProperties

return ChannelBehaviour.Interface
