-- Copyright (c) 2015 Adobe Systems Incorporated. All rights reserved.
--
--   Permission is hereby granted, free of charge, to any person obtaining a
--   copy of this software and associated documentation files (the "Software"),
--   to deal in the Software without restriction, including without limitation
--   the rights to use, copy, modify, merge, publish, distribute, sublicense,
--   and/or sell copies of the Software, and to permit persons to whom the
--   Software is furnished to do so, subject to the following conditions:
--
--   The above copyright notice and this permission notice shall be included in
--   all copies or substantial portions of the Software.
--
--   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--   DEALINGS IN THE SOFTWARE.

-- Base class for analytics with functions for calculating counts,timers
-- and updating the cache with data on every service call.
--
--
--
-- Usage in Nginx conf:
--
-- location api-gateway-stats {
--    allow 127.0.0.1;
--    deny all;
--    content_by_lua '
--      local MetricsBuffer = require "metrics.MetricsBuffer"
--      local metrics = MetricsBuffer:new()
--      local json = assert( metrics:toJson(), "Could not read metrics")
--      ngx.say( json )
--    ';
-- }

local cjson = require "cjson"

local M = {}

function M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--- Increments a counter with the given <value>
-- @param metric The name of the metrics
-- @param value The value to intecrement with
--
function M:count(metric, value)
    local localMetrics = ngx.shared.stats_counters
    local r
    if ( localMetrics == nil ) then
        ngx.log(ngx.ERROR, "Please define 'lua_shared_dict stats_counters 50m;' in http block")
        return nil
    end

    value = tonumber(value) or 0
    if value == 0 then -- to exit when nil/zero
        return 0
    end

    r = localMetrics:incr(metric, value)
    if ( r == nil ) then
        localMetrics:add(metric, value)
        return value
    end
    return r
end

--- Adds a new timer value. Unline counters, timers are averaged when flushed
-- @param metric The name of the metrics
-- @param value A new value for the timer
--
function M:timer(metric, value)
    local localMetrics = ngx.shared.stats_timers
    local r, counter
    if ( localMetrics == nil ) then
        ngx.log(ngx.ERROR, "Please define 'lua_shared_dict stats_timers 50m;' in http block")
        return nil
    end

    value = tonumber(value) or -2

    -- Timers are counting only the positive values, by convention
    if ( value < 0 ) then
        return value
    end

    r, counter = localMetrics:get(metric)
    if ( r == nil ) then
        localMetrics:set(metric, value, 0, 1)
        return value
    end
    -- FIXES: attempt to perform arithmetic on local 'counter' (a nil value)
    if ( counter == nil ) then
        counter = 0
    end
    -- Adding the timers and increamenting the counter to compute avg later
    counter = counter + 1
    r = r + value
    localMetrics:set(metric, r, 0, counter)
    return r
end

function M:getJsonFor( metric_type )
   -- convert shared_dict to table
    local localMetrics = ngx.shared[metric_type]
    if ( localMetrics == nil ) then
        return nil
    end
    local keys = localMetrics:get_keys(1024)
    local counter
    local jsonObj = {}
    local count = 0
    for i,metric in pairs(keys) do
        local value, counter = localMetrics:get(metric)
        if(counter == nil) then
            counter = 0
        end
        -- check if avg needs to be computed
        if(counter == 1 or counter == 0) then
            jsonObj[metric] = value
        end
        if(counter >= 2) then
            jsonObj[metric] = math.floor(value/counter)
        end
        -- mark item as expired
        localMetrics:set(metric, 0, 0.001,0)
        count = i
    end
    return cjson.encode(jsonObj),count,jsonObj
end

function M:toJson( flushExpiredMetrics )
    local counters, count_counters, counterObject = self:getJsonFor("stats_counters")
    local timers, count_timers, timerObject = self:getJsonFor("stats_timers")
    local flush = flushExpiredMetrics or true

    -- ngx.log(ngx.INFO, "Wrote " .. count_counters .. " counters and " .. count_timers .. " timers.")

    if ( flush == true ) then
        self:flushExpiredKeys()
    end
    return "{\"counters\":" .. counters .. ",\"timers\":" .. timers .. "}", counterObject, timerObject
end

function M:flushExpiredKeys()
    local metrics = ngx.shared.stats_counters
    if ( metrics ~= nil ) then
        metrics:flush_expired()
    end

    metrics = ngx.shared.stats_timers
    if ( metrics ~= nil ) then
        metrics:flush_expired()
    end
end

return M

