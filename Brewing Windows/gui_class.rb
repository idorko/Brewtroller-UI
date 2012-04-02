
# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: noname.xrc 
# Generated at: Fri Feb 10 16:21:59 -0700 2012

class TextFrameBase < Wx::Frame
	
	attr_reader :m_title, :m_staticline1, :load, :m_staticline3,
              :m_statictext17, :m_textctrl3, :m_statictext20,
              :temp_label, :m_statictext22, :m_statictext23,
              :doughin_temp, :doughin_time, :m_statictext24,
              :acid_temp, :acid_time, :m_statictext25, :protein_temp,
              :protein_time, :m_statictext26, :sacch_temp, :sach_time,
              :m_statictext27, :sacch2_temp, :sacch2_time,
              :m_statictext28, :mash_out_temp, :mash_out_time,
              :sparge_label, :sparge_temp, :sparge_label1,
              :hlt_setpoint, :batch_vol_label, :batch_vol,
              :grain_label, :grain_weight, :sparge_label11,
              :boil_time, :sparge_label12, :hlt_setpoint1,
              :sparge_label13, :pitch_temp, :sparge_label14,
              :boil_additions, :sparge_label15, :hlt_setpoint2,
              :m_staticline4, :m_statictext51, :port, :m_statictext231, :baud, 
              :m_statictext291, :prog_choice1, :upload, :download 
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load(File.join(File.dirname(__FILE__), "noname.xrc"))
		xml.load_frame_subclass(self, parent, "MainFrame")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@m_title = finder.call("m_title")
		@m_staticline1 = finder.call("m_staticline1")
		@load = finder.call("load")
		@m_staticline3 = finder.call("m_staticline3")
		@m_statictext17 = finder.call("m_staticText17")
		@m_textctrl3 = finder.call("m_textCtrl3")
		@m_statictext20 = finder.call("m_staticText20")
		@temp_label = finder.call("temp_label")
		@m_statictext22 = finder.call("m_staticText22")
		@m_statictext23 = finder.call("m_staticText23")
		@doughin_temp = finder.call("doughin_temp")
		@doughin_time = finder.call("doughin_time")
		@m_statictext24 = finder.call("m_staticText24")
		@acid_temp = finder.call("acid_temp")
		@acid_time = finder.call("acid_time")
		@m_statictext25 = finder.call("m_staticText25")
		@protein_temp = finder.call("protein_temp")
		@protein_time = finder.call("protein_time")
		@m_statictext26 = finder.call("m_staticText26")
		@sacch_temp = finder.call("sacch_temp")
		@sach_time = finder.call("sach_time")
		@m_statictext27 = finder.call("m_staticText27")
		@sacch2_temp = finder.call("sacch2_temp")
		@sacch2_time = finder.call("sacch2_time")
		@m_statictext28 = finder.call("m_staticText28")
		@mash_out_temp = finder.call("mash_out_temp")
		@mash_out_time = finder.call("mash_out_time")
		@sparge_label = finder.call("sparge_label")
		@sparge_temp = finder.call("sparge_temp")
		@sparge_label1 = finder.call("sparge_label1")
		@hlt_setpoint = finder.call("hlt_setpoint")
		@batch_vol_label = finder.call("batch_vol_label")
		@batch_vol = finder.call("batch_vol")
		@grain_label = finder.call("grain_label")
		@grain_weight = finder.call("grain_weight")
		@sparge_label11 = finder.call("sparge_label11")
		@boil_time = finder.call("boil_time")
		@sparge_label12 = finder.call("sparge_label12")
		@hlt_setpoint1 = finder.call("hlt_setpoint1")
		@sparge_label13 = finder.call("sparge_label13")
		@pitch_temp = finder.call("pitch_temp")
		@sparge_label14 = finder.call("sparge_label14")
		@boil_additions = finder.call("boil_additions")
		@sparge_label15 = finder.call("sparge_label15")
		@hlt_setpoint2 = finder.call("hlt_setpoint2")
		@m_staticline4 = finder.call("m_staticline4")
		@m_statictext51 = finder.call("m_staticText51")
		@port = finder.call("port")
		@m_statictext231 = finder.call("m_staticText231")
		@baud = finder.call("baud")
		@m_statictext291 = finder.call("m_staticText291")
		@prog_choice1 = finder.call("prog_choice1")
		@download = finder.call("download")
		@upload = finder.call("upload")

		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end


