--[[
	@1/1/16
	
	@load-module
	@colour-module
--]]

local _game = game
local run_service = _game:GetService('RunService')
local local_player = game.Players.LocalPlayer
local player_gui = local_player:WaitForChild('PlayerGui')

local load = {}
local colour = {}
local vector = {}

local color_off = Color3.new(13/255,13/255,13/255)
local color_on = Color3.new(40/255,40/255,40/255)

local function switch(input)
	return function(self) return self[input] or self['default'] end
end





--@vector-module
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
		local time = time or .2
		local c1 = frame.BackgroundColor3
		for delta = 0,1,(1/time)/60 do
			frame.BackgroundColor3 = colour.lerp(c1,c2,delta)
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
	
	function load.menu()
		local self = game.ReplicatedStorage.Menu:Clone()
		self.Parent = player_gui
		local notification = self.Notification.Text
		local img = self.Notification.ImageButton
		load.button(
			self.Notification.ImageButton,
			{
				['mouse-leave'] = function() notification:TweenPosition(UDim2.new(0,75,1.5,0),'Out','Sine',.2,true) colour.tween(img,color_off) end;
			
				['mouse-enter'] = function() notification:TweenPosition(UDim2.new(-2.5,0,1.5,0),'Out','Sine',.2,true) colour.tween(img,color_on) end;
			}
		)
		
		local folder = self.Buttons

		load.folder(
			folder,
			{
				['CRIME.NET'] = {
					['mouse-enter'] = function() folder['CRIME.NET']:TweenPosition(UDim2.new(0, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'],color_on) end;
					['mouse-leave'] = function() folder['CRIME.NET']:TweenPosition(UDim2.new(0, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['CRIME.NET'],color_off) end;
				};

				['Inventory'] = {
					['mouse-enter'] = function() folder['Inventory']:TweenPosition(UDim2.new(0.25, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Inventory'],color_on) end;
					['mouse-leave'] = function() folder['Inventory']:TweenPosition(UDim2.new(0.25, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Inventory'],color_off) end;
				};

				['Loadout'] = {
					['mouse-enter'] = function() folder['Loadout']:TweenPosition(UDim2.new(0.5, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Loadout'],color_on) end;
					['mouse-leave'] = function() folder['Loadout']:TweenPosition(UDim2.new(0.5, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Loadout'],color_off) end;
				};

				['Tutorial'] = {
					['mouse-enter'] = function() folder['Tutorial']:TweenPosition(UDim2.new(0.75, 15,1, -105),'Out','Sine',.2,true) colour.tween(folder['Tutorial'],color_on) end;
					['mouse-leave'] = function() folder['Tutorial']:TweenPosition(UDim2.new(0.75, 15,1, -75),'Out','Sine',.2,true) colour.tween(folder['Tutorial'],color_off) end;
				};
 			
			}
		)
	end
end








load.menu()