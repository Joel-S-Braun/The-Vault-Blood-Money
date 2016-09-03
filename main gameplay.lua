
--[[
	@24/4/16
	@axel-studios
	@the-vault-blood-money
	@waffloid
--]]


math.randomseed(math.sin(tick())*tick())

local _replicated_storage = game.ReplicatedStorage
local _assets = _replicated_storage.Assets
local _network = _replicated_storage.Network

local pathfinding_service = game:GetService('PathfindingService')


local called = {}
local remote_functions = {}
local event = {}
local named_events = {}
local vector = {}
local cframe = {}
local action = {}
local downed_players = {}
local behavior_matrix = {}
local brain = {communication={},interaction={}}
local ignore = {workspace.Enemys,workspace.Ignore_Folder,workspace.ActiveSpot,workspace.ActiveSpot}
local interaction_list = {}
local named_events = {}
local pseudo_character = {}
local total = {}

local dist_threshold = 10^-7
local movement_threshold = 30
local downed_health_threshold = 10
local danger = 1
local civilians = 0
local enemy_count = 0
local bag_money_cap = 10000
local total_money = 0

local heisters_noticed

local speed = Vector3.new(14,50,14)
local vision = (Vector3.new(0,0,1)-CFrame.Angles(0,math.rad(40),0).lookVector).Magnitude

local function index_table(tab,real_tab)
	real_tab = real_tab or ''	for i,v in pairs(tab) do
		print(real_tab,i,":",v)
		if type(v) == 'table' then
			index_table(v,real_tab..'	')
		end
	end
end
local function angle(cframe)
	return cframe - cframe.p
end

local function get_obj(real_model)
	local model
	for w in string.gmatch(real_model,'%w+') do
		if not model then
			model = workspace
		else
			if #model:GetChildren() >= 1 then
				if not model:FindFirstChild(w) then
					local _,last_index = real_model:find(w)
					model = model:FindFirstChild(real_model:sub(last_index+2,#real_model))
				else
					model = model:FindFirstChild(w)
				end
			end
		end
	end
	return model
end





--@math module
do
	-- vector
	function vector.random(radius)
		local radius = (radius or 6)*math.sqrt(math.random())
		local angle = math.random()*math.pi
		return Vector3.new(math.sin(angle)*radius,0,math.cos(angle)*radius)
	end
	-- cframe
	function cframe.spread(r)
		r = math.rad(r)
		return CFrame.Angles((math.random()*r)-(r/2),(math.random()*r)-(r/2),0)
	end
end




 
--@init
do
	game.Players.PlayerAdded:connect(function(plr)
		local char = _assets.PlayerModel:Clone()
		char:SetPrimaryPartCFrame(workspace.Spawn_Point.CFrame+vector.random(5)+Vector3.new(0,2,0))
		char.Name = plr.Name
		plr.Character = char
		char.Parent = workspace
	end)
end






















do
	
	behavior_matrix.new = function(matrix_funcs)
		
		local matrix = {happy=0,fear=0,tolerance = 2} -- 2 = neutral, 2 = most positive, -2 = most negative,tolerance = numerical root of emotions
		local funcs = {
			behavior = function()
				return matrix_funcs[math.floor(matrix.happy)..','..math.floor(matrix.fear)]
			end
		}
		local meta_func = {
			__index = function(_,index)
				return funcs[index]()
			end
		}
		local real_matrix={matrix=matrix,behavior={}}
		setmetatable(real_matrix.behavior,{__index=funcs.behavior})
		return real_matrix
	end
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
		return remote_functions[name](player,...)
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
			event:connect(function(...) local output = {condition(...)} if output[1] then new_event:fire(unpack(output)) end end)
		end
		if name then
			--'ok',name)
			named_events[name] = event
		end
		return event
	end
	
	remote_functions['Ping'] = function(time)
		return time,tick()
	end
end
--'networking crap loaded')

local objectives = event.new('Objectives')







--@action module
do
	local shoot_event = event.new('shoot')

	local downed_event = event.new('downed')
	local ragdoll_event = event.new('ragdoll')
	
	downed_event:connect(function(name,value)
		downed_players[name] = value
	end)
end















--@interaction module
do
	local class = {}
	
	local picked_up_drill


	-- bag
	do
		local bags_state = {}
		local welds = {}
		
		class.Bag = {}
		function class.Bag:is_interactive(plr,obj)
			if not bags_state[obj.Name] and not welds[plr.Name] then -- if no one has bag
				return {'pick up bag',true,.2} -- message is put on billboard gui, on obj.
			elseif bags_state[obj.Name] == plr then
				return {'press g to drop the bag. you cannot interact with anything, or sprint until you have dropped the bag.',false,.2} 
				-- message is not put on billboard gui, put on msg instead
			else
				print(obj.Name,bags_state[obj.Name])
			end
		end

		function class.Bag:interact(plr,obj)
			plr = plr.Character
			if not bags_state[obj.Name] and not welds[plr.Name] then
				if obj.Name == 'Interactive_Bag_ThermalBag' and not picked_up_drill then
					picked_up_drill = true
					objectives:fire('Take your bag to the vault')
				end
				bags_state[obj.Name] = plr
				obj.CanCollide = false
				local weld = Instance.new('ManualWeld',plr)
				welds[plr.Name] = weld
				weld.Part0 = plr.Torso
				weld.Part1 = obj
				weld.C1 = CFrame.new(0,0,-.5 - obj.Size.Z/2) * CFrame.Angles(0,0,math.rad(math.random(60,120)))
			elseif bags_state[obj.Name] == plr then
				if welds[plr.Name] then
					obj.CanCollide = true
					welds[plr.Name]:Destroy()
					welds[plr.Name] = nil
					bags_state[obj.Name] = nil
				end
			end
		end
	end
	
	--drill
	do
		local drill
		
		class.Drill = {}
		function class.Drill:is_interactive(plr,obj)
			if (obj).Name == 'Interactive_Drill_Bag' then
				return {'set up drill',true,1}
			elseif (obj).Name == 'Interactive_Drill_Jammed' then
				return {'fix drill',true,1}
			end
		end
		
		function class.Drill:interact(plr,obj)
			if (obj).Name == 'Interactive_Drill_Bag' then
				if heisters_noticed then
					objectives:fire('Protect the thermal drill')
				else
					objectives:fire('Wait for the vault to open')
				end
				obj:Destroy()
				drill = _assets.Drill
				drill.Parent = workspace.Interactive
				drill.Name = 'Interactive_Drill_ThermalDrill'
			elseif (obj).Name == 'Interactive_Drill_Jammed' then
				drill.Name = 'Interactive_Drill_ThermalDrill'
			end
		end
	end
	
	--dead npcs
	do
		class.Dead = {}
		function class.Dead:is_interactive(plr,obj)
			if obj.Name:find('Guard') then
				return {'answer pager',true,3}
			else
				return {'use body bag',true,1}
			end
		end
		
		local existing_bags = 0
		local existing_pagered = 0
		function class.Dead:interact(plr,obj)
			if obj.Name:find('Guard') then
				existing_pagered = existing_pagered + 1
				obj.Name = 'Interactive_Dead_Pagered'..existing_pagered
			else
				existing_bags = existing_bags + 1
				local center = obj:GetModelCFrame()
				local bag = _assets.BodyBag:Clone()
				bag.Parent = workspace.Interactive
				
				obj:Destroy()
				bag.Name = 'Interactive_Bag_Body Bag'..existing_bags
				bag.CFrame = center
			end
		end
	end
	
	--money
	do
		class.Money = {}
		
		function class.Money:is_interactive(plr,obj)
			return {'bag the money',true,1}
		end
		
		local existing_bags = 0
		function class.Money:interact(plr,obj)
			existing_bags = existing_bags + 1
			local center = obj:GetModelCFrame()
			local bag = _assets.MoneyBag:Clone()
			bag.Parent = workspace.Interactive
			
			obj:Destroy()
			bag.Name = 'Interactive_Bag_MoneyBag'..existing_bags
			bag.CFrame = center
		end
	end

	remote_functions['interactive'] = function(plr,spec_class,object) -- e.g. Waffloid,Bag,workspace.Interactive.Interactive_Bag_ThermalBag
		if plr.Character.Humanoid.Health > 0  and plr.Character:FindFirstChild('Torso') then
			return class[spec_class]:is_interactive(plr.Character,workspace.Interactive:FindFirstChild(object))
		end
	end

	event.new('interact'):connect(function(plr,spec_class,object,...) -- e.g. Waffloid,Bag,workspace.Interactive.Interactive_Bag_ThermalBag
		if plr.Character.Humanoid.Health > 0  and plr.Character:FindFirstChild('Torso') then -- physically CANNOT interact if dead
			if class[spec_class]:is_interactive(plr.Character,workspace.Interactive:FindFirstChild(object),...) then
				local obj = workspace.Interactive:FindFirstChild(object)
						
				class[spec_class]:interact(plr,obj)
			end
		end
	end)
end











--@pseudo_characters
do
	local move = event.new('move')
	
	function optimise_path(path_points)
		local next_point,lookvector
		for i,v in pairs(path_points) do
			next_point = path_points[i+1]
			if next_point then
				if lookvector then
					if (lookvector-CFrame.new(v,next_point).lookVector).Magnitude < 0.3 then
						path_points[i] = nil
					else
						lookvector = CFrame.new(v,next_point).lookVector
					end
				else
					lookvector = CFrame.new(v,next_point).lookVector
				end
			end
		end
	end
	
	function pseudo_character.new(orig_char,parent,health) -- possibly add brain?
		health = health or 100
		total[orig_char.Name] = (total[orig_char.Name] or 0)+1
		local char = orig_char:Clone()
		char.Name = 'Char'..total[char.Name]
		
		local pseudo_char = {}
		
		function pseudo_char:move_to(position)
			
			local offset = position-char.Torso.Position
			
			move:fire(char:GetFullName(),char.Torso.Position,position+Vector3.new(0,1,0))
			
			local time 
			if offset.Y < 0 then
				time = (offset / Vector3.new(16,120,16)).Magnitude
			else
				time = (offset / Vector3.new(1,1,1)).Magnitude
			end
			wait(time)
			char:MoveTo(position)
		end
		
		function pseudo_char:pathfind_to(position)
			local path = pathfinding_service:ComputeRawPathAsync(char.Torso.Position,position,500)
			local points = path:GetPointCoordinates()
			optimise_path(points)
			for _,position in pairs(points) do
				pseudo_char:move_to(position)
			end
		end
		
		pseudo_char.Character = char
		char.Parent = parent
		return pseudo_char
	end
end













--@gamelogic
do
	local _interactive = workspace.Interactive
	
	local is_vault_open = false
	
	local vault_opened = event.new('Vault opened')
	local narration = event.new('narration')
	local police_assault = event.new('police assault')
	local spotted = event.new('Spotted')
	
	workspace.Interactive.BagArea.Touched:connect(function(hit)
		print(hit,'1')
		if hit:FindFirstChild("Money") then
			print(hit,'2')
			if hit.Money.Value <= bag_money_cap then
				repeat wait() until hit.CanCollide
				print('i can collide!')
				if (hit.Position-workspace.Interactive.BagArea.Position).Magnitude <= 23 then
					total_money = total_money + hit.Money.Value
					hit.Money:Destroy()
					hit.Name = 'Used Moneybag'
					wait(2)
					hit.Anchored = true
					hit.CanCollide = false
				end
			else
				print('bonlond')
				--BANISHED TO OGGYLAND RARARARARAR
			end
		end
	end)
	
	vault_opened:connect(function(player)
		objectives:fire("Steal the money in the vault")
		if not player then -- if a player opens it it means that they C4/tripmine'd it open
			_interactive.Vault:Destroy()
		end
	end)
	
	spotted:connect(function()
		narration:fire("Police assault should be coming soon. They'll be here in around 30 seconds.")
		wait(math.random(28,32))
		police_assault:fire(true)
		for real_wave = 1,2 + danger do
			wave(real_wave)
			wait((civilians)*5+10)
			police_assault:fire(false)
		end
	end)
	
	_assets.Drill.Changed:connect(function(v)
		print(v,'44 in the 4 door')
		if _interactive:FindFirstChild('Drill') then
			for i = 5,0,-1 do	
				print('onli'..i..'seconds left')
				wait(1)
				if math.random(1,3) == 1 then
					_interactive.Interactive_Drill_ThermalDrill.Name = 'Interactive_Drill_Jammed'
					_interactive:WaitForChild('Interactive_Drill_ThermalDrill')
				end
			end
			vault_opened:fire()
		end
	end)
	
	local enemys = {'Cop','Cop','SWAT'}
	local limit = 30 + danger * 5
	-- add in specific vehicles spawn too!!!!!!!
	function wave(specific_wave)
		for _ = 1,(math.random(10+(specific_wave*5)))/3.5 do -- rough enemy count
			local enemy = enemys[math.min(math.random(specific_wave),#enemys)]
			local spawn_children = workspace.Spawn:FindFirstChild(enemy):GetChildren()
			local spawn = spawn_children[math.random(#spawn_children)].Position
			for i = 1,math.random(3,5) do
				if enemy_count <= limit then
					enemy_count = enemy_count + 1
					local enemy_body = game.ReplicatedStorage.Assets:FindFirstChild(enemy):Clone()
					enemy_body.Parent = workspace.Enemys:FindFirstChild(enemy)
					enemy_body:SetPrimaryPartCFrame(CFrame.new(spawn + vector.random()) * CFrame.new(0,2,0))
					brain[enemy:lower()](enemy_body)
					enemy_body.Name = enemy..#workspace.Enemys[enemy]:GetChildren()
					wait(.2)
				end
			end
			wait(2 + (2/specific_wave))
		end
	end
	
	local end_screen = event.new('End screen')
	
	local sent_message_finish
	local first_met_requirement
	
	while wait(.1) do -- main loop, will handle everythin
		-- bag touched loop
		do
			local thermal_bag = _interactive:FindFirstChild('Interactive_Bag_ThermalBag')
			if thermal_bag then
				if (thermal_bag.Position-_interactive.VaultArea.Position).Magnitude < 8 and thermal_bag.CanCollide == true then
					objectives:fire("Set up the thermal drill")
					_interactive.Interactive_Bag_ThermalBag.Name = 'Interactive_Drill_Bag'
					wait(3)
					if _interactive:FindFirstChild("Interactive_Drill_Bag") then -- in case that they set up drill b4 it anchors
						
						_interactive.Interactive_Drill_Bag.Anchored = true
						_interactive.Interactive_Drill_Bag.CanCollide = false
					end
				end
			end
		end
		
		--van stuff
		do
			local good_to_go
			if total_money >= 500 then
				if not sent_message_finish then
					sent_message_finish = true
					objectives:fire("Take more money or stay in van to finish the heist")
				end
				good_to_go = true
				for _,plr in pairs(game.Players:GetPlayers()) do
					local torso = plr.Character:FindFirstChild("Torso")
					if torso then
						local distance = (workspace.Interactive.BagArea.Position-torso.Position).Magnitude
						print(distance)
						if distance > 20 then
							good_to_go = false
							first_met_requirement = nil
						end
					end
				end
			end
			if good_to_go and not first_met_requirement then
				first_met_requirement = tick()
			elseif good_to_go and (tick()-first_met_requirement) >= 10 then
				end_screen:fire(total_money,heisters_in_custody or 0,civilians_killed or 0,math.floor(total_money/10000)*1000)
				print('END')
				break
			end
		end
	end
end
