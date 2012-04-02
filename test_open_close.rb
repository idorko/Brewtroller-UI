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


BTnic.set_port(ARGV[0])
puts BTnic.get_port
BTnic.set_baud(115200)
puts BTnic.get_baud
BTnic.open_connection
for i in 1..120
	puts i.to_s << " " << BTnic.get_temperature("BOIL").map { |i| i.to_s}.join(",")
	sleep(1)
end
puts "Done"
