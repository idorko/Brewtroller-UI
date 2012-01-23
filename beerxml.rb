require 'rexml/document'

#open file for reading
file = IO.read('lawnmowerspecial.xml')

#extract xml data
doc = REXML::Document.new(file)
root = doc.root
names = []
mash_temp = []
root.elements.each('RECIPE/NAME') do |ele|
	names << ele.text
end
root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/STEP_TEMP') do |ele|
	mash_temp << ele.text
end
puts names
puts mash_temp
