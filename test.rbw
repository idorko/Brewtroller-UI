require 'rubygems'
require 'serialport'

sp = SerialPort.new("COM5", 115200, 8, 1, 0)
sp.read_timeout = 2000
data = sp.readline("\r\n")
sp.print("A\r")
data2 = sp.readline("\r\n")
puts data
puts data2
puts sp.readline("\r\n")
sp.close