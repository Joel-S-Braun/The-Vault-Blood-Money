--[[
	@17/2/16
	
	@heartbeat-module
	@event-module
--]]

local _replicated_storage = game.ReplicatedStorage
local _network = _replicated_storage.Network

local data_store = game:GetService("DataStoreService"):GetDataStore('Data')
local http_service = game:GetService('HttpService')
local run_service = game:GetService('RunService')

local event_id = {}
local event = {}
local heartbeat = {}
local binded_events

local github_raw = 'https://raw.githubusercontent.com/WaffloidRBX/The-Vault-Blood-Money/master/'





--@heartbeat-module
do
	function heartbeat.bind(func)
		local id = tostring(func)
		binded_events[id]=func
		return function()
			binded_events[id]=nil
		end
	end
	
	run_service.Changed:connect(function()
		for i,v in pairs(binded_events) do
			v()
		end
	end)
end






--@event-module
do
	
	function event.to_pseudo(real)
		local event = event.new()
		real:connect(event.fire)
		return event
	end
	
	function event.new(name) -- tbh it does far more than just handle events but watevr (works like gamelogic cells + events)
		local event = {name=name,connections={}}
		
		event_id[tostring(event)] = event
		
		function event:connect(func)
			local id = tostring(func)
			event.connections[id] = func
			return function() -- terminates connected function
				event.connections[id]=nil
			end
		end
		
		function event:fire(...)
			event.value={...}
			if name then
				_network.RemoteEvent:FireAllClients(name...)
			end
			for _,v in pairs(event.connections) do
				v(...)
			end
		end
		
		function event:bind(func)
			return heartbeat.bind(function()
				func(event.value)
			end)
		end
		
		function event:link(condition,output)
			return event:connect(function(...)
				if condition(...) then
					output:fire(...)
				end
			end)
		end
		return event
	end
	
	_network.EventState.OnServerInvoke = function(player,name)
		for i,v in pairs(event_id) do
			if v.name == name then
				repeat wait() until v.value
				return v.value
			end
		end
	end
end

local player_added = (game.Players.PlayerAdded)
local player_removing = (game.Players.PlayerRemoving)

local update = event.new('update') -- lol it never even fires, just holds data like a good gamelogic
update.value = (http_service:GetAsync(github_raw..'update')) -- loads JSON stored on github which contains update info