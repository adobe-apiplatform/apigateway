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

-- Records the metrics for the current request.
--
-- # Sample StatsD messages
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.count
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.responseTime
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.upstreamResponseTime
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.validate_request.GET.200.responseTime
--
-- NOTE: by default it logs the root-path of the request. If the root path is used for versioning ( i.e. v1.0 ) there is the property $metric_path that
-- can be set on the location block in order to override the root-path
--
-- Created by IntelliJ IDEA.
-- User: nramaswa
-- Date: 3/14/14
-- Time: 12:45 AM
-- To change this template use File | Settings | File Templates.
--
local MetricsCls = require "metrics.MetricsBuffer"
local metrics = MetricsCls:new()

local M = {}

function M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- To replace . with _
local function normalizeString(input)
    return input:gsub("%.", "_")
end

local function getPathForMetrics(serviceName)
    local user_defined_path = ngx.var.metrics_path
    if user_defined_path ~= nil and #user_defined_path < 2 then
        user_defined_path = nil
    end

    local request_uri = user_defined_path or ngx.var.uri or "/" .. serviceName
    local pattern = "(?:\\/?\\/?)([^\\/:]+)" -- To get the first part of the request uri excluding content after :
    local requestPathFromURI, err = ngx.re.match(request_uri, pattern)
    local requestPath = serviceName -- default value

    if err then
        ngx.log(ngx.WARN, "Assigned requestPath as serviceName due to error in extracting requestPathFromURI: ", err)
    end

    if requestPathFromURI then
        if requestPathFromURI[1] then
            requestPath = requestPathFromURI[1]
            requestPath = requestPath:gsub("%.", "_")
            --ngx.log(ngx.INFO, "\n the extracted requestPath::"..requestPath)
        end
    end
    return requestPath
end

function M:logCurrentRequest()
    -- Variables used in the bucket path
    local publisherName = ngx.var.publisher_org_name or "undefined"
    local consumerName = ngx.var.consumer_org_name or "undefined"
    local appName = ngx.var.app_name or "undefined"
    local serviceName = ngx.var.service_name or "undefined"
    local realm = ngx.var.service_env or ngx.var.realm or "sandbox"
    local requestMethod = ngx.var.request_method or "undefined"
    local status = ngx.var.status or "0"
    local validateRequestStatus = ngx.var.validate_request_status or "0"

    -- Values for metrics - converted tonumber() later
    local bucketCountValue = 1
    local requestTime = tonumber(ngx.var.request_time) or -1
    local upstreamResponseTime = tonumber(ngx.var.upstream_response_time) or -1
    local validateTime = tonumber(ngx.var.validate_request_response_time) or -1
    local rgnName = ngx.var.aws_region or "undefined"
    local bytesSent = tonumber(ngx.var.bytes_sent) or -1
    local bytesReceived = tonumber(ngx.var.request_length) or -1

    -- ---------------------------------------------------------------------- --
    -- ------------- Logging for all the requests            ---------------  --
    -- ---------------------------------------------------------------------- --

    local bucket = "publisher." .. normalizeString(publisherName) ..
            ".consumer." .. normalizeString(consumerName) ..
            ".application." .. normalizeString(appName) ..
            ".service." .. normalizeString(serviceName) ..
            "." .. realm ..
            ".region." .. rgnName ..
            ".request.";
    local validate_request_response_time = bucket .. "validate_request." .. validateRequestStatus .. ".responseTime";

    local requestPath = getPathForMetrics(serviceName)

    local bytes_sent = bucket .. "bytesSent";
    local bytes_received = bucket .. "bytesReceived";


    --bandwidth data - update only if its greater than zero to sum up all calls
    if bytesSent > 0 then
        metrics:count(bytes_sent, bytesSent)
    end
    if bytesReceived > 0 then
        metrics:count(bytes_received, bytesReceived)
    end

    -- log validate timer entry only if its passed
    if validateTime >= 0 then
        metrics:timer(validate_request_response_time, validateTime)
    end

    -- ---------------------------------------------------------------------- --
    -- ------------- Non-blocked requests related logging    ---------------  --
    -- ---------------------------------------------------------------------- --

    -- Choosing log buckets in statsd based on validation success/failure in the gateway
    if (validateRequestStatus == "200" or validateRequestStatus == "0" or validateRequestStatus == 200 or validateRequestStatus == "na") then
        local cc_bucket = bucket ..
                requestPath .. "." ..
                requestMethod .. "." .. status;

        local cc_response_time = cc_bucket .. ".responseTime";
        local cc_upstream_response_time = cc_bucket .. ".upstreamResponseTime";

        local hit_count_for_bucket = cc_bucket .. ".count";


        --increament the count for all the calls
        metrics:count(hit_count_for_bucket, bucketCountValue)
        -- timers
        if requestTime >= 0 then
            metrics:timer(cc_response_time, requestTime)
        end
        --timer data - update only if its greater than or = zero as its avging all calls
        if upstreamResponseTime >= 0 then
            metrics:timer(cc_upstream_response_time, upstreamResponseTime)
        end
        return
    end

    -- ---------------------------------------------------------------------- --
    -- ------------- Blocked requests related logging        ---------------  --
    -- ---------------------------------------------------------------------- --

    local blocked_bucket = bucket .. "_blocked_"

    local code_count_bucket = blocked_bucket .. "." .. validateRequestStatus .. ".count"
    local bytes_sent_bucket = blocked_bucket .. ".bytesSent"
    local bytes_received_bucket = blocked_bucket .. ".bytesReceived"

    --increament the count for all the calls
    metrics:count(code_count_bucket, bucketCountValue)

    --bandwidth data - update only if its greater than zero to sum up all calls
    if bytesSent > 0 then
        metrics:count(bytes_sent_bucket, bytesSent)
    end
    if bytesReceived > 0 then
        metrics:count(bytes_received_bucket, bytesReceived)
    end
end


return M

