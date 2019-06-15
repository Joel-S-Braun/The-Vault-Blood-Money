--[[
	@1/28/2017
	@axel-studios
	@the-vault-blood-money
	@lobby-server
	@waffloid
--]]

local _network = game.ReplicatedStorage.Network
local _replicated_storage = game.ReplicatedStorage

local http_service = game:GetService('HttpService')
local datastore_service = game:GetService('DataStoreService')
local datastore = datastore_service:GetDataStore("TemporarySki")

local announcement_link = 'http://pastebin.com/raw/aRWs8TvU'
local twitter_codes = 'http://pastebin.com/raw/RSkRY1Ss'
local ban_list = 'http://pastebin.com/raw/rpW4cePU'

local current_announcement = http_service:GetAsync(announcement_link) -- returns string

local named_events = {}
local remote_functions = {}
local event = {}
local client_inventory = {}
local inventory = {}
local item_data = {}

items_equip = {
	primary_masks ='Default Mask', -- false = nothing
	primary_skins = nil, --?
	secondary_skins = nil,
	primary_gun = 'M4',
	secondary_gun = 'M9',
	primary_barrel=nil,
	secondary_barrel=nil,
	primary_sight=nil,
	secondary_sight=nil,
	primary_grip=nil,
	secondary_grip=nil,
}

for _,module in pairs(_replicated_storage.items:GetChildren()) do
	module_script = require(module)
	module_script.name=module.Name
	item_data[module.Name] = module_script
end

local items_owned = {m4=item_data.m4,m9=item_data.m9,normal=item_data.normal}

local function scroll(tab,offset)
	local offset = offset or 1
	local new = {}
	for i,v in pairs(tab) do
		new[(((i+offset)-1)%#tab)+1] = v
	end
	for i,v in pairs(new) do
		tab[i]=v
	end
end

local function exp_curve(l)
	l = math.floor(l)
	return math.floor((l^1.5)*400) + 1300
end

local function get_level(exp)
	return ((exp-1300)/40) ^ (1/1.5)
end

--@networking/events
do
	_network.RemoteEvent.OnServerEvent:connect(function(plr,name,...)
		local event = named_events[name]
		if event then
			for i,v in pairs(event.connections) do
				if type(v) == 'function' then
					v(plr,...)
				else
					v:fire(plr,...)
				end
			end
		end
	end)

	_network.RemoteFunction.OnServerInvoke = function(player,name,...)
		local remote_func,timeout = remote_functions[name],tick()
		if not remote_func then
			repeat wait() remote_func = remote_functions[name] until remote_func or ((tick()-5) > timeout)
		end
		local d={remote_func(player,...)}
		print(unpack(d),'RETURN DA TING B0SS')
		return unpack(d) 
	end

	function event.new(name)
		local event = {connections={}}
		function event:fire(...)
			--'send232')
			if name then
				--'sent')
				_network.RemoteEvent:FireAllClients(name,...)
			end
			for  x = 1,#event.connections do
				if type(event.connections[x]) == 'function' then
					event.connections[x](...)
				else
					event.connections[x]:fire(...)
				end
			end
		end
		function event:connect(func)
			event.connections[#event.connections+1] = func
		end
		function event:condition(new_event,condition)
			event:connect(function(...) local output = {condition(...)}
				if output[1] then new_event:fire(...) end end)
		end
		if name then
			--'ok',name)
			named_events[name] = event
		end
		return event
	end
end










--0.00325
--local start=tick() local d = {a={},b={}} e = {} meta={__index=d} for i = 1,10000 do setmetatable({},meta) end local fin = tick() print(fin-start)
--inventory module
do
	remote_functions['get inventory'] = function(plr)
		inventory.new(plr.UserId) -- either generates new inventory model or indexes exisiting model
		return client_inventory[plr.UserId] -- jetter of ski
	end
	remote_functions['attempt purchase'] = function(plr,obj)
		local player = inventory.new(plr.UserId)
		return player:attempt_purchase(obj) -- lol much complex
	end
	event.new('change order'):connect(function(plr,class,obj)
		local body = inventory.new(plr.UserId)
		if body.owned_items[obj] then
			body.equipped_items[class]=obj
		end
	end)

	--attachment:
	
	
	
	function inventory.new(id)
		if not inventory[id]   then
			local old_loaded_level,loaded_exp,loaded_cash,loaded_items
			
			--load data
			local loaded_successfully = pcall(function()
				loaded_exp,loaded_cash,loaded_equip,loaded_items  = 0,5000,items_equip,items_owned -- replace with datastore and points
				
				old_loaded_level = 1 -- use datastore xd xd xd
			end)
			if not loaded_successfully then
				return -- rip try agen xd
			end
			
			local new_inventory = {
				cash=loaded_cash,
				old_level=old_loaded_level,
				level=1,--get level from exp
				exp=loaded_exp,
				
				equipped_items=loaded_equip,
				owned_items=loaded_items,
			}
			
			inventory[id]=new_inventory
			
			function new_inventory:attempt_save()
				
			end
			
			function new_inventory:attempt_purchase(item)
				if not new_inventory.owned_items[item] then
					local data = item_data[item]
					print(item)
					local new_cash = new_inventory.cash - data.cost
					print(new_cash,'purchase shoudlnt go thru lol',new_inventory.cash,data.cost)
					if data.level_req <= new_inventory.level then
						if new_cash >= 0 then
							print('bomboclort, purchase went thru!')
							new_inventory.cash = new_cash
							table.insert(new_inventory.owned_items,item)
						else
							return 'You cannot afford this product'
						end
					else
						return 'You are too low of a level noob xd level up'
					end
				else
					return 'You already own this item' -- gwarm fam
				end
			end
			
			local client_inventory_model = {
				cash=loaded_cash,
				old_level=old_loaded_level,
				level=1,--get level from exp
				exp=loaded_exp,
				
				equipped_items=loaded_equip,
				owned_items=loaded_items, -- CONVERT TO LINEAR TABLE WITH STRINGS ONLY
			}
			
			client_inventory[id] = client_inventory_model
			
			return new_inventory
		else
			return inventory[id]
		end
	end
	
--	game.Players.PlayerAdded:connect(function(plr)
--		inventory.new(plr.UserId) -- loads data and hashes in table
--	end)

	local waffloid = inventory.new(18221493) -- keep on going. you never retire. if your bloods still flowing keep on going
	--waffloid:attempt_purchase('Silencer')
end


remote_functions['get announcement'] = function()
	return current_announcement
end

spawn(function()
	local new_announcement = event.new('new announcement')
	while wait(10) do
		local new_value = http_service:GetAsync(announcement_link)
		if new_value ~= current_announcement then -- announcment has changed!
			current_announcement = new_value
			new_announcement:fire(new_value)
		end
	end
end)
