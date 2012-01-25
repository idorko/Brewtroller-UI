require "./beerxml.rb"
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
puts "Done"
