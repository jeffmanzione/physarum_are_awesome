# This is a program which simulates protein shocking by induced electrical
# current. This process gives the medium memristance properties.

# Constants and other
$r = Random.new			# Just a random for initialization
IDEAL_V = -70				# Ideal membrane potential. Why not -70?
DELTA_C_FACT = 0.1		# Rate of ion transportation across membrane
DIFFUSION_FACT = 0.1		# Rate of diffusion throughout medium
RECOVERY_TIME = 120		# Recovery time from protein shocking
RED_FLOW_FACT = 0.05		# Reduced flow factor of ions in reverse of shock direction
# idk what this should be. It does not matter really for our purposes.
DEFAULT_MEDIA_CHARGE = 50.0

$extern_c = 0		# External induced charge from current

# world class
class World
	# new
	def initialize(x, y, fill = 0.5)
		# building the array for the world	
		@agents = []
		@medium = []	
		for i in (0...y)
			row = []
			med = []
			for j in (0...x)
				val = $r.rand(0..1000)
				if val <= fill*1000
					row.push(Agent.new)
				else
					row.push(nil)
				end
				med.push($r.rand(60...80))
			end
			@agents.push(row)
			@medium.push(med)
		end
	end

	def advance
		# prints these three values
		puts "%f\t%f\t%f" % [average_medium_charge, average_agent_charge, average_mem_potential]

		new_agents = []
		new_medium = []
		
		# agents affecting the medium
		for i in (0...@agents.length)
			row = []
			med = []
			for j in (0...@agents[0].length)
				row.push(@agents[i][j])
				unless @agents[i][j].nil?
					change = @agents[i][j].advance(@medium[i][j])
					med.push(@medium[i][j] - change)
				else
					med.push(@medium[i][j])
				end			
			end
			new_agents.push(row)
			new_medium.push(med)
		end
		
		@agents = new_agents
		@medium = new_medium

		# diffusion of ions
		for i in (0...@agents.length)
			for j in (0...@agents[0].length)
				new_medium[i][j] += DIFFUSION_FACT * (self.neighbors(i, j).reduce(:+) / 9 - @medium[i][j])
			end
		end

		@medium = new_medium

	end

	def neighbors(x, y)
		[@medium[x][y], 
			@medium[(x+1)%@medium.length][y], 
			@medium[(x-1)%@medium.length][y],
			@medium[x][(y-1)%@medium[0].length], 
			@medium[(x+1)%@medium.length][(y-1)%@medium[0].length], 
			@medium[(x-1)%@medium.length][(y-1)%@medium[0].length],
			@medium[x][(y+1)%@medium[0].length], 
			@medium[(x+1)%@medium.length][(y+1)%@medium[0].length], 
			@medium[(x-1)%@medium.length][(y+1)%@medium[0].length]]
	end

	def to_s
		count = 0
		tot = 0
		str = " "
		for i in (0...@agents[0].length)
			str << "_"
		end
	
		str << "\n"

		for i in (0...@agents.length)
			row = @agents[i]
			str << "|"
			for j in (0...row.length)
				tot += 1
				if @agents[i][j].to_s == 'O'
					count += 1;
					str << 'O'
				else
					str << ' '
				end
			end
			str << "|\n"
		end
		str << " "

		for i in (0...@agents[0].length)
			str << "-"
		end
		str << ("\nTotal: %d, Agents: %d, Fill: %.2f" % [tot, count, count * 1.0 / tot])
		
		str
	end

	def medium_charge
		str = " "
		for i in (0...@medium[0].length)
			str << "_"
		end
	
		str << "\n"

		for i in (0...@medium.length)
			str << "|"
			for j in (0...@medium[0].length)
				str << ("%.2f " % [@medium[i][j]])
			end
			str << "|\n"
		end
		str << " "

		for i in (0...@medium[0].length)
			str << "-"
		end
		
		str
	end

	def agent_charge
		str = " "
		for i in (0...@agents[0].length)
			str << "_"
		end
	
		str << "\n"

		for i in (0...@agents.length)
			str << "|"
			for j in (0...@agents[0].length)
				if @agents[i][j].nil?
					str << '-'
				else
					str << ("%.2f " % [@agents[i][j].charge])
				end
			end
			str << "|\n"
		end
		str << " "

		for i in (0...@agents[0].length)
			str << "-"
		end
		
		str
	end

	def average_mem_potential
		tot = 0
		count = 0		
		for i in (0...@agents.length)
			for j in (0...@agents[0].length)
				unless @agents[i][j].nil?
					count += 1
					tot += @agents[i][j].mem_potential(@medium[i][j])
				end
			end
		end

		tot / count
	end

	def average_medium_charge
		tot = 0
		count = 0		
		@medium.each { |row|
			row.each { |loc|
				count += 1
				tot += loc + $extern_c
			}		
		}

		tot / count
	end

	def average_agent_charge
		tot = 0
		count = 0		
		@agents.each { |row|
			row.each { |loc|
				unless loc.nil?
					count += 1
					tot += loc.charge
				end
			}		
		}

		tot / count
	end

end

LEFT = -1
RIGHT = 1

# Physarum
class Agent
	def initialize(charge = 0)
		@charge = charge
	end

	def charge
		@charge
	end

	def advance medium_charge
		mem_potential = @charge - ($extern_c + medium_charge)

		if not @shocked and (IDEAL_V - mem_potential).abs > 40
			#puts "Shocked %s" % [((IDEAL_V - mem_potential) > 0) ? "RIGHT" : "LEFT"]
			@shocked = true
			@recovery_dir = ((IDEAL_V - mem_potential) > 0) ? RIGHT : LEFT
			@till = 0
		elsif @shocked 
			if (IDEAL_V - mem_potential).abs > 40 and (((IDEAL_V - mem_potential) > 0) ? RIGHT : LEFT) != @recovery_dir
				#puts "Antishocked"
				@till = 0
			else
				@till += 1
			end

			if @till == RECOVERY_TIME	# recovered
				#puts "Recovered"
				@shocked = false
			end
		end
		

		d_charge = DELTA_C_FACT * (IDEAL_V - mem_potential)

		if @shocked and ((d_charge > 0 and @recovery_dir == LEFT) or (d_charge > 0 and @recovery_dir == RIGHT))
				#puts "REDUCED"
				d_charge *= RED_FLOW_FACT
		end
		@charge += d_charge

		d_charge
	end

	def mem_potential medium_charge
		@charge - ($extern_c + medium_charge)
	end

	def to_s
		'O'
	end
end

# running the simulation

two_shocks = true

world = World.new(100, 100)
puts "Agents are Os"
puts world.to_s

puts "\n\n"

puts "Medium charge	Agent charge	Membrane Potential"
(0...30).each {
	world.advance
}

if two_shocks

	#puts "\nElectrical current introduced."
	#puts ""

	$extern_c  -= 100

	(0...100).each {
		world.advance
	}

	puts "\nElectrical current removed."
	puts ""

	$extern_c  += 100

	(0...20).each {
		world.advance
	}

end

$extern_c  -= 125

(0...100).each {
	world.advance
}

#puts "\nElectrical current removed."
#puts ""

$extern_c  += 125

(0...70).each {
	world.advance
}

# end of simulation


