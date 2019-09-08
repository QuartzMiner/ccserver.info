local config = require("lapis.config")

config({"development", "production"}, {
  mod_auth_endpoint = "http://ccserver.info:8092/request_auth"
})
