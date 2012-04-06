#The BTnic module implements the BTnic protocol
#for usage over a serial connection.

#Data is recieved and verified, then returned as an array.
#Vessel options are HLT, MASH and BOIL.

#Note BTnic Protocol page has re@@sponse code for set alarm incorrect
#it should be e
#On set output settings 7 fields are required, need \t at end
#On set program settings 22 fields are required


require 'rubygems'
require 'serialport'

module BTnic
	
	@@port = ""
	@@baud = 0	
	@@sp = nil
	public
		
	#parameter setup
	def get_port
		@@port
	end
	
	def get_baud
		@@baud
	end
	
	def set_port(port)
		@@port = port
	end
	
	def set_baud(baud)
		@@baud = baud
	end

	
	#BTnic methods
	def get_boil_temp
		#@@sp = open_connection(@@port, @@baud)
		data = get_data("A")
		validate_data("A", data)
		#close_connection(@@@@sp)
		return data
	end
	
	def get_volume_calibrations(vessel)
		#@@@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "B"+(vessel_index.to_s)
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end 	

	def get_evap_rate
		#@@sp = open_connection(@@port, @@baud)
		data = get_data("C")
		validate_data("C", data)
		#close_connection(@@sp)
		return data
	end	
	
	def get_output_settings(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "D"+(vessel_index.to_s)
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end

	def get_program_settings(prog_num)
		check_prog(prog_num)
		#@@sp = open_connection(@@port, @@baud)
		code = "E"+(prog_num.to_s)
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end

	def get_temperature_sensor_address(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "F"+(vessel_index.to_s)
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end

	def get_version_information
		#@@sp = open_connection(@@port, @@baud)
		data = get_data("G")
		validate_data("G", data)
		#close_connection(@@sp)
		return data
	end

	def get_volume_settings(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "H"+(vessel_index.to_s)
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end

	def initialize_eeprom 
		#@@sp = open_connection(@@port, @@baud)
		data = get_data("I")
		validate_data("I", data)
		#close_connection(@@sp)
		return data		 
	end

	def scan_for_temperature_sensor 
		#@@sp = open_connection(@@port, @@baud)
		data = get_data("J")
		validate_data("J", data)
		#close_connection(@@sp)
		return data
	end

	def set_boil_temp(temp)		
		#@@sp = open_connection(@@port, @@baud)
		code = "K"+"\t"+temp.to_s
		data = get_data(code)
		code = "A"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_volume_calibration(vessel, calibration_params)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "L"+vessel_index.to_s+"\t"+calibration_params.to_s
		data = get_data(code)
		code = "B"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end		
	
	def set_evap_rate(rate)		
		#@@sp = open_connection(@@port, @@baud)
		code = "M"+"\t"+rate.to_s
		data = get_data(code)
		code = "C"
		validate_data(code, data)
		#close_connection(@@sp)
		return data
	end

	def set_output_settings(vessel, calibration_params)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "N"+vessel_index.to_s+"\t"+calibration_params.to_s+"\t"
		data = get_data(code)
		code = "D"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	
	
	def set_program_settings(program, settings)
		#@@sp = open_connection(@@port, @@baud)
		code = "O"+program.to_s+"\t"+settings.to_s
		data = get_data(code)
		code = "E"+program.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_temperature_sensor(sensor, address)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(sensor)
		code = "P"+vessel_index.to_s+"\t"+address.to_s
		data = get_data(code)
		code = "F"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end		
	
	def set_valve_profile_configuration(index, calibration_params)
		#@@sp = open_connection(@@port, @@baud)
		code = "Q"+index.to_s+"\t"+calibration_params.to_s
		data = get_data(code)
		code = "d"+index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_volume_settings(vessel, calibration_params)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "R"+vessel_index.to_s+"\t"+calibration_params.to_s
		data = get_data(code)
		code = "H"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def advance_step(step_index)
		#@@sp = open_connection(@@port, @@baud)
		code = "S"+step_index.to_s
		data = get_data(code)
		code = "n"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def exit_step(step_index)
		#@@sp = open_connection(@@port, @@baud)
		code = "T"+step_index.to_s
		data = get_data(code)
		code = "n"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def start_step(prog_index,step)
		#@@sp = open_connection(@@port, @@baud)
		code = "U"+prog_index.to_s+"\t"+step.to_s
		data = get_data(code)
		code = "n"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end
	
	def set_alarm_status(status)
		if status == "ON"
			status = '1'
		elsif status == "OFF"
			status = '0'
		else
			raise TypeError "Invalid Alarm Status. Must be ON or OFF."	
		end
		#@@sp = open_connection(@@port, @@baud)
		code = "V"+"\t"+status.to_s
		data = get_data(code)
		code = "e"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_autovalve_status(status)
		#@@sp = open_connection(@@port, @@baud)
		code = "W"+"\t"+status.to_s
		data = get_data(code)
		code = "u"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_setpoint(vessel, setpoint)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "X"+vessel_index.to_s+"\t"+setpoint.to_s
		data = get_data(code)
		code = "t"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def set_timer_status(vessel, status)
		if status == "ACTIVE"
			status = "1"
		elsif status == "PAUSED"
			status = "0"
		else
			raise TypeError "Invalid Timer Status. Must be ACTIVE or PAUSED."	
		end
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "Y"+vessel_index.to_s+"\t"+status.to_s
		data = get_data(code)
		code = "o"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	

	def set_timer_value(vessel, value)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "Z"+vessel_index.to_s+"\t"+value.to_s
		data = get_data(code)
		code = "o"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	


	def set_valve_profile_status(calibration_params)
		#@@sp = open_connection(@@port, @@baud)
		code = "b"+"\t"+calibration_params.to_s
		data = get_data(code)
		code = "w"
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def reset(level)		
		if level == "SOFT"
			status = "1"
		elsif level == "HARD"
			status = "0"
		else
			raise TypeError "Invalid reset level. Must be SOFT or HARD."	
		end
		#@@sp = open_connection(@@port, @@baud)
		code = "c"+"\t"+level.to_s
		get_data(code)
		#close_connection(@@sp)
	end

	def get_valve_profile_configuration(valve)
		#@@sp = open_connection(@@port, @@baud)
		code = "d"+valve.to_s
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_alarm_status
		#@@sp = open_connection(@@port, @@baud)
		code = "e"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_step_programs
		#@@sp = open_connection(@@port, @@baud)
		code = "n"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_timer_status(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "o"+vessel_index.to_s
		data = get_data(code)
		code = "o"+vessel_index.to_s
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	

	def get_volume(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "p"+vessel_index.to_s
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	

	def get_temperature(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "q"+vessel_index.to_s
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_steam_pressure
		#@@sp = open_connection(@@port, @@baud)
		code = "r"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	
	
	def get_heat_output_status(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "s"+vessel_index.to_s
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_setpoint(vessel)
		#@@sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "t"+vessel_index.to_s
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end

	def get_autovalve_status
		#@@sp = open_connection(@@port, @@baud)
		code = "u"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	

	def get_valve_output_status
		#@@sp = open_connection(@@port, @@baud)
		code = "v"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	

	def get_valve_profile_status
		#@@sp = open_connection(@@port, @@baud)
		code = "w"
		data = get_data(code)
		validate_data(code, data)
		#close_connection(@@sp)
		return data 
	end	
	


	#connection methods
	def open_connection
		@@sp = SerialPort.new(@@port, @@baud)
		#read timeout or @@sp hangs
		@@sp.read_timeout = 2000
		#return initialization string that brewtroller sends on reset
		@@sp.readline("\r\n")
		return @@sp
	end
	
	def close_connection
		 @@sp.close
		return true
	end
	
	private
	#data retrieval 
	def get_data(code)
		#add terminiating character, send code
		code += "\r"
		#puts code
		@@sp.print(code)
		data = @@sp.readline("\r\n")
		raise TypeError, "\n No data recieved." if data == nil
	

		#parse data
		parsed_data = data.split("\t")
		#workaround for BT sending back 1
		#basically get new data point.
		if (parsed_data[0] == "1\r\n")
			data = @@sp.readline("\r\n")
			parsed_data = data.split("\t")
		end
		
		return parsed_data
	end

	#error checking
	def validate_data(code, data)
		
		if(data[1]!=code)
			if data[1] == '!'
				raise TypeError, "Invalid Command.\n"
			elsif data[1] == '$'
				raise TypeError, "Invalid Command Index.\n"
			elsif data[1] == '#'
				raise TypeError, "Invalid Command Parameters\n"
			else 
				raise TypeError, "Unknown Error.\n"
			end
		end
	end
	def get_vessel_index(vessel)
		if vessel == "HLT"
			return 0
		elsif vessel == "MASH"
			return 1
		elsif vessel == "BOIL"
			return 2
		elsif vessel == "H2OIN"
			return 3
		elsif vessel == "H2OOUT"
			return 4
		elsif vessel == "BEEROUT"
			return 5
		elsif vessel == "AUX1"
			return 6
		elsif vessel == "AUX2"
			return 7
		elsif vessel == "AUX3" 
			return 8
		else 
			raise TypeError, "\n Invalid vessel. \n Vessel options are: \n HLT\n MASH\n BOIL\n H2OIN\n H2OOUT\n BEEROUT\n AUX1\n AUX2\n AUX3\n"
		end
	end

	def check_prog(prog)
		raise TypeError, "Invalid program index." if (prog < 0 || prog > 19)
	end
	
end
  
