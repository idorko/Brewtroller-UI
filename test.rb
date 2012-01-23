require "./beerxml.rb"
include BeerXML

file = IO.read(ARGV[0])
BeerXML.parse_mash(file)
puts BeerXML.get_names
