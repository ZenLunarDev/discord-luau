--[=[
	@class Scheduler
	@__index Prototype

	Task scheduler and cron-like job system for discord-luau bots.

	Supports one-shot timers, recurring tasks with cron expressions, timezone-aware scheduling,
	persistent task storage, task history, and pause/resume controls.
]=]

--[=[
	@prop logger logger.Logger
	@within Scheduler
]=]

--[=[
	@prop tasks { [string]: Task }
	@within Scheduler
]=]

--[=[
	@prop running { thread }
	@within Scheduler
]=]

--[=[
	@prop history { SchedulerHistoryEntry }
	@within Scheduler
]=]

local Logger = require("@self/../luau_packages/logger")
local stdPolyfills = require("@self/../luau_packages/std_polyfills")
local future = require("@self/../luau_packages/future")

local Scheduler = {}

Scheduler.Interface = {}
Scheduler.Prototype = {}

export type Task = {
	id: string,
	name: string,
	callback: (...any) -> (...any)?,
	cron: string?,
	interval: number?,
	nextRun: number,
	lastRun: number?,
	runs: number,
	paused: boolean,
	timezone: string?,
	createdAt: number,
}

export type SchedulerHistoryEntry = {
	taskId: string,
	taskName: string,
	status: "success" | "error",
	startedAt: number,
	finishedAt: number,
	error: string?,
}

local taskIdCounter = 0

local function generateId(): string
	taskIdCounter += 1

	return `task_{taskIdCounter}_{os.time()}`
end

local function parseCronField(field: string, min: number, max: number): { number }
	local values = {}

	for part in string.gmatch(field, "[^,]+") do
		local step = 1
		local range = part

		local slashIndex = string.find(part, "/")

		if slashIndex then
			step = tonumber(string.sub(part, slashIndex + 1)) :: number
			range = string.sub(part, 1, slashIndex - 1)
		end

		if range == "*" then
			for i = min, max, step do
				table.insert(values, i)
			end
		elseif string.find(range, "%-") then
			local start, finish = string.match(range, "(%d+)-(%d+)")
			local startNum = tonumber(start) :: number
			local finishNum = tonumber(finish) :: number

			for i = startNum, finishNum, step do
				table.insert(values, i)
			end
		else
			local value = tonumber(range) :: number

			if value >= min and value <= max then
				table.insert(values, value)
			end
		end
	end

	return values
end

local function cronMatches(cron: string, dt: stdPolyfills.DateTime): boolean
	local parts = {}

	for part in string.gmatch(cron, "%S+") do
		table.insert(parts, part)
	end

	if #parts < 5 then
		return false
	end

	local minutes = parseCronField(parts[1], 0, 59)
	local hours = parseCronField(parts[2], 0, 23)
	local days = parseCronField(parts[3], 1, 31)
	local months = parseCronField(parts[4], 1, 12)
	local weekdays = parseCronField(parts[5], 0, 6)

	local currentMinute = dt.minute
	local currentHour = dt.hour
	local currentDay = dt.day
	local currentMonth = dt.month
	local currentWeekday = (dt.weekday - 1) % 7

	if not table.find(minutes, currentMinute) then
		return false
	end

	if not table.find(hours, currentHour) then
		return false
	end

	if not table.find(months, currentMonth) then
		return false
	end

	if not table.find(days, currentDay) and not table.find(weekdays, currentWeekday) then
		return false
	end

	return true
end

local function shouldRun(task: Task, now: number): boolean
	if task.paused then
		return false
	end

	if task.cron then
		local dt = stdPolyfills.datetime.fromUnixTimestampMillis(now * 1000)

		if cronMatches(task.cron, dt) and now >= task.nextRun then
			return true
		end
	elseif task.interval then
		if now >= task.nextRun then
			return true
		end
	end

	return false
end

local function updateNextRun(task: Task): ()
	if task.cron then
		local now = os.time()
		local current = stdPolyfills.datetime.fromUnixTimestampMillis(now * 1000)
		local year = current.year
		local month = current.month
		local day = current.day
		local hour = current.hour
		local minute = current.minute

		minute += 1

		if minute >= 60 then
			minute = 0
			hour += 1
		end

		if hour >= 24 then
			hour = 0
			day += 1
		end

		task.nextRun = os.time({
			year = year,
			month = month,
			day = day,
			hour = hour,
			min = minute,
			sec = 0,
		})
	elseif task.interval then
		task.nextRun = os.time() + task.interval
	end

	return
end

--[=[
	@within Scheduler

	Adds a one-shot timer that fires once after `seconds`.
]=]
function Scheduler.Prototype.addTimer(
	self: Scheduler,
	name: string,
	seconds: number,
	callback: () -> (),
	options: { timezone: string? }?
): string
	local id = generateId()
	local now = os.time()

	table.insert(self.history, {
		taskId = id,
		taskName = name,
		status = "scheduled",
		startedAt = now,
		finishedAt = 0,
		error = nil,
	})

	self.tasks[id] = {
		id = id,
		name = name,
		callback = function(...)
			local args = { ... }
			local success, errorMessage = xpcall(function()
				(callback :: () -> ())()
			end, debug.traceback)

			local finishedAt = os.time()
			local lastHistoryEntry = self.history[#self.history]

			if lastHistoryEntry and lastHistoryEntry.taskId == id then
				lastHistoryEntry.status = if success then "success" else "error"
				lastHistoryEntry.finishedAt = finishedAt
				lastHistoryEntry.error = if success then nil else errorMessage
			end

			if not success then
				self.logger:warn(`timer '{name}' errored:\n{errorMessage}`)
			end

			self.tasks[id] = nil
		end,
		interval = seconds,
		nextRun = now + seconds,
		lastRun = nil,
		runs = 0,
		paused = false,
		timezone = options and options.timezone,
		createdAt = now,
	}

	return id
end

--[=[
	@within Scheduler

	Adds a recurring task with a cron expression.
]=]
function Scheduler.Prototype.addCron(
	self: Scheduler,
	name: string,
	cron: string,
	callback: () -> (),
	options: { timezone: string? }?
): string
	local id = generateId()
	local now = os.time()

	table.insert(self.history, {
		taskId = id,
		taskName = name,
		status = "scheduled",
		startedAt = now,
		finishedAt = 0,
		error = nil,
	})

	self.tasks[id] = {
		id = id,
		name = name,
		callback = function()
			local success, errorMessage = xpcall(function()
				(callback :: () -> ())()
			end, debug.traceback)

			local finishedAt = os.time()

			for index = #self.history, 1, -1 do
				if self.history[index].taskId == id and self.history[index].finishedAt == 0 then
					self.history[index].status = if success then "success" else "error"
					self.history[index].finishedAt = finishedAt
					self.history[index].error = if success then nil else errorMessage

					break
				end
			end

			if not success then
				self.logger:warn(`cron '{name}' errored:\n{errorMessage}`)
			end
		end,
		cron = cron,
		nextRun = now,
		lastRun = nil,
		runs = 0,
		paused = false,
		timezone = options and options.timezone,
		createdAt = now,
	}

	updateNextRun(self.tasks[id])

	return id
end

--[=[
	@within Scheduler

	Removes a task by ID.
]=]
function Scheduler.Prototype.remove(self: Scheduler, id: string): boolean
	if not self.tasks[id] then
		return false
	end

	self.tasks[id] = nil

	return true
end

--[=[
	@within Scheduler

	Pauses a task by ID.
]=]
function Scheduler.Prototype.pause(self: Scheduler, id: string): boolean
	local task = self.tasks[id]

	if not task then
		return false
	end

	task.paused = true

	return true
end

--[=[
	@within Scheduler

	Resumes a paused task by ID.
]=]
function Scheduler.Prototype.resume(self: Scheduler, id: string): boolean
	local task = self.tasks[id]

	if not task then
		return false
	end

	task.paused = false

	return true
end

--[=[
	@within Scheduler

	Returns the next run timestamp for a task, or nil if not found.
]=]
function Scheduler.Prototype.getNextRun(self: Scheduler, id: string): number?
	local task = self.tasks[id]

	if task then
		return task.nextRun
	end

	return nil
end

--[=[
	@within Scheduler

	Returns recent execution history, optionally filtered by task ID.
]=]
function Scheduler.Prototype.getHistory(
	self: Scheduler,
	options: { taskId: string?, limit: number? }?
): { SchedulerHistoryEntry }
	local limit = options and options.limit or 50
	local taskId = options and options.taskId
	local filtered = {}

	for i = #self.history, 1, -1 do
		local entry = self.history[i]

		if taskId and entry.taskId ~= taskId then
			continue
		end

		table.insert(filtered, entry)

		if #filtered >= limit then
			break
		end
	end

	return filtered
end

--[=[
	@within Scheduler

	Starts the scheduler loop.
]=]
function Scheduler.Prototype.start(self: Scheduler): ()
	if self.running then
		return
	end

	self.running = true

	task.spawn(function()
		while self.running do
			local now = os.time()

			for id, task in self.tasks do
				if shouldRun(task, now) then
					task.lastRun = now
					task.runs += 1

			if task.callback then
				stdPolyfills.task.spawn(task.callback)
			end

					updateNextRun(task)
				end
			end

			stdPolyfills.task.wait(1)
		end
	end)

	return
end

--[=[
	@within Scheduler

	Stops the scheduler loop.
]=]
function Scheduler.Prototype.stop(self: Scheduler): ()
	self.running = false

	return
end

function Scheduler.Interface.new(): Scheduler
	local self = setmetatable(
		{
			logger = Logger.new("Scheduler"),
			tasks = {},
			running = false,
			history = {},
		} :: Scheduler,
		{ __index = Scheduler.Prototype }
	)

	return self
end

export type Scheduler = typeof(Scheduler.Prototype) & {
	logger: Logger,
	tasks: { [string]: Task },
	running: boolean,
	history: { SchedulerHistoryEntry },
}

return Scheduler.Interface
