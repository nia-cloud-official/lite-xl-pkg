local core = require "core"
local command = require "core.command"
local config = require "core.config"
local system = require "system"

-- Robust JSON parser with error handling
local json = (function()
    local json = {}
    function json.decode(str)
        local success, res = pcall(function()
            return load("return " .. str, "json", "t", {})()
        end)
        return success and res or nil
    end
    return json
end)()

-- Simple async scheduler
local scheduler = {
    tasks = {},
    new = function(self, fn)
        table.insert(self.tasks, coroutine.create(fn))
    end,
    update = function(self)
        for i = #self.tasks, 1, -1 do
            local co = self.tasks[i]
            if coroutine.status(co) == "dead" then
                table.remove(self.tasks, i)
            else
                local ok, err = coroutine.resume(co)
                if not ok then core.error("[PKG] Scheduler error:", err) end
            end
        end
    end
}

-- Package manager core
local lite_pkg = {
    _VERSION = "2.0.0",
    _DEBUG = true
}

-- Configuration
config.plugins.lite_pkg = {
    registry = "https://raw.githubusercontent.com/lite-xl/plugins/main/registry.json",
    install_dir = EXEDIR .. "/data/plugins",
    git = "git",
    timeout = 15
}

-- Debug logging
local function log(...)
    if lite_pkg._DEBUG then
        core.log_quiet("[PKG] " .. string.format(...))
    end
end

-- Check Git availability
local function has_git()
    local cmd = string.format('%s --version > %s 2>&1',
        config.plugins.lite_pkg.git,
        PLATFORM == "Windows" and "NUL" or "/dev/null"
    )
    return os.execute(cmd) == 0
end

-- Fetch registry data
local function fetch_registry()
    local url = config.plugins.lite_pkg.registry
    log("Fetching registry from: %s", url)
    
    local content, err = system.get_text(url)
    if not content then
        core.error("[PKG] Registry fetch failed: " .. (err or "unknown error"))
        return nil
    end
    
    local data = json.decode(content)
    if not data or not data.plugins then
        core.error("[PKG] Invalid registry format")
        return nil
    end
    
    log("Found %d plugins in registry", #data.plugins)
    return data.plugins
end

-- Install plugin implementation
local function install_plugin(name)
    if not has_git() then
        core.error("[PKG] Git not found in PATH")
        return false
    end

    local plugins = fetch_registry()
    if not plugins then return false end

    for _, plugin in ipairs(plugins) do
        if plugin.name == name then
            log("Found plugin: %s (%s)", name, plugin.repo)
            
            local install_path = config.plugins.lite_pkg.install_dir .. "/" .. name
            local cmd = string.format(
                '%s clone --depth 1 --quiet %s "%s"',
                config.plugins.lite_pkg.git,
                plugin.repo,
                install_path
            )
            
            log("Executing: %s", cmd)
            local success = os.execute(cmd)
            
            if success then
                log("Installation successful")
                core.request_restart()
                return true
            else
                core.error("[PKG] Installation failed")
                os.execute(string.format('rm -rf "%s"', install_path))
                return false
            end
        end
    end
    
    core.error("[PKG] Plugin '%s' not found in registry", name)
    return false
end

-- User commands
command.add("core.docview", {
    ["pkg:install"] = function()
        core.command_view:enter("Install plugin:", {
            submit = function(text)
                scheduler:new(function()
                    core.status_view:show_message("Installing %s...", text)
                    install_plugin(text)
                    core.status_view:hide()
                end)
            end
        })
    end
})

-- Maintenance thread
core.add_thread(function()
    while true do
        scheduler:update()
        coroutine.yield(0.1)
    end
end)

return lite_pkg
