require "./beerxmlnew.rb"
require "./BTnic.rb"
include BTnic
include BeerXML

#file = IO.read(ARGV[0])
#BeerXML.parse_mash(file)
#puts BeerXML.get_names

#puts ("test"+'\r').chomp
#puts ("test"+"\r").chomp
#puts ("test"+"\r")

vessel_params = "10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10\t10"
output_settings = "1\t4\t100\t150\t145\t10\t0"
puts vessel_params
BTnic.set_port(ARGV[0])
puts BTnic.get_port
BTnic.set_baud(115200)
puts BTnic.get_baud
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
puts (BTnic.get_volume_calibrations("BOIL")).map { |i| i.to_s}.join(",")
puts (BTnic.get_evap_rate).map { |i| i.to_s}.join(",")

puts (BTnic.get_output_settings("HLT")).map { |i| i.to_s}.join(",")

puts (BTnic.get_program_settings(5)).map { |i| i.to_s}.join(",")
puts (BTnic.get_temperature_sensor_address("HLT")).map { |i| i.to_s}.join(",")
puts (BTnic.get_version_information).map { |i| i.to_s}.join(",")
puts (BTnic.get_volume_settings("BOIL")).map { |i| i.to_s}.join(",")
puts (BTnic.scan_for_temperature_sensor).map { |i| i.to_s}.join(",")
puts (BTnic.set_volume_calibration("BOIL", vessel_params)).map { |i| i.to_s}.join(",")
puts (BTnic.set_boil_temp(100)).map { |i| i.to_s}.join(",")
puts (BTnic.set_evap_rate(10)).map { |i| i.to_s}.join(",")
puts (BTnic.set_output_settings("HLT", output_settings)).map { |i| i.to_s}.join(",")
puts (BTnic.set_program_settings(1, "TEST\t100\t5\t150\t15\t175\t25\t175\t10\t200\t50\t275\t234\t10\t15\t60\t1\t75\t8\t13\t56\t68")).map { |i| i.to_s}.join(",")
puts (BTnic.set_temperature_sensor("HLT", "0\t20\t100\t150\t145\t1\t25\t32")).map { |i| i.to_s}.join(",")
puts (BTnic.set_valve_profile_configuration(9, 8)).map { |i| i.to_s}.join(",")
puts (BTnic.set_volume_settings("MASH", "5000\t2000")).map { |i| i.to_s}.join(",")
puts (BTnic.advance_step(8)).map { |i| i.to_s}.join(",")
puts (BTnic.exit_step(7)).map { |i| i.to_s}.join(",")
puts (BTnic.start_step(9, 10)).map { |i| i.to_s}.join(",")
puts (BTnic.set_alarm_status("OFF")).map { |i| i.to_s}.join(",")
puts (BTnic.set_autovalve_status(1)).map { |i| i.to_s}.join(",")
puts (BTnic.set_setpoint("BOIL", "10")).map { |i| i.to_s}.join(",")
puts (BTnic.set_timer_status("MASH", "PAUSED")).map { |i| i.to_s}.join(",")
puts (BTnic.set_timer_value("MASH", 100)).map { |i| i.to_s}.join(",")
puts (BTnic.set_valve_profile_status("2048\t0")).map { |i| i.to_s}.join(",")
puts (BTnic.get_valve_profile_configuration(12)).map { |i| i.to_s}.join(",")
puts (BTnic.get_alarm_status()).map { |i| i.to_s}.join(",")
puts (BTnic.get_step_programs()).map { |i| i.to_s}.join(",")
puts (BTnic.get_timer_status("MASH")).map { |i| i.to_s}.join(",")
puts (BTnic.get_volume("MASH")).map { |i| i.to_s}.join(",")
puts (BTnic.get_temperature("MASH")).map { |i| i.to_s}.join(",")
puts (BTnic.get_steam_pressure()).map { |i| i.to_s}.join(",")
puts (BTnic.get_heat_output_status("MASH")).map { |i| i.to_s}.join(",")
puts (BTnic.get_setpoint("MASH")).map { |i| i.to_s}.join(",")
puts (BTnic.get_autovalve_status()).map { |i| i.to_s}.join(",")
puts (BTnic.get_valve_output_status()).map { |i| i.to_s}.join(",")
puts (BTnic.get_valve_profile_status()).map { |i| i.to_s}.join(",")
BTnic.reset("SOFT")
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
BTnic.reset("HARD")
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")


puts "Done"
