#The BTnic module implements the BTnic protocol
#for usage over a serial connection.

#Data is recieved and verified, then returned as an array.
#Vessel options are HLT, MASH and BOIL.

require 'rubygems'
require 'serialport'

module BTnic
	
	@@port = ""
	@@baud = 0	

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
		sp = open_connection(@@port, @@baud)
		data = get_data("A", sp)
		validate_data("A", data)
		close_connection(sp)
		return data
	end
	
	def get_volume_calibrations(vessel)
		sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "B"+(vessel_index.to_s)
		data = get_data(code ,sp)
		validate_data(code, data)
		close_connection(sp)
		return data
	end 	

	def get_evap_rate 
		sp = open_connection(@@port, @@baud)
		data = get_data("C", sp)
		validate_data("C", data)
		close_connection(sp)
		return data
	end	
	
	def get_output_settings(vessel)
		sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "D"+(vessel_index.to_s)
		data = get_data(code ,sp)
		validate_data(code, data)
		close_connection(sp)
		return data
	end

	def get_program_settings(prog_num)
		check_prog(prog_num)
		sp = open_connection(@@port, @@baud)
		code = "E"+(prog_num.to_s)
		data = get_data(code ,sp)
		validate_data(code, data)
		close_connection(sp)
		return data
	end

	def get_temperature_sensor_address(vessel)
		sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "F"+(vessel_index.to_s)
		data = get_data(code ,sp)
		validate_data(code, data)
		close_connection(sp)
		return data
	end

	def get_version_information
		sp = open_connection(@@port, @@baud)
		data = get_data("G", sp)
		validate_data("G", data)
		close_connection(sp)
		return data
	end

	def get_volume_settings(vessel)
		sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "H"+(vessel_index.to_s)
		data = get_data(code ,sp)
		validate_data(code, data)
		close_connection(sp)
		return data
	end

	def initialize_eeprom
		sp = open_connection(@@port, @@baud)
		data = get_data("I", sp)
		validate_data("I", data)
		close_connection(sp)
		return data		 
	end

	def scan_for_temperature_sensor
		sp = open_connection(@@port, @@baud)
		data = get_data("J", sp)
		validate_data("J", data)
		close_connection(sp)
		return data
	end

	def set_boil_temp(temp)		
		sp = open_connection(@@port, @@baud)
		code = "K"+"\t"+temp.to_s
		data = get_data(code, sp)
		code = "A"
		validate_data(code, data)
		close_connection(sp)
		return data 
	end

	def set_volume_calibration(vessel, calibration_params)
		sp = open_connection(@@port, @@baud)
		vessel_index = get_vessel_index(vessel)
		code = "L"+vessel_index.to_s+"\t"+calibration_params.to_s
		data = get_data(code, sp)
		code = "B"+vessel_index.to_s
		validate_data(code, data)
		close_connection(sp)
		return data 
	end		
	
	def set_evap_rate(rate)
		code = "M "+rate
		@@sp.write(code)
		return get_data
	end

	private
	#connection methods
	def open_connection(port, baud)
		return sp = SerialPort.new(port, baud)
	end
	
	def close_connection(sp)
		 sp.close
	end

	#data retrieval 
	def get_data(code, sp)
		#add terminiating character, send code
		code += "\r"
		puts code
		sp.print(code)
		data = sp.readline("\r\n")
		raise TypeError, "\n No data recieved." if data == nil

		#parse data
		parsed_data = data.split("\t")
		return parsed_data
	end

	#error checking
	def validate_data(code, data)
		raise TypeError, "Response code error: " + data[1].to_s + code if 
			(data[1] == '!' || data[1] == '!' || data[1] == '#' || code != data[1])
	end

	def get_vessel_index(vessel)
		if vessel == "HLT"
			return 0
		elsif vessel == "MASH"
			return 1
		elsif vessel == "BOIL"
			return 2
		else 
			raise TypeError, "\n Invalid vessel. \n Vessel options are: \n HLT\n MASH\n BOIL\n"
		end
	end

	def check_prog(prog)
		raise TypeError, "Invalid program index." if (prog < 0 || prog > 19)
	end
	
end
  
