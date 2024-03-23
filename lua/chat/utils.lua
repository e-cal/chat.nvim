
local M = {}


M.ensureUrlProtocol = function(str)
  if M.startsWith(str, "https://") or M.startsWith(str, "http://") then
    return str
  end

  return "https://" .. str
end

return M
