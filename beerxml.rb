#!/user/bin/env ruby
require 'rexml/document'
require "./utility.rb"
include Conversions

#open file for reading
file = IO.read(ARGV[0])

#extract xml data
doc = REXML::Document.new(file)
root = doc.root
names = []
mash_temps = []
mash_times = []
sparge_temp = []
#pull data from XML format
root.elements.each('RECIPE/NAME') do |ele|
	names << ele.text
end
root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/STEP_TEMP') do |ele|
	mash_temps << ele.text
end
root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/STEP_TIME') do |ele|
	mash_times << ele.text
end
root.elements.each('RECIPE/MASH/SPARGE_TEMP') do |ele|
	sparge_temp << ele.text
end
Conversions.celcius_to_farenheit(mash_temps)
Conversions.celcius_to_farenheit(sparge_temp)
