--[[
	@1/1/16
	
	@vectormodule
	@load-module
	@colour-module
--]]

local _game = game
local run_service = _game:GetService('RunService')
local local_player = game.Players.LocalPlayer
local player_gui = local_player:WaitForChild('PlayerGui')
local lobby_gui = player_gui:WaitForChild('LobbyGui')

workspace.CurrentCamera.CameraType = 6
workspace.CurrentCamera.CoordinateFrame = CFrame.new(-55.5601311, 7.1210412, 20.1081375, 0.469456315, 0.172260368, -0.839931607, 7.45058149e-09, 0.951272726, 0.30835107, 0.88295579, -0.14475736, 0.446580946)

local load = {}
local colour = {}
local vector = {}
local processed_data = { -- formatted version of data stored or maybe raw idk yet
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

local loadout_type = 'Primary'
local color_off = Color3.new(13/255,13/255,13/255)
local color_on = Color3.new(40/255,40/255,40/255)
local color_highlight = Color3.new(37/255,37/255,37/255)
local color_black = Color3.new(0,0,0)

local function switch(input)
	return function(self) return self[input] or self['default'] end
end

local function list(name,offset)
	local processed = processed_data[name]
	local new = {}
	for i = 1,#processed do
		new[i] = processed[((i+offset-1)%#processed)+1]
	end
	processed_data[name] = new
	return processed_data[name][1]
end





--@vectormodule
do
	local col = Color3.new
	
	function vector.to_color3(vec)
		return col(vec.X,vec.Y,vec.Z)
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

	function colour.tween(frame,c2,time) -- EW REPLACE WITH BIND TO RUNSERVICE
		local time = time or .1
		local c1 = frame.BackgroundColor3
		for delta = 0,1,(1/time)/60 do
			frame.BackgroundColor3 = colour.lerp(c1,c2,delta)
			run_service.RenderStepped:wait()
			-- WHY THE FUCK ISNT THERE A RENDERSTEPPED WAIT HERE. WHY.
		end
	end
end









--@load-module
do
	function load.button(button,switchtable)
		switchtable['default'] = function() end
		button.MouseButton1Up:connect(switch('button-1-up')(switchtable))
		button.MouseButton1Down:connect(switch('button-1-down')(switchtable))
		button.MouseEnter:connect(switch('mouse-enter')(switchtable))
		button.MouseLeave:connect(switch('mouse-leave')(switchtable))
	end

	
	function load.folder(folder,switchtable)
		switchtable['default'] = {default=function()end}
		local folderchildren = folder:GetChildren()
		for i = 1,#folderchildren do
			local button = folderchildren[i]
			load.button(button,switch(button.Name)(switchtable))
		end
	end
	

	function load.crime_net(visible)
		local self = lobby_gui.CrimeNet
		self.Visible = visible
	end
	

	function load.edit_party(visible)
		local self = lobby_gui.EditParty
		self.Visible = visible
	end

	
	function load.character(visible)
		local self = lobby_gui.Character
		self.Visible = visible
		local children = self.Main.Centre.Switches:GetChildren()
		for i = 1,#children do
			local label = children[i]
			label.Text = (processed_data[label.Name] or {'none'})[1]:upper()
			
			label.RightArrow.MouseButton1Up:connect(function()
				label.Text = (list(label.Name,1) or 'none'):upper()
			end)
			
			label.LeftArrow.MouseButton1Up:connect(function()
				label.Text = (list(label.List,-1) or 'none'):upper()
			end)
		end
	end
	

	function load.loadout(visible)
		local self = lobby_gui.Loadout
		self.Visible = visible
		
		local function update()
			local children = self.Main.Centre.Switches:GetChildren()
			for i = 1,#children do
				local label = children[i]
				label.Text = ((processed_data[loadout_type..'_'..label.Name] or {'none'})[1] or 'none'):upper()
			end
		end
		
		self.Main.Centre.Primary.MouseButton1Up:connect(function()
			loadout_type = 'Primary'
			coroutine.wrap(colour.tween)(self.Main.Centre.Primary,color_highlight,.1)
			coroutine.wrap(colour.tween)(self.Main.Centre.Secondary,color_black,.1)
			update()
		end)
		
		self.Main.Centre.Secondary.MouseButton1Up:connect(function()
			loadout_type = 'Secondary'
			coroutine.wrap(colour.tween)(self.Main.Centre.Primary,color_black,.1)
			coroutine.wrap(colour.tween)(self.Main.Centre.Secondary,color_highlight,.1) -- dont worry, coroutines make me cry just as much as they make u cry
			update()
		end)
		
		self.Main.Centre.Primary.TextLabel.Text = processed_data['Primary_Weapon'][1]:upper()
		self.Main.Centre.Secondary.TextLabel.Text = processed_data['Secondary_Weapon'][1]:upper()
		
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
			label.Text = ((processed_data[loadout_type..'_'..label.Name] or {'none'})[1] or 'none'):upper()
			
			label.RightArrow.MouseButton1Up:connect(function()
				print(processed_data[loadout_type..'_'..label.Name])
				label.Text = (list(loadout_type..'_'..label.Name,1) or 'none'):upper()
			end)
			
			label.LeftArrow.MouseButton1Up:connect(function()
				label.Text = (list(loadout_type..'_'..label.Name,-1) or 'none'):upper()
			end)
		end
	end
	

	function load.ready_up(visible)
		local self = lobby_gui.ReadyUp
		self.Visible = visible
	end
		

	function load.shop(visible)
		local self = lobby_gui.Shop
		self.Visible = visible
	end
	

	function load.menu(visible)
		local self = lobby_gui.Menu
		local notification = self.Notification.Text
		local img = self.Notification
		self.Visible = visible
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
					['mouse-enter'] = function() folder['CRIME.NET']:TweenPosition(UDim2.new(0, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'],color_on) end;
					['mouse-leave'] = function() folder['CRIME.NET']:TweenPosition(UDim2.new(0, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'],color_off) end;
					['button-1-up'] = function() lobby_gui.Menu.Visible = false lobby_gui.CrimeNet.Visible = true end;
				};

				['Shop'] = {
					['mouse-enter'] = function() folder['Shop']:TweenPosition(UDim2.new(0.15, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Shop'],color_on) end;
					['mouse-leave'] = function() folder['Shop']:TweenPosition(UDim2.new(0.15, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Shop'],color_off) end;
					['button-1-up'] = function() lobby_gui.Menu.Visible = false lobby_gui.Shop.Visible = true end;
				};

				['Loadout'] = {
					['mouse-enter'] = function() folder['Loadout']:TweenPosition(UDim2.new(0.5, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Loadout'],color_on) end;
					['mouse-leave'] = function() folder['Loadout']:TweenPosition(UDim2.new(0.5, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Loadout'],color_off) end;
					['button-1-up'] = function() lobby_gui.Menu.Visible = false lobby_gui.Loadout.Visible = true end;
				};

				['Tutorial'] = {
					['mouse-enter'] = function() folder['Tutorial']:TweenPosition(UDim2.new(0.75, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Tutorial'],color_on) end;
					['mouse-leave'] = function() folder['Tutorial']:TweenPosition(UDim2.new(0.75, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Tutorial'],color_off) end;
				};
 			
			}
		)
	end
end



print('kek')



load.character()
load.crime_net()
load.edit_party()
load.loadout()
load.ready_up()
load.shop()
load.menu(true)