repeat wait() until game.Players.LocalPlayer.Character

local run_service = game:GetService('RunService')

local local_player = game.Players.LocalPlayer
local _character = local_player.Character

local delta = {}
local mathf = {}
local animations = {}













--mathf module
do
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
















--@player_animation ski
do	
	--@init
	local player_animation = {gundes=CFrame.new(),
		leftdes=Vector3.new(),rightdes=Vector3.new(),
		leftreal = Vector3.new(),rightreal=Vector3.new(),gunreal = CFrame.new(),
		sway_speed = 1.3,sway_factor = 32 ,gun_offset=CFrame.new(),gun_recoil=CFrame.new(),
		model=workspace.Player1,
	}
	
	do
		for i,v in pairs(script:GetChildren()) do
			animations[v.Name] = require(v)
		end

		local_player.Character.Torso['Left Shoulder']:Destroy()
		local_player.Character.Torso['Right Shoulder']:Destroy()

		local_player.Character['Right Arm'].Size = Vector3.new(.9,.9,2)
		weld = Instance.new('ManualWeld')
		weld.Parent = local_player.Character.Torso
		weld.Part0 = local_player.Character.Head
		weld.Part1 = local_player.Character['Right Arm']
		weld.Name = 'Right Arm'
		weld.C0 = CFrame.new(1.5,-1,0)

		local_player.Character['Left Arm'].Size = Vector3.new(.9,.9,2)
		weld = Instance.new('ManualWeld')
		weld.Parent = local_player.Character.Torso
		weld.Part0 = local_player.Character.Head
		weld.Part1 = local_player.Character['Left Arm']
		weld.Name = 'Left Arm'
		weld.C0 = CFrame.new(-1.5,-1,0)

		weld = Instance.new('ManualWeld')
		weld.Parent = local_player.Character.Torso
		weld.Part0 = local_player.Character.Head
		--weld.Part1 = local_player.Character.gun
		weld.Name = 'gun'
		weld.C0 = CFrame.Angles(0,math.pi,0)

		game.Players.LocalPlayer.Character.Torso.Neck.C1 = CFrame.new()
	end



	
	function run_animation(anim,obj,priority)
		priority = priority or 201
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
		for i = 0,math.pi*2,math.rad(36) do
			--player_animation.gun_recoil = player_animation.gun_recoil * CFrame.new(0,math.sin(i)/36,0) * CFrame.Angles(math.sin(i)/30,0,0)
			wait()
		end
		--player_animation.gun_recoil = CFrame.new()
	end



	function interpret_player() -- specifically made for THIS client, not others. may just recycle code in diff function for NPCs OR modify this to return function
		for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
			if v:IsA("BasePart") then
				v.LocalTransparencyModifier = 0
			end
		end
		
		game.Players.LocalPlayer.Character.Torso.Neck.C0 = player_animation.gun_offset * CFrame.Angles(math.asin(workspace.CurrentCamera.CFrame.lookVector.Y),0,0) + Vector3.new(0,1.5,0)
		
		local right_start = player_animation.model.Head.CFrame * CFrame.new(1.5,-1,0)
		local left_start = player_animation.model.Head.CFrame * CFrame.new(-1.5,-1,0)
		
		local delta_val = 1- 1/2^(delta.get( player_animation.model:GetFullName() ) * 10 )
		delta.set(player_animation.model:GetFullName())
		
		--real cframe
		player_animation.gunreal = player_animation.gunreal:lerp(player_animation.gundes,delta_val)
		player_animation.leftreal = player_animation.leftreal:lerp(player_animation.leftdes,delta_val)
		player_animation.rightreal = player_animation.rightreal:lerp(player_animation.rightdes,delta_val)

		--gun
		player_animation.model.Torso.gun.C1 = (player_animation.gunreal)
		
		--right arm
		local offset = player_animation.rightreal - Vector3.new(1.5,-1,0) 
		local magnitude = mathf.clamp(-0.3,1.4,player_animation.rightreal.Magnitude-1)
		player_animation.model.Torso['Right Arm'].C1 =  ((CFrame.Angles(math.atan2(offset.Y,-offset.Z),math.atan2(offset.X,offset.Z),0)) * CFrame.new(0,0,magnitude)):inverse() -- Vector3.new(-1,.5,-.5)
		
		--left arm
		local offset = player_animation.leftreal - Vector3.new(-1.5,-1,0)
		local magnitude = mathf.clamp(-0.3,1.4,player_animation.leftreal.Magnitude-1)
		player_animation.model.Torso['Left Arm'].C1 = ((CFrame.Angles(math.atan2(offset.Y,-offset.Z),math.atan2(offset.X,offset.Z),0)) * CFrame.new(0,0,magnitude)):inverse()
	end
	
	--repeat wait until casing

	run_service:BindToRenderStep('Animate',201,interpret_player)
	
	run_animation('Run',player_animation)
end














--@weapon ski
do
	
end


