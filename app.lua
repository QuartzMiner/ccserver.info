local lapis = require("lapis")
local app = lapis.Application()
app:enable("etlua")
app.layout = require "views.layout"

local LoginController = require("controllers/LoginController")
local loginController = LoginController(app, { except = {'/', '/about'} })
app:match('login', '/login', loginController.login)
app:post('/logout', loginController.logout)

app:get("/", function(self)
  self.page_title = "ccserver.info - ComputerCraft Server"
  self.cookies.foo = "bar"
--  return "Welcome to Lapis " .. require("lapis.version")
self.modList = {
  {
    name = 'ComputerCraft',
    href = 'https://cc.crzd.me',
    label = 'ComputerCraft CI',
    version = 'ComputerCraft 1.80pr1 build5 for Minecraft 1.12.2'
  },
  {
    name = 'OpenComputers',
    href = 'https://www.curseforge.com/minecraft/mc-mods/opencomputers/files',
    label = 'CurseForge/OpenComputers',
    version = 'MC1.12.2-1.7.4.153'
  }
}

  return { render = "index" }
end)

return app
