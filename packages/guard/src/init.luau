--[=[
	@class Guard
	@__index Prototype

	Permission guards and authorization system for discord-luau commands.

	Supports user permission checks, role checks, channel/guild checks, custom guard functions,
	rate limiting per user/guild, and audit logging of guard evaluations.
]=]

--[=[
	@prop logger logger.Logger
	@within Guard
]=]

--[=[
	@prop rateLimits { [string]: { count: number, resetAt: number } }
	@within Guard
]=]

--[=[
	@prop auditLog { GuardAuditEntry }
	@within Guard
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")
local apiTypes = require("@self/../luau_packages/api_types")
local classes = require("@self/../luau_packages/classes")
local bit = require("@self/../luau_packages/bit")

local Guard = {}

Guard.Interface = {}
Guard.Prototype = {}

export type GuardContext = {
	interaction: any,
	member: (classes.GuildMember)?,
	channel: (classes.GuildText | classes.GuildVoice | classes.GuildAnnouncement)?,
	guild: classes.Guild?,
	user: classes.User?,
}

export type GuardResult = {
	passed: boolean,
	reason: string?,
	action: "allow" | "deny" | "challenge",
}

export type GuardAuditEntry = {
	timestamp: number,
	guildId: string?,
	userId: string,
	command: string,
	result: string,
	reason: string?,
	details: { [string]: any },
}

local auditLogMaxSize = 1000

local permissionsMap = apiTypes.permission.Permissions

--[=[
	@within Guard

	Evaluates a required permissions bitmask against the member's permissions.
]=]
function Guard.Prototype.checkPermissions(
	self: Guard,
	requiredPermissions: number,
	context: GuardContext
): GuardResult
	local member = context.member

	if not member then
		return {
			passed = false,
			reason = "Member context not found",
			action = "deny",
		}
	end

	local memberPermissions = member.permissions

	if not memberPermissions then
		return {
			passed = false,
			reason = "Member permissions not found",
			action = "deny",
		}
	end

	local missing = {}

	for permissionName, permissionValue in permissionsMap do
		if bit.band(requiredPermissions :: number, permissionValue :: number) == (permissionValue :: number) then
			if bit.band(memberPermissions :: number, permissionValue :: number) ~= (permissionValue :: number) then
				table.insert(missing, permissionName)
			end
		end
	end

	if #missing > 0 then
		return {
			passed = false,
			reason = `Missing permissions: {table.concat(missing, ", ")}`,
			action = "deny",
		}
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a list of role IDs against the member's roles.
]=]
function Guard.Prototype.checkRoles(
	self: Guard,
	roleIds: { string },
	context: GuardContext
): GuardResult
	local member = context.member

	if not member then
		return {
			passed = false,
			reason = "Member context not found",
			action = "deny",
		}
	end

	local memberRoleIds = member.roles or {}

	for _, requiredRoleId in roleIds do
		if not table.find(memberRoleIds, requiredRoleId) then
			return {
				passed = false,
				reason = `Missing role: {requiredRoleId}`,
				action = "deny",
			}
		end
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a channel type constraint.
]=]
function Guard.Prototype.checkChannelType(
	self: Guard,
	allowedTypes: { apiTypes.channel.ChannelTypes },
	context: GuardContext
): GuardResult
	local channel = context.channel

	if not channel then
		return {
			passed = false,
			reason = "Channel context not found",
			action = "deny",
		}
	end

	local channelType = channel.type

	if not table.find(allowedTypes, channelType) then
		local typeNames = {}

		for _, t in allowedTypes do
			table.insert(typeNames, tostring(t))
		end

		return {
			passed = false,
			reason = `Channel type {tostring(channelType)} not allowed. Allowed: {table.concat(typeNames, ", ")}`,
			action = "deny",
		}
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a guild-only constraint.
]=]
function Guard.Prototype.checkGuildOnly(self: Guard, context: GuardContext): GuardResult
	if not context.guild then
		return {
			passed = false,
			reason = "Command can only be used in a guild",
			action = "deny",
		}
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a DM-only constraint.
]=]
function Guard.Prototype.checkDMOnly(self: Guard, context: GuardContext): GuardResult
	if context.guild then
		return {
			passed = false,
			reason = "Command can only be used in DMs",
			action = "deny",
		}
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a custom guard function.
]=]
function Guard.Prototype.checkCustom(
	self: Guard,
	guardFn: (context: GuardContext) -> GuardResult?,
	context: GuardContext
): GuardResult
	local success, result = xpcall(function()
		return (guardFn :: (GuardContext) -> GuardResult?)(context)
	end, debug.traceback)

	if not success then
		return {
			passed = false,
			reason = `Guard function threw: {tostring(result)}`,
			action = "deny",
		}
	end

	if result then
		return result
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Evaluates a rate limit constraint per user or guild.
]=]
function Guard.Prototype.checkRateLimit(
	self: Guard,
	key: string,
	limit: number,
	window: number,
	context: GuardContext
): GuardResult
	local userId = context.user and context.user.id or "unknown"
	local now = os.time()
	local rateKey = `{key}:{userId}`

	local current = self.rateLimits[rateKey]

	if not current then
		self.rateLimits[rateKey] = {
			count = 1,
			resetAt = now + window,
		}

		return {
			passed = true,
			reason = nil,
			action = "allow",
		}
	end

	if now > current.resetAt then
		current.count = 1
		current.resetAt = now + window

		return {
			passed = true,
			reason = nil,
			action = "allow",
		}
	end

	current.count += 1

	if current.count > limit then
		local retryAfter = current.resetAt - now

		return {
			passed = false,
			reason = `Rate limited. Try again in {retryAfter} seconds.`,
			action = "challenge",
		}
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Runs a list of guards and returns the first failing result, or passes if all pass.
]=]
function Guard.Prototype.runGuards(
	self: Guard,
	guards: { { type: string, options: any } },
	context: GuardContext
): GuardResult
	for _, guardEntry in guards do
		local result: GuardResult

		if guardEntry.type == "permissions" then
			result = self:checkPermissions(guardEntry.options.permissions :: number, context)
		elseif guardEntry.type == "roles" then
			result = self:checkRoles(guardEntry.options.roleIds :: { string }, context)
		elseif guardEntry.type == "channelType" then
			result = self:checkChannelType(guardEntry.options.allowedTypes :: { apiTypes.channel.ChannelTypes }, context)
		elseif guardEntry.type == "guildOnly" then
			result = self:checkGuildOnly(context)
		elseif guardEntry.type == "dmOnly" then
			result = self:checkDMOnly(context)
		elseif guardEntry.type == "custom" then
			result = self:checkCustom(guardEntry.options.guardFn :: (GuardContext) -> GuardResult?, context)
		elseif guardEntry.type == "rateLimit" then
			result = self:checkRateLimit(
				guardEntry.options.key :: string,
				guardEntry.options.limit :: number,
				guardEntry.options.window :: number,
				context
			)
		else
			result = {
				passed = false,
				reason = `Unknown guard type: {guardEntry.type}`,
				action = "deny",
			}
		end

		table.insert(self.auditLog, {
			timestamp = os.time(),
			guildId = context.guild and context.guild.id,
			userId = context.user and context.user.id or "unknown",
			command = context.interaction.data and context.interaction.data.name or "unknown",
			result = if result.passed then "pass" else "fail",
			reason = result.reason,
			details = guardEntry.options,
		})

		if #self.auditLog > auditLogMaxSize then
			table.remove(self.auditLog, 1)
		end

		if not result.passed then
			return result
		end
	end

	return {
		passed = true,
		reason = nil,
		action = "allow",
	}
end

--[=[
	@within Guard

	Returns the audit log.
]=]
function Guard.Prototype.getAuditLog(self: Guard): { GuardAuditEntry }
	return self.auditLog
end

--[=[
	@within Guard

	Clears the audit log.
]=]
function Guard.Prototype.clearAuditLog(self: Guard): ()
	table.clear(self.auditLog)

	return
end

function Guard.Interface.new(): Guard
	local self = setmetatable(
		{
			logger = Logger.new("Guard"),
			rateLimits = {},
			auditLog = {},
		} :: Guard,
		{ __index = Guard.Prototype }
	)

	return self
end

export type Guard = typeof(Guard.Prototype) & {
	logger: Logger,
	rateLimits: { [string]: { count: number, resetAt: number } },
	auditLog: { GuardAuditEntry },
}

return Guard.Interface
