#!/usr/bin/ruby
$LOAD_PATH.unshift File.dirname($0)
require 'rubygems'
require 'wx'
require 'gui_class'
require 'beerxmlnew'
require 'BTNic'

include BeerXML
include BTnic

class BeerXML2BrewTroller < TextFrameBase
	
	def initialize
		super
		evt_button(load) { |event| import_program() }
		evt_button(download) { |event| download_program() }
	end
	
	def import_program()
		fd = Wx::FileDialog.new(self, "Choose a file...", "~/"," ", "*.xml", Wx::FD_OPEN)
		fd.show_modal
		fn = fd.get_directory + "\\" +fd.get_filename()		
		BeerXML.parse_mash(fn)
		
		m_textctrl3.value = BeerXML.get_names[0].to_s
		doughin_temp.value = BeerXML.get_mash_temps[0].to_s
		doughin_time.value = BeerXML.get_mash_times[0].to_s
		acid_time.value = BeerXML.get_mash_times[1].to_s
		acid_temp.value = BeerXML.get_mash_temps[1].to_s
		protein_temp.value = BeerXML.get_mash_temps[2].to_s
		protein_time.value = BeerXML.get_mash_times[2].to_s
		sach_time.value = BeerXML.get_mash_times[3].to_s
		sacch_temp.value = BeerXML.get_mash_temps[3].to_s	
		sacch2_time.value = BeerXML.get_mash_times[4].to_s
		sacch2_temp.value = BeerXML.get_mash_temps[4].to_s	
		mash_out_time.value = BeerXML.get_mash_times[5].to_s
		mash_out_temp.value = BeerXML.get_mash_temps[5].to_s	
		sparge_temp.value = BeerXML.get_sparge_temp[0].to_s
		batch_vol.value = BeerXML.get_volumes[0].to_f.round.to_s
		grain_weight.value = BeerXML.get_other_params[0].to_f.round.to_s
		boil_time.value = BeerXML.get_other_params[1].to_s
		hlt_setpoint1.value = ((BeerXML.get_other_params[2].to_f*100).round).to_s
		pitch_temp.value = BeerXML.get_other_temps[0].to_s

	end	
	
	def download_program()
		download.disable
		#run one code to flush serial buffer
		#determine HLT or MASH
		if hlt_setpoint2.get_value == "HLT"
			hltormash = 0
		else
			hltormash = 1
		end	
		#parse control string
		control = "#{m_textctrl3.get_value}\t#{doughin_temp.get_value()}\t#{doughin_time.get_value()}\t#{acid_temp.get_value}\t#{acid_time.get_value}\t#{protein_temp.get_value()}\t#{protein_time.get_value}\t#{sacch_temp.get_value}\t#{sach_time.get_value}\t#{sacch2_temp.get_value}\t#{sacch2_time.get_value}\t#{mash_out_temp.get_value}\t#{mash_out_time.get_value}\t#{sparge_temp.get_value}\t#{hlt_setpoint.get_value}\t#{batch_vol.get_value+"000"}\t#{grain_weight.get_value+"000"}\t#{boil_time.get_value}\t#{hlt_setpoint1.get_value}\t#{pitch_temp.get_value}\t#{boil_additions.get_value}\t#{hltormash}"

		#download to brewtroller
		BTnic.set_baud(115200)
		BTnic.set_port(port.get_value)
	#	BTnic.get_boil_temp()
		BTnic.set_program_settings(prog_choice1.get_selection, control)
		download.enable
	end
end

class ErrorWindow < Wx::MiniFrame
	def new(message)
		super	
		@error_window=Wx::Window.new
		@error_window.add(Wx::StaticText.new(self, -1, message), 1, EXPAND, 0)
				
		@error_window.add(@close_button = Wx::Button.new(self, -1, "Close"), 0, Wx::ALIGN_CENTER, 0)
		evt_button(@close_button) {|event| self.close()}
		show		
	end
end

class MyApp < Wx::App

	def on_init
		BeerXML2BrewTroller.new.show
	end
	
	def on_run
		super
		rescue Exception => e
			if e.message == "exit"
				exit()
			end
			md = Wx::MessageDialog.new(
				nil,
				"Error: #{e.message}",
				"Error",
				Wx::ICON_INFORMATION)
			md.show_modal
			
			retry
		
	end
end

MyApp.new.main_loop()

#Wx::App.run do
#	BeerXML2BrewTroller.new.show
	
#end

