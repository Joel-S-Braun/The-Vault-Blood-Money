--[[
	@17/2/16
	
	@heartbeat-module
	@network-module
	@event-module
--]]

local _replicated_storage = game.ReplicatedStorage
local _network = _replicated_storage.Network

local data_store_service = game:GetService("DataStoreService")
local item_data = data_store_service:GetDataStore('Item_Data')
local player_data = data_store_service:GetDataStore('Player_Data')
local http_service = game:GetService('HttpService')
local run_service = game:GetService('RunService')

local event_id = {}
local event = {}
local heartbeat = {}
local network = {}
local binded_events = {}
local remote_functions = {}
local player_info = {}
local items_info = {}
local connect = {}

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















--@network-module
do
	_network.RemoteEvent.OnServerEvent:connect(function(player,name,...)
		if connect[name] then
			connect[name](player,...)
		end
	end)
	
	function network.invoke(...) -- player,name,...
		return _network.RemoteFunction:InvokeClient(...)
	end
	
	function network.get_event(player,name) -- player, name
		return unpack(network.invoke(player,'get_event',name))
	end	
end














--@event-module
do
	
	function event.to_pseudo(real)
		local event = event.new()
		real:connect(event['fire'])
		return event
	end
	
	function event.new(name) -- tbh it does far more than just handle events but watevr (works like gamelogic cells + events)
		local event = {name=name,connections={}}
		
		event_id[event.name or tostring(event)] = event
		
		function event:connect(func)
			local id = tostring(func)
			event.connections[id] = func
			return function() -- terminates connected function
				event.connections[id]=nil
			end
		end
		
		function event:change_val(...)
			event.value = {...}
		end
		
		function event:fire(...)
			event.value={...}
			if event.name then
				_network.RemoteEvent:FireAllClients(event.name,...)
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
	
	remote_functions['get_event'] = function(player,name)
		return event_id[name].value -- simples
	end
	
	_network.RemoteFunction.OnServerInvoke = function(player,name,...)
		repeat wait() until remote_functions[name]
		return remote_functions[name](player,...)
	end
end






    







--unlisted
do
	local default_item_data = { -- formatted version of data stored or maybe raw idk yet
		['Primary_Attachment'] = {
			'Laser';
			'Green laser';
			false;
		}; -- first option is current equipped item, false is 'none'
		['Primary_Sight'] = {
			'Holo sight';
			'VCOG sight';
			false;
		};
		['Primary_Weapon'] ={
			'AK47';
			'M16';
			'SPAS-12';
		};
		
		['Secondary_Attachment'] = {
			'Laser';
			false;
		};
		['Secondary_Sight'] = {
			'STR sight';
			false;
		};
		['Secondary_Weapon'] = {
			'M9';
			'Deagle';
			'Revolver';
		};
	}
	
	
	local update = event.new('update') -- lol it never even fires, just holds data like a good gamelogic cell
	update:change_val((http_service:GetAsync(github_raw..'update'))) -- loads JSON stored on github which contains update info
	
	local player_added = (game.Players.PlayerAdded)
	local player_removing = (game.Players.PlayerRemoving)
	
	connect['list_updated'] = function(player,info)
		items_info[player.Name] = info
	end
	
	connect['player_data_updated'] = function(player,info)
		player_info[player.Name] = info
	end
	
	remote_functions['get_item_data'] = function(player)
		local info = item_data:GetAsync(player.UserId)
		print(info)
		info = info or default_item_data
		items_info[player.Name] = info
		return info
	end
	
	remote_functions['get_player_data'] = function(player)
		local info = player_data:GetAsync(player.UserId) or {Cash = 0,last_login = os.time(),last_update = ''} -- label = nil
		player_info[player.Name] = info
		return info
	end
	
	player_removing:connect(function(player)
		item_data:SetAsync(player.UserId,items_info[player.Name])
		player_data:SetAsync(player.UserId,player_info[player.Name]) -- yes ik 2 different SetAsyncs im sorry ok IM SORRY
	end)
end