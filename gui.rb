#!/usr/bin/ruby
$LOAD_PATH.unshift File.dirname($0)
require 'rubygems'
require 'wx'
require 'gnuplot'
require 'ptools'
require 'gui_class'
require 'beerxmlnew'
require 'BTNic'

include BeerXML
include BTnic

class LogFrame < Wx::Frame
	#graph file for usage outside of frame
	@@fn_graph = nil
	
	def get_graph
		@@fn_graph
	end
	
	def initialize(title, baud, port)
		super(nil, :title => title, :size => [640, 510])
		@i = 0.0
		@temperatures = [[],[],[]]
		@x = []	
		
		#save csv file
		fd = Wx::FileDialog.new(self, "Save raw data where?", "~/","data","*.csv", Wx::FD_SAVE)
		fd.show_modal
		fn = fd.get_directory + "\\" +fd.get_filename()	
		f = File.open(fn, 'w')
		f.write("TIME, HLT, MASH, BOIL\n")
		f.close
		
		fd = Wx::FileDialog.new(self, "Save graph where?", "", "output","*.gif", Wx::FD_SAVE)
		fd.show_modal
		fn_graph = fd.get_directory + "\\" + fd.get_filename()	
		@@fn_graph = fn_graph
		#create initial plot
		Gnuplot.open do |gp|	
			Gnuplot::Plot.new( gp ) do |plot|
				#image output
				plot.terminal "gif"
				plot.output File.expand_path(fn_graph, __FILE__)
				#ploting stuff
				plot.xrange "[0:1]"
				plot.title "Brew Session Temperatures"
				plot.ylabel "Temperature (F)"
				plot.xlabel "Time (min)"
				plot.arbitrary_lines << "set grid x y"
				plot.arbitrary_lines << "set mytics 5"
				plot.arbitrary_lines << 'set xlabel "Time (min)"'
				plot.data << Gnuplot::DataSet.new( [[0], [0]] ) {|ds| 
					ds.with = "linespoints"
					ds.title = "HLT"
				}
			end
		end

		#open connection to BT
		BTnic.set_baud(baud)
		BTnic.set_port(port)
		BTnic.open_connection
		
		#set up data log timer
		timer = Wx::Timer.new(self, Wx::ID_ANY)
		evt_timer(timer.id) { |event| log_data(fn, fn_graph)}
		timer.start(30000)
		
		#set up focus event
		evt_set_focus() { |event| load_graph(fn_graph) }
		evt_close() { |event| BTnic.close_connection; self.destroy }
	end
	
	def load_graph(fn)
		#img_file = File.join( File.dirname(__FILE__), fn)
		@image = Wx::Image.new(fn)
		@image = @image.to_bitmap
		self.paint do |dc|
			dc.draw_bitmap(@image,0,0,false)
		end
	end
	
	def log_data(fn, fn_graph)
		#get and process data	
		@temperatures[0] << BTnic.get_temperature("HLT")[2].chop.to_f/100
		@temperatures[1] << BTnic.get_temperature("MASH")[2].chop.to_f/100
		@temperatures[2] << BTnic.get_temperature("BOIL")[2].chop.to_f/100
		@x << @i/2
		File.open(fn, 'a') {|f| f.write("#{@i}, #{@temperatures[0].last}, #{@temperatures[1].last}, #{@temperatures[2].last}\n") }
		@i+=1
		
		#generate plot
		Gnuplot.open do |gp|	
			Gnuplot::Plot.new( gp ) do |plot|
			#image output
			plot.terminal "gif"
			plot.output File.expand_path(fn_graph, __FILE__)
			#ploting stuff
			plot.xrange "[0:#{@temperatures[0].length}]"
			plot.title "Brew Session Temperatures"
			plot.ylabel "Temperature (F)"
			plot.xlabel "Time (min)"
			plot.arbitrary_lines << "set grid x y"
			plot.arbitrary_lines << "set mytics 5"
			plot.arbitrary_lines << 'set xlabel "Time (min)"'
			plot.data = [
				Gnuplot::DataSet.new( [@x, @temperatures[0]] ) {|ds| 
					ds.with = "linespoints"
					ds.title = "HLT"
				},
				Gnuplot::DataSet.new( [@x, @temperatures[1]] ) {|ds| 
					ds.with = "linespoints"
					ds.title = "MASH"
				},
				Gnuplot::DataSet.new( [@x, @temperatures[2]] ) {|ds| 
					ds.with = "linespoints"
					ds.title = "BOIL"
				}
			]			
			end
		end
		#display image
		load_graph(fn_graph)
	end
end
class BeerXML2BrewTroller < TextFrameBase
	
	BAUD = [2400, 4800, 9600, 19200, 38400, 57600, 115200]
	def initialize
		super
		evt_button(load) { |event| import_program() }
		evt_button(download) { |event| download_program() }
		evt_button(upload) { |event| upload_program() }
		evt_button(log) { |event| log_data_window() }
	end
	
	def log_data_window()
		#create log window
			@log_window = LogFrame.new("Temperature Log", BAUD[baud.get_selection], port.get_value )
			@log_window.show
			@log_window.load_graph(@log_window.get_graph)
			timer = Wx::Timer.new(self, Wx::ID_ANY)
			evt_timer(timer.id) { |event| @log_window.load_graph(@log_window.get_graph)}
			timer.start(100)
			@log_window.evt_close { |event| timer.stop; BTnic.close_connection; @log_window.destroy }
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
		download.enable
		upload.enable
		log.enable
	end	
	
	def upload_program()
		download.disable
		upload.disable
		log.disable
		BTnic.set_baud(BAUD[baud.get_selection])
		BTnic.set_port(port.get_value)
		BTnic.open_connection
		settings = BTnic.get_program_settings(prog_choice1.get_selection)
		
		m_textctrl3.value = settings[2].to_s
		doughin_temp.value = settings[3].to_s
		doughin_time.value = settings[4].to_s
		acid_temp.value = settings[5].to_s
		acid_time.value = settings[6].to_s
		protein_temp.value = settings[7].to_s
		protein_time.value = settings[8].to_s
		sacch_temp.value = settings[9].to_s	
		sach_time.value = settings[10].to_s
		sacch2_temp.value = settings[11].to_s
		sacch2_time.value = settings[12].to_s
		mash_out_temp.value = settings[13].to_s	
		mash_out_time.value = settings[14].to_s
		sparge_temp.value = settings[15].to_s
		hlt_setpoint1.value = settings[16].to_s
		batch_vol.value = (settings[17].to_i/1000000).to_s
		grain_weight.value = (settings[18].to_i/1000000).to_s
		boil_time.value = settings[19].to_s
		hlt_setpoint1.value = settings[20].to_s #mash ratio
		pitch_temp.value = settings[21].to_s
		boil_additions.value = settings[22].to_s
		hlt_setpoint2.selection = settings[23].to_i
		
		BTnic.close_connection
		download.enable
		upload.enable
		log.enable
	end
	
	def download_program()
		log.disable
		download.disable
		upload.disable
		#run one code to flush serial buffer
		#determine HLT or MASH
		#parse control string
		control = "#{m_textctrl3.get_value}\t#{doughin_temp.get_value()}\t#{doughin_time.get_value()}\t#{acid_temp.get_value}\t#{acid_time.get_value}\t#{protein_temp.get_value()}\t#{protein_time.get_value}\t#{sacch_temp.get_value}\t#{sach_time.get_value}\t#{sacch2_temp.get_value}\t#{sacch2_time.get_value}\t#{mash_out_temp.get_value}\t#{mash_out_time.get_value}\t#{sparge_temp.get_value}\t#{hlt_setpoint.get_value}\t#{batch_vol.get_value+"000"}\t#{grain_weight.get_value+"000"}\t#{boil_time.get_value}\t#{hlt_setpoint1.get_value}\t#{pitch_temp.get_value}\t#{boil_additions.get_value}\t#{hlt_setpoint2.get_selection}"

		#download to brewtroller
		BTnic.set_baud(BAUD[baud.get_selection])
		BTnic.set_port(port.get_value)
		BTnic.open_connection
	#	BTnic.get_boil_temp()
		BTnic.set_program_settings(prog_choice1.get_selection, control)
		
		download.enable
		upload.enable
		log.enable
		BTnic.close_connection
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

