require "rubygems"
require "wx"
require "beerxml"
require "BTnic"
include BTnic
include Wx
include BeerXML

class MyFrame < Frame
	def initialize()
		super(nil, -1, 'BeerXML2BrewTroller')
		
		@title_row = BoxSizer.new(HORIZONTAL)	
		@title_row.add_spacer(1)
		@title_row.add(Wx::StaticText.new(self,-1,"BeerXML2BrewTroller"),1 ,EXPAND, 0)
		@import_row = BoxSizer.new(HORIZONTAL)
		@import_row.add_spacer(1)
		
		@import_button = Button.new(self, -1, "Import BeerXML")
		evt_button(@import_button) {|event| my_button_click(event)}
		@import_row.add(@import_button)	
		
		@mash_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
		#@prog_sizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
		@prog_num_sizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
		@prog_num_sizer.add(Wx::StaticText.new(self, -1, "Program Number:"), 0, Wx::ALIGN_CENTER, 0)
		@prog_num_sizer.add(@prog_num = Wx::Choice.new(self, :choices => %w(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)), 0, Wx::ALIGN_CENTER, 0)
		@main_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
		@main_sizer.add(@title_row, 0, Wx::ALIGN_CENTER, 0)
		@main_sizer.add(@prog_num_sizer, 0, Wx::ALIGN_CENTER, 0)
		@main_sizer.add(@mash_sizer, 0, Wx::ALIGN_CENTER, 0)
		@main_sizer.add(@prog_sizer, 0, Wx::ALIGN_CENTER, 0)
		@mash_sizer.add(@port = Wx::TextCtrl.new(self, -1, "Input Serial Port Location."), 1, EXPAND, 0)
		@mash_sizer.add(@download_button = Wx::Button.new(self, -1, "Download to BrewTroller"), 0, Wx::ALIGN_CENTER,0)
		@download_button.enable(false)
		evt_button(@download_button) { |event| download()}
		@main_sizer.add(@import_row, 0, Wx::ALIGN_CENTER, 0)

		@main_sizer.add(@exit_button = Wx::Button.new(self, -1, "Exit"), 0, Wx::ALIGN_CENTER, 0)
		evt_button(@exit_button) {|event| exit()}
		@main_sizer.add(@error = Wx::StaticText.new(self, -1, ""), 1, EXPAND, 0)
		set_sizer @main_sizer
		show
		
	end
	
	def download
		#download mash steps to BrewTroller
		
		#setup BTnic parameters, test connection
		BTnic.set_port(@port.get_value())
		BTnic.set_baud(115200)
		BTnic.get_boil_temp
		
	end	
	
	def my_button_click(event)
		fd = FileDialog.new(self, "Choose a file...", "~/", " ", "*.xml", FD_OPEN)
		fd.show_modal
		
		fn = fd.get_filename()
	 	BeerXML.parse_mash(fn)
	
		@import_button.enable(false)		
	
		@mash_sizer_name = Wx::BoxSizer.new(Wx::HORIZONTAL)
		@mash_sizer_name.add_spacer(1)
		@mash_sizer_name.add(Wx::StaticText.new(self, -1, "Name: #{BeerXML.get_names.to_s}"),1, EXPAND, 0)
		@mash_sizer.add(@mash_sizer_name, 0, Wx::ALIGN_CENTER, 0)

		@mash_sizer_title = Wx::BoxSizer.new(Wx::HORIZONTAL)
		@mash_sizer_title.add_spacer(1)
		@mash_sizer_title.add(Wx::StaticText.new(self, -1, "Mash Steps:"), 1, EXPAND, 0)
		@mash_sizer.add(@mash_sizer_title, 0, Wx::ALIGN_CENTER, 0)
		
		for i in 0..BeerXML.get_mash_temps.size-1
			@mash_sizer.add(Wx::StaticText.new(self, -1, "#{(i+1).to_s}: #{BeerXML.get_mash_temps[i].to_s}\xC2\xB0	#{BeerXML.get_mash_times[i]} Minutes"),1 , EXPAND, 0)
		end
		@mash_sizer.add(Wx::StaticText.new(self, -1, "Sparge Temp: #{BeerXML.get_sparge_temp.to_s}\xC2\xB0"),1 , EXPAND, 0)
		@download_button.enable(true)
		layout
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

class MyApp < App

	def on_init
		MyFrame.new
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


