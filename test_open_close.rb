require "./beerxmlnew.rb"
require "./BTnic.rb"
require "gnuplot"
include BTnic
include BeerXML

#deal with initializations
BTnic.set_port(ARGV[0])
puts BTnic.get_port
BTnic.set_baud(115200)
puts BTnic.get_baud
BTnic.open_connection
			#hlt, mash, boil
temperatures = [[],[],[]]
x = []
#collect data
for i in 0..4
	puts i
	temperatures[0] << BTnic.get_temperature("HLT")[2].chop.to_f
	temperatures[1] << BTnic.get_temperature("MASH")[2].chop.to_f 
	temperatures[2] << BTnic.get_temperature("BOIL")[2].chop.to_f
	x<<i
	sleep(1)
end

#write data to file
f = File.open("data.csv", 'w')
f.write("HLT, MASH, BOIL\n")
for i in 0..temperatures[0].length-1 
	f.write("#{temperatures[0][i]}, #{temperatures[1][i]}, #{temperatures[2][i]}\n")
end

Gnuplot.open do |gp|
	Gnuplot::Plot.new( gp ) do |plot|
		#image output
		plot.terminal "gif"
		#File.open("output.gif", 'w')
		puts File.expand_path("../output.gif", __FILE__)
		plot.output File.expand_path("../output.gif", __FILE__)
		#ploting stuff
		plot.xrange "[0:5]"
		plot.title "Brew Session Temperatures"
		plot.ylabel "Temperature (F)"
		plot.xlabel "Time (min)"
		plot.data = [
			Gnuplot::DataSet.new( [x, temperatures[0]] ) {|ds| 
			ds.with = "linespoints"
			ds.title = "HLT"
		},
			Gnuplot::DataSet.new( [x, temperatures[1]] ) {|ds| 
			ds.with = "linespoints"
			ds.title = "MASH"
		},
		Gnuplot::DataSet.new( [x, temperatures[2]] ) {|ds| 
			ds.with = "linespoints"
			ds.title = "BOIL"
		}
		]
			
	end
end
puts "Done"
