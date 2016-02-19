--[[
	@1/1/16
	
	@vectormodule
	@networkmodule
	@event-module
	@colour-module
	@load-module
--]]

local run_service = game:GetService('RunService')
local local_player = game.Players.LocalPlayer
local starter_gui = game.StarterGui
local player_gui = local_player:WaitForChild('PlayerGui')
local lobby_gui = starter_gui.LobbyGui:Clone()
lobby_gui.Parent = player_gui

local _replicated_storage = game.ReplicatedStorage
local _network = _replicated_storage.Network

workspace.CurrentCamera.CameraType = 6
workspace.CurrentCamera.CoordinateFrame = CFrame.new(
	-55.5601311, 7.1210412, 20.1081375, 
	0.469456315, 0.172260368, -0.839931607, 
	7.45058149e-09, 0.951272726, 0.30835107, 
	0.88295579, -0.14475736, 0.446580946)

local load = {}
local colour = {}
local network = {}
local vector = {}
local button_id = {}
local event_id = {}
local event = {}
local remote_functions = {}

local loadout_type = 'Primary'

local color_off = Color3.new(13/255,13/255,13/255)
local color_on = Color3.new(40/255,40/255,40/255)
local color_highlight = Color3.new(37/255,37/255,37/255)
local color_black = Color3.new(0,0,0)

local function fnil() end
local function switch(input)
	return function(self) return self[input] or self['default'] or fnil end
end














--@vector-module
do
	local col = Color3.new
	
	function vector.to_color3(vec)
		return col(vec.X,vec.Y,vec.Z)
	end
end














--@network-module
do
	local connect = {}
	
	_network.RemoteEvent.OnClientEvent:connect(function(name,...)
		for _,v in pairs(connect[name] or {}) do
			v(...)
		end
	end)
	
	function network.invoke(...)
		return _network.RemoteFunction:InvokeServer(...)
	end
	
	function network.get_event(name)
		return unpack(network.invoke('get_event',name))
	end
	
	function network.connect(name,func)
		connect[name] =  {} or connect[name]
		connect[tostring(func)] = func
		return function()
			connect[tostring(func)] = nil
		end
	end
end

















--@event-module
do
	remote_functions['get_event'] = function(name)
		for i,v in pairs(event_id) do
			if v.name == name then
				return v.value
			end
		end
	end
	
	function event.new(name)
		local event = {name=name,connections={}}
		
		event_id[tostring(event)] = event
		
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
				print('fired')
				_network.RemoteEvent:FireServer(event.name,...)
			end
			for _,v in pairs(event.connections) do
				v(...)
			end
		end
		
		function event:bind(func)
			run_service.BindToRenderStep(tostring(func)) -- serialised RAM address of function
			return function()
				run_service.UnbindToRenderStep(tostring(func))
			end
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
	
	_network.RemoteFunction.OnClientInvoke = function(name,...)
		return remote_functions[name](...)
	end
end

















--@colour-module
do
	local new_vec = Vector3.new
	local col = Color3.new

	function colour.to_vector3(colour)
		return new_vec(colour.r,colour.g,colour.b)
	end
	
	function colour.lerp(c1,c2,delta)
		return vector.to_color3(colour.to_vector3(c1):lerp(colour.to_vector3(c2),delta))
	end

	function colour.tween(frame,c2,time)
		run_service:UnbindFromRenderStep(frame:GetFullName()) -- in case there was an anim running beforehand
		local time = time or .1
		local c1 = frame.BackgroundColor3
		local base = tick()
		run_service:BindToRenderStep(frame:GetFullName(),Enum.RenderPriority.Camera.Value,function()
			local elapsed_time = (tick()-base)
			local delta = elapsed_time/time
			if delta > 1 then
				delta = 1
				frame.BackgroundColor3 = colour.lerp(c1,c2,delta)
				run_service:UnbindFromRenderStep(frame:GetFullName())
			else
				frame.BackgroundColor3 = colour.lerp(c1,c2,delta)
			end
		end)
	end
end














--@load-module
do
	function load.highlight(button)
		return function() colour.tween(button,color_on,.1) end
	end

	function load.lowlight(button)
		return function() colour.tween(button,color_off,.1) end
	end	

	function load.button(button,switchtable)
		button_id[button:GetFullName()] = switchtable
		button.MouseButton1Up:connect(switch('button-1-up')(switchtable))
		button.MouseButton1Down:connect(switch('button-1-down')(switchtable))
		button.MouseEnter:connect(switch('mouse-enter')(switchtable) or load.highlight(button))
		button.MouseLeave:connect(switch('mouse-leave')(switchtable) or load.lowlight(button))
	end

	
	function get_button_switchtable(button)
		return button_id[button:GetFullName()]
	end

	function load.folder(folder,switchtable)
		switchtable['default'] = {}
		local folderchildren = folder:GetChildren()
		for i = 1,#folderchildren do
			local button = folderchildren[i]
			load.button(button,switch(button.Name)(switchtable))
		end
	end
	
	function load.switch_ui(old,new)
		return function()
			old.Visible = false
			new.Visible = true
			load.off(old)
		end
	end

	function load.off(frame)
		for i,v in pairs(frame:GetChildren()) do
			local switchtable = get_button_switchtable(v)
			if switchtable then
				(switchtable['mouse-leave'] or load.lowlight(v))()
			end
			load.off(v)
		end
	end
	
	item_data = network.invoke('get_item_data')
	
	function load.ui()
		
		local list_updated = event.new('list_updated')
		
		local function list(name,offset)
			local processed = item_data[name]
			if processed then
				local new = {}
				for i = 1,#processed do
					new[i] = processed[((i+offset-1)%#processed)+1]
				end
				item_data[name] = new
				list_updated:fire(item_data)
				return item_data[name][1]
			end
		end
		
		local function crime_net()
			local self = lobby_gui.CrimeNet
			self.Visible = false
			load.folder(self.Options,
				{
					['Menu'] = {
						['button-1-up'] = load.switch_ui(self,lobby_gui.Menu);
					};
				}
			)
		end
		local function edit_party()
			local self = lobby_gui.EditParty
			self.Visible = false
		end
		local function character()
			local self = lobby_gui.Character
			self.Visible = false
			local children = self.Main.Centre.Switches:GetChildren()
			for i = 1,#children do
				local label = children[i]
				label.Text = (item_data[label.Name] or {'none'})[1]:upper()
				
				label.RightArrow.MouseButton1Up:connect(function()
					label.Text = (list(label.Name,1) or 'none'):upper()
				end)
				
				label.LeftArrow.MouseButton1Up:connect(function()
					label.Text = (list(label.List,-1) or 'none'):upper()
				end)
			end
		end
		
		local function loadout()
			local self = lobby_gui.Loadout
			self.Visible = false
			
			local function update()
				local children = self.Main.Centre.Switches:GetChildren()
				for i = 1,#children do
					local label = children[i]
					label.Text = ((item_data[loadout_type..'_'..label.Name] or {'none'})[1] or 'none'):upper()
				end
			end
			
			self.Main.Centre.Primary.MouseButton1Up:connect(function()
				loadout_type = 'Primary'
				colour.tween(self.Main.Centre.Primary,color_highlight,.1)
				colour.tween(self.Main.Centre.Secondary,color_black,.1)
				update()
			end)
			
			self.Main.Centre.Secondary.MouseButton1Up:connect(function()
				loadout_type = 'Secondary'
				colour.tween(self.Main.Centre.Primary,color_black,.1)
				colour.tween(self.Main.Centre.Secondary,color_highlight,.1)
				update()
			end)
			
			self.Main.Centre.Primary.TextLabel.Text = item_data['Primary_Weapon'][1]:upper()
			self.Main.Centre.Secondary.TextLabel.Text = item_data['Secondary_Weapon'][1]:upper()
			
			self.Main.Centre.Primary.Left.MouseButton1Up:connect(function()
				self.Main.Centre.Primary.TextLabel.Text = list('Primary_Weapon',1)
			end)
			self.Main.Centre.Primary.Right.MouseButton1Up:connect(function()
				self.Main.Centre.Primary.TextLabel.Text = list('Primary_Weapon',-1)
			end)
			self.Main.Centre.Secondary.Left.MouseButton1Up:connect(function()
				self.Main.Centre.Secondary.TextLabel.Text = list('Secondary_Weapon',1):upper()
			end)
			self.Main.Centre.Secondary.Right.MouseButton1Up:connect(function()
				self.Main.Centre.Secondary.TextLabel.Text = list('Secondary_Weapon',-1):upper()
			end)
			
			local children = self.Main.Centre.Switches:GetChildren()
			for i = 1,#children do
				local label = children[i]
				local lists = {}
				local function label_list(add)
					return lists[loadout_type..'_list'](add)
				end
				label.Text = ((item_data[loadout_type..'_'..label.Name] or {'none'})[1] or 'none'):upper()
				
				label.RightArrow.MouseButton1Up:connect(function()
					label.Text = (list(loadout_type..'_'..label.Name,1) or 'none'):upper()
				end)
				
				label.LeftArrow.MouseButton1Up:connect(function()
					label.Text = (list(loadout_type..'_'..label.Name,-1) or 'none'):upper()
				end)
			end
	
	
			load.folder(self.Options,
				{
					['Menu'] = {
						['button-1-up'] = load.switch_ui(self,lobby_gui.Menu)
					};
				}
			)
		end
		local function ready_up()
			local self = lobby_gui.ReadyUp
			self.Visible = false
		end
		local function shop()
			local self = lobby_gui.Shop
			self.Visible = false
			load.folder(self.Options,
				{
					['Menu'] = {
						['button-1-up'] = load.switch_ui(self,lobby_gui.Menu)
					};
				}
			)
		end
		local function menu()
			local self = lobby_gui.Menu
			local notification = self.Notification.Text
			local img = self.Notification
			local update = network.get_event('update')
			local update = game.HttpService:JSONDecode(update)
			local number = (('0'):rep(6-#update['Update_Count'])..update['Update_Count'])
			local txt = ''
			for i = 3,8,2 do -- could probably use gmatch but im too lazy
				txt = txt..number:sub(i-2,i-1)..'/' 
			end 
			txt = (txt:sub(1,#txt-1))
			
			self.Notification.Text.UpdateNumber.Text = txt
			self.Notification.Text.Description.Text = update['Update']
			
			self.Visible = true
			load.button(
				self.Notification.ImageButton,
				{
					['mouse-leave'] = function() notification:TweenPosition(UDim2.new(0,75,1.5,0),'Out','Sine',.3,true) colour.tween(img,color_off) end;
					['mouse-enter'] = function() notification:TweenPosition(UDim2.new(-2.5,0,1.5,0),'Out','Sine',.3,true) colour.tween(img,color_on) end;
				}
			)
			local folder = self.Buttons
			load.folder(
				folder,
				{
					['CRIME.NET'] = {
						['mouse-enter'] = function() folder['CRIME.NET'].Facade:TweenPosition(UDim2.new(0,0,0,0),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'].Facade,color_on,.1) end;
						['mouse-leave'] = function() folder['CRIME.NET'].Facade:TweenPosition(UDim2.new(0,0,0,20),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'].Facade,color_off,.1) end;
						['button-1-up'] = load.switch_ui(lobby_gui.Menu,lobby_gui.CrimeNet)
					};
	
					['Shop'] = {
						['mouse-enter'] = function() folder['Shop'].Facade:TweenPosition(UDim2.new(0,0,0,0),'Out','Sine',.2,true) colour.tween(folder['Shop'].Facade,color_on,.1) end;
						['mouse-leave'] = function() folder['Shop'].Facade:TweenPosition(UDim2.new(0,0,0,20),'Out','Sine',.2,true) colour.tween(folder['Shop'].Facade,color_off,.1) end;
						['button-1-up'] = load.switch_ui(lobby_gui.Menu,lobby_gui.Shop)
					};
	
					['Loadout'] = {
						['mouse-enter'] = function() folder['Loadout'].Facade:TweenPosition(UDim2.new(0,0,0,0),'Out','Sine',.2,true) colour.tween(folder['Loadout'].Facade,color_on,.1) end;
						['mouse-leave'] = function() folder['Loadout'].Facade:TweenPosition(UDim2.new(0,0,0,20),'Out','Sine',.2,true) colour.tween(folder['Loadout'].Facade,color_off,.1) end;
						['button-1-up'] = load.switch_ui(lobby_gui.Menu,lobby_gui.Loadout)
					};
	
					['Tutorial'] = {
						['mouse-enter'] = function() folder['Tutorial'].Facade:TweenPosition(UDim2.new(0,0,0,0),'Out','Sine',.2,true) colour.tween(folder['Tutorial'].Facade,color_on,.1) end;
						['mouse-leave'] = function() folder['Tutorial'].Facade:TweenPosition(UDim2.new(0,0,0,20),'Out','Sine',.2,true) colour.tween(folder['Tutorial'].Facade,color_off,.1) end;
					};
	 			
				}
			)
		end
		
		crime_net()
		edit_party()
		loadout	()
		ready_up()
		shop()
		menu()
	end
	load.ui()
end