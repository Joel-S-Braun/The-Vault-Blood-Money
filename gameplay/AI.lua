local specific = {see={'heister','sgunshot','dead_body'},hear={'hgunshot','scream'},smell={'laughing_gas','tear_gas'},feel={'torso_pain','legs_pain','head_pain'}}
--									pain sadness fear
local desired = {heister=Vector3.new(0.5,  0.5,   1),dead_body=Vector3.new(.5,2,2),sgunshot=Vector3.new(0.5,.5,2),
	hgunshot=Vector3.new(0.5,0.5,2),scream=Vector3.new(0.5,0.5,1),laughing_gas=Vector3.new(-3,.3,-2),tear_gas=Vector3.new(1,.6,1),
	torso_pain=Vector3.new(2,.6,1),legs_pain=Vector3.new(1.5,.6,1),head_pain=Vector3.new(3,.6,2)}

local val = Vector3.new(.5,.5,.5)




local function abs(v)
	return Vector3.new(v.X,v.Y,v.Z)
end

local function clone(t)
	local new = {}
	for i,v in pairs(t) do
		new[i]=v
	end
	return new
end






--@AI module
do
	local function sigmoid(t)
		return 1/(math.exp(-t)+1)
	end

	function create_ai_model(tolerance,perceptor,brain)
		local function magnitude(val)
			return math.max((abs(val)-Vector3.new(.5,.5,.5)).Magnitude,.01)
		end

		local terminate

		local concious = 1
		
		local sensory = {}
		local delta = {}
		
		local short_term = {}
		local long_term = {}
		local to_long = {}
		
		local memory = {}
		
		setmetatable(memory,{
				__newindex = function(t,i,v)
					local to_long_val = (delta[i] or -6)
					if to_long_val then
						to_long[i] = (delta[i] or -6)
					end
					short_term[i]={v=v,t=tick()}
					long_term[i] = nil
				end,
				__index = function(t,i)
					if short_term[i] then
						if ((tick()-5) > short_term[i].t) then
							if sigmoid((long_term[i] or -6) * (concious/2 + 0.5))>math.random() then
								long_term[i]=short_term[i]
								short_term[i]=nil
								return long_term[i].v
							else
								short_term[i]=nil
								return nil
							end
						else
							to_long[i] = (to_long[i] or -6) + .5
							return short_term[i].v
						end
					elseif long_term[i] then
						return long_term[i].v
					end
				end
			}
		)
		
		local function get_avg(v)
			local total = Vector3.new()
			for i,v in pairs(specific[v]) do
				local additional = 	(desired[v]- Vector3.new(.5,.5,.5)) * sigmoid(delta[v] * tolerance) + Vector3.new(.5,.5,.5)
				total = total + additional
			end
			return total/#specific[v]
		end
		
		local val = Vector3.new(.5,.5,.5)
		
		for i,v in pairs(desired) do
			delta[i] = -6
		end
		
		local total = Vector3.new()
		for i,v in pairs(specific) do
			sensory[i] = get_avg(i)
			total = total + sensory[i]
		end
		total = total/4

		spawn(function()
			while not terminate do
				delta = perceptor(delta,concious,memory)
				for i,v in pairs(delta) do
					if sigmoid(v) then
						memory[i]=v
						to_long[i]=v
					end
				end

				wait(1.2-concious)

				local total = Vector3.new()
				for i,v in pairs(specific) do
					sensory[i] = get_avg(i)
					total = total + sensory[i]
				end
				total = total/4

				ai(total,memory)
			end
		end)

		return function()
			terminate = true
		end
	end

	
end



create_ai_model(1,perceptor,AI) -- REPLACE SKI