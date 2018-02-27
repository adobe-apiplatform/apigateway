package = "apigateway"
version = "2.0.2-1"

local fsPrefix = "./api-gateway-config/scripts/lua/"
local packagePrefix = "api-gateway."

local function make_plat(plat)
    return {
        modules = {
            [packagePrefix .. ""] = fsPrefix .. "api_gateway_init.lua",
            [packagePrefix .. "metrics.factory"] = fsPrefix .. "metrics/factory.lua",
            [packagePrefix .. "metrics.MetricsBuffer"] = fsPrefix .. "metrics/MetricsBuffer.lua",
            [packagePrefix .. "metrics.MetricsCollector"] = fsPrefix .. "metrics/MetricsCollector.lua"
        }
    }
end

source = {
    url = "https://github.com/adobe-apiplatform/apigateway.git",
    tag = "api-gateway-docker-2.0.2"
}

description = {
    summary = "Base API Gateway installation",
    license = "MIT"
}

dependencies = {
    "lua > 5.1"
}

build = {
    type = "builtin",
    platforms = {
        unix = make_plat("unix"),
        macosx = make_plat("macosx"),
        haiku = make_plat("haiku"),
        win32 = make_plat("win32"),
        mingw32 = make_plat("mingw32")
    }
}