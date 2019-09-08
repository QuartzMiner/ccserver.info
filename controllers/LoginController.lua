local config = require("lapis.config").get()
local respond_to = require("lapis.application").respond_to
local validate = require("lapis.validate")
local openssl_rand = require("openssl.rand")
local encoding = require("lapis.util.encoding")
local to_json = require("lapis.util").to_json
local capture_errors = require("lapis.application").capture_errors
local encode_base64, decode_with_secret = encoding.encode_base64, encoding.decode_with_secret
local redis = require 'redis'

local redis_params = {
    host = 'redis',
    port = 6379,
}

--print(value)
local authenticated = function(session)
    if session.authenticated then return true end
    local client = redis.connect(redis_params)
    -- DBからトークン検索
    local authenticated = client:hget(session.token, 'authenticated')
    if not authenticated then return false end
    session.user = {
        minecraft_user = client:hget(session.token, 'minecraft_user')
    }
    session.authenticated = true
    client:del(session.token)
end

return function(app, options)
    local except_routes = options.except
    app:before_filter(function(self)
        table.insert(except_routes, 'login')
        table.insert(except_routes, '/authenticate')
        -- もし except_routes に合致したならば何もしない
        for _, route in pairs(except_routes) do
            if route == self.route_name or route == self.req.parsed_url.path then return end
        end

        if self.session.token and not authenticated(self.session) then -- 認証完了してないなら待ち画面で覆う
            local client = redis.connect(redis_params)
            local minecraft_user = client:hget(self.session.token, 'minecraft_user')
            if minecraft_user then
                self.minecraft_user = minecraft_user
                return self:write({ render = 'authenticating' })
            end
            -- タイムアウトしてたらログイン行きなので下に流す
        end

        local now = os.time()
        if self.session.user and now < (self.session.expire or now + 1) then -- 認証完了したユーザ
            self.session.expire = os.time() + 30 * 60 --min
            -- 他で使いやすいように self.user に入れる
            self.user = self.session.user
            return
        end

        -- ログインに飛ばす
        self.session.redirect_to = self.req.parsed_url.path
        return self:write({ redirect_to = self:url_for("login") })

    end)

    local login = respond_to({
        GET = function(self)
            return { render = 'login' }
        end,
        POST = function(self)
            local client = redis.connect(redis_params)
            validate.assert_valid(self.params, {
                { "minecraft_user", exists = true, min_length = 2, max_length = 128 },
            })
            local minecraft_user, token = self.params.minecraft_user, encode_base64(openssl_rand.bytes(32))
            self.session.token = token
            client:hset(token, 'minecraft_user', minecraft_user)
            client:expire(token, 5 * 60)

            self.token = token

            local http = require("lapis.nginx.http")
            http.simple({
                url = config.mod_auth_endpoint,
                method = "POST",
                body = to_json {
                    user = minecraft_user,
                    token = token
                }
            })
            return { redirect_to = self.session.redirect_to }
        end
    })
    local logout = function(self)
        self.session = {}
        return { redirect_to = "/" }
    end

    app:post('/authenticate', function(self)
        -- マイクラ側から直接投げるとして。cookieは使えない
        validate.assert_valid(self.params, {
            { "data", exists = true, max_length = 2048 },
        })
        local data, err = decode_with_secret(self.params.data, config.minecraft_secret)
        if not data then return end
        local minecraft_user, token = data.user, data.token

        local client = redis.connect(redis_params)
        local user = client:hget(token, 'minecraft_user')
        if not user == minecraft_user then return end
        client:hset(token, 'authenticated', true)
        client:expire(token, 5 * 60)
    end)

    return {
        login = login,
        logout = logout,
    }
end
