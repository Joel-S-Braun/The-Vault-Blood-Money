--[[
	@20/4/16
	@axel-studios
	@the-vault-blood-money
	@waffloid
--]]

repeat wait()  until game.Players.LocalPlayer.Character

local run_service = game:GetService('RunService')

local player = game.Players.LocalPlayer
local _character = player.Character
local _replicated_storage = game.ReplicatedStorage
local _humanoid = _character:WaitForChild("Humanoid")
local _network = _replicated_storage.Network
local _assets = _replicated_storage.Assets
local _interface = player.PlayerGui:WaitForChild('UI')
local _ui = _interface.Gameplay

local heartbeat_funcs = {}
local character_module = {}
local animation = {anims={}}
local named_events = {}
local movement = {}
local movement_data = {}
local event = {}
local player_anims = {}
local named_events = {}
local event = {}
local pseudo_char_interp = {} -- "game.workspace.npc1" = {start=cframe,finish=cframe,start_time=start_time,length=length,angle=angle}
local pseudo_char_output = {} -- "game.workspace.npc1" = cframe=current_cframe
local animation = {}
local running_animations = {} -- {Workspace.Waffloid={wave={start_time=start_time,looped=true},jump=start_time}}
local animation_start = {}
local current_keyframe = {}
local ui_logic = {}
local weld_status = {} 
local delta = {}
local mathf = {}
local weapon = {}
local animations = {}
local remote_functions

local anim_render_dist = 90
local movement_render_dist = 150
local rot_constraint = 20
local user_input_service = game:GetService('UserInputService')
local has_bag
local interacting

local is_aiming
local reloading
local shooting

local tutorial_mode = true
local casing_mode = true


function index_table(tab,real_tab)
	real_tab = real_tab or ''	for i,v in pairs(tab) do
		--(real_tab,i,":",v)
		if type(v) == 'table' then
			index_table(v,real_tab..'	')
		end
	end
end

local function get_obj(real_model)
	local model
	for w in string.gmatch(real_model,'%w+') do
		if not model then
			model = workspace
		else
			model = model:FindFirstChild(w)
		end
	end
	return model
end












--mathf module
do
	
	function mathf.round(num) -- for that pesky fpp
		return math.floor(num*12)/12
	end


	function mathf.extract_angle(c)
		return c-c.p--hot
	end

	function mathf.clamp(min,max,val)
		return math.max(min,math.min(max,val))
	end

	function mathf.abs(vec)
		return Vector3.new(math.abs(vec.X),math.abs(vec.Y),math.abs(vec.Z))
	end

	function mathf.len(t)
		local l=0
		for i,v in pairs(t) do
			l=l+1
		end
		return l
	end
end












--delta module
do
	local id = {}
	function delta.set(name)
		id[name]=tick()
	end
	function delta.get(name)
		if id[name] then
			return tick()-id[name]
		else
			delta.set(name)
			return 0
		end
	end
end











-- DO SYNC
--@player_animation ski
do	
	--@init
	player_animation = {gundes=CFrame.new(),
		leftdes=Vector3.new(),rightdes=Vector3.new(),
		leftreal = Vector3.new(),rightreal=Vector3.new(),gunreal = CFrame.new(),
		sway_speed = 1.3,sway_factor = 32 ,gun_offset=CFrame.new(),gun_recoil=CFrame.new(),
		model=_character,
	}
	
	do
		for i,v in pairs(script:GetChildren()) do
			animations[v.Name] = require(v)
		end

		_character.Torso['Left Arm']:Destroy()
		_character.Torso['Right Arm']:Destroy()

		_character['Right Arm'].Size = Vector3.new(.9,2,.9)
		weld = Instance.new('ManualWeld')
		weld.Parent = _character.Torso
		weld.Part0 = _character.Head
		weld.Part1 = _character['Right Arm']
		weld.Name = 'Right Arm'
		weld.C0 = CFrame.new(1.5,-1,0)

		_character['Left Arm'].Size = Vector3.new(.9,2,.9)
		weld = Instance.new('ManualWeld')
		weld.Parent = _character.Torso
		weld.Part0 = _character.Head
		weld.Part1 = _character['Left Arm']
		weld.Name = 'Left Arm'
		weld.C0 = CFrame.new(-1.5,-1,0)

		_character.Torso.Gun.C0 = CFrame.Angles(0,math.pi,0)
		_character.Torso.Head.C1 = CFrame.new()
	end



	
	function run_animation(anim,obj,priority)
		priority = priority or 210
		delta.set(obj.model:GetFullName())
		if animations[anim][0] and (mathf.len(animations[anim]) == 1) then
			for index,value in pairs(animations[anim][0]) do
				obj[index]=value
			end
		else
			run_service:BindToRenderStep(priority..tostring(obj),priority,function() -- so that only 1 player_animation with this priority can run at same time (makes shit like running scheduling 999x
			local has_animated
			
				for time,slide in pairs(animations[anim]) do
					if time > delta.get(obj.model:GetFullName()) then
						has_animated = true
						for index,value in pairs(slide) do
							obj[index]=value
						end
					end
				end
				if not has_animated then
					run_service:UnbindFromRenderStep(priority..obj.model:GetFullName())
				end
			end)
		end
	end



	function recoil(animation)
		local id = animation.model:GetFullName().."Recoil"
		delta.set(id)
		run_service:UnbindFromRenderStep(id)
		run_service:BindToRenderStep(id,201,function()
			workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(math.sin(delta.get(id) * 15) / 60,0,0)
			player_animation.gun_recoil = CFrame.Angles(math.sin(math.min(delta.get(id),0.2) * math.pi * 10 )/(10 + (delta.get(id) * 100)),0,0)
			if (delta.get(id) * 10) >= 1 then
				player_animation.gun_recoil = CFrame.new()
				run_service:UnbindFromRenderStep(id)
			end
		end)
		--player_animation.gun_recoil = CFrame.new()
	end



	function interpret_player() -- specifically made for THIS client, not others. may just recycle code in diff function for NPCs OR modify this to return function
		for i,v in pairs(_character:GetChildren()) do
			if v:IsA("BasePart") then
				v.LocalTransparencyModifier = 0
			end
		end
		
		_character.Torso.Head.C0 = player_animation.gun_offset * player_animation.gun_recoil * CFrame.Angles(math.asin(workspace.CurrentCamera.CFrame.lookVector.Y),0,0) + Vector3.new(0,1.5,0)

		local right_start = player_animation.model.Head.CFrame * CFrame.new(1.5,-1,0)
		local left_start = player_animation.model.Head.CFrame * CFrame.new(-1.5,-1,0)
		
		local delta_val = 1- 1/2^(delta.get( player_animation.model:GetFullName() ) * 10 )
		delta.set(player_animation.model:GetFullName())
		
		--real cframe
		player_animation.gunreal = player_animation.gunreal:lerp(player_animation.gundes,delta_val)
		player_animation.leftreal = player_animation.leftreal:lerp(player_animation.leftdes,delta_val)
		player_animation.rightreal = player_animation.rightreal:lerp(player_animation.rightdes,delta_val)

		--gun
		player_animation.model.Torso.Gun.C1 = (player_animation.gunreal)
		
		--right arm
		local offset = player_animation.rightreal - Vector3.new(1.5,-1,0) 
		local magnitude = mathf.clamp(-0.3,1.4,player_animation.rightreal.Magnitude-1)
		player_animation.model.Torso['Right Arm'].C1 =  CFrame.Angles(math.rad(90),0,0) * ((CFrame.Angles(math.atan2(offset.Y,-offset.Z),math.atan2(offset.X,offset.Z),0)) * CFrame.new(0,0,magnitude)):inverse()
		
		--left arm
		local offset = player_animation.leftreal - Vector3.new(-1.5,-1,0)
		local magnitude = mathf.clamp(-0.3,1.4,player_animation.leftreal.Magnitude-1)
		player_animation.model.Torso['Left Arm'].C1 = CFrame.Angles(math.rad(90),0,0) * ((CFrame.Angles(math.atan2(offset.Y,-offset.Z),math.atan2(offset.X,offset.Z),0)) * CFrame.new(0,0,magnitude)):inverse()-- * CFrame.Angles(math.rad(-90),0,0)
	end
	
	--repeat wait until casing

	run_service:BindToRenderStep('Animate',201,interpret_player)
	
	run_animation('Hipfire',player_animation)
end















--@skills
do
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
--('networking/event module loaded')













--@color module
do
	local positive_not_scared_desired = Color3.new(30/255, 199/255, 143/255)
	local negative_not_scared_desired = Color3.new(255/255, 0, 0)
	local positive_sadness_desired = Color3.new(0, 24/255, 158/255)
	local negative_sadness_desired = Color3.new(215/255, 255/255, 153/255)
	
	local increment = .35
	local delta_increment = 1


	function decide_emotion_color(not_scared,sadness)
		local not_scared_color,sadness_color
		if math.abs(not_scared) == not_scared then
			not_scared_color = Color3.new(.5,.5,.5):lerp(positive_not_scared_desired,(not_scared/10)^increment)
		else
			not_scared_color = Color3.new(.5,.5,.5):lerp(negative_not_scared_desired,(not_scared/-10)^increment)
		end
		
		if math.abs(sadness) == sadness then
			sadness_color = Color3.new(.5,.5,.5):lerp(positive_sadness_desired,(sadness/10)^increment)
		else
			sadness_color = Color3.new(.5,.5,.5):lerp(negative_sadness_desired,(sadness/-10)^increment)
		end
		
		local delta = math.abs(not_scared)/(math.abs(sadness)+math.abs(not_scared))
		return sadness_color:lerp(not_scared_color,delta)
	end
	
	run_service:BindToRenderStep('Detection',199,function()
		for _,object in pairs(workspace.DetectionMeter:GetChildren()) do
			object.block.CFrame = CFrame.new(object.Value.Position + Vector3.new(0,2,0)) * CFrame.Angles(math.rad(45),math.rad(45),0)
			local transparency = (math.abs(object.Not_Scared.Value+object.Sadness.Value)/10)^.3
			if transparency < .05 and transparency > -.05 then
				transparency = 1
			end
			local color = decide_emotion_color(object.Not_Scared.Value,object.Sadness.Value)
			object.block.BrickColor = BrickColor.new(color)
			object.block.Transparency = transparency
			for i,v in pairs(object.block:GetChildren()) do
				v.Frame.Transparency = transparency
				v.Frame.BackgroundColor3 = color
			end
		end
	end)
end



















--@pseudocharacter module
do
end
--('pseudocharacter module loaded')



















--@interacion module
do
	
	local interact = event.new('interact')

	local function get_interactive_data(model)
		local is_interactive,class,name
		if model and model.Parent.Parent then
			if (model.Parent.Parent == workspace.Interactive) then
				return model.Parent.Name,model.Name,model
			elseif model:IsDescendantOf(workspace.Interactive) then
				return get_interactive_data(model.Parent) -- if its inside model ski recursive
			end
		end
	end

	local function is_interactive(obj)
		if obj and obj.Parent then
			local class,name = get_interactive_data(obj)
			if class then
				return _network.RemoteFunction:InvokeServer('interactive',class,obj)
			end
		end
	end
	
	local last_mouse_hit = workspace.Buildings.SkyFog
	local mouse = player:GetMouse()
	local global_class,name,interactive_data
	
	local interact_ui = player.PlayerGui.UI.Interact
	
	run_service:BindToRenderStep('Interaction',160,function()
		if not casing_mode then
			local target = mouse.Target or workspace.Buildings.SkyFog
			if target and not interacting then  
				if last_mouse_hit~= target then
					local class,name,target=get_interactive_data(target)
					local set_parent
					if class then
						global_class = class
						interactive_data = is_interactive(target)
						
						if interactive_data and not has_bag then
							interact_time = tonumber(interactive_data[3])
							
							interact_ui.Adornee = target
							interact_ui.Enabled = true
							
							interact_ui.Key.Text = 'F'
							
							interact_ui.Text.Text = interactive_data[1]:upper()
						end
						
					else
						interact_ui.Enabled = false
						interact_ui.Adornee = nil
						global_class = nil
						interact_time = nil
						interactive_data = nil
					end
					last_mouse_hit = target
				end
			end
		end
	end)
	
	function interact_proxy(time,key)
		if interactive_data and not has_bag and time and key then
			interacting = true
			local obj = last_mouse_hit
			_character.Humanoid.WalkSpeed = 0
			for i = 0,1,(1/60) /time do -- use bind
				interact_ui.Text.Frame.Size = UDim2.new(i,0,1,0)
				run_service.RenderStepped:wait()
				if (not user_input_service:IsKeyDown(Enum.KeyCode[key])) and true then
					interact_ui.Text.Frame.Size = UDim2.new(0,0,1,0)
					_character.Humanoid.WalkSpeed = 16
					interacting = false
					return
				end
			end
			interact_ui.Text.Frame.Size = UDim2.new(0,0,1,0)
			interact_ui.Enabled = false
			interact_ui.Adornee = nil
			interact:fire(global_class,last_mouse_hit)
			if global_class == 'Bag' then
				has_bag = last_mouse_hit
			end
			
			_character.Humanoid.WalkSpeed = 16
			interacting = false
			
			if obj and obj.Parent then
				local interactive,class,name = get_interactive_data(name)
				local new_data = is_interactive(obj)
				if new_data and not new_data[2] then
					_ui.OnscreenInteract.Visible = true
					_ui.OnscreenInteract.Text = new_data[1]:upper()
				end
			end
		end
	end
	
	function attempt_drop()
		if has_bag then
			_ui.OnscreenInteract.Visible = false
			interact:fire('Bag',has_bag);
			has_bag = nil
		end
	end
end
















--@gamelogic
do
	local picked_up_thermalbag
	local picked_up_money_bag
	
	local recieve_broken_light = event.new('Client broke light')
	local recieve_broken_glass = event.new('Client broke glass')
	local receive_open_door = event.new('Client open door')
	local receive_close_door = event.new('Client close door')

	recieve_broken_light:connect(function(part)
		part:ClearAllChildren()
		part.Material = 'Plastic'
	end)

	receive_open_door:connect(function(door)
		id = 'Open door '..math.random()
		local desired = math.rad(math.random(70,120))
		delta.set(id)
		run_service:BindToRenderStep(id,201,function()
			local delta = math.min(delta.get(id) * 3,1)
			
			door:SetPrimaryPartCFrame(CFrame.Angles(0,math.sin(delta * desired) * math.pi/2,0) + door.PrimaryPart.Position)

			if delta >= 1 then
				run_service:UnbindFromRenderStep(id)
			end
		end)
	end)

	receive_close_door:connect(function(door)
		id = 'Open door '..math.random()
		local desired = math.rad(math.random(70,120))
		delta.set(id)
		run_service:BindToRenderStep(id,201,function()
			local delta = 1-math.min(delta.get(id) * 3,1)
			
			door:SetPrimaryPartCFrame(CFrame.Angles(0,math.sin(delta * desired) * math.pi/2,0) + door.PrimaryPart.Position)

			if delta <= 0 then
				run_service:UnbindFromRenderStep(id)
			end
		end)
	end)
	
	recieve_broken_glass:connect(function(part)
		print('rasclart')
		local w1 = Instance.new('WedgePart')
		local w2 = Instance.new('WedgePart')

		w1.Size = part.Size
		w2.Size = part.Size

		w1.Transparency = part.Transparency
		w2.Transparency = part.Transparency

		w1.BrickColor = part.BrickColor
		w2.BrickColor = part.BrickColor

		w1.Velocity = workspace.CurrentCamera.CFrame.lookVector * 20
		w2.Velocity = workspace.CurrentCamera.CFrame.lookVector * 20

		w1.Parent = workspace
		w2.Parent = workspace
	
		w1.CFrame = part.CFrame
		w2.CFrame = part.CFrame * CFrame.Angles(math.rad(180),0,0)
		
		

		part:Destroy()

	end)
	
	function leave_casing()
		local gun = _replicated_storage.Gun
	end
	

	
	workspace.Flashbang.ChildAdded:connect(function(flashbang)
		if (flashbang.Position-_character.Torso.Position).Magnitude < 15 then
			_character.Humanoid.WalkSpeed = 4
			_ui.Visible = false
			for i = 0,1,.1 do
				game.Lighting.ColorCorrection.Brightness = i
				run_service.RenderStepped:wait() -- sorry
			end
			wait(math.random(3,5))
			for i = 1,0,-0.01 do
				game.Lighting.ColorCorrection.Brightness = i
				run_service.RenderStepped:wait() -- sorry
			end
			_character.Humanoid.WalkSpeed = 16
			_ui.Visible = true
		end
	end)
	
	run_service:BindToRenderStep('Game logic',170,function()
		if has_bag and has_bag.Name == 'Interactive_Bag_ThermalBag' then
			if not picked_up_thermalbag then
				picked_up_thermalbag = tick()
			else
				local brightness = math.sin(picked_up_thermalbag-tick())/3 + 0.5
				workspace.Interactive.VaultArea.Transparency = brightness
			end
		elseif (has_bag and has_bag.Name:find('MoneyBag')) or picked_up_money_bag then
			if not picked_up_money_bag then
				picked_up_money_bag = tick()
			end
			local brightness = math.sin(picked_up_money_bag-tick())/3 + 0.5
			workspace.Interactive.BagArea.Transparency = brightness
		elseif picked_up_thermalbag then
			--('dr0pped baggio')
			picked_up_thermalbag = nil
			workspace.Interactive.VaultArea.Transparency = 1
		end
	end)
end















--@weapon module
do

	local dest_env = event.new('player shoot')
	local break_light = event.new('Broke light')
	local shatter_glass = event.new('Broke glass')
	

	local function shoot()
		--if not reloading then
			if weapon.clip > 0 then
				local ray =  Ray.new(_character.Torso.Gun.Part1.Position,_character.Torso.Gun.Part1.CFrame.lookVector*-300)
				local hit,pos,norm = workspace:FindPartOnRayWithIgnoreList(ray,{_character})

				if hit then
					if(hit:IsDescendantOf(workspace.walls) or hit:IsDescendantOf(workspace.Broken)) and hit.Material == Enum.Material.Concrete then
						dest_env:fire(hit,pos,norm)
					elseif hit:IsDescendantOf(workspace.Lights) then
						break_light:fire(hit)
					elseif math.floor(hit.Transparency)~=hit.Transparency and (math.min(hit.Size.X,hit.Size.Y,hit.Size.Z) <= 1.5) then
						print('brapalap')
						shatter_glass:fire(hit)
						
					end
				end
				

				print('buss da skeng!')
				weapon.clip = weapon.clip-1
				recoil(player_animation)
			else
				weapon.reload()
			end
		--end
	end

	local function reload()
		reloading = true
		print('reloading')
		wait(2)
		weapon.clip = weapon.full_clip
		reloading = false
	end

	local function run(key_up)
		if key_up then
			_humanoid.WalkSpeed = 20
			sprint = true
			run_animation('Run',player_animation)
		else
			_humanoid.WalkSpeed = 16
			sprint = false
			run_animation('Hipfire',player_animation)
		end
	end

	local function aim(aim)
		if aim then
			is_aiming = true
			run_animation('Aim',player_animation)
		else
			is_aiming = false
			run_animation('Hipfire',player_animation)
		end
	end
	
	local is_shooting

	local function shoot_semi(key_up)
		if key_up then
			shoot()
		end
	end

	primary_weapon = {}
	primary_weapon.full_clip = 13
	primary_weapon.clip = 13

	primary_weapon.shoot = shoot_semi
	primary_weapon.run = run
	primary_weapon.reload = reload
	primary_weapon.aim = aim

	weapon = primary_weapon
end

















--input module
do
	user_input_service.InputBegan:connect(function(input)
		if _character and _character:FindFirstChild("Humanoid") then
			if not casing_mode then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.R then
						weapon.reload()
					elseif input.KeyCode == Enum.KeyCode.LeftShift then
						_humanoid.WalkSpeed = 20
						sprinting = true
						run_animation('Run',player_animation)
					elseif input.KeyCode == Enum.KeyCode.E then
						--weapon_module.change_weapon()
					elseif input.KeyCode == Enum.KeyCode.One then
						--weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Two then
						--weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Q then
						if not sprinting and not reloading then
							weapon.aim(not is_aiming)
							print('MEH HAFFI AIM')
						end
					elseif input.KeyCode == Enum.KeyCode.F then
						interact_proxy(interact_time,'F')
					elseif input.KeyCode == Enum.KeyCode.G then
						attempt_drop()
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					if not reloading then
						weapon.shoot(true)
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					if not sprinting and not reloading then
						weapon.aim(true)
					end
				end
			elseif input.KeyCode == Enum.KeyCode.G then
				_ui.OnscreenInteract.Visible = false
				casing_mode = false
				local gun = game.ReplicatedStorage.Assets.WeaponGun:Clone()
				gun.Parent = workspace
				local gun_weld = _character.Torso.Gun
				gun_weld.Part1 = gun
				gun.Name = 'Gun'
				--animation.run(_character,'hipfire')
				if workspace.Interactive:FindFirstChild("Interactive_Bag_ThermalBag") then
					ui_logic['Objectives']:fire("Get the thermal drill bag")
				end
			end
		end
	end)
	
	user_input_service.InputEnded:connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.LeftShift then
				sprinting = false
				_humanoid.WalkSpeed = 16
				run_animation('Hipfire',player_animation)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			--('EEEEE I SWEAR TO GOD WHY DOESNT THIS FIRE')
			shooting = false
			run_service:UnbindFromRenderStep('Shoot')
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if is_aiming then
				weapon.aim(false)
			end
		end
	end)
end















--@ui module
do
	local police_assault = event.new('police assault')
	local narration = event.new('narration')
	local downed = event.new('downed')
	
	local ui = {}
	
	function ui.new(name,func)
		local curr_event = event.new()
		event.new(name):connect(curr_event)
		ui_logic[name] = curr_event
		ui_logic[name]:connect(func)
	end
	
	local last_open
	local last_narration
	local blur
	
	ui.new('Objectives',function(objectives)
		if objectives then
			local time = tick()
			last_open = time
			_ui.Objectives.Frame:TweenSize(UDim2.new(0,0,0,60),'Out','Sine',.5)
			wait(2)
			_ui.Objectives.Frame.TextLabel.Text = ' '..objectives:upper()
			if last_open == time then
				_ui.Objectives.Frame:TweenSize(UDim2.new(0,550,0,60),'Out','Sine',.5)
			end
		else
			_ui.Objectives.Frame:TweenSize(UDim2.new(0,0,0,60),'Out','Sine',.5)
			wait(.5)
			_ui.Objectives.Frame.TextLabel.Text = ''
		end
	end)
	
	ui.new('Police Assault',function(val,...)
		
		if val then
			_ui.PoliceAssault.Frame:TweenSize(UDim2.new(0,-550,0,60),'Out','Sine',.5)
		else
			_ui.PoliceAssault.Frame:TweenSize(UDim2.new(0,0,0,60),'Out','Sine',.5)
		end
	end)
	
	ui.new('Downed',function(is_downed)
		--(is_downed)
		if is_downed then
			_humanoid.WalkSpeed = 0
			blur = true
			local amount = game.Lighting.Bluri.Size^2
			for i,v in pairs(_ui:GetChildren()) do
				v.Visible = false
			end
			_ui.DownedUI.Visible = true
			run_service:BindToRenderStep('BlurCamera',Enum.RenderPriority.Camera.Value-10,function()
				if (amount >= 10*60) or (not blur) then
					--('stop!!!!!!')
					run_service:UnbindFromRenderStep('BlurCamera')
				end
				game.Lighting.ColorCorrection.Saturation = -math.atan(math.sqrt(amount)/5)/math.pi
				game.Lighting.Blur.Size = math.sqrt(amount)
				amount = amount + 1
			end)
		else
			_humanoid.WalkSpeed = 16
			local finish
			blur = false
			local amount = game.Lighting.Blur.Size^2
			run_service:BindToRenderStep('UnblurCamera',Enum.RenderPriority.Camera.Value-10,function()
				if blur or amount == 0 then
					finish = true
					run_service:UnbindFromRenderStep('UnblurCamera')
				end
				game.Lighting.ColorCorrection.Saturation = -math.atan(math.sqrt(amount)/5)/math.pi
				game.Lighting.Blur.Size = math.sqrt(amount)
				amount = math.max(amount - 6,0)
			end)
			repeat wait() until finish
			wait(.2)
			for i,v in pairs(_ui:GetChildren()) do
				v.Visible = true
			end
			_ui.DownedUI.Visible = false
		end
	end)
	
	ui.new('Time',function()
		local start = tick()
		spawn(function()
			while wait(1) do
				local sec,min = tostring(math.floor((tick()-start)%60)),tostring(math.floor((tick()-start)/60))
				sec = string.rep('0',(2-#sec))..sec
				_ui.Time.Text = min..':'..sec
			end
		end)
	end)
	
	local function load_number(text_label,prefix,number)
		local start = tick()
		run_service:BindToRenderStep('Load number '..text_label.Name,199,function()
			local delta = tick()-start
			if delta <= 1 then
				text_label.Text = prefix..math.floor(number * delta)
			else
				text_label.Text = prefix..math.floor(number)
				run_service:UnbindFromRenderStep('Load number '..text_label.Name)
			end
		end)
		repeat wait() until (tick()-start) >= 1 -- yields once the loop b4 yields
	end
	
	ui.new('End screen',function(total_money,heisters_in_custody,civilians_killed,stealthed)
		if total_money == 0 then
			--_interface.HeistCompleted.Completed.BackgroundColor3 = Color3.fromRGB(185, 0, 19)
			_interface.HeistCompleted.Completed.Text.Text = 'HEIST FAILED'
		end
		local stealth_bonus = 0
		if stealthed then
			stealth_bonus = total_money  * .2
		end
		local result =math.max((total_money + stealth_bonus) - ((heisters_in_custody * 5000) + (civilians_killed * 1000)),0)
		print(result,total_money,((heisters_in_custody * 5000) + (civilians_killed * 1000)))
		
		
		_ui.Visible = false
		wait(1)
		_interface.HeistCompleted.Visible = true
		
		_interface.HeistCompleted.Custody.Text.Text = 'HEISTERS IN CUSTODY x'..heisters_in_custody
		_interface.HeistCompleted.Civilians.Text.Text = 'CIVILIANS KILLED x'..civilians_killed
		
		load_number(_interface.HeistCompleted.Stolen.Value,'$',total_money)
		load_number(_interface.HeistCompleted.Bonus.Value,'$',stealth_bonus)
		
		load_number(_interface.HeistCompleted.Civilians.Value, '-$', (civilians_killed * 1000))
		load_number(_interface.HeistCompleted.Custody.Value, '-$',(heisters_in_custody * 5000))
		load_number(_interface.HeistCompleted.Total.Value,'$',result)
	end)
	
	local function relay(...)
		 return ... 
	end
	
	ui_logic['Time']:fire()
	
	police_assault:condition(ui_logic['Police Assault'],relay)
	downed:condition(ui_logic['Downed'],function(char,is_downed)
		if (char) == _character then -- if its meeee
			return is_downed
		end
	end)
end