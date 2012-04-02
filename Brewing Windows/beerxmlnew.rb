require 'rexml/document'
require 'utility.rb'
include Conversions

module BeerXML

		@@names = []
		@@mash_temps = []
		@@mash_times = []
		@@sparge_temp = []
		@@other_params = []
		@@volumes = []
		@@other_temps = []

	def parse_mash(file_raw)
		#clean out any saved array values
		@@names.clear
		@@mash_temps.clear
		@@mash_times.clear
		@@sparge_temp.clear
		@@volumes.clear
		@@other_temps.clear
		@@other_params.clear
		#open file for reading
		file = IO.read(file_raw)
	
		#extract xml data
		doc = REXML::Document.new(file)
		root = doc.root
	#pull data from XML format
		root.elements.each('RECIPE/NAME') do |ele|
			@@names << ele.text
		end
		root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/STEP_TEMP') do |ele|
			@@mash_temps << ele.text
		end
		root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/STEP_TIME') do |ele|
			@@mash_times << ele.text
		end
		root.elements.each('RECIPE/MASH/SPARGE_TEMP') do |ele|
			@@sparge_temp << ele.text
		end
		root.elements.each('RECIPE/EQUIPMENT/BATCH_SIZE') do |ele|
			@@volumes << ele.text
		end
		
		temp = 0 
		root.elements.each('RECIPE/FERMENTABLES/FERMENTABLE') do |ele|
			ele.elements.each('INVENTORY') do |ele|
				 temp2 = ele.text.to_s.delete(" lb")
				 temp += temp2.to_f.round
			end
		end
		@@other_params << temp

		root.elements.each('RECIPE/BOIL_TIME') do |ele|
			@@other_params << ele.text
		end

		root.elements.each('RECIPE/MASH/MASH_STEPS/MASH_STEP/WATER_GRAIN_RATIO') do |ele|
			@@other_params << ele.text
		end
		
		root.elements.each('RECIPE/PRIMARY_TEMP') do |ele|
			@@other_temps << ele.text
		end

		Conversions.celcius_to_farenheit(@@mash_temps)
		Conversions.celcius_to_farenheit(@@sparge_temp)
		Conversions.celcius_to_farenheit(@@other_temps)
		Conversions.litres_to_gallons(@@volumes)
		#add trailing 0s
		for i in 0..6
			if i > @@mash_temps.size
				@@mash_temps << 0
				@@mash_times << 0
			end
		end
		
	end
	
	def get_other_temps
		@@other_temps
	end
	
	def get_volumes
		@@volumes
	end
	
	def get_other_params
		@@other_params
	end

	def get_names
		@@names
	end
	
	def get_mash_temps
		@@mash_temps
	end
	
	def get_mash_times
		@@mash_times
	end
	
	def get_sparge_temp
		@@sparge_temp
	end
end
