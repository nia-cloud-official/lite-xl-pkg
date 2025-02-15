local core = require "core"
local system = require "system"

local scheduler = {
  tasks = {},
  id_counter = 0
}

function scheduler.new(fn)
  local id = scheduler.id_counter + 1
  scheduler.id_counter = id
  scheduler.tasks[id] = { coroutine = coroutine.create(fn) }
  return id
end

function scheduler.update()
  for id, task in pairs(scheduler.tasks) do
    if coroutine.status(task.coroutine) == "dead" then
      scheduler.tasks[id] = nil
    else
      local ok, err = coroutine.resume(task.coroutine)
      if not ok then
        core.error("Scheduler task failed: %s", err)
        scheduler.tasks[id] = nil
      end
    end
  end
end

return scheduler
