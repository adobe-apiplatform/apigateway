#/*
# * Copyright (c) 2012 Adobe Systems Incorporated. All rights reserved.
# *
# * Permission is hereby granted, free of charge, to any person obtaining a
# * copy of this software and associated documentation files (the "Software"),
# * to deal in the Software without restriction, including without limitation
# * the rights to use, copy, modify, merge, publish, distribute, sublicense,
# * and/or sell copies of the Software, and to permit persons to whom the
# * Software is furnished to do so, subject to the following conditions:
# *
# * The above copyright notice and this permission notice shall be included in
# * all copies or substantial portions of the Software.
# *
# * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# * DEALINGS IN THE SOFTWARE.
# *
# */
# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    # lua_package_path "$pwd/lib/?.lua;;";
#    init_by_lua '
#        local v = require "jit.v"
#        v.on("$Test::Nginx::Util::ErrLogFile")
#        require "resty.core"
#    ';
    include /etc/api-gateway/conf.d/*.conf;
_EOC_

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: check that JIT is enabled
--- http_config eval: $::HttpConfig
--- config
    location /jitcheck {
        content_by_lua '
            if jit then
                ngx.say(jit.version);
            else
                ngx.say("JIT Not Enabled");
            end
        ';
    }
--- request
GET /jitcheck
--- response_body_like eval
["LuaJIT 2.1.0-alpha"]
--- no_error_log
[error]

=== TEST 2: check health-check page
--- http_config eval: $::HttpConfig
--- config
    location /health-check {
        access_log off;
            # MIME type determined by default_type:
            default_type 'text/plain';

            content_by_lua "ngx.say('API-Platform is running!')";
    }
--- request
GET /health-check
--- response_body_like eval
["API-Platform in running!"]
--- no_error_log
[error]

=== TEST 3: check nginx_status is enabled
--- http_config eval: $::HttpConfig
--- config
    location /nginx_status {
            stub_status on;
            access_log   off;
            allow 127.0.0.1;
            deny all;
    }
--- request
GET /nginx_status
--- response_body_like eval
["Active connections: 1"]
--- no_error_log
[error]

