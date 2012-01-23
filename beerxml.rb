module BeerXML
require 'rexml/document'
require "./utility.rb"
include Conversions


		@@names = []
		@@mash_temps = []
		@@mash_times = []
		@@sparge_temp = []

	def parse_mash(file_raw)
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
		Conversions.celcius_to_farenheit(@@mash_temps)
		Conversions.celcius_to_farenheit(@@sparge_temp)
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
