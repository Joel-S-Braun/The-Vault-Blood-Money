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

for i,v in pairs(workspace.SWAT:GetChildren()) do
	Instance.new('Humanoid',v)
end

workspace.SWAT.ChildAdded:connect(function(x)
	Instance.new('Humanoid',x)
end)


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



------- add SHIT FOR PSEUDO CHARS




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















--@animation module
do

end
--('animation module has loaded')



















--@pseudocharacter module
do
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
	
end











--@gamelogic
do
	local picked_up_thermalbag
	local picked_up_money_bag
	
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















--input module
do
	user_input_service.InputBegan:connect(function(input)
		if local_player.Character and local_player.Character:FindFirstChild("Humanoid") then
			if not casing_mode then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.R then
						weapon_module.reload()
					elseif input.KeyCode == Enum.KeyCode.LeftShift then
						--weapon_module.sprint(true)
						--repeat wait() until local_player.Character.Torso.Velocity.Magnitude < 1
						--weapon_module.sprint(false)
					elseif input.KeyCode == Enum.KeyCode.E then
						--weapon_module.change_weapon()
					elseif input.KeyCode == Enum.KeyCode.One then
						--weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Two then
						--weapon_module.change_weapon('primary')
					elseif input.KeyCode == Enum.KeyCode.Q then
						--weapon_module.ADS(not is_aiming)
					elseif input.KeyCode == Enum.KeyCode.F then
						interact_proxy(interact_time,'F')
					elseif input.KeyCode == Enum.KeyCode.G then
						attempt_drop()
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					--[[if weapon_module.current_weapon_data.semi_auto then
						--weapon_module.shoot()
					elseif weapon_module.current_weapon_data.burst then
						if (burst_debounce or 0) <= tick() then
							for i = 1,weapon_module.current_weapon_data.burst do
								wait()
								--weapon_module.shoot()
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
							--('i swear to allah',shooting)
							if not shooting then
								run_service:UnbindFromRenderStep('Shoot')
							end
							if shooting then
								if (tick()-last_fired) >= interval then
									last_fired = tick()
									--weapon_module.shoot()
								end
							end
						end)
					end]]
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					--weapon_module.ADS(true)
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
				--weapon_module.sprint(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			--('EEEEE I SWEAR TO GOD WHY DOESNT THIS FIRE')
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
		if get_obj(char) == _character then -- if its meeee
			return is_downed
		end
	end)
end