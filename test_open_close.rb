require "./beerxmlnew.rb"
require "./BTnic_updated.rb"
include BTnic
include BeerXML

#file = IO.read(ARGV[0])
#BeerXML.parse_mash(file)
#puts BeerXML.get_names

#puts ("test"+'\r').chomp
#puts ("test"+"\r").chomp
#puts ("test"+"\r")


BTnic.set_port(ARGV[0])
puts BTnic.get_port
BTnic.set_baud(115200)
puts BTnic.get_baud
BTnic.open_connection
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
puts (BTnic.get_boil_temp).map { |i| i.to_s}.join(",")
puts "Done"
