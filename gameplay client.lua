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
local remote_functions

local anim_render_dist = 90
local movement_render_dist = 150
local rot_constraint = 20
local user_input_service = game:GetService('UserInputService')
local local_player = game.Players.LocalPlayer

local burst_debounce
local primary_weapon,secondary_weapon
local has_bag
local interacting
local is_aiming
local idle_gun
local reloading
local shooting
local tutorial_mode = true
local casing_mode = true

local function round(num) -- for that pesky fpp
	return math.floor(num*12)/12
end


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


---------------------------------------------------------------------------------------------------------------------------------------------------
walk = 
{
	animation = require(script.Walk),
	priority = 2,
	interp_time = .2,
	states={} -- states can be used for reloading, for instance; a state being clip_available, which would be linked to an event to replace the clip
}

aim = 
{
	animation = require(script.Aim),
	priority = 6,
	interp_time = .1,
	states={}
}

falling = 
{
	animation = require(script.Falling),
	priority = 3,
	interp_time = .2,
	states={}
}

idle = 
{
	animation = require(script.Idle),
	priority = 1,
	interp_time = .2,
	states={}
}

hipfire = 
{
	animation = require(script.Hipfire),
	priority = 5,
	interp_time = .1,
	states={}
}

---------------------------------------------------------------------------------------------------------------------------------------------------



for i,v in pairs(workspace.Enemys:GetChildren()) do
	v.ChildAdded:connect(function(v)
		Instance.new('Humanoid',v)
	end)
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
















--@animation module
do
	function animation.compile(anim)
		local length = 0
		for index,keyframe in pairs(anim.animation) do
			length = length + keyframe.time
		end
		
		anim.length = length + anim.interp_time
		
		function anim:get_keyframe(time,loop) -- first keyframe must be same as last keyframe for true loop
			if loop then
				time = time % anim.length
			elseif time > anim.length then
				return #anim.animation-1,#anim.animation,1,'terminate'
			end
			if time <= 0 then
				warn("Attempted to get a keyframe either below or equal to 0")
				time = 0.000001
			end
			local curr_len = 0
			for key,keyframe in pairs(anim.animation) do
				curr_len = curr_len + keyframe.time
				if curr_len >= time then
					local start_time = curr_len-keyframe.time
					
					local delta = (time - start_time) / keyframe.time
					return key-1,key, delta
				end
			end
		end
	end
	
	animation.compile(walk)
	animation.compile(aim)
	animation.compile(falling)
	animation.compile(idle)
	animation.compile(hipfire)
	
	run_service:BindToRenderStep("Animation calulation",198,function()
		weld_status = {} -- idk if this'll reduce GC spam or increase it lol
		for object,animations in pairs(running_animations) do
			local animation_output = {} -- the CFrame data compiled from all animations for each object in 1 table, will be used to modify objects weld stuff to animate, {cframe,priority}
			for animation_name,data in pairs(animations) do
				local start_time = data.start_time
				local real_animation = getfenv()[animation_name]
				local curr_time = (tick()-start_time)
				if curr_time%real_animation.length <= real_animation.interp_time then
					if current_keyframe[object:GetFullName()][animation_name] ~= 1 then
						current_keyframe[object:GetFullName()][animation_name] = 1
						if real_animation.states[1] then
							for i,v in pairs(real_animation.states[1]) do
								v()
							end
						end
					end
					if curr_time > real_animation.interp_time then
						animation_start[object:GetFullName()][animation_name] = real_animation.animation[#real_animation.animation].joints
					end
					local start,finish,delta = animation_start[object:GetFullName()][animation_name],real_animation.animation[1].joints,(curr_time % real_animation.length)/(real_animation.interp_time)
					for joint_name,value in pairs(finish) do
						data = {cframe=start[joint_name]:lerp(value,delta),priority=real_animation.priority}
						
						if not animation_output[joint_name] then
							animation_output[joint_name] = {cframe=start[joint_name]:lerp(value,delta),priority=real_animation.priority,kek=delta}
						elseif animation_output[joint_name].priority <= real_animation.priority then
							animation_output[joint_name] = {cframe=start[joint_name]:lerp(value,delta),priority=real_animation.priority}
						end
					end
				else
					
					local start_key,end_key,delta,terminate = real_animation:get_keyframe((tick()-start_time) - real_animation.interp_time,data.looped)
					
					if current_keyframe[object:GetFullName()][animation_name] ~= end_key then
						current_keyframe[object:GetFullName()][animation_name] = end_key
						if real_animation.states[end_key] then
							for i,v in pairs(real_animation.states[end_key]) do
								v()
							end
						end
					end
					for joint_name,value in pairs(real_animation.animation[start_key].joints) do
						if not animation_output[joint_name] then
							local bossman_remedy =value:lerp(real_animation.animation[end_key].joints[joint_name],delta) -- danm i was tired when i wrote this LMAO
							animation_output[joint_name] = 
							{cframe=bossman_remedy,priority=real_animation.priority,special_id = 'aliens are modifing'}
						elseif animation_output[joint_name].priority <= real_animation.priority then							
							local cframe = real_animation.animation[start_key].CFrame:lerp(real_animation.animation[end_key],delta)
							if joint_name == 'Left Leg' then
								print(cframe,'wun')
							end
							animation_output[joint_name] = {priority=real_animation.priority,cframe=cframe}
						end
					end
					
					if terminate then
						running_animations[object][animations] = nil -- terminates animation
						--run_service:UnbindFromRenderStep("Render "..object:GetFullName())
					end
				end
			end
			for obj,output in pairs(animation_output) do
				if obj == 'Left Leg' then
				end
				animation_output[obj] = output.cframe
			end
			weld_status[object:GetFullName()] = animation_output
		end
	end)
	
	function animation.run(object,animation,looped,pseudo)
		current_keyframe[object:GetFullName()] = current_keyframe[object:GetFullName()] or {}
		current_keyframe[object:GetFullName()][animation] = current_keyframe[object:GetFullName()][animation] or 1
		local strt = {}
		if not pseudo then
			for _,object in pairs(object.Torso:GetChildren()) do
				if object:IsA("Motor6D") then
					strt[object.Name] = object.C1
				end
			end
		else
			for _,obj in pairs(object:GetChildren()) do
				if obj:IsA("BasePart") then
					strt[obj.Name] =  object.Torso.CFrame:toObjectSpace(obj.CFrame)
				end
			end
		end
		animation_start[object:GetFullName()] = animation_start[object:GetFullName()] or {}
		animation_start[object:GetFullName()][animation] = strt
		
		if not running_animations[object] then
			running_animations[object] = {}
		end
		running_animations[object][animation] = {start_time=tick(),looped=looped,pseudo=pseudo}
		run_service:BindToRenderStep("Render "..object:GetFullName(),199,function()
			local output = weld_status[object:GetFullName()]
			for specific_obj,cframe in pairs(output) do
				if not pseudo then
					object.Torso:FindFirstChild(specific_obj).C1 = cframe
				else
					local c0 = _assets.PlayerModel.Torso[specific_obj].C0
					if specific_obj == 'Right Arm' or specific_obj == 'Left Arm' then
						c0 = c0 + Vector3.new(0,1,0)
					end
					object:FindFirstChild(specific_obj).CFrame = object.Torso.CFrame * c0 * cframe:inverse()
				end
			end
		end)
	end
	
	local run_anim = event.new('server run animation')
	local end_anim = event.new('server end animation')
	
	event.new('run animation'):connect(function(char,anim,looped,pseudo)
		animation.run(char,anim,looped,pseudo)
	end)
	
	event.new('stop animation'):connect(function(char,anim)
		running_animations[get_obj(char)][anim] = nil
		run_service:UnbindFromRenderStep('Render '..char)
	end)
end
--('animation module has loaded')



















--@pseudocharacter module
do
	
	event.new('move'):connect(function(char,start,finish)
		local offset = (finish-start)
		local magnitude
		if offset.Y < 0 then
			magnitude = (offset/Vector3.new(16,120,16)).Magnitude
		else
			magnitude = (offset/Vector3.new(1,1,1)).Magnitude
		end
		
		start,finish = CFrame.new(start),CFrame.new(finish)
		
		local angle = CFrame.Angles(0,math.atan2(-offset.X,-offset.Z),0)
		
		pseudo_char_interp[char] = {start=start,finish=finish,start_time=tick(),length=magnitude,angle=angle}
		local real_char = get_obj(char)
		
		animation.run(real_char,'walk',true,true)
		
		run_service:BindToRenderStep('Move'..char,197,function()
			real_char:SetPrimaryPartCFrame(pseudo_char_output[char])
		end)
		
	end)
	
	run_service:BindToRenderStep('Pseudo Charculations',196,function() -- lol
		for char,data in pairs(pseudo_char_interp) do
			local delta = (tick() - data.start_time)/data.length
			if delta > 1 then
				pseudo_char_interp[char] = nil
				run_service:UnbindFromRenderStep('Move '..char)
				running_animations[get_obj(char)]['walk'] = nil
				run_service:UnbindFromRenderStep('Render '..char)
			else
				pseudo_char_output[char] = data.start:lerp(data.finish,delta) * data.angle
			end
		end
	end)
end
--('pseudocharacter module loaded')



















--@interacion module
do
	
	local interact = event.new('interact')

	local function get_interactive_data(model_name)
		local is_interactive,class,name
		local i = 0
		for w in string.gmatch(model_name,'%w+') do
			i = i + 1
			if i == 1 and w == 'Interactive' then
				is_interactive=true
			elseif i == 2 then
				class = w
			elseif i == 3 then
				name=w
			end
		end
		return is_interactive,class,name
	end

	local function is_interactive(obj)
		if obj and obj.Parent then
			local is_interactive,class,name = get_interactive_data(obj.Name)
			if is_interactive then
				return _network.RemoteFunction:InvokeServer('interactive',class,obj.Name)
			end
		end
	end
	
	local last_mouse_hit = workspace.Map.Baseplate
	local mouse = game.Players.LocalPlayer:GetMouse()
	local global_class,name,interactive_data
	
	local interact_ui = local_player.PlayerGui.UI.Interact
	
	run_service:BindToRenderStep('Interaction',160,function()
		if not casing_mode then
			local target = mouse.Target or workspace.Map.Baseplate
			if target and not interacting then  
				if ((last_mouse_hit):GetFullName() ~= target:GetFullName()) then
					--(last_mouse_hit.Name)
					local interactive,class,name=get_interactive_data(target.Name)
					local set_parent
					if not interactive and target.Parent ~= workspace.Interactive and target.Parent ~= game then
						interactive,class,name = get_interactive_data(target.Parent.Name)
						target = target.Parent
					end
					--(interactive,class,name,'lewisham tesco')
					if interactive then
						--('let a man float')
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
			local_player.Character.Humanoid.WalkSpeed = 0
			for i = 0,1,(1/60) /time do
				interact_ui.Text.Frame.Size = UDim2.new(i,0,1,0)
				run_service.RenderStepped:wait()
				if (not user_input_service:IsKeyDown(Enum.KeyCode[key])) and true then
					interact_ui.Text.Frame.Size = UDim2.new(0,0,1,0)
					local_player.Character.Humanoid.WalkSpeed = 16
					interacting = false
					return
				end
			end
			interact_ui.Text.Frame.Size = UDim2.new(0,0,1,0)
			interact_ui.Enabled = false
			interact_ui.Adornee = nil
			name = last_mouse_hit.Name
			interact:fire(global_class,name)
			if global_class == 'Bag' then
				has_bag = last_mouse_hit
			end
			
			local_player.Character.Humanoid.WalkSpeed = 16
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
			interact:fire('Bag',has_bag.Name);
			has_bag = nil
		end
	end
end

























local weapon_module = {}
do
	local _weapons = _replicated_storage.Weapons
	
	local secondary_weapon,meleee -- strings
	local secondary_attachments,primary_data,secondary_data -- tables
	
	--load gun
	do
		primary_weapon = 'AK'
		primary_attachments={Sight='Scope_MediumRange',Barrel='Compensator'}
		secondary_weapon = 'DE'
		secondary_attachments = {Sight='Scope_MediumRange',Barrel='Compensator'}
		melee = 'Knife'
	end
	
	-- load weapon
	do
		local obj_type=type
		local function load_weapon(weapon_name,attachment,type)
			local weapon = _weapons[type][weapon_name]:Clone()
			weapon.Parent = _replicated_storage
			
			local weapon_stats = require(weapon.data)
			weapon.data:Destroy()
			
			for node,attachment in pairs(attachment) do
				local real_node = weapon:FindFirstChild(node)
				if real_node then
					local real_attachment = game.ReplicatedStorage.Weapons[type]:FindFirstChild(attachment)
					if real_attachment then
						real_attachment = real_attachment:Clone()
						real_attachment.PrimaryPart = real_attachment[node]
						real_attachment:SetPrimaryPartCFrame(real_node.CFrame)
						real_attachment.PrimaryPart:Destroy()
						real_node:Destroy()
						for index,value in pairs(require(real_attachment.data)) do
							if weapon_stats[index] and obj_type(weapon_stats[index])=='number' then
								weapon_stats[index] = weapon_stats[index]+value
							else
								weapon_stats[index]=value
							end
						end
						real_attachment.data:Destroy()
						for _,part in pairs(real_attachment:GetChildren()) do
							part.Parent = weapon
						end
						real_attachment:Destroy()
					else
						error('Attachment '..attachment..' does not exist')
					end
				else
					error('Node '..node..' does not exist on '..weapon.Name)
				end
			end
			return weapon,weapon_stats
		end
		
		primary_weapon,primary_data = load_weapon(primary_weapon,primary_attachments,'Primary')
		secondary_weapon,secondary_data = load_weapon(secondary_weapon,secondary_attachments,'Secondary')
	end
	
	primary_data.full_ammo = primary_data.ammo
	secondary_data.full_ammo = secondary_data.ammo
	

	weapon_module.current_weapon = secondary_weapon
	weapon_module.current_weapon_data = secondary_data
	weapon_module.current_type = 'secondary'
	
	-- secondary_weapon.Name
	
	function weapon_module.ADS(is_ads)
		if not reloading then
			is_aiming = is_ads
			local current_fov = workspace.CurrentCamera.FieldOfView
			local start = tick()
	
			if is_ads then
				animation.run(_character,'aim',true)
				running_animations[_character]['hipfire'] = nil
				local offset = workspace.CurrentCamera.FieldOfView - weapon_module.current_weapon_data.ads_fov
				run_service:BindToRenderStep("Aim",130,function()
					local delta = (tick()-start) / .1
					workspace.CurrentCamera.FieldOfView = current_fov - (offset * delta)
					if delta >= 1 then
						run_service:UnbindFromRenderStep("Aim")
					end
				end)
			else
				animation.run(_character,'hipfire',true)
				running_animations[_character]['aim'] = nil
				local offset = 70-weapon_module.current_weapon_data.ads_fov
				run_service:BindToRenderStep("Aim",130,function()
					local delta = (tick()-start) / .1
					workspace.CurrentCamera.FieldOfView = current_fov + (offset * delta)
					if delta >= 1 then
						run_service:UnbindFromRenderStep("Aim")
					end
				end)
			end
		end
	end
	
	function weapon_module.reload()
		if is_aiming then
			weapon_module.ADS(false)
		end
		if weapon_module.current_weapon_data.clip - 1 ~= 0 then
			reloading = true
			wait(weapon_module.current_weapon_data.reload_time)
			reloading = false
			weapon_module.current_weapon_data.ammo = weapon_module.current_weapon_data.full_ammo
			weapon_module.current_weapon_data.clip = weapon_module.current_weapon_data.clip - 1
		end
	end
	
	function weapon_module.shoot()
		if weapon_module.current_weapon_data.ammo ~= 0 then
			local accel = 2
			local angle = CFrame.Angles(math.rad(2),0,math.rad(math.random(-10,10)/10))
			run_service:BindToRenderStep("Recoil",201,function()
				print(accel)
				if accel == 0 then
					accel = accel - .2
				else
					accel = accel - .8
				end
				if accel <= -.3 then
					run_service:UnbindFromRenderStep("Recoil")
				end
				local cam_offset = CFrame.new(0,0,0):lerp(angle,accel)
				offset = cam_offset:lerp(CFrame.new(),.2)
				workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame  * cam_offset
			end)
			weapon_module.current_weapon_data.ammo = weapon_module.current_weapon_data.ammo-1
		else
			weapon_module.reload()
		end
	end
	
	
	
	function weapon_module.sprint(start)
		local walkspeed = 16
		if start then
			--start run anim
			walkspeed = weapon_module.current_weapon_data.sprint_speed
		end
		local_player.Character.Humanoid.WalkSpeed = walkspeed
	end
	
	function weapon_module.change_weapon(weapon)
		-- switch gun anim
		if not weapon then
			weapon = ({primary='secondary',secondary='primary'})[weapon_module.current_type]

			if weapon == 'primary' then
				weapon_module.current_weapon = primary_weapon
				weapon_module.current_weapon_data = primary_data
			else
				weapon_module.current_weapon = secondary_data
				weapon_module.current_weapon_data = secondary_data
			end
			weapon_module.current_type = weapon
		end
	end
	
	local c0,c1 = _character.Torso.Head.C0,_character.Torso.Head.C1
	
	run_service:BindToRenderStep('Weapon render',210,function()
		local offset = offset or CFrame.new(0,0,0)
		for _,limb in pairs(_character:GetChildren()) do
			if limb:IsA("BasePart") and limb.Name ~= 'Head' then
				limb.LocalTransparencyModifier = 0
			end
			local vector = workspace.CurrentCamera.CFrame.lookVector
			if not casing_mode and not idle_gun then
				_character.Torso.Head.C0 = CFrame.Angles(math.atan2(vector.Y,math.sin(math.acos(vector.Y))),0,0) * offset  + Vector3.new(0,1.5,0)
				_character.Torso.Head.C1 = CFrame.new(0,0,0)
			else
				_character.Torso.Head.C0,_character.Torso.Head.C1 = c0,c1
			end
		end
	end)
	
end

animation.run(_character,'walk',true)











--@gamelogic
do
	local picked_up_thermalbag
	local picked_up_money_bag
	
	function leave_casing()
		local gun = _replicated_storage.Gun
	end
	
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















--input module
do
	user_input_service.InputBegan:connect(function(input)
		if local_player.Character and local_player.Character:FindFirstChild("Humanoid") then
			if not casing_mode then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.R then
						weapon_module.reload()
					elseif input.KeyCode == Enum.KeyCode.LeftShift then
						weapon_module.sprint(true)
						repeat wait() until local_player.Character.Torso.Velocity.Magnitude < 1
						weapon_module.sprint(false)
					elseif input.KeyCode == Enum.KeyCode.E then
						weapon_module.change_weapon()
					elseif input.KeyCode == Enum.KeyCode.One then
						weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Two then
						weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Q then
						weapon_module.ADS(not is_aiming)
					elseif input.KeyCode == Enum.KeyCode.F then
						interact_proxy(interact_time,'F')
					elseif input.KeyCode == Enum.KeyCode.G then
						attempt_drop()
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					if weapon_module.current_weapon_data.semi_auto then
						weapon_module.shoot()
					elseif weapon_module.current_weapon_data.burst then
						if (burst_debounce or 0) <= tick() then
							for i = 1,weapon_module.current_weapon_data.burst do
								wait()
								weapon_module.shoot()
							end
							burst_debounce = tick() + 60/weapon_module.current_weapon_data.rate_of_fire
						end
					else
						local rate_of_fire = weapon_module.current_weapon_data.rate_of_fire
						local interval = 60/rate_of_fire
						weapon_module.shoot()
						local last_fired = tick()
						shooting = true
						run_service:BindToRenderStep('Shoot',195,function()
							print('i swear to allah',shooting)
							if not shooting then
								run_service:UnbindFromRenderStep('Shoot')
							end
							if shooting then
								if (tick()-last_fired) >= interval then
									last_fired = tick()
									weapon_module.shoot()
								end
							end
						end)
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					weapon_module.ADS(true)
				end
			elseif input.KeyCode == Enum.KeyCode.G then
				_ui.OnscreenInteract.Visible = false
				casing_mode = false
				local gun = game.ReplicatedStorage.Assets.WeaponGun:Clone()
				gun.Parent = workspace
				local gun_weld = _character.Torso.Gun
				gun_weld.Part0 = _character['Right Arm']
				gun_weld.Part1 = gun
				gun.Name = 'Gun'
				animation.run(_character,'hipfire')
				if workspace.Interactive:FindFirstChild("Interactive_Bag_ThermalBag") then
					ui_logic['Objectives']:fire("Get the thermal drill bag")
				end
			end
		end
	end)
	
	user_input_service.InputEnded:connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.LeftShift then
				weapon_module.sprint(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			print('EEEEE I SWEAR TO GOD WHY DOESNT THIS FIRE')
			shooting = false
			run_service:UnbindFromRenderStep('Shoot')
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
			if delta < 1 then
				text_label.Text = prefix..math.floor(number * delta)
			else
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
		local result =math.max(total_money + stealth_bonus - ((heisters_in_custody * 5000) + (civilians_killed * 1000)),0)
		
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
		if get_obj(char) == _character then -- if its meeee
			return is_downed
		end
	end)
end
