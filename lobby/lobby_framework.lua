--[[
	@1/28/2017
	@axel-studios
	@the-vault-blood-money
	@lobby-client
	@waffloid
--]]


local _network = game.ReplicatedStorage.Network
local _replicated_storage = game.ReplicatedStorage

local event = {}
local named_events = {}
local remote_functions = {}
local item_modules = {}
local click_data = {}

local crew_logo = {630653212,630652920} -- 1,2

local crew_name = {'Greengate Crew','Blood Crew'}
local gamemode = {'pvp raid','heist'}
local shop_select = {one='WEAPON',two='MISC',three='ATTACH.',four='MASKS',five='SKINS'}
local skill_select = {one='TACTICIAN',two='SPECTRE',three='BEZERK',four='SPECLIAST',five='TECHNICIAN'}

local run_service = game:GetService('RunService')

local gamemode={'heist','pvp raid'}

local current_page

local map_imgs = {
	['Axel Theatre'] = {612712250,UDim2.new(0.507, 0,0.37, 0)},
	['WaffleCorp Convenience Raid'] = {633990610,UDim2.new(0.73, 0,0.35, 0)},
	['First National Bank'] = {612711079,UDim2.new(0.675, 0,0.315, 0)},
	['Green Leaf Bank'] = {633985279,UDim2.new(0.61, 0,0.46, 0)},
	['SilverStone Bank'] = {633985188},
	['North Silver Town Warehouse'] = {612713574},
	['default'] = {612712906},
	
}

local maps_unlock = {
	heist = {
		['Coral Raid'] = 1,
		['Axel Theatre'] = 1, -- unlocked on first play
		['WaffleCorp Convenience Raid'] = 5,
		['First National Bank'] = 13,
		['Citi Bank'] = 21,
		['Polinoli Bank'] = 34,
		['Green Leaf Bank'] = 52,
		['Silverstone Bank'] = 73,
		['Casino Raid'] = 85,
		
	},
	['pvp raid'] = {
		['Greengate Apartment Raid']= 1,
		['Woodberry Estate Raid '] = 1,
		['Upper Greengate Warehouse Raid'] = 42,
		['North Silver Town Warehouse'] = 42,
	}
} -- 31 total proxy places needed. gg

local map_desc = {
	['Coral Raid'] = {desc=1,difficulty='easy',maximum_score=069},
	['Axel Theatre'] = {desc=1,difficulty='easy',maximum_score=069}, -- unlocked on first play
	['WaffleCorp Convenience Raid'] = {desc=5,difficulty='medium',maximum_score=069},
	['First National Bank'] = {desc=13,difficulty='medium',maximum_score=069},
	['Citi Bank'] = {desc=21,difficulty='hard',maximum_score=069},
	['Polinoli Bank'] = {desc=41,difficulty='hard',maximum_score=069},
	['Green Leaf Bank'] = {desc=52,difficulty='very hard',maximum_score=069},
	['Silverstone Bank'] = {desc=73,difficulty='very hard',maximum_score=069},
	['Casino Raid'] = {desc=81,difficulty='impossible',maximum_score=069},
	['Greengate Apartment Raid']= {desc=0,difficulty='medium',maximum_score=069},
	['Woodberry Estate Raid '] = {desc=1,difficulty='medium',maximum_score=069},
	['Upper Greengate Warehouse Raid'] = {desc=42,difficulty='hard',maximum_score=069},
	['North Silver Town Warehouse'] = {desc=42,difficulty='hard',maximum_score=069},
}

local maps = {
	['pvp raid'] = {},
	['heist']= {}
}

local _gui

local inventory_data
local current_crew

local function exp_curve(l)
	l = math.floor(l)
	return math.floor((1.1^l)*100 + (l*1000)) + 1300
end

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
local function lines(text,len)
	return ('0'):rep(len-#text)..text
end

--@networking/events
do
	_network.RemoteEvent.OnClientEvent:connect(function(name,...)
		local event = named_events[name]
		if event then
			for i,v in pairs(event.connections) do
				if type(v) == 'function' then
					v(...)
				else
					v:fire(...)
				end
			end
		end
	end)

	_network.RemoteFunction.OnClientInvoke = function(name,...)
		local func = remote_functions[name]
		if func then
			return func(...)
		end
	end

	function event.new(name)
		local event = {connections={}}
		function event:fire(...)
			if name then
				_network.RemoteEvent:FireServer(name,...)
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
			event:connect(function(...) local output = {condition(...)} if #output ~= 0 then new_event:fire(unpack(output)) end end)
		end
		if name then
			named_events[name] = event
		end
		return event
	end
end







--inventory
do
	--local self_inventory = 
end








--@init
do
	pcall(function()
		local starterGui = game:GetService('StarterGui')
		starterGui:SetCore("TopbarEnabled", false)
	end)
	
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	workspace.CurrentCamera.CameraType = 6
	workspace.CurrentCamera.CFrame = CFrame.new(-58.5442123, 5.5469656, 19.6558266, 0.426971704, 0.201771796, -0.881466568, -7.4505806e-09, 0.974787951, 0.223133475, 0.904265046, -0.0952716693, 0.416206837)
	
	_gui = game.StarterGui.gui:Clone()
	_gui.Parent = game.Players.LocalPlayer.PlayerGui
	current_crew = (game.Players.LocalPlayer.UserId%2)+1  -- 1 = greeng8,2=bled
	_gui.main_menu.info.crew.Image = 'rbxassetid://'..crew_logo[current_crew]
	
	_gui.main_menu.Visible = true
	_gui.item_interact.Visible = false
	_gui.matchmaking.Visible = false
	
	inventory_data = _network.RemoteFunction:InvokeServer('get inventory')
	
	if not inventory_data then -- if data failed to load, retry till it loads. if datastore temporarily breaks game will break but at least they dont override data lol
		repeat 
			wait(5)
			inventory_data = _network.RemoteFunction:InvokeServer('get inventory')
		until inventory_data -- yay it loaded, carry on now!
	end
	local change_order = event.new('change order')
	function inventory_data:attempt_purchase(obj)
		print(obj,'Y THO')
		local purchase_failed = _network.RemoteFunction:InvokeServer('attempt purchase',obj)
		if not purchase_failed then
			print('the ink splashes')
			inventory_data.owned_items[obj] = item_modules[obj]
			attempt_load_shop(current_page)()
		end
		print(purchase_failed,'N 1 5 N 1 7 S H O')
	end
	function inventory_data:change_order(class,obj)
		change_order:fire(class,obj)
		if inventory_data.owned_items[obj] then
			inventory_data.equipped_items[class]=obj
		end
	end
	
	for gamemode,list in pairs(maps_unlock) do
		for map,level in pairs(list) do
			if level <= inventory_data.level then
				maps[gamemode][#maps[gamemode]+1] = map
			end
		end
	end
	
	local attempt_equip,attempt_buy
	
	for _,module in pairs(_replicated_storage.items:GetChildren()) do
		module_script = require(module)
		module_script.name=module.Name
		item_modules[module.Name] = module_script
	end
	
	local item_interact_sidebar_loader = {
		inventory={},
		skills={},
		shop={},
	}
	
	--local selected_item
	
	
	
	
	
	
	--menu
	do
		--local current_item_interact
		
		local button_data = {
			inventory = function()
				clear_icon()
				attempt_load_inventory(current_page or 'gun')()--meh
				_gui.main_menu.Visible = false
				_gui.item_interact.Visible = true
				
				_gui.item_interact.body.data.ui_name.Text = 'INVENTORY'
				
				for name,val in pairs(shop_select) do
					_gui.item_interact.body.select[name].Text = val
				end
			end,
			play = function()
				_gui.main_menu.Visible = false
				_gui.matchmaking.Visible = true
			end,
			shop = function()
				clear_icon()
				attempt_load_shop(current_page or 'gun')()--meh 2.0
				_gui.main_menu.Visible = false
				_gui.item_interact.Visible = true
				
				_gui.item_interact.body.data.ui_name.Text = 'SHOP'
				
				for name,val in pairs(shop_select) do
					_gui.item_interact.body.select[name].Text = val
				end
			end,
			skills = function()
				_gui.main_menu.Visible = false
				_gui.item_interact.Visible = true
				
				_gui.item_interact.body.data.ui_name.Text = 'SKILLS'
				
				for name,val in pairs(skill_select) do
					_gui.item_interact.body.select[name].Text = val
				end
			end,
			tutorial = function()
				
			end,
		}

		local function attempt_run(i)
			return function()
				local func = current_item_interact[i]
				if func then
					func()
				end
			end
		end
		
		_gui.item_interact.body.bottom_half.sidebar.buttons.buy.MouseButton1Up:connect(function()
			if current_item_interact == item_interact_sidebar_loader.shop then
				print(selected_item,'k')
				inventory_data:attempt_purchase(selected_item) -- tfw variable dissapears lol
			end
		end)
		
		_gui.item_interact.body.select.one.MouseButton1Up:connect(attempt_run(1)) -- func returns func dont cry ok
		_gui.item_interact.body.select.two.MouseButton1Up:connect(attempt_run(2))
		_gui.item_interact.body.select.three.MouseButton1Up:connect(attempt_run(3))
		_gui.item_interact.body.select.four.MouseButton1Up:connect(attempt_run(4))
		_gui.item_interact.body.select.five.MouseButton1Up:connect(attempt_run(5))
		
		for _,button in pairs(_gui.main_menu.select.buttons:GetChildren()) do
			button.MouseEnter:connect(function()
				_gui.main_menu.select.scroll:TweenPosition(button.Position, "Out", "Quad", .2,true)
				button:TweenPosition(UDim2.new(0,50,button.Position.Y.Scale,0), "Out", "Quad", .2,true)
			end)
			button.MouseLeave:connect(function()
				button:TweenPosition(UDim2.new(0,30,button.Position.Y.Scale,0), "Out", "Quad", .2,true)
			end)
			button.MouseButton1Up:connect(function()
				button_data[button.Name]()
				current_item_interact = item_interact_sidebar_loader[button.Name]
				print(button.Name,'meme')
				_gui.back.Visible = true
			end)
		end
		
		_gui.main_menu.info.plrdata.data.cash.Text = '$'..inventory_data.cash
		_gui.main_menu.info.plrdata.data.level.Text = lines(tostring(inventory_data.level),3)
		_gui.main_menu.info.plrdata.data.name.Text=game.Players.LocalPlayer.Name:upper()
		_gui.main_menu.info.plrdata.data.xp.Text = inventory_data.exp..'/'..(exp_curve(inventory_data.level+1)-exp_curve(inventory_data.level))
	end
	
	
	
	
	
	
	
	--matchmaking
	do
		local current_map_scroll = maps.heist
		
		local function update_matchmaking()
			print(current_map_scroll,#current_map_scroll)
			for i,v in pairs(current_map_scroll) do
				print(i,v,'Xd')
			end
			_gui.matchmaking.gamemode.text.Text = gamemode[1]:upper()
			_gui.matchmaking.map.text.Text = current_map_scroll[1]:upper()
			print(current_map_scroll[1],current_map_scroll)
			local data = map_imgs[current_map_scroll[1]] or map_imgs.default
			_gui.matchmaking.sidebar.selected.Image = 'rbxassetid://'..data[1]
			if data[2] then
				_gui.matchmaking.sidebar.selected.Vault.Visible = true
				_gui.matchmaking.sidebar.selected.Vault.Position = data[2]
			else
				_gui.matchmaking.sidebar.selected.Vault.Visible = false
			end
			_gui.matchmaking.sidebar.selected.name.Text = current_map_scroll[1]:upper()
			_gui.matchmaking.sidebar.selected.desc.Text = map_desc[current_map_scroll[1]].desc
			_gui.matchmaking.sidebar.item_info.data.difficulty.Text = map_desc[current_map_scroll[1]].difficulty:upper()
			_gui.matchmaking.sidebar.item_info.data.max_score.Text = map_desc[current_map_scroll[1]].maximum_score
		end
		
		run_service:BindToRenderStep('Flash red dot',199,function()
			_gui.matchmaking.sidebar.selected.Vault.ImageTransparency = 0.45 + (math.sin(tick()) * 0.15)
		end)

		_gui.matchmaking.gamemode.left.MouseButton1Up:connect(function()
			scroll(gamemode,-1)
			current_map_scroll = maps[gamemode[1]]
			print(gamemode[1])
			update_matchmaking()
		end)
		_gui.matchmaking.gamemode.right.MouseButton1Up:connect(function()
			scroll(gamemode,1)
			current_map_scroll = maps[gamemode[1]]
			update_matchmaking()
		end)
		
		_gui.matchmaking.map.left.MouseButton1Up:connect(function()
			scroll(current_map_scroll,-1)
			update_matchmaking()
		end)
		
		_gui.matchmaking.map.right.MouseButton1Up:connect(function()
			scroll(current_map_scroll,1)
			update_matchmaking()
		end)
		
		
	end
	
	
	
	
	
	
	--misc
	do -- i dont actually need a new scope for this but it looks more organiseder
		function load_buttons(list)
			local increment = 0
			for _,obj in pairs(_gui.item_interact.body.bottom_half.sidebar.buttons:GetChildren()) do
				if list[obj.Name] then
					obj.Visible = true
					obj.Position = UDim2.new(0,0,-increment,-(increment-1)*10)
					increment = increment + 1
				else
					obj.Visible = false
				end
			end
			_gui.item_interact.body.bottom_half.sidebar.item_info.Position = UDim2.new(0,20,0.5,-increment*50)
		end
		function load_icons(list)
			list = list
			for real_icon = 1,24 do
				local icon = list[real_icon]
				local obj = _gui.item_interact.body.bottom_half.item_select.box:FindFirstChild(tostring(real_icon),true)
				if not icon then
					obj.Visible = false
				else
					--icon = icon.id
					if type(icon) == 'number' then
						icon = 'rbxassetid://'..icon -- for number JET SKI
					end
					obj.Visible = true
					obj.BackgroundTransparency = 0.7
					obj.Image = 'rbxassetid://'..icon.id
					obj.tick.primary.Visible,obj.tick.secondary.Visible,obj.tick.tertiary.Visible=false
					for class,item in pairs(inventory_data.equipped_items) do
						if item == icon.name then
							if class:sub(1,#'primary')=='primary' then
								obj.tick.primary.Visible = true
							elseif class:sub(1,#'secondary')=='secondary' then
								obj.tick.secondary.Visible = true
							else
								obj.tick.tertiary.Visible = true -- right?
							end
						end
					end
				end
			end
		end
		
		function clear_icon()
			--_gui.item_interact.body.bottom_half.sidebar.selected.desc.Text = ''
			_gui.item_interact.body.bottom_half.sidebar.selected.Visible = false
			--[[for _,obj in pairs(_gui.item_interact.body.bottom_half.sidebar.selected.side:GetChildren()) do
				obj.Text = ''
			end]]
			_gui.item_interact.body.bottom_half.sidebar.item_info.Visible = false
			load_buttons{}
		end
		
		local function load_data(num) -- GROSS SPAGHETTI CODE AHEAD WARNING
			
			local real_data = click_data[tonumber(num)]
			selected_item = click_data[tonumber(num)].name
			
			_gui.item_interact.body.bottom_half.sidebar.selected.side.name.Text =real_data.name:upper()
			_gui.item_interact.body.bottom_half.sidebar.selected.Visible = true
			if real_data.level_req then
				_gui.item_interact.body.bottom_half.sidebar.selected.side.lvl_req.Text = 'LEVEL '.. real_data.level_req..' NEEDED'
				_gui.item_interact.body.bottom_half.sidebar.selected.side.cost.Text = '$'..real_data.cost
			else
				_gui.item_interact.body.bottom_half.sidebar.selected.side.lvl_req.Text=''
				_gui.item_interact.body.bottom_half.sidebar.selected.side.cost.Text = ''
			end
			
			_gui.item_interact.body.bottom_half.sidebar.selected.desc.Text = (real_data.desc or ''):upper()
			_gui.item_interact.body.bottom_half.sidebar.selected.Image = 'rbxassetid://'..real_data.id
			
			if current_item_interact==item_interact_sidebar_loader.inventory then
				if real_data.specific=='primary' then
					load_buttons{primary=true}
				elseif real_data.specific=='secondary' then
					load_buttons{secondary=true}
				elseif real_data.specific=='all' then
					load_buttons{primary=true,secondary=true,tertiary=true}
				else
					load_buttons{primary=true,secondary=true}
				end
			end
			
			-- ik loops exist but TYPE is a thing ((rekd))
			if real_data.accuracy or real_data.damage or real_data.recoil then
				_gui.item_interact.body.bottom_half.sidebar.item_info.Visible = true
				
				_gui.item_interact.body.bottom_half.sidebar.item_info.data.accuracy.Text =': '.. real_data.accuracy or '0'
				_gui.item_interact.body.bottom_half.sidebar.item_info.data.damage.Text = ': '..real_data.damage or '0'
				_gui.item_interact.body.bottom_half.sidebar.item_info.data.recoil.Text = ': '..real_data.recoil or '0'
				_gui.item_interact.body.bottom_half.sidebar.item_info.data.type.Text = ': '..(real_data.type or real_data.shop_class):upper()
			else
				_gui.item_interact.body.bottom_half.sidebar.item_info.Visible = false
			end
		end
		
		for _,box in pairs(_gui.item_interact.body.bottom_half.item_select.box:GetChildren()) do
			box.MouseButton1Up:connect(function()
				load_data(box.Name)
			end)
			for _,box in pairs(box:GetChildren()) do -- muh recursives!
				if box:IsA("ImageButton") then
					box.MouseButton1Up:connect(function()
						load_data(box.Name)
					end)
				end
			end
		end
		
		local function clear_ui(select)--BETTER
			return function()
				print('u wot matt?')
				for _,object in pairs(_gui.item_interact.body.select:GetChildren()) do
					if select == object then
						object.BackgroundTransparency = 0.2
					else
						object.BackgroundTransparency = 1
					end
				end
			end
		end
		
		for _,object in pairs(_gui.item_interact.body.select:GetChildren()) do
			object.MouseButton1Up:connect(clear_ui(object)) -- technically recursive?
		end
	end
	
	
	
	
	--shop
	do -- hi mr west can u see this, if u can remember to get the laptop k thx (btw i worked 2 hours today so far are u proud lol)
		
		
		--load_buttons({equip_primary=true})
		
		load_icons(click_data)

		function attempt_load_shop(class)
			return function()
				load_buttons{buy=true}
				current_page = class
				click_data={}
				_gui.item_interact.body.bottom_half.sidebar.item_info.Visible = false
				for obj_name,data in pairs(item_modules) do
					if data.shop_class == class and not inventory_data.owned_items[obj_name] then
						click_data[#click_data+1] = data
					end
				end
				_gui.item_interact.body.bottom_half.sidebar.selected.desc.Visible = true
				load_icons(click_data)
			end
		end
		
		item_interact_sidebar_loader.shop[1] =attempt_load_shop('gun')
		item_interact_sidebar_loader.shop[2] =attempt_load_shop('misc')--?
		item_interact_sidebar_loader.shop[3] =attempt_load_shop('attachment')
		item_interact_sidebar_loader.shop[4] =attempt_load_shop('mask') -- why is this in shop, i will never know lol (its pretty much clickbait as you can only get masks from achievements)
		item_interact_sidebar_loader.shop[5] =attempt_load_shop('skin') -- also only achievable, lol. (well, PROBABLY only achievable. may sell cases nd dat)
	end
	
	
	
	
	
	
	--inventory
	do
		function attempt_load_inventory(class)
			return function()
				--clear_icon()
				click_data = {}
				current_page = class
				for name,data in pairs(inventory_data.owned_items) do
					if data.shop_class == class then
						click_data[#click_data+1]=data
					end
				end
				load_icons(click_data)
				_gui.item_interact.body.bottom_half.sidebar.selected.desc.Visible = false
				--load_buttons()
			end
		end
		
		_gui.item_interact.body.bottom_half.sidebar.buttons.primary.MouseButton1Up:connect(function()
			if inventory_data.equipped_items[item_modules[selected_item].class] ~= selected_item then
				inventory_data:change_order('primary_'..item_modules[selected_item].class ,selected_item)
			else
				inventory_data:change_order('primary_'..item_modules[selected_item].class ,nil or )
			end
			
			--attempt_load_inventory(current_page)() -- WEE WOO WEE WOO MEMORY LEAK, REPLACE (or no?)
		end)
		
		item_interact_sidebar_loader.inventory[1] =attempt_load_inventory('gun')
		item_interact_sidebar_loader.inventory[2] =attempt_load_inventory('misc')--?
		item_interact_sidebar_loader.inventory[3] =attempt_load_inventory('attachment')
		item_interact_sidebar_loader.inventory[4] =attempt_load_inventory('mask') -- why is this in shop, i will never know lol (its pretty much clickbait as you can only get masks from achievements)
		item_interact_sidebar_loader.inventory[5] =attempt_load_inventory('skin')
	end
	
	_gui.back.MouseButton1Up:connect(function()
		for i,v in pairs(_gui:GetChildren()) do
			v.Visible = false
		end
		_gui.main_menu.Visible = true
	end)
	
end







_gui.main_menu.announcement.data.Text = _network.RemoteFunction:InvokeServer('get announcement'):upper()
event.new('new announcement'):connect(function(new_announcement)
	_gui.main_menu.announcement.data.Text = new_announcement:upper()
end)
