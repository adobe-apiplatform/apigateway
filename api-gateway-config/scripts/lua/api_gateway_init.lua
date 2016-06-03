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

-- An initialization script on a per worker basis.
-- User: ddascal
-- Date: 07/12/14
-- Time: 16:44
--

local _M = {}


--- Loads a lua gracefully. If the module doesn't exist the exception is caught, logged and the execution continues
-- @param module path to the module to be loaded
--
local function loadrequire(module)
    ngx.log(ngx.DEBUG, "Loading module [" .. tostring(module) .. "]")
    local function requiref(module)
        require(module)
    end

    local res = pcall(requiref, module)
    if not (res) then
        ngx.log(ngx.WARN, "Could not load module [", module, "].")
        return nil
    end
    return require(module)
end

--- Initializes the `zmqLogger` used by `trackingRulesLogger.lua` from api-gateway-request-tracking module
-- @param parentObject
--
local function initZMQLogger(parentObject)
    ngx.log(ngx.DEBUG, "Initializing ZMQLogger on property [zmqLogger]")
    -- when the ZmqModule is not present the script does not break
    local ZmqLogger = loadrequire("api-gateway.zmq.ZeroMQLogger")

    if (ZmqLogger == nil) then
        return
    end

    local zmq_publish_address = "ipc:///tmp/nginx_queue_listen"
    ngx.log(ngx.INFO, "Starting new ZmqLogger on pid [", tostring(ngx.worker.pid()), "] on address [", zmq_publish_address, "]")
    local zmqLogger = ZmqLogger:new()
    zmqLogger:connect(ZmqLogger.SOCKET_TYPE.ZMQ_PUB, zmq_publish_address)

    parentObject.zmqLogger = zmqLogger
end

local function initValidationFactory(parentObject)
    parentObject.validation = require "api-gateway.validation.factory"
end

local function initTrackingFactory(parentObject)
    parentObject.tracking = require "api-gateway.tracking.factory"
end

local function initMetricsFactory(parentObject)
    parentObject.metrics = require "metrics.factory"
end

initValidationFactory(_M)
initZMQLogger(_M)
initTrackingFactory(_M)
initMetricsFactory(_M)
-- TODO: test health-check with the new version of Openresty
-- initRedisHealthCheck()

ngx.apiGateway = _M

