local file=assert(io.open('resources/rp_core/systems/chat/client.lua'));local source=file:read('*a');file:close()
local callback=assert(source:match('(function RPChatClient.receiveNativeMessage.-\nend)'))
local lines,cancelled={},0
RPChatClient={addMessage=function(line) lines[#lines+1]=line end}
function cancelEvent() cancelled=cancelled+1 end
assert(loadstring(callback))()
RPChatClient.receiveNativeMessage('[SMS] message',200,190,225)
RPChatClient.receiveNativeMessage('[F] message',100,120,140)
assert(#lines==2 and cancelled==2,'legacy messages appear once in DX chat with native display cancelled')
assert(lines[1].text=='[SMS] message' and lines[1].color[3]==225,'text and colors retained')
print('DX chat bridge: native SMS/faction/diagnostic messages stay visible with the default chat hidden')
