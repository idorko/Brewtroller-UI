# License, not of this script, but of the application it contains:
#
# Copyright Erik Veenstra <rubywebdialogs@erikveen.dds.nl>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA 02111-1307 USA.

# License of this script, not of the application it contains:
#
# Copyright Erik Veenstra <tar2rubyscript@erikveen.dds.nl>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA 02111-1307 USA.

# Parts of this code are based on code from Thomas Hurst
# <tom@hur.st>.

# Tar2RubyScript constants

unless defined?(BLOCKSIZE)
  ShowContent	= ARGV.include?("--tar2rubyscript-list")
  JustExtract	= ARGV.include?("--tar2rubyscript-justextract")
  ToTar		= ARGV.include?("--tar2rubyscript-totar")
  Preserve	= ARGV.include?("--tar2rubyscript-preserve")
end

ARGV.concat	[]

ARGV.delete_if{|arg| arg =~ /^--tar2rubyscript-/}

ARGV << "--tar2rubyscript-preserve"	if Preserve

# Tar constants

unless defined?(BLOCKSIZE)
  BLOCKSIZE		= 512

  NAMELEN		= 100
  MODELEN		= 8
  UIDLEN		= 8
  GIDLEN		= 8
  CHKSUMLEN		= 8
  SIZELEN		= 12
  MAGICLEN		= 8
  MODTIMELEN		= 12
  UNAMELEN		= 32
  GNAMELEN		= 32
  DEVLEN		= 8

  TMAGIC		= "ustar"
  GNU_TMAGIC		= "ustar  "
  SOLARIS_TMAGIC	= "ustar\00000"

  MAGICS		= [TMAGIC, GNU_TMAGIC, SOLARIS_TMAGIC]

  LF_OLDFILE		= '\0'
  LF_FILE		= '0'
  LF_LINK		= '1'
  LF_SYMLINK		= '2'
  LF_CHAR		= '3'
  LF_BLOCK		= '4'
  LF_DIR		= '5'
  LF_FIFO		= '6'
  LF_CONTIG		= '7'

  GNUTYPE_DUMPDIR	= 'D'
  GNUTYPE_LONGLINK	= 'K'	# Identifies the *next* file on the tape as having a long linkname.
  GNUTYPE_LONGNAME	= 'L'	# Identifies the *next* file on the tape as having a long name.
  GNUTYPE_MULTIVOL	= 'M'	# This is the continuation of a file that began on another volume.
  GNUTYPE_NAMES		= 'N'	# For storing filenames that do not fit into the main header.
  GNUTYPE_SPARSE	= 'S'	# This is for sparse files.
  GNUTYPE_VOLHDR	= 'V'	# This file is a tape/volume header.  Ignore it on extraction.
end

class Dir
  def self.rm_rf(entry)
    File.chmod(0755, entry)

    if File.ftype(entry) == "directory"
      pdir	= Dir.pwd

      Dir.chdir(entry)
        Dir.new(".").each do |e|
          Dir.rm_rf(e)	if not [".", ".."].include?(e)
        end
      Dir.chdir(pdir)

      begin
        Dir.delete(entry)
      rescue => e
        $stderr.puts e.message
      end
    else
      begin
        File.delete(entry)
      rescue => e
        $stderr.puts e.message
      end
    end
  end
end

class Reader
  def initialize(filehandle)
    @fp	= filehandle
  end

  def extract
    each do |entry|
      entry.extract
    end
  end

  def list
    each do |entry|
      entry.list
    end
  end

  def each
    @fp.rewind

    while entry	= next_entry
      yield(entry)
    end
  end

  def next_entry
    buf	= @fp.read(BLOCKSIZE)

    if buf.length < BLOCKSIZE or buf == "\000" * BLOCKSIZE
      entry	= nil
    else
      entry	= Entry.new(buf, @fp)
    end

    entry
  end
end

class Entry
  attr_reader(:header, :data)

  def initialize(header, fp)
    @header	= Header.new(header)

    readdata =
    lambda do |header|
      padding	= (BLOCKSIZE - (header.size % BLOCKSIZE)) % BLOCKSIZE
      @data	= fp.read(header.size)	if header.size > 0
      dummy	= fp.read(padding)	if padding > 0
    end

    readdata.call(@header)

    if @header.longname?
      gnuname		= @data[0..-2]

      header		= fp.read(BLOCKSIZE)
      @header		= Header.new(header)
      @header.name	= gnuname

      readdata.call(@header)
    end
  end

  def extract
    if not @header.name.empty?
      if @header.dir?
        begin
          Dir.mkdir(@header.name, @header.mode)
        rescue SystemCallError => e
          $stderr.puts "Couldn't create dir #{@header.name}: " + e.message
        end
      elsif @header.file?
        begin
          File.open(@header.name, "wb") do |fp|
            fp.write(@data)
            fp.chmod(@header.mode)
          end
        rescue => e
          $stderr.puts "Couldn't create file #{@header.name}: " + e.message
        end
      else
        $stderr.puts "Couldn't handle entry #{@header.name} (flag=#{@header.linkflag.inspect})."
      end

      #File.chown(@header.uid, @header.gid, @header.name)
      #File.utime(Time.now, @header.mtime, @header.name)
    end
  end

  def list
    if not @header.name.empty?
      if @header.dir?
        $stderr.puts "d %s" % [@header.name]
      elsif @header.file?
        $stderr.puts "f %s (%s)" % [@header.name, @header.size]
      else
        $stderr.puts "Couldn't handle entry #{@header.name} (flag=#{@header.linkflag.inspect})."
      end
    end
  end
end

class Header
  attr_reader(:name, :uid, :gid, :size, :mtime, :uname, :gname, :mode, :linkflag)
  attr_writer(:name)

  def initialize(header)
    fields	= header.unpack('A100 A8 A8 A8 A12 A12 A8 A1 A100 A8 A32 A32 A8 A8')
    types	= ['str', 'oct', 'oct', 'oct', 'oct', 'time', 'oct', 'str', 'str', 'str', 'str', 'str', 'oct', 'oct']

    begin
      converted	= []
      while field = fields.shift
        type	= types.shift

        case type
        when 'str'	then converted.push(field)
        when 'oct'	then converted.push(field.oct)
        when 'time'	then converted.push(Time::at(field.oct))
        end
      end

      @name, @mode, @uid, @gid, @size, @mtime, @chksum, @linkflag, @linkname, @magic, @uname, @gname, @devmajor, @devminor	= converted

      @name.gsub!(/^\.\//, "")

      @raw	= header
    rescue ArgumentError => e
      raise "Couldn't determine a real value for a field (#{field})"
    end

    raise "Magic header value #{@magic.inspect} is invalid."	if not MAGICS.include?(@magic)

    @linkflag	= LF_FILE			if @linkflag == LF_OLDFILE or @linkflag == LF_CONTIG
    @linkflag	= LF_DIR			if @name[-1] == '/' and @linkflag == LF_FILE
    @linkname	= @linkname[1,-1]		if @linkname[0] == '/'
    @size	= 0				if @size < 0
    @name	= @linkname + '/' + @name	if @linkname.size > 0
  end

  def file?
    @linkflag == LF_FILE
  end

  def dir?
    @linkflag == LF_DIR
  end

  def longname?
    @linkflag == GNUTYPE_LONGNAME
  end
end

class Content
  @@count	= 0	unless defined?(@@count)

  def initialize
    @archive	= File.open(File.expand_path(__FILE__), "rb"){|f| f.read}.gsub(/\r/, "").split(/\n\n/)[-1].split("\n").collect{|s| s[2..-1]}.join("\n").unpack("m").shift
    temp	= ENV["TEMP"]
    temp	= "/tmp"	if temp.nil?
    temp	= File.expand_path(temp)
    @tempfile	= "#{temp}/tar2rubyscript.f.#{Process.pid}.#{@@count += 1}"
  end

  def list
    begin
      File.open(@tempfile, "wb")	{|f| f.write @archive}
      File.open(@tempfile, "rb")	{|f| Reader.new(f).list}
    ensure
      File.delete(@tempfile)
    end

    self
  end

  def cleanup
    @archive	= nil

    self
  end
end

class TempSpace
  @@count	= 0	unless defined?(@@count)

  def initialize
    @archive	= File.open(File.expand_path(__FILE__), "rb"){|f| f.read}.gsub(/\r/, "").split(/\n\n/)[-1].split("\n").collect{|s| s[2..-1]}.join("\n").unpack("m").shift
    @olddir	= Dir.pwd
    temp	= ENV["TEMP"]
    temp	= "/tmp"	if temp.nil?
    temp	= File.expand_path(temp)
    @tempfile	= "#{temp}/tar2rubyscript.f.#{Process.pid}.#{@@count += 1}"
    @tempdir	= "#{temp}/tar2rubyscript.d.#{Process.pid}.#{@@count}"

    @@tempspace	= self

    @newdir	= @tempdir

    @touchthread =
    Thread.new do
      loop do
        sleep 60*60

        touch(@tempdir)
        touch(@tempfile)
      end
    end
  end

  def extract
    Dir.rm_rf(@tempdir)	if File.exists?(@tempdir)
    Dir.mkdir(@tempdir)

    newlocation do

		# Create the temp environment.

      File.open(@tempfile, "wb")	{|f| f.write @archive}
      File.open(@tempfile, "rb")	{|f| Reader.new(f).extract}

		# Eventually look for a subdirectory.

      entries	= Dir.entries(".")
      entries.delete(".")
      entries.delete("..")

      if entries.length == 1
        entry	= entries.shift.dup
        if File.directory?(entry)
          @newdir	= "#{@tempdir}/#{entry}"
        end
      end
    end

		# Remember all File objects.

    @ioobjects	= []
    ObjectSpace::each_object(File) do |obj|
      @ioobjects << obj
    end

    at_exit do
      @touchthread.kill

		# Close all File objects, opened in init.rb .

      ObjectSpace::each_object(File) do |obj|
        obj.close	if (not obj.closed? and not @ioobjects.include?(obj))
      end

		# Remove the temp environment.

      Dir.chdir(@olddir)

      Dir.rm_rf(@tempfile)
      Dir.rm_rf(@tempdir)
    end

    self
  end

  def cleanup
    @archive	= nil

    self
  end

  def touch(entry)
    entry	= entry.gsub!(/[\/\\]*$/, "")	unless entry.nil?

    return	unless File.exists?(entry)

    if File.directory?(entry)
      pdir	= Dir.pwd

      begin
        Dir.chdir(entry)

        begin
          Dir.new(".").each do |e|
            touch(e)	unless [".", ".."].include?(e)
          end
        ensure
          Dir.chdir(pdir)
        end
      rescue Errno::EACCES => error
        $stderr.puts error
      end
    else
      File.utime(Time.now, File.mtime(entry), entry)
    end
  end

  def oldlocation(file="")
    if block_given?
      pdir	= Dir.pwd

      Dir.chdir(@olddir)
        res	= yield
      Dir.chdir(pdir)
    else
      res	= File.expand_path(file, @olddir)	if not file.nil?
    end

    res
  end

  def newlocation(file="")
    if block_given?
      pdir	= Dir.pwd

      Dir.chdir(@newdir)
        res	= yield
      Dir.chdir(pdir)
    else
      res	= File.expand_path(file, @newdir)	if not file.nil?
    end

    res
  end

  def self.oldlocation(file="")
    if block_given?
      @@tempspace.oldlocation { yield }
    else
      @@tempspace.oldlocation(file)
    end
  end

  def self.newlocation(file="")
    if block_given?
      @@tempspace.newlocation { yield }
    else
      @@tempspace.newlocation(file)
    end
  end
end

class Extract
  @@count	= 0	unless defined?(@@count)

  def initialize
    @archive	= File.open(File.expand_path(__FILE__), "rb"){|f| f.read}.gsub(/\r/, "").split(/\n\n/)[-1].split("\n").collect{|s| s[2..-1]}.join("\n").unpack("m").shift
    temp	= ENV["TEMP"]
    temp	= "/tmp"	if temp.nil?
    @tempfile	= "#{temp}/tar2rubyscript.f.#{Process.pid}.#{@@count += 1}"
  end

  def extract
    begin
      File.open(@tempfile, "wb")	{|f| f.write @archive}
      File.open(@tempfile, "rb")	{|f| Reader.new(f).extract}
    ensure
      File.delete(@tempfile)
    end

    self
  end

  def cleanup
    @archive	= nil

    self
  end
end

class MakeTar
  def initialize
    @archive	= File.open(File.expand_path(__FILE__), "rb"){|f| f.read}.gsub(/\r/, "").split(/\n\n/)[-1].split("\n").collect{|s| s[2..-1]}.join("\n").unpack("m").shift
    @tarfile	= File.expand_path(__FILE__).gsub(/\.rbw?$/, "") + ".tar"
  end

  def extract
    File.open(@tarfile, "wb")	{|f| f.write @archive}

    self
  end

  def cleanup
    @archive	= nil

    self
  end
end

def oldlocation(file="")
  if block_given?
    TempSpace.oldlocation { yield }
  else
    TempSpace.oldlocation(file)
  end
end

def newlocation(file="")
  if block_given?
    TempSpace.newlocation { yield }
  else
    TempSpace.newlocation(file)
  end
end

if ShowContent
  Content.new.list.cleanup
elsif JustExtract
  Extract.new.extract.cleanup
elsif ToTar
  MakeTar.new.extract.cleanup
else
  TempSpace.new.extract.cleanup

  $:.unshift(newlocation)
  $:.push(oldlocation)

  s	= ENV["PATH"].dup
  if Dir.pwd[1..2] == ":/"	# Hack ???
    s << ";#{newlocation.gsub(/\//, "\\")}"
    s << ";#{oldlocation.gsub(/\//, "\\")}"
  else
    s << ":#{newlocation}"
    s << ":#{oldlocation}"
  end
  ENV["PATH"]	= s

  TAR2RUBYSCRIPT	= true	unless defined?(TAR2RUBYSCRIPT)

  newlocation do
    if __FILE__ == $0
      $0.replace(File.expand_path("./init.rb"))

      if File.file?("./init.rb")
        load File.expand_path("./init.rb")
      else
        $stderr.puts "%s doesn't contain an init.rb ." % __FILE__
      end
    else
      if File.file?("./init.rb")
        load File.expand_path("./init.rb")
      end
    end
  end
end


# cnVieXdlYmRpYWxvZ3MvAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAADAwMDA3NTUAMDAwMTc1MAAwMDAxNzUwADAwMDAwMDAwMDAw
# ADEwMjUwMzIwNjIxADAxMzc3NQAgNQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3RhciAgAGVyaWsA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZXJpawAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAwMDAwMDAwADAwMDAwMDAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAABydWJ5d2ViZGlhbG9ncy9pbml0LnJiAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAw
# MDE3NTAAMDAwMDAwMDI2NDMAMTAyNTAzMjA2MjEAMDE1Mjc1ACAwAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAHVzdGFyICAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABl
# cmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAw
# MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgInJi
# Y29uZmlnIgpyZXF1aXJlICJmdG9vbHMiCgppZiBfX0ZJTEVfXyA9PSAkMAoK
# ICBEaXIuY2hkaXIoRmlsZS5kaXJuYW1lKCQwKSkKCiAgRnJvbURpcnMJPSBb
# Ii4iLCAiLi9saWIiLCAiLi9ydWJ5bGliL2xpYiJdCiAgVG9EaXIJCT0gQ29u
# ZmlnOjpDT05GSUdbInNpdGVsaWJkaXIiXSArICIvZXYiCgogIEZpbGUubWtw
# YXRoKFRvRGlyKQlpZiBub3QgRmlsZS5kaXJlY3Rvcnk/KFRvRGlyKQoKICBG
# cm9tRGlycy5lYWNoIGRvIHxmcm9tZGlyfAogICAgZnJvbWRpcgk9IERpci5w
# d2QJaWYgZnJvbWRpciA9PSAiLiIKCiAgICBpZiBGaWxlLmRpcmVjdG9yeT8o
# ZnJvbWRpcikKICAgICAgRGlyLm5ldyhmcm9tZGlyKS5lYWNoIGRvIHxmaWxl
# fAogICAgICAgIGlmIGZpbGUgPX4gL1wubGliXC5yYiQvCiAgICAgICAgICBm
# cm9tZmlsZQk9IGZyb21kaXIgKyAiLyIgKyBmaWxlCiAgICAgICAgICB0b2Zp
# bGUJCT0gVG9EaXIgKyAiLyIgKyBmaWxlLnN1YigvXC5saWJcLnJiLywgIi5y
# YiIpCgogICAgICAgICAgcHJpbnRmICIlcyAtPiAlc1xuIiwgZnJvbWZpbGUs
# IHRvZmlsZQoKICAgICAgICAgIEZpbGUuZGVsZXRlKHRvZmlsZSkJaWYgRmls
# ZS5maWxlPyh0b2ZpbGUpCgogICAgICAgICAgRmlsZS5vcGVuKHRvZmlsZSwg
# InciKSB7fGZ8IGYucHV0cyBGaWxlLm5ldyhmcm9tZmlsZSkucmVhZGxpbmVz
# fQogICAgICAgIGVuZAogICAgICBlbmQKICAgIGVuZAogIGVuZAoKZWxzZQoK
# ICBGcm9tRGlycwk9IFsiLiIsICIuL2xpYiIsICIuL3J1YnlsaWIvbGliIl0K
# ICBUb0RpcgkJPSAiLi9ldiIKCiAgRmlsZS5ta3BhdGgoVG9EaXIpCWlmIG5v
# dCBGaWxlLmRpcmVjdG9yeT8oVG9EaXIpCgogIEZyb21EaXJzLmVhY2ggZG8g
# fGZyb21kaXJ8CiAgICBmcm9tZGlyCT0gRGlyLnB3ZAlpZiBmcm9tZGlyID09
# ICIuIgoKICAgIGlmIEZpbGUuZGlyZWN0b3J5Pyhmcm9tZGlyKQogICAgICBE
# aXIubmV3KGZyb21kaXIpLmVhY2ggZG8gfGZpbGV8CiAgICAgICAgaWYgZmls
# ZSA9fiAvXC5saWJcLnJiJC8KICAgICAgICAgIGZyb21maWxlCT0gZnJvbWRp
# ciArICIvIiArIGZpbGUKICAgICAgICAgIHRvZmlsZQk9IFRvRGlyICsgIi8i
# ICsgZmlsZS5zdWIoL1wubGliXC5yYi8sICIucmIiKQoKICAgICAgICAgICNw
# cmludGYgIiVzIC0+ICVzXG4iLCBmcm9tZmlsZSwgdG9maWxlCgogICAgICAg
# ICAgRmlsZS5kZWxldGUodG9maWxlKQlpZiBGaWxlLmZpbGU/KHRvZmlsZSkK
# CiAgICAgICAgICBGaWxlLm9wZW4odG9maWxlLCAidyIpIHt8ZnwgZi5wdXRz
# IEZpbGUubmV3KGZyb21maWxlKS5yZWFkbGluZXN9CiAgICAgICAgZW5kCiAg
# ICAgIGVuZAogICAgZW5kCiAgZW5kCgogIG9sZGxvY2F0aW9uIGRvCiAgICBm
# aWxlCT0gbmV3bG9jYXRpb24oImF1dG9yZXF1aXJlLnJiIikKCiAgICBsb2Fk
# IGZpbGUJaWYgRmlsZS5maWxlPyhmaWxlKQogIGVuZAoKZW5kCgAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJ1Ynl3
# ZWJkaWFsb2dzL0xJQ0VOU0UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAwMDAwNjQ0ADAwMDE3NTAAMDAwMTc1MAAwMDAwMDAwMTI3NgAxMDI1
# MDMyMDYyMQAwMTUwMTAAIDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdXN0YXIgIABlcmlrAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAMDAwMDAwMAAwMDAwMDAwAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAIyBDb3B5cmlnaHQgRXJpayBWZWVuc3RyYSA8cnVieXdl
# YmRpYWxvZ3NAZXJpa3ZlZW4uZGRzLm5sPgojIAojIFRoaXMgcHJvZ3JhbSBp
# cyBmcmVlIHNvZnR3YXJlOyB5b3UgY2FuIHJlZGlzdHJpYnV0ZSBpdCBhbmQv
# b3IKIyBtb2RpZnkgaXQgdW5kZXIgdGhlIHRlcm1zIG9mIHRoZSBHTlUgR2Vu
# ZXJhbCBQdWJsaWMgTGljZW5zZSwKIyB2ZXJzaW9uIDIsIGFzIHB1Ymxpc2hl
# ZCBieSB0aGUgRnJlZSBTb2Z0d2FyZSBGb3VuZGF0aW9uLgojIAojIFRoaXMg
# cHJvZ3JhbSBpcyBkaXN0cmlidXRlZCBpbiB0aGUgaG9wZSB0aGF0IGl0IHdp
# bGwgYmUKIyB1c2VmdWwsIGJ1dCBXSVRIT1VUIEFOWSBXQVJSQU5UWTsgd2l0
# aG91dCBldmVuIHRoZSBpbXBsaWVkCiMgd2FycmFudHkgb2YgTUVSQ0hBTlRB
# QklMSVRZIG9yIEZJVE5FU1MgRk9SIEEgUEFSVElDVUxBUgojIFBVUlBPU0Uu
# IFNlZSB0aGUgR05VIEdlbmVyYWwgUHVibGljIExpY2Vuc2UgZm9yIG1vcmUg
# ZGV0YWlscy4KIyAKIyBZb3Ugc2hvdWxkIGhhdmUgcmVjZWl2ZWQgYSBjb3B5
# IG9mIHRoZSBHTlUgR2VuZXJhbCBQdWJsaWMKIyBMaWNlbnNlIGFsb25nIHdp
# dGggdGhpcyBwcm9ncmFtOyBpZiBub3QsIHdyaXRlIHRvIHRoZSBGcmVlCiMg
# U29mdHdhcmUgRm91bmRhdGlvbiwgSW5jLiwgNTkgVGVtcGxlIFBsYWNlLCBT
# dWl0ZSAzMzAsCiMgQm9zdG9uLCBNQSAwMjExMS0xMzA3IFVTQS4KAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AHJ1Ynl3ZWJkaWFsb2dzL1JFQURNRQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAwMDAwNjQ0ADAwMDE3NTAAMDAwMTc1MAAwMDAwMDAwMDE0
# MAAxMDI1MDMyMDYyMQAwMTQ2NTAAIDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdXN0YXIgIABlcmlr
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGVyaWsAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAMDAwMDAwMAAwMDAwMDAwAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAIFVzYWdlOiBydWJ5IGluc3RhbGwucmIKCkZv
# ciBtb3JlIGluZm9ybWF0aW9uLCBzZWUKaHR0cDovL3d3dy5lcmlrdmVlbi5k
# ZHMubmwvcnVieXdlYmRpYWxvZ3MvIC4KAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABydWJ5d2ViZGlh
# bG9ncy9hdXRvcmVxdWlyZS5yYgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# MDAwMDY0NAAwMDAxNzUwADAwMDE3NTAAMDAwMDAwMDAwMzYAMTAyNTAzMjA2
# MjEAMDE2NjY2ACAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAAZXJpawAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAABlcmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAADAwMDAwMDAAMDAwMDAwMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAHJlcXVpcmUgbmV3bG9jYXRpb24oImV2L3J3ZCIpCgAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcnVieXdlYmRpYWxvZ3MvQ0hBTkdF
# TE9HAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDA2NDQAMDAw
# MTc1MAAwMDAxNzUwADAwMDAwMDA2NzM3ADEwMjUwMzIwNjIxADAxNTIyNAAg
# MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAB1c3RhciAgAGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwMDAw
# ADAwMDAwMDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tCgowLjIuMCAtIDA0LjA2LjIwMDUKCiogQWRkZWQg
# YmV0dGVyIGJyb3dzZXIgZGV0ZWN0aW9uIG9uIEN5Z3dpbi4KCiogQWRkZWQg
# bWltZSBzdXBwb3J0IGZvciByd2RfZmlsZXMvKiAoaGFyZCBjb2RlZCwgZm9y
# IG5vdy4uLikKCiogUldEaWFsb2cjc2VydmUgbm93IHN0b3BzIHRoZSBhcHBs
# aWNhdGlvbiB3aGVuIHRoZSBhcHBsaWNhdGlvbgogIGlzIGJlaW5nIHdyYXBw
# ZWQgYnkgUnVieVNjcmlwdDJFeGUuIEZpeGVkIGEgYnVnIGNvbmNlcm5pbmcK
# ICB0aGUgZGV0ZWN0aW9uIG9mIGNvbmZpZ3VyYXRpb24gZmlsZXMuCgoqIEFk
# ZGVkIEFycmF5I3J3ZF90YWJsZS4KCiogQWRkZWQgUldEaWFsb2cjdGV4dC4K
# CiogQWRkZWQgUldEaWFsb2cjdGltZW91dC4KCiogSSBjaGFuZ2VkIGEgbG90
# IG9mIHNtYWxsIG90aGVyIHRoaW5ncyB3aGljaCBhcmUgcHJvYmFibHkgbm90
# CiAgd29ydGggbWVudGlvbmluZyBpbmRpdmlkdWFsbHksIGJ1dCBlbmhhbmNl
# IHRoZSB0b3RhbCAiZmVlbCIKICBvZiBSdWJ5V2ViRGlhbG9ncy4KCi0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0KCjAuMS4yIC0gMTYuMTIuMjAwNAoKKiBBZGRlZCBy
# ZWZyZXNoIHRvIDx3aW5kb3c+LgoKKiBBZGRlZCB3aWR0aCBhbmQgaGVpZ2h0
# IHRvIDxpbWFnZT4uCgoqIEFkZGVkIHRoZSAoZXhwZXJpbWVudGFsKSBwcm9n
# cmVzcyBiYXIuCgoqIEZpeGVkIGEgYnVnIGNvbmNlcm5pbmcgYSBmcm96ZW4g
# c3RyaW5nICggRU5WWyJSV0RCUk9XU0VSIl0pLgoKKiBGaXhlZCB0aGUgaGFu
# ZGxpbmcgb2Ygc3BhY2VzIGluIEVOVlsiUldEQlJPV1NFUiJdIHVuZGVyCiAg
# Q3lnd2luLgoKLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQoKMC4xLjEgLSAwNS4xMi4y
# MDA0CgoqIEFkZGluZyB0aGUga2V5L3ZhbHVlcyBpbiB0aGUgY29uZmlndXJh
# dGlvbiBmaWxlIHRvIEVOViBpcwogIG9ubHkgZG9uZSBpZiBFTlYgZG9lc24n
# dCBhbHJlYWR5IGluY2x1ZGUgdGhlIGtleS4KCiogQ29ycmVjdGVkIHRoZSBo
# YW5kbGluZyBvZiAlMSBpbiBFTlZbIlJXREJST1dTRVIiXS4KCiogQ29ycmVj
# dGVkIHRoZSBoYW5kbGluZyBvZiBodHRwOi8vbG9jYWxob3N0Ojc3MDEgKG5v
# IGZpbmFsIC8pLgoKKiBSZW5hbWVkIHRoZSBlbWJlZGRlZCBwaXhlbC5naWYg
# dG8gcndkX3BpeGVsLmdpZi4KCiogUmVtb3ZlZCB0aGUgZGVmaW5pdGlvbiBv
# ZiB0aGUgKHdlc3Rlcm4pIGNoYXJhY3RlciBzZXQgaW4gdGhlCiAgdGVtcGxh
# dGVzLgoKLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQoKMC4xLjAgLSAyOC4xMS4yMDA0
# CgoqIEFkZGVkIGJyb3dzZXIgZGV0ZWN0aW9uIGZvciBMaW51eC4KCiogQWRk
# ZWQgdGhlbWUgaGFuZGxpbmcuCgoqIEFkZGVkIDxwYW5lbD4uCgoqIEFkZGVk
# IGFsdCB0byA8aW1hZ2U+LgoKKiBDaGFuZ2VkIHRoZSBsYXlvdXQgb2YgdGFi
# cy4KCi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KCjAuMC4xMSAtIDAzLjA5LjIwMDQK
# CiogQWRkZWQgYSBkaWZmZXJlbnQgdGVtcGxhdGUgZm9yIFBEQSdzIGFuZCB0
# aGUgKGV4cGVyaW1lbnRhbCkKICBkZXRlY3Rpb24gb2YgUERBJ3MuCgoqIEFk
# ZGVkIGZpbGVuYW1lIGhhbmRsaW5nIGZvciBkb3dubG9hZC4KCi0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0KCjAuMC4xMCAtIDIxLjA4LjIwMDQKCiogU2Vzc2lvbi1p
# ZHMgYXJlIG5vdyBzdG9yZWQgaW4gY29va2llcywgaW4gc3RlYWQgb2YgaW4g
# aGlkZGVuCiAgZm9ybSBmaWVsZHMuCgoqIEFkZGVkIGRvd25sb2FkLgoKLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLQoKMC4wLjkgLSAxNS4wNS4yMDA0CgoqIERlZmF1
# bHQgcG9ydCBpc24ndCAxMjM0IGFueW1vcmUsIGJ1dCBvbmUgaW4gdGhlIHJh
# bmdlCiAgNzcwMS03NzA5LgoKKiBDcmVhdGVkIFJXRFJlY29ubmVjdC4KCiog
# QWRkZWQgZ3N1YigvJXBvcnQlLywgcG9ydC50b19zKSB0byBFTlZbIlJXREJS
# T1dTRVIiXS4KCiogQ2hhbmdlZCB0aGUgY2FsbCB0byBIYXNoI3J3ZF90YWJs
# ZS4KCi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KCjAuMC44IC0gMDUuMDUuMjAwNAoK
# KiBBZGRlZCBAcndkX2NhbGxfYWZ0ZXJfYmFjay4KCi0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0KCjAuMC43IC0gMjguMDQuMjAwNAoKKiBDb3JyZWN0ZWQgc29tZSBl
# eGNlcHRpb24gaGFuZGxpbmcgcmVnYXJkaW5nIHRoZSBJTyB3aXRoIHRoZQog
# IGJyb3dzZXIuCgoqIEFkZGVkIG1heGxlbmd0aCB0byB0ZXh0IGFuZCBwYXNz
# d29yZC4KCiogQWRkZWQgbmV0d29yayB3aXRob3V0IGF1dGhlbnRpY2F0aW9u
# LgoKLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLQoKMC4wLjYgLSAyNC4wNC4yMDA0Cgoq
# IENvcnJlY3RlZCBpby1oYW5kbGluZy4gS29ucXVlcm9yIGNvdWxkIGtpbGwg
# dGhlIGFwcGxpY2F0aW9uLgoKKiBDaGFuZ2VkIHNvbWUgbGF5b3V0ICggd2lu
# ZG93IGFuZCB0YWJzKS4KCi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KCjAuMC41IC0g
# MjMuMDQuMjAwNAoKKiBSZXBsYWNlZCB0aGUgc3ltbGluayBieSBhIGNvcHkg
# aW4gaW5zdGFsbC5yYiAuIEl0IGRpZG4ndCB3b3JrCiAgdW5kZXIgTGludXgu
# CgotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tCgowLjAuNCAtIDIyLjA0LjIwMDQKCiog
# Q2hhbmdlZCB0aGUgcmVjZW50bHkgYWRkZWQgdGFiLWhhbmRsaW5nLgoKKiBD
# b3JyZWN0ZWQgc29tZSBjdXJzb3IgcG9zaXRpb25pbmcgZ2xpdGNoZXMuCgot
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tCgowLjAuMyAtIDIxLjA0LjIwMDQKCiogQSBt
# aW5vciBjaGFuZ2UgaW4gbWVzc2FnZS4KCi0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0K
# CjAuMC4yIC0gMjAuMDQuMjAwNAoKKiBBZGRlZCBzb21lIHRhYi1oYW5kbGlu
# Zy4KCi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KCjAuMC4xIC0gMTcuMDQuMjAwNAoK
# KiBBbHBoYSByZWxlYXNlCgotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
# LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCgAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJ1Ynl3ZWJkaWFsb2dzL1ZFUlNJ
# T04AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwNjQ0ADAw
# MDE3NTAAMDAwMTc1MAAwMDAwMDAwMDAwNgAxMDI1MDMyMDYyMQAwMTUwNDEA
# IDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAdXN0YXIgIABlcmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDAw
# MAAwMDAwMDAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMC4y
# LjAKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAABydWJ5d2ViZGlhbG9ncy9TVU1NQVJZAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDY0NAAwMDAxNzUwADAwMDE3
# NTAAMDAwMDAwMDAxMDQAMTAyNTAzMjA2MjEAMDE1MDUwACAwAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AHVzdGFyICAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlr
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFRoZSBXZWIgQnJvd3Nl
# ciBhcyBhIEdyYXBoaWNhbCBVc2VyIEludGVyZmFjZSBmb3IgUnVieSBBcHBs
# aWNhdGlvbnMKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAcnVieXdlYmRpYWxvZ3MvbGliLwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAADAwMDA3NTUAMDAwMTc1MAAwMDAxNzUwADAwMDAwMDAw
# MDAwADEwMjUwMzIwNjIxADAxNDU0MwAgNQAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3RhciAgAGVy
# aWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZXJpawAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAwMDAwMDAwADAwMDAwMDAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAABydWJ5d2ViZGlhbG9ncy9saWIvbWltZS5s
# aWIucmIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUw
# ADAwMDE3NTAAMDAwMDAwMzE2MTMAMTAyNTAzMjA2MjEAMDE2NTczACAwAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAHVzdGFyICAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AABlcmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAw
# MDAwMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAG1vZHVsZSBF
# Vk1pbWUKICBNaW1lVHlwZSA9IHt9CgogIE1pbWVUeXBlWycxMjMnXSA9ICdh
# cHBsaWNhdGlvbi92bmQubG90dXMtMS0yLTMnCiAgTWltZVR5cGVbJzNkcydd
# ID0gJ2ltYWdlL3gtM2RzJwogIE1pbWVUeXBlWydhJ10gPSAnYXBwbGljYXRp
# b24veC11bml4LWFyY2hpdmUnCiAgTWltZVR5cGVbJ2FidyddID0gJ2FwcGxp
# Y2F0aW9uL3gtYWJpd29yZCcKICBNaW1lVHlwZVsnYWMzJ10gPSAnYXVkaW8v
# YWMzJwogIE1pbWVUeXBlWydhZm0nXSA9ICdhcHBsaWNhdGlvbi94LWZvbnQt
# YWZtJwogIE1pbWVUeXBlWydhZyddID0gJ2ltYWdlL3gtYXBwbGl4LWdyYXBo
# aWMnCiAgTWltZVR5cGVbJ2FpZiddID0gJ2F1ZGlvL3gtYWlmZicKICBNaW1l
# VHlwZVsnYWlmYyddID0gJ2F1ZGlvL3gtYWlmZicKICBNaW1lVHlwZVsnYWlm
# ZiddID0gJ2F1ZGlvL3gtYWlmZicKICBNaW1lVHlwZVsnYXAnXSA9ICdhcHBs
# aWNhdGlvbi94LWFwcGxpeC1wcmVzZW50cycKICBNaW1lVHlwZVsnYXBlJ10g
# PSAnYXBwbGljYXRpb24veC1hcGUnCiAgTWltZVR5cGVbJ2FyaiddID0gJ2Fw
# cGxpY2F0aW9uL3gtYXJqJwogIE1pbWVUeXBlWydhcyddID0gJ2FwcGxpY2F0
# aW9uL3gtYXBwbGl4LXNwcmVhZHNoZWV0JwogIE1pbWVUeXBlWydhc2MnXSA9
# ICd0ZXh0L3BsYWluJwogIE1pbWVUeXBlWydhc2YnXSA9ICd2aWRlby94LW1z
# LWFzZicKICBNaW1lVHlwZVsnYXNwJ10gPSAnYXBwbGljYXRpb24veC1hc3An
# CiAgTWltZVR5cGVbJ2FzeCddID0gJ2F1ZGlvL3gtbXMtYXN4JwogIE1pbWVU
# eXBlWydhdSddID0gJ2F1ZGlvL3gtdWxhdycKICBNaW1lVHlwZVsnYXZpJ10g
# PSAndmlkZW8veC1tc3ZpZGVvJwogIE1pbWVUeXBlWydhdyddID0gJ2FwcGxp
# Y2F0aW9uL3gtYXBwbGl4LXdvcmQnCiAgTWltZVR5cGVbJ2JhayddID0gJ2Fw
# cGxpY2F0aW9uL3gtYmFja3VwJwogIE1pbWVUeXBlWydiY3BpbyddID0gJ2Fw
# cGxpY2F0aW9uL3gtYmNwaW8nCiAgTWltZVR5cGVbJ2JkZiddID0gJ2FwcGxp
# Y2F0aW9uL3gtZm9udC1iZGYnCiAgTWltZVR5cGVbJ2JpYiddID0gJ3RleHQv
# YmliJwogIE1pbWVUeXBlWydiaW4nXSA9ICdhcHBsaWNhdGlvbi9vY3RldC1z
# dHJlYW0nCiAgTWltZVR5cGVbJ2JsZW5kJ10gPSAnYXBwbGljYXRpb24veC1i
# bGVuZGVyJwogIE1pbWVUeXBlWydibGVuZGVyJ10gPSAnYXBwbGljYXRpb24v
# eC1ibGVuZGVyJwogIE1pbWVUeXBlWydibXAnXSA9ICdpbWFnZS9ibXAnCiAg
# TWltZVR5cGVbJ2J6J10gPSAnYXBwbGljYXRpb24veC1iemlwJwogIE1pbWVU
# eXBlWydiejInXSA9ICdhcHBsaWNhdGlvbi94LWJ6aXAnCiAgTWltZVR5cGVb
# J2MnXSA9ICd0ZXh0L3gtYycKICBNaW1lVHlwZVsnYysrJ10gPSAndGV4dC94
# LWMrKycKICBNaW1lVHlwZVsnY2MnXSA9ICd0ZXh0L3gtYysrJwogIE1pbWVU
# eXBlWydjZGYnXSA9ICdhcHBsaWNhdGlvbi94LW5ldGNkZicKICBNaW1lVHlw
# ZVsnY2RyJ10gPSAnYXBwbGljYXRpb24vdm5kLmNvcmVsLWRyYXcnCiAgTWlt
# ZVR5cGVbJ2NnaSddID0gJ2FwcGxpY2F0aW9uL3gtY2dpJwogIE1pbWVUeXBl
# WydjZ20nXSA9ICdpbWFnZS9jZ20nCiAgTWltZVR5cGVbJ2NsYXNzJ10gPSAn
# YXBwbGljYXRpb24veC1qYXZhLWJ5dGUtY29kZScKICBNaW1lVHlwZVsnY2xz
# J10gPSAndGV4dC94LXRleCcKICBNaW1lVHlwZVsnY3BpbyddID0gJ2FwcGxp
# Y2F0aW9uL3gtY3BpbycKICBNaW1lVHlwZVsnY3BwJ10gPSAndGV4dC94LWMr
# KycKICBNaW1lVHlwZVsnY3NoJ10gPSAndGV4dC94LWNzaCcKICBNaW1lVHlw
# ZVsnY3NzJ10gPSAndGV4dC9jc3MnCiAgTWltZVR5cGVbJ2NzdiddID0gJ3Rl
# eHQveC1jb21tYS1zZXBhcmF0ZWQtdmFsdWVzJwogIE1pbWVUeXBlWydkYXQn
# XSA9ICd2aWRlby9tcGVnJwogIE1pbWVUeXBlWydkYmYnXSA9ICdhcHBsaWNh
# dGlvbi94LXhiYXNlJwogIE1pbWVUeXBlWydkYyddID0gJ2FwcGxpY2F0aW9u
# L3gtZGMtcm9tJwogIE1pbWVUeXBlWydkY2wnXSA9ICd0ZXh0L3gtZGNsJwog
# IE1pbWVUeXBlWydkY20nXSA9ICdpbWFnZS94LWRjbScKICBNaW1lVHlwZVsn
# ZGViJ10gPSAnYXBwbGljYXRpb24veC1kZWInCiAgTWltZVR5cGVbJ2Rlc2t0
# b3AnXSA9ICdhcHBsaWNhdGlvbi94LWdub21lLWFwcC1pbmZvJwogIE1pbWVU
# eXBlWydkaWEnXSA9ICdhcHBsaWNhdGlvbi94LWRpYS1kaWFncmFtJwogIE1p
# bWVUeXBlWydkaWZmJ10gPSAndGV4dC94LXBhdGNoJwogIE1pbWVUeXBlWydk
# anYnXSA9ICdpbWFnZS92bmQuZGp2dScKICBNaW1lVHlwZVsnZGp2dSddID0g
# J2ltYWdlL3ZuZC5kanZ1JwogIE1pbWVUeXBlWydkb2MnXSA9ICdhcHBsaWNh
# dGlvbi9tc3dvcmQnCiAgTWltZVR5cGVbJ2RzbCddID0gJ3RleHQveC1kc2wn
# CiAgTWltZVR5cGVbJ2R0ZCddID0gJ3RleHQveC1kdGQnCiAgTWltZVR5cGVb
# J2R2aSddID0gJ2FwcGxpY2F0aW9uL3gtZHZpJwogIE1pbWVUeXBlWydkd2cn
# XSA9ICdpbWFnZS92bmQuZHdnJwogIE1pbWVUeXBlWydkeGYnXSA9ICdpbWFn
# ZS92bmQuZHhmJwogIE1pbWVUeXBlWydlbCddID0gJ3RleHQveC1lbWFjcy1s
# aXNwJwogIE1pbWVUeXBlWydlbWYnXSA9ICdpbWFnZS94LWVtZicKICBNaW1l
# VHlwZVsnZXBzJ10gPSAnYXBwbGljYXRpb24vcG9zdHNjcmlwdCcKICBNaW1l
# VHlwZVsnZXRoZW1lJ10gPSAnYXBwbGljYXRpb24veC1lLXRoZW1lJwogIE1p
# bWVUeXBlWydldHgnXSA9ICd0ZXh0L3gtc2V0ZXh0JwogIE1pbWVUeXBlWydl
# eGUnXSA9ICdhcHBsaWNhdGlvbi94LW1zLWRvcy1leGVjdXRhYmxlJwogIE1p
# bWVUeXBlWydleiddID0gJ2FwcGxpY2F0aW9uL2FuZHJldy1pbnNldCcKICBN
# aW1lVHlwZVsnZiddID0gJ3RleHQveC1mb3J0cmFuJwogIE1pbWVUeXBlWydm
# aWcnXSA9ICdpbWFnZS94LXhmaWcnCiAgTWltZVR5cGVbJ2ZpdHMnXSA9ICdp
# bWFnZS94LWZpdHMnCiAgTWltZVR5cGVbJ2ZsYWMnXSA9ICdhdWRpby94LWZs
# YWMnCiAgTWltZVR5cGVbJ2ZsYyddID0gJ3ZpZGVvL3gtZmxjJwogIE1pbWVU
# eXBlWydmbGknXSA9ICd2aWRlby94LWZsaScKICBNaW1lVHlwZVsnZ2InXSA9
# ICdhcHBsaWNhdGlvbi94LWdhbWVib3ktcm9tJwogIE1pbWVUeXBlWydnY2hl
# bXBhaW50J10gPSAnYXBwbGljYXRpb24veC1nY2hlbXBhaW50JwogIE1pbWVU
# eXBlWydnY3JkJ10gPSAndGV4dC94LXZjYXJkJwogIE1pbWVUeXBlWydnY3J5
# c3RhbCddID0gJ2FwcGxpY2F0aW9uL3gtZ2NyeXN0YWwnCiAgTWltZVR5cGVb
# J2dlbSddID0gJ3RleHQveC1ydWJ5Z2VtJwogIE1pbWVUeXBlWydnZW4nXSA9
# ICdhcHBsaWNhdGlvbi94LWdlbmVzaXMtcm9tJwogIE1pbWVUeXBlWydnZydd
# ID0gJ2FwcGxpY2F0aW9uL3gtc21zLXJvbScKICBNaW1lVHlwZVsnZ2lmJ10g
# PSAnaW1hZ2UvZ2lmJwogIE1pbWVUeXBlWydnbGFkZSddID0gJ2FwcGxpY2F0
# aW9uL3gtZ2xhZGUnCiAgTWltZVR5cGVbJ2duYyddID0gJ2FwcGxpY2F0aW9u
# L3gtZ251Y2FzaCcKICBNaW1lVHlwZVsnZ251Y2FzaCddID0gJ2FwcGxpY2F0
# aW9uL3gtZ251Y2FzaCcKICBNaW1lVHlwZVsnZ251bWVyaWMnXSA9ICdhcHBs
# aWNhdGlvbi94LWdudW1lcmljJwogIE1pbWVUeXBlWydncmF5J10gPSAnaW1h
# Z2UveC1ncmF5JwogIE1pbWVUeXBlWydndGFyJ10gPSAnYXBwbGljYXRpb24v
# eC1ndGFyJwogIE1pbWVUeXBlWydneiddID0gJ2FwcGxpY2F0aW9uL3gtZ3pp
# cCcKICBNaW1lVHlwZVsnaCddID0gJ3RleHQveC1jLWhlYWRlcicKICBNaW1l
# VHlwZVsnaCsrJ10gPSAndGV4dC94LWMtaGVhZGVyJwogIE1pbWVUeXBlWydo
# ZGYnXSA9ICdhcHBsaWNhdGlvbi94LWhkZicKICBNaW1lVHlwZVsnaGxscydd
# ID0gJ3RleHQveC1obGxhcGlzY3JpcHQnCiAgTWltZVR5cGVbJ2hwcCddID0g
# J3RleHQveC1jLWhlYWRlcicKICBNaW1lVHlwZVsnaHMnXSA9ICd0ZXh0L3gt
# aGFza2VsbCcKICBNaW1lVHlwZVsnaHRtJ10gPSAndGV4dC9odG1sJwogIE1p
# bWVUeXBlWydodG1sJ10gPSAndGV4dC9odG1sJwogIE1pbWVUeXBlWydpY2In
# XSA9ICdpbWFnZS94LWljYicKICBNaW1lVHlwZVsnaWNvJ10gPSAnaW1hZ2Uv
# eC1pY28nCiAgTWltZVR5cGVbJ2ljcyddID0gJ3RleHQvY2FsZW5kYXInCiAg
# TWltZVR5cGVbJ2lkbCddID0gJ3RleHQveC1pZGwnCiAgTWltZVR5cGVbJ2ll
# ZiddID0gJ2ltYWdlL2llZicKICBNaW1lVHlwZVsnaWZmJ10gPSAnaW1hZ2Uv
# eC1pZmYnCiAgTWltZVR5cGVbJ2lsYm0nXSA9ICdpbWFnZS94LWlsYm0nCiAg
# TWltZVR5cGVbJ2lzbyddID0gJ2FwcGxpY2F0aW9uL3gtaXNvLWltYWdlJwog
# IE1pbWVUeXBlWydpdCddID0gJ2F1ZGlvL3gtaXQnCiAgTWltZVR5cGVbJ2ph
# ciddID0gJ2FwcGxpY2F0aW9uL3gtamF2YS1hcmNoaXZlJwogIE1pbWVUeXBl
# WydqYXZhJ10gPSAndGV4dC94LWphdmEnCiAgTWltZVR5cGVbJ2pwZSddID0g
# J2ltYWdlL2pwZWcnCiAgTWltZVR5cGVbJ2pwZWcnXSA9ICdpbWFnZS9qcGVn
# JwogIE1pbWVUeXBlWydqcGcnXSA9ICdpbWFnZS9qcGVnJwogIE1pbWVUeXBl
# WydqcHInXSA9ICdhcHBsaWNhdGlvbi94LWpidWlsZGVyLXByb2plY3QnCiAg
# TWltZVR5cGVbJ2pweCddID0gJ2FwcGxpY2F0aW9uL3gtamJ1aWxkZXItcHJv
# amVjdCcKICBNaW1lVHlwZVsnanMnXSA9ICd0ZXh0L3gtamF2YXNjcmlwdCcK
# ICBNaW1lVHlwZVsna2RlbG5rJ10gPSAnYXBwbGljYXRpb24veC1rZGUtYXBw
# LWluZm8nCiAgTWltZVR5cGVbJ2tpbCddID0gJ2FwcGxpY2F0aW9uL3gta2ls
# bHVzdHJhdG9yJwogIE1pbWVUeXBlWydrcHInXSA9ICdhcHBsaWNhdGlvbi94
# LWtwcmVzZW50ZXInCiAgTWltZVR5cGVbJ2tzcCddID0gJ2FwcGxpY2F0aW9u
# L3gta3NwcmVhZCcKICBNaW1lVHlwZVsna3dkJ10gPSAnYXBwbGljYXRpb24v
# eC1rd29yZCcKICBNaW1lVHlwZVsnbGEnXSA9ICdhcHBsaWNhdGlvbi94LXNo
# YXJlZC1saWJyYXJ5LWxhJwogIE1pbWVUeXBlWydsaGEnXSA9ICdhcHBsaWNh
# dGlvbi94LWxoYScKICBNaW1lVHlwZVsnbGhzJ10gPSAndGV4dC94LWxpdGVy
# YXRlLWhhc2tlbGwnCiAgTWltZVR5cGVbJ2xoeiddID0gJ2FwcGxpY2F0aW9u
# L3gtbGh6JwogIE1pbWVUeXBlWydsbyddID0gJ2FwcGxpY2F0aW9uL3gtb2Jq
# ZWN0LWZpbGUnCiAgTWltZVR5cGVbJ2x0eCddID0gJ3RleHQveC10ZXgnCiAg
# TWltZVR5cGVbJ2x3byddID0gJ2ltYWdlL3gtbHdvJwogIE1pbWVUeXBlWyds
# d29iJ10gPSAnaW1hZ2UveC1sd28nCiAgTWltZVR5cGVbJ2x3cyddID0gJ2lt
# YWdlL3gtbHdzJwogIE1pbWVUeXBlWydseXgnXSA9ICd0ZXh0L3gtbHl4Jwog
# IE1pbWVUeXBlWydtJ10gPSAndGV4dC94LW9iamMnCiAgTWltZVR5cGVbJ20z
# dSddID0gJ2F1ZGlvL3gtbXBlZ3VybCcKICBNaW1lVHlwZVsnbTRhJ10gPSAn
# YXVkaW8veC1tNGEnCiAgTWltZVR5cGVbJ21hbiddID0gJ3RleHQveC10cm9m
# Zi1tYW4nCiAgTWltZVR5cGVbJ21kJ10gPSAnYXBwbGljYXRpb24veC1nZW5l
# c2lzLXJvbScKICBNaW1lVHlwZVsnbWUnXSA9ICd0ZXh0L3gtdHJvZmYtbWUn
# CiAgTWltZVR5cGVbJ21ncCddID0gJ2FwcGxpY2F0aW9uL3gtbWFnaWNwb2lu
# dCcKICBNaW1lVHlwZVsnbWlkJ10gPSAnYXVkaW8veC1taWRpJwogIE1pbWVU
# eXBlWydtaWRpJ10gPSAnYXVkaW8veC1taWRpJwogIE1pbWVUeXBlWydtaWYn
# XSA9ICdhcHBsaWNhdGlvbi94LW1pZicKICBNaW1lVHlwZVsnbWlmZiddID0g
# J2ltYWdlL3gtbWlmZicKICBNaW1lVHlwZVsnbW0nXSA9ICd0ZXh0L3gtdHJv
# ZmYtbW0nCiAgTWltZVR5cGVbJ21tbCddID0gJ3RleHQvbWF0aG1sJwogIE1p
# bWVUeXBlWydtb2QnXSA9ICdhdWRpby94LW1vZCcKICBNaW1lVHlwZVsnbW92
# J10gPSAndmlkZW8vcXVpY2t0aW1lJwogIE1pbWVUeXBlWydtb3ZpZSddID0g
# J3ZpZGVvL3gtc2dpLW1vdmllJwogIE1pbWVUeXBlWydtcDEnXSA9ICdhdWRp
# by9tcGVnJwogIE1pbWVUeXBlWydtcDInXSA9ICd2aWRlby9tcGVnJwogIE1p
# bWVUeXBlWydtcDMnXSA9ICdhdWRpby9tcGVnJwogIE1pbWVUeXBlWydtcGUn
# XSA9ICd2aWRlby9tcGVnJwogIE1pbWVUeXBlWydtcGVnJ10gPSAndmlkZW8v
# bXBlZycKICBNaW1lVHlwZVsnbXBnJ10gPSAndmlkZW8vbXBlZycKICBNaW1l
# VHlwZVsnbXJwJ10gPSAnYXBwbGljYXRpb24veC1tcnByb2plY3QnCiAgTWlt
# ZVR5cGVbJ21ycHJvamVjdCddID0gJ2FwcGxpY2F0aW9uL3gtbXJwcm9qZWN0
# JwogIE1pbWVUeXBlWydtcyddID0gJ3RleHQveC10cm9mZi1tcycKICBNaW1l
# VHlwZVsnbXN4J10gPSAnYXBwbGljYXRpb24veC1tc3gtcm9tJwogIE1pbWVU
# eXBlWyduNjQnXSA9ICdhcHBsaWNhdGlvbi94LW42NC1yb20nCiAgTWltZVR5
# cGVbJ25jJ10gPSAnYXBwbGljYXRpb24veC1uZXRjZGYnCiAgTWltZVR5cGVb
# J25lcyddID0gJ2FwcGxpY2F0aW9uL3gtbmVzLXJvbScKICBNaW1lVHlwZVsn
# bnN2J10gPSAndmlkZW8veC1uc3YnCiAgTWltZVR5cGVbJ28nXSA9ICdhcHBs
# aWNhdGlvbi94LW9iamVjdC1maWxlJwogIE1pbWVUeXBlWydvZGEnXSA9ICdh
# cHBsaWNhdGlvbi9vZGEnCiAgTWltZVR5cGVbJ29nZyddID0gJ2FwcGxpY2F0
# aW9uL29nZycKICBNaW1lVHlwZVsnb2xlbyddID0gJ2FwcGxpY2F0aW9uL3gt
# b2xlbycKICBNaW1lVHlwZVsncCddID0gJ3RleHQveC1wYXNjYWwnCiAgTWlt
# ZVR5cGVbJ3BhbG0nXSA9ICdpbWFnZS94LXBhbG0nCiAgTWltZVR5cGVbJ3Bh
# cyddID0gJ3RleHQveC1wYXNjYWwnCiAgTWltZVR5cGVbJ3Bhc2NhbCddID0g
# J3RleHQveC1wYXNjYWwnCiAgTWltZVR5cGVbJ3BhdGNoJ10gPSAndGV4dC94
# LXBhdGNoJwogIE1pbWVUeXBlWydwYm0nXSA9ICdpbWFnZS94LXBvcnRhYmxl
# LWJpdG1hcCcKICBNaW1lVHlwZVsncGNkJ10gPSAnaW1hZ2UveC1waG90by1j
# ZCcKICBNaW1lVHlwZVsncGNmJ10gPSAnYXBwbGljYXRpb24veC1mb250LXBj
# ZicKICBNaW1lVHlwZVsncGN0J10gPSAnaW1hZ2UveC1waWN0JwogIE1pbWVU
# eXBlWydwY3gnXSA9ICdpbWFnZS94LXBjeCcKICBNaW1lVHlwZVsncGRiJ10g
# PSAnYXBwbGljYXRpb24veC1wYWxtLWRhdGFiYXNlJwogIE1pbWVUeXBlWydw
# ZGYnXSA9ICdhcHBsaWNhdGlvbi9wZGYnCiAgTWltZVR5cGVbJ3BlcmwnXSA9
# ICd0ZXh0L3gtcGVybCcKICBNaW1lVHlwZVsncGZhJ10gPSAnYXBwbGljYXRp
# b24veC1mb250LXR5cGUxJwogIE1pbWVUeXBlWydwZmInXSA9ICdhcHBsaWNh
# dGlvbi94LWZvbnQtdHlwZTEnCiAgTWltZVR5cGVbJ3BnbSddID0gJ2ltYWdl
# L3gtcG9ydGFibGUtZ3JheW1hcCcKICBNaW1lVHlwZVsncGduJ10gPSAnYXBw
# bGljYXRpb24veC1jaGVzcy1wZ24nCiAgTWltZVR5cGVbJ3BncCddID0gJ2Fw
# cGxpY2F0aW9uL3BncCcKICBNaW1lVHlwZVsncGhwJ10gPSAnYXBwbGljYXRp
# b24veC1waHAnCiAgTWltZVR5cGVbJ3BocDMnXSA9ICdhcHBsaWNhdGlvbi94
# LXBocCcKICBNaW1lVHlwZVsncGhwNCddID0gJ2FwcGxpY2F0aW9uL3gtcGhw
# JwogIE1pbWVUeXBlWydwaWN0J10gPSAnaW1hZ2UveC1waWN0JwogIE1pbWVU
# eXBlWydwbCddID0gJ3RleHQveC1wZXJsJwogIE1pbWVUeXBlWydwbHMnXSA9
# ICdhdWRpby94LXNjcGxzJwogIE1pbWVUeXBlWydwbSddID0gJ3RleHQveC1w
# ZXJsJwogIE1pbWVUeXBlWydwbmcnXSA9ICdpbWFnZS9wbmcnCiAgTWltZVR5
# cGVbJ3BubSddID0gJ2ltYWdlL3gtcG9ydGFibGUtYW55bWFwJwogIE1pbWVU
# eXBlWydwbyddID0gJ3RleHQveC1wbycKICBNaW1lVHlwZVsncHAnXSA9ICd0
# ZXh0L3gtcGFzY2FsJwogIE1pbWVUeXBlWydwcG0nXSA9ICdpbWFnZS94LXBv
# cnRhYmxlLXBpeG1hcCcKICBNaW1lVHlwZVsncHBzJ10gPSAnYXBwbGljYXRp
# b24vdm5kLm1zLXBvd2VycG9pbnQnCiAgTWltZVR5cGVbJ3BwdCddID0gJ2Fw
# cGxpY2F0aW9uL3ZuZC5tcy1wb3dlcnBvaW50JwogIE1pbWVUeXBlWydwcydd
# ID0gJ2FwcGxpY2F0aW9uL3Bvc3RzY3JpcHQnCiAgTWltZVR5cGVbJ3BzZCdd
# ID0gJ2ltYWdlL3gtcHNkJwogIE1pbWVUeXBlWydwc2YnXSA9ICdhcHBsaWNh
# dGlvbi94LWZvbnQtbGludXgtcHNmJwogIE1pbWVUeXBlWydwc2lkJ10gPSAn
# YXVkaW8vcHJzLnNpZCcKICBNaW1lVHlwZVsncHknXSA9ICd0ZXh0L3gtcHl0
# aG9uJwogIE1pbWVUeXBlWydweWMnXSA9ICdhcHBsaWNhdGlvbi94LXB5dGhv
# bi1ieXRlLWNvZGUnCiAgTWltZVR5cGVbJ3FpZiddID0gJ2FwcGxpY2F0aW9u
# L3FpZicKICBNaW1lVHlwZVsncXQnXSA9ICd2aWRlby9xdWlja3RpbWUnCiAg
# TWltZVR5cGVbJ3JhJ10gPSAnYXVkaW8veC1yZWFsLWF1ZGlvJwogIE1pbWVU
# eXBlWydyYW0nXSA9ICdhdWRpby94LXBuLXJlYWxhdWRpbycKICBNaW1lVHlw
# ZVsncmFyJ10gPSAnYXBwbGljYXRpb24veC1yYXInCiAgTWltZVR5cGVbJ3Jh
# cyddID0gJ2ltYWdlL3gtY211LXJhc3RlcicKICBNaW1lVHlwZVsncmInXSA9
# ICd0ZXh0L3gtcnVieScKICBNaW1lVHlwZVsncmJhJ10gPSAndGV4dC94LXJ1
# YnknCiAgTWltZVR5cGVbJ3JidyddID0gJ3RleHQveC1ydWJ5JwogIE1pbWVU
# eXBlWydyZWonXSA9ICdhcHBsaWNhdGlvbi94LXJlamVjdCcKICBNaW1lVHlw
# ZVsncmdiJ10gPSAnaW1hZ2UveC1yZ2InCiAgTWltZVR5cGVbJ3JtJ10gPSAn
# YXVkaW8veC1yZWFsLWF1ZGlvJwogIE1pbWVUeXBlWydyb2ZmJ10gPSAndGV4
# dC94LXRyb2ZmJwogIE1pbWVUeXBlWydycG0nXSA9ICdhcHBsaWNhdGlvbi94
# LXJwbScKICBNaW1lVHlwZVsncnRmJ10gPSAnYXBwbGljYXRpb24vcnRmJwog
# IE1pbWVUeXBlWydydHgnXSA9ICd0ZXh0L3JpY2h0ZXh0JwogIE1pbWVUeXBl
# WydydWJ5J10gPSAndGV4dC94LXJ1YnknCiAgTWltZVR5cGVbJ3J1Ynl3J10g
# PSAndGV4dC94LXJ1YnknCiAgTWltZVR5cGVbJ3J2J10gPSAnYXVkaW8veC1y
# ZWFsLWF1ZGlvJwogIE1pbWVUeXBlWydzJ10gPSAndGV4dC94LWFzbScKICBN
# aW1lVHlwZVsnczNtJ10gPSAnYXVkaW8veC1zM20nCiAgTWltZVR5cGVbJ3Nj
# bSddID0gJ3RleHQveC1zY2hlbWUnCiAgTWltZVR5cGVbJ3NkYSddID0gJ2Fw
# cGxpY2F0aW9uL3ZuZC5zdGFyZGl2aXNpb24uZHJhdycKICBNaW1lVHlwZVsn
# c2RjJ10gPSAnYXBwbGljYXRpb24vdm5kLnN0YXJkaXZpc2lvbi5jYWxjJwog
# IE1pbWVUeXBlWydzZGQnXSA9ICdhcHBsaWNhdGlvbi92bmQuc3RhcmRpdmlz
# aW9uLmltcHJlc3MnCiAgTWltZVR5cGVbJ3NkcCddID0gJ2FwcGxpY2F0aW9u
# L3ZuZC5zdGFyZGl2aXNpb24uaW1wcmVzcycKICBNaW1lVHlwZVsnc2RzJ10g
# PSAnYXBwbGljYXRpb24vdm5kLnN0YXJkaXZpc2lvbi5jaGFydCcKICBNaW1l
# VHlwZVsnc2R3J10gPSAnYXBwbGljYXRpb24vdm5kLnN0YXJkaXZpc2lvbi53
# cml0ZXInCiAgTWltZVR5cGVbJ3NnaSddID0gJ2ltYWdlL3gtc2dpJwogIE1p
# bWVUeXBlWydzZ2wnXSA9ICdhcHBsaWNhdGlvbi92bmQuc3RhcmRpdmlzaW9u
# LndyaXRlcicKICBNaW1lVHlwZVsnc2dtJ10gPSAndGV4dC9zZ21sJwogIE1p
# bWVUeXBlWydzZ21sJ10gPSAndGV4dC9zZ21sJwogIE1pbWVUeXBlWydzaCdd
# ID0gJ3RleHQveC1zaCcKICBNaW1lVHlwZVsnc2hhciddID0gJ2FwcGxpY2F0
# aW9uL3gtc2hhcicKICBNaW1lVHlwZVsnc2lkJ10gPSAnYXVkaW8vcHJzLnNp
# ZCcKICBNaW1lVHlwZVsnc2xrJ10gPSAndGV4dC9zcHJlYWRzaGVldCcKICBN
# aW1lVHlwZVsnc21kJ10gPSAnYXBwbGljYXRpb24vdm5kLnN0YXJkaXZpc2lv
# bi5tYWlsJwogIE1pbWVUeXBlWydzbWYnXSA9ICdhcHBsaWNhdGlvbi92bmQu
# c3RhcmRpdmlzaW9uLm1hdGgnCiAgTWltZVR5cGVbJ3NtaSddID0gJ2FwcGxp
# Y2F0aW9uL3gtc21pbCcKICBNaW1lVHlwZVsnc21pbCddID0gJ2FwcGxpY2F0
# aW9uL3gtc21pbCcKICBNaW1lVHlwZVsnc21sJ10gPSAnYXBwbGljYXRpb24v
# eC1zbWlsJwogIE1pbWVUeXBlWydzbXMnXSA9ICdhcHBsaWNhdGlvbi94LXNt
# cy1yb20nCiAgTWltZVR5cGVbJ3NuZCddID0gJ2F1ZGlvL2Jhc2ljJwogIE1p
# bWVUeXBlWydzbyddID0gJ2FwcGxpY2F0aW9uL3gtc2hhcmVkLWxpYnJhcnkn
# CiAgTWltZVR5cGVbJ3NwZCddID0gJ2FwcGxpY2F0aW9uL3gtZm9udC1zcGVl
# ZG8nCiAgTWltZVR5cGVbJ3NxbCddID0gJ3RleHQveC1zcWwnCiAgTWltZVR5
# cGVbJ3NyYyddID0gJ2FwcGxpY2F0aW9uL3gtd2Fpcy1zb3VyY2UnCiAgTWlt
# ZVR5cGVbJ3N0YyddID0gJ2FwcGxpY2F0aW9uL3ZuZC5zdW4ueG1sLmNhbGMu
# dGVtcGxhdGUnCiAgTWltZVR5cGVbJ3N0ZCddID0gJ2FwcGxpY2F0aW9uL3Zu
# ZC5zdW4ueG1sLmRyYXcudGVtcGxhdGUnCiAgTWltZVR5cGVbJ3N0aSddID0g
# J2FwcGxpY2F0aW9uL3ZuZC5zdW4ueG1sLmltcHJlc3MudGVtcGxhdGUnCiAg
# TWltZVR5cGVbJ3N0bSddID0gJ2F1ZGlvL3gtc3RtJwogIE1pbWVUeXBlWydz
# dHcnXSA9ICdhcHBsaWNhdGlvbi92bmQuc3VuLnhtbC53cml0ZXIudGVtcGxh
# dGUnCiAgTWltZVR5cGVbJ3N0eSddID0gJ3RleHQveC10ZXgnCiAgTWltZVR5
# cGVbJ3N1biddID0gJ2ltYWdlL3gtc3VuLXJhc3RlcicKICBNaW1lVHlwZVsn
# c3Y0Y3BpbyddID0gJ2FwcGxpY2F0aW9uL3gtc3Y0Y3BpbycKICBNaW1lVHlw
# ZVsnc3Y0Y3JjJ10gPSAnYXBwbGljYXRpb24veC1zdjRjcmMnCiAgTWltZVR5
# cGVbJ3N2ZyddID0gJ2ltYWdlL3N2Zyt4bWwnCiAgTWltZVR5cGVbJ3N2Z3on
# XSA9ICdpbWFnZS9zdmcreG1sJwogIE1pbWVUeXBlWydzd2YnXSA9ICdhcHBs
# aWNhdGlvbi94LXNob2Nrd2F2ZS1mbGFzaCcKICBNaW1lVHlwZVsnc3hjJ10g
# PSAnYXBwbGljYXRpb24vdm5kLnN1bi54bWwuY2FsYycKICBNaW1lVHlwZVsn
# c3hkJ10gPSAnYXBwbGljYXRpb24vdm5kLnN1bi54bWwuZHJhdycKICBNaW1l
# VHlwZVsnc3hnJ10gPSAnYXBwbGljYXRpb24vdm5kLnN1bi54bWwud3JpdGVy
# Lmdsb2JhbCcKICBNaW1lVHlwZVsnc3hpJ10gPSAnYXBwbGljYXRpb24vdm5k
# LnN1bi54bWwuaW1wcmVzcycKICBNaW1lVHlwZVsnc3htJ10gPSAnYXBwbGlj
# YXRpb24vdm5kLnN1bi54bWwubWF0aCcKICBNaW1lVHlwZVsnc3h3J10gPSAn
# YXBwbGljYXRpb24vdm5kLnN1bi54bWwud3JpdGVyJwogIE1pbWVUeXBlWydz
# eWxrJ10gPSAndGV4dC9zcHJlYWRzaGVldCcKICBNaW1lVHlwZVsndCddID0g
# J3RleHQveC10cm9mZicKICBNaW1lVHlwZVsndGFyJ10gPSAnYXBwbGljYXRp
# b24veC10YXInCiAgTWltZVR5cGVbJ3RjbCddID0gJ3RleHQveC10Y2wnCiAg
# TWltZVR5cGVbJ3RleCddID0gJ3RleHQveC10ZXgnCiAgTWltZVR5cGVbJ3Rl
# eGknXSA9ICd0ZXh0L3gtdGV4aW5mbycKICBNaW1lVHlwZVsndGV4aW5mbydd
# ID0gJ3RleHQveC10ZXhpbmZvJwogIE1pbWVUeXBlWyd0Z2EnXSA9ICdpbWFn
# ZS94LXRnYScKICBNaW1lVHlwZVsndGd6J10gPSAnYXBwbGljYXRpb24veC1j
# b21wcmVzc2VkLXRhcicKICBNaW1lVHlwZVsndGhlbWUnXSA9ICdhcHBsaWNh
# dGlvbi94LXRoZW1lJwogIE1pbWVUeXBlWyd0aWYnXSA9ICdpbWFnZS90aWZm
# JwogIE1pbWVUeXBlWyd0aWZmJ10gPSAnaW1hZ2UvdGlmZicKICBNaW1lVHlw
# ZVsndG9ycmVudCddID0gJ2FwcGxpY2F0aW9uL3gtYml0dG9ycmVudCcKICBN
# aW1lVHlwZVsndHInXSA9ICd0ZXh0L3gtdHJvZmYnCiAgTWltZVR5cGVbJ3Rz
# diddID0gJ3RleHQvdGFiLXNlcGFyYXRlZC12YWx1ZXMnCiAgTWltZVR5cGVb
# J3R0YyddID0gJ2FwcGxpY2F0aW9uL3gtZm9udC10dGYnCiAgTWltZVR5cGVb
# J3R0ZiddID0gJ2FwcGxpY2F0aW9uL3gtZm9udC10dGYnCiAgTWltZVR5cGVb
# J3R4dCddID0gJ3RleHQvcGxhaW4nCiAgTWltZVR5cGVbJ3VzdGFyJ10gPSAn
# YXBwbGljYXRpb24veC11c3RhcicKICBNaW1lVHlwZVsndmNmJ10gPSAndGV4
# dC94LXZjYWxlbmRhcicKICBNaW1lVHlwZVsndmNzJ10gPSAndGV4dC94LXZj
# YWxlbmRhcicKICBNaW1lVHlwZVsndmknXSA9ICd0ZXh0L3gtdmknCiAgTWlt
# ZVR5cGVbJ3ZpbSddID0gJ3RleHQveC12aScKICBNaW1lVHlwZVsndml2J10g
# PSAndmlkZW8vdm5kLnZpdm8nCiAgTWltZVR5cGVbJ3Zpdm8nXSA9ICd2aWRl
# by92bmQudml2bycKICBNaW1lVHlwZVsndm9iJ10gPSAndmlkZW8vbXBlZycK
# ICBNaW1lVHlwZVsndm9jJ10gPSAnYXVkaW8veC12b2MnCiAgTWltZVR5cGVb
# J3ZvciddID0gJ2FwcGxpY2F0aW9uL3ZuZC5zdGFyZGl2aXNpb24ud3JpdGVy
# JwogIE1pbWVUeXBlWyd3YXYnXSA9ICdhdWRpby94LXdhdicKICBNaW1lVHlw
# ZVsnd2F4J10gPSAnYXVkaW8veC1tcy1hc3gnCiAgTWltZVR5cGVbJ3drMSdd
# ID0gJ2FwcGxpY2F0aW9uL3ZuZC5sb3R1cy0xLTItMycKICBNaW1lVHlwZVsn
# d2szJ10gPSAnYXBwbGljYXRpb24vdm5kLmxvdHVzLTEtMi0zJwogIE1pbWVU
# eXBlWyd3azQnXSA9ICdhcHBsaWNhdGlvbi92bmQubG90dXMtMS0yLTMnCiAg
# TWltZVR5cGVbJ3drcyddID0gJ2FwcGxpY2F0aW9uL3ZuZC5sb3R1cy0xLTIt
# MycKICBNaW1lVHlwZVsnd21mJ10gPSAnaW1hZ2UveC13bWYnCiAgTWltZVR5
# cGVbJ3dtdiddID0gJ3ZpZGVvL3gtbXMtd212JwogIE1pbWVUeXBlWyd3cmwn
# XSA9ICdtb2RlbC92cm1sJwogIE1pbWVUeXBlWyd3dngnXSA9ICd2aWRlby94
# LW1zLXd2eCcKICBNaW1lVHlwZVsneGFjJ10gPSAnYXBwbGljYXRpb24veC1n
# bnVjYXNoJwogIE1pbWVUeXBlWyd4YmVsJ10gPSAnYXBwbGljYXRpb24veGJl
# bCcKICBNaW1lVHlwZVsneGJtJ10gPSAnaW1hZ2UveC14Yml0bWFwJwogIE1p
# bWVUeXBlWyd4Y2YnXSA9ICdpbWFnZS94LXhjZicKICBNaW1lVHlwZVsneGkn
# XSA9ICdhdWRpby94LXhpJwogIE1pbWVUeXBlWyd4bGEnXSA9ICdhcHBsaWNh
# dGlvbi92bmQubXMtZXhjZWwnCiAgTWltZVR5cGVbJ3hsYyddID0gJ2FwcGxp
# Y2F0aW9uL3ZuZC5tcy1leGNlbCcKICBNaW1lVHlwZVsneGxkJ10gPSAnYXBw
# bGljYXRpb24vdm5kLm1zLWV4Y2VsJwogIE1pbWVUeXBlWyd4bHMnXSA9ICdh
# cHBsaWNhdGlvbi92bmQubXMtZXhjZWwnCiAgTWltZVR5cGVbJ3hsdCddID0g
# J2FwcGxpY2F0aW9uL3ZuZC5tcy1leGNlbCcKICBNaW1lVHlwZVsneG0nXSA9
# ICdhdWRpby94LXhtJwogIE1pbWVUeXBlWyd4bWwnXSA9ICd0ZXh0L3htbCcK
# ICBNaW1lVHlwZVsneHBtJ10gPSAnaW1hZ2UveC14cGl4bWFwJwogIE1pbWVU
# eXBlWyd4d2QnXSA9ICdpbWFnZS94LXh3aW5kb3dkdW1wJwogIE1pbWVUeXBl
# Wyd5J10gPSAndGV4dC94LXlhY2MnCiAgTWltZVR5cGVbJ3lhY2MnXSA9ICd0
# ZXh0L3gteWFjYycKICBNaW1lVHlwZVsneiddID0gJ2FwcGxpY2F0aW9uL3gt
# Y29tcHJlc3MnCiAgTWltZVR5cGVbJ3ppcCddID0gJ2FwcGxpY2F0aW9uL3pp
# cCcKICBNaW1lVHlwZVsnem9vJ10gPSAnYXBwbGljYXRpb24veC16b28nCmVu
# ZAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABydWJ5d2ViZGlhbG9ncy9s
# aWIvc2dtbC5saWIucmIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc1
# NQAwMDAxNzUwADAwMDE3NTAAMDAwMDAwMTAxMjUAMTAyNTAzMjA2MjEAMDE2
# NjAxACAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAHVzdGFyICAAZXJpawAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAABlcmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAw
# MDAwMDAAMDAwMDAwMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AHJlcXVpcmUgImV2L3RyZWUiCgpjbGFzcyBTR01MT2JqZWN0IDwgVHJlZU9i
# amVjdAogIGRlZiB0b19zCiAgICByZXMJPSAiIgoKICAgIHBhcnNldHJlZSgi
# cHJlY2hpbGRyZW5fdG9fcyIsICJwb3N0Y2hpbGRyZW5fdG9fcyIsIHJlcykK
# CiAgICByZXMKICBlbmQKCiAgZGVmIHRvX2gKICAgIHJlcwk9ICIiCgogICAg
# cGFyc2V0cmVlKCJwcmVjaGlsZHJlbl90b19zZ21sIiwgInBvc3RjaGlsZHJl
# bl90b19zZ21sIiwgcmVzKQoKICAgIHJlcwogIGVuZAplbmQKCmNsYXNzIFRl
# eHQgPCBTR01MT2JqZWN0CiAgZGVmIGluaXRpYWxpemUodGV4dCkKICAgIHN1
# cGVyKCkKICAgIEB0ZXh0ID0gdGV4dAogIGVuZAoKICBkZWYgcHJlY2hpbGRy
# ZW5fdG9fcyhyZXMpCiAgICAjcmVzIDw8ICIje0NHSS51bmVzY2FwZUhUTUwo
# QHRleHQpfSAiCiAgICByZXMgPDwgQHRleHQKICBlbmQKCiAgZGVmIHByZWNo
# aWxkcmVuX3RvX3NnbWwocmVzKQogICAgI3JlcyA8PCAiI3tDR0kudW5lc2Nh
# cGVIVE1MKEB0ZXh0KX0iCiAgICByZXMgPDwgQHRleHQKICBlbmQKZW5kCgpj
# bGFzcyBDb21tZW50IDwgU0dNTE9iamVjdAogIGRlZiBpbml0aWFsaXplKHRl
# eHQpCiAgICBzdXBlcigpCiAgICBAdGV4dCA9IHRleHQKICBlbmQKCiAgZGVm
# IHByZWNoaWxkcmVuX3RvX3NnbWwocmVzKQogICAgcmVzIDw8ICIje0B0ZXh0
# fSIKICBlbmQKZW5kCgpjbGFzcyBTcGVjaWFsIDwgU0dNTE9iamVjdAogIGRl
# ZiBpbml0aWFsaXplKHRleHQpCiAgICBzdXBlcigpCiAgICBAdGV4dCA9IHRl
# eHQKICBlbmQKCiAgZGVmIHByZWNoaWxkcmVuX3RvX3NnbWwocmVzKQogICAg
# cmVzIDw8ICIje0B0ZXh0fSIKICBlbmQKZW5kCgpjbGFzcyBJbnN0cnVjdGlv
# biA8IFNHTUxPYmplY3QKICBkZWYgaW5pdGlhbGl6ZSh0ZXh0KQogICAgc3Vw
# ZXIoKQogICAgQHRleHQgPSB0ZXh0CiAgZW5kCgogIGRlZiBwcmVjaGlsZHJl
# bl90b19zZ21sKHJlcykKICAgIHJlcyA8PCAiI3tAdGV4dH0iCiAgZW5kCmVu
# ZAoKY2xhc3MgVGFnIDwgU0dNTE9iamVjdAogIGF0dHJfcmVhZGVyIDphcmdz
# CiAgYXR0cl93cml0ZXIgOmFyZ3MKCiAgZGVmIGluaXRpYWxpemUoc3VidHlw
# ZSwgYXJncz17fSkKICAgIHN1cGVyKHN1YnR5cGUpCiAgICBAYXJncyA9IGFy
# Z3MKICAgIEB0ZXh0ID0gIiIKICBlbmQKZW5kCgpjbGFzcyBPcGVuVGFnIDwg
# VGFnCiAgZGVmIGluaXRpYWxpemUoKmFyZ3MpCiAgICBzdXBlcgogICAgQHVw
# b3Jkb3duID0gRG93bgogIGVuZAoKICBkZWYgcHJlY2hpbGRyZW5fdG9fc2dt
# bChyZXMpCiAgICBhCT0gW0BzdWJ0eXBlXQoKICAgIEBhcmdzLnNvcnQuZWFj
# aCBkbyB8aywgdnwKICAgICAgaWYgbm90IHYuaW5jbHVkZT8oIiciKQogICAg
# ICAgIGEgPDwgIiN7a309JyN7dn0nIgogICAgICBlbHNlCiAgICAgICAgaWYg
# bm90IHYuaW5jbHVkZT8oJyInKQogICAgICAgICAgYSA8PCAiI3trfT1cIiN7
# dn1cIiIKICAgICAgICBlbHNlCiAgICAgICAgICBhIDw8ICIje2t9PScje3Yu
# Z3N1YigvXCcvLCAnIicpfSciCiAgICAgICAgZW5kCiAgICAgIGVuZAogICAg
# ZW5kCgogICAgcmVzIDw8ICI8I3thLmpvaW4oIiAiKX0+IiArIEB0ZXh0CiAg
# ZW5kCgogIGRlZiBwb3N0Y2hpbGRyZW5fdG9fc2dtbChyZXMpCiAgICByZXMg
# PDwgIjwvI3tAc3VidHlwZX0+IglpZiBAY2xvc2VkCiAgZW5kCmVuZAoKY2xh
# c3MgQ2xvc2VUYWcgPCBUYWcKICBkZWYgaW5pdGlhbGl6ZSgqYXJncykKICAg
# IHN1cGVyCiAgICBAdXBvcmRvd24gPSBEdW1teQogIGVuZAplbmQKCmNsYXNz
# IFNHTUwgPCBUcmVlCiAgZGVmIGluaXRpYWxpemUoKmFyZ3MpCiAgICBAdGFn
# Y2FjaGUJPSB7fQoKICAgIHN1cGVyCiAgZW5kCgogIGRlZiBidWlsZG9iamVj
# dHMoc3RyaW5nKQogICAgQG9iamVjdHMgPSBbXQoKICAgIHZlcndlcmszCT0K
# ICAgIGxhbWJkYSBkbyB8c3RyaW5nfAogICAgICBhCT0gW10KICAKICAgICAg
# c3RyaW5nWzEuLi0yXS5zcGxpdGJsb2NrcyhbIiciLCAiJyJdLCBbJyInLCAn
# IiddKS5jb2xsZWN0IGRvIHx0eXBlLCBzfAogICAgICAgIGNhc2UgdHlwZQog
# ICAgICAgIHdoZW4gMAogICAgICAgICAgaWYgc2VsZi5jbGFzcy50b19zID09
# ICJIVE1MIgogICAgICAgICAgICBzLnNwbGl0d29yZHMuZWFjaCBkbyB8d3wK
# ICAgICAgICAgICAgICBkCT0gdy5zcGxpdCgiPSIsIDIpCiAgCiAgICAgICAg
# ICAgICAgaWYgZC5sZW5ndGggPT0gMQogICAgICAgICAgICAgICAgYSA8PCBk
# WzBdCiAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgYSA8PCBk
# WzBdCWlmIG5vdCBkWzBdLm5pbD8gYW5kIG5vdCBkWzBdLmVtcHR5PwogICAg
# ICAgICAgICAgICAgYSA8PCAiPSIKICAgICAgICAgICAgICAgIGEgPDwgZFsx
# XQlpZiBub3QgZFsxXS5uaWw/IGFuZCBub3QgZFsxXS5lbXB0eT8KICAgICAg
# ICAgICAgICBlbmQKICAgICAgICAgICAgZW5kCiAgICAgICAgICBlbHNlCiAg
# ICAgICAgICAgIGEuY29uY2F0IHMuc3BsaXR3b3JkcyhbIi8iLCAiPSJdKQog
# ICAgICAgICAgZW5kCiAgICAgICAgd2hlbiAxLCAyCXRoZW4gYSA8PCBzCiAg
# ICAgICAgZW5kCiAgICAgIGVuZAogIAogICAgICBvcGVuCT0gZmFsc2UKICAg
# ICAgY2xvc2UJPSBmYWxzZQogIAogICAgICBhID0gYVswXS5zcGxpdHdvcmRz
# KCIvIikgKyBhWzEuLi0xXQogIAogICAgICBpZiBhWzBdID09ICIvIgogICAg
# ICAgIGNsb3NlCT0gdHJ1ZQogICAgICAgIGEuc2hpZnQKICAgICAgZWxzZQog
# ICAgICAgIG9wZW4JPSB0cnVlCiAgICAgIGVuZAogIAogICAgICBpZiBhWy0x
# XSA9PSAiLyIKICAgICAgICBjbG9zZQk9IHRydWUKICAgICAgICBhLnBvcAog
# ICAgICBlbmQKICAKICAgICAgdGFnCT0gYS5zaGlmdC5kb3duY2FzZQogICAg
# ICBhcmdzCT0ge30KICAKICAgICAgd2hpbGUgbm90IGEubGVuZ3RoLnplcm8/
# CiAgICAgICAgaWYgYS5sZW5ndGggPj0gMyBhbmQgYVsxXSA9PSAiPSIKICAg
# ICAgICAgIGtleQk9IGEuc2hpZnQuZG93bmNhc2UKICAgICAgICAgIGR1bW15
# CT0gYS5zaGlmdAogICAgICAgICAgdmFsdWUJPSBhLnNoaWZ0Lm5vcXVvdGVz
# CiAgICAgICAgICBhcmdzW2tleV0JPSB2YWx1ZQogICAgICAgIGVsc2UKICAg
# ICAgICAgIGtleQk9IGEuc2hpZnQuZG93bmNhc2UKICAgICAgICAgIGFyZ3Nb
# a2V5XQk9ICIiCiAgICAgICAgZW5kCiAgICAgIGVuZAogIAogICAgICBbdGFn
# LCBhcmdzLCBvcGVuLCBjbG9zZV0KICAgIGVuZAoKICAgIHZlcndlcmsyCT0K
# ICAgIGxhbWJkYSBkbyB8c3RyaW5nfAogICAgICBpZiBAdGFnY2FjaGUuaW5j
# bHVkZT8gc3RyaW5nCiAgICAgICAgcmVzCT0gQHRhZ2NhY2hlW3N0cmluZ10K
# ICAgICAgZWxzZQogICAgICAgIHJlcwk9IHZlcndlcmszLmNhbGwoc3RyaW5n
# KQoKICAgICAgICBAdGFnY2FjaGVbc3RyaW5nXSA9IHJlcwogICAgICBlbmQK
# CiAgICAgIHJlcwogICAgZW5kCgogICAgdmVyd2VyazEgPQogICAgbGFtYmRh
# IGRvIHxzdHJpbmd8CiAgICAgIHRhZywgYXJncywgb3BlbiwgY2xvc2UJPSB2
# ZXJ3ZXJrMi5jYWxsKHN0cmluZykKCiAgICAgIEBvYmplY3RzIDw8IE9wZW5U
# YWcubmV3KHRhZy5kdXAsIGFyZ3MuZHVwKQlpZiBvcGVuCiAgICAgIEBvYmpl
# Y3RzIDw8IENsb3NlVGFnLm5ldyh0YWcuZHVwLCBhcmdzLmR1cCkJaWYgY2xv
# c2UKICAgIGVuZAoKICAgIHN0cmluZy5zcGxpdGJsb2NrcyhbIjwhLS0iLCAi
# LS0+Il0sIFsiPCEiLCAiPiJdLCBbIjw/IiwgIj8+Il0sIFsiPCIsICI+Il0p
# LmVhY2ggZG8gfHR5cGUsIHN8CiAgICAgIGNhc2UgdHlwZQogICAgICB3aGVu
# IDAJCXRoZW4gQG9iamVjdHMgPDwgVGV4dC5uZXcocykKICAgICAgd2hlbiAx
# CQl0aGVuIEBvYmplY3RzIDw8IENvbW1lbnQubmV3KHMpCiAgICAgIHdoZW4g
# MgkJdGhlbiBAb2JqZWN0cyA8PCBTcGVjaWFsLm5ldyhzKQogICAgICB3aGVu
# IDMJCXRoZW4gQG9iamVjdHMgPDwgSW5zdHJ1Y3Rpb24ubmV3KHMpCiAgICAg
# IHdoZW4gNAkJdGhlbiB2ZXJ3ZXJrMS5jYWxsKHMpCiAgICAgIGVuZAogICAg
# ZW5kCiAgZW5kCgogIGRlZiB0b19zCiAgICByZXMJPSAiIgoKICAgIHBhcnNl
# dHJlZSgicHJlY2hpbGRyZW5fdG9fcyIsICJwb3N0Y2hpbGRyZW5fdG9fcyIs
# IHJlcykKCiAgICByZXMKICBlbmQKCiAgZGVmIHRvX2gKICAgIHJlcwk9ICIi
# CgogICAgcGFyc2V0cmVlKCJwcmVjaGlsZHJlbl90b19zZ21sIiwgInBvc3Rj
# aGlsZHJlbl90b19zZ21sIiwgcmVzKQoKICAgIHJlcwogIGVuZAplbmQKAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAHJ1Ynl3ZWJkaWFsb2dzL2xpYi94bWwubGli
# LnJiAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwNzU1ADAwMDE3NTAA
# MDAwMTc1MAAwMDAwMDAwNTMxNQAxMDI1MDMyMDYyMQAwMTY0NDQAIDAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAdXN0YXIgIABlcmlrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDAwMAAwMDAw
# MDAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcmVxdWlyZSAi
# ZXYvc2dtbCIKCmNsYXNzIFNHTUxPYmplY3QKICBkZWYgdG9feChjbG9zZXRh
# Z3M9dHJ1ZSkKICAgIHJlcwk9ICIiCgogICAgcGFyc2V0cmVlKCJwcmVjaGls
# ZHJlbl90b194IiwgInBvc3RjaGlsZHJlbl90b194IiwgcmVzLCBjbG9zZXRh
# Z3MpCgogICAgcmVzCiAgZW5kCmVuZAoKY2xhc3MgVGV4dCA8IFNHTUxPYmpl
# Y3QKICBkZWYgcHJlY2hpbGRyZW5fdG9feChyZXMsIGNsb3NldGFncykKICAg
# IHJlcyA8PCBAdGV4dC5zdHJpcAl1bmxlc3MgQHRleHQuc3RyaXAuZW1wdHk/
# CiAgZW5kCmVuZAoKY2xhc3MgQ29tbWVudCA8IFNHTUxPYmplY3QKICBkZWYg
# cHJlY2hpbGRyZW5fdG9feChyZXMsIGNsb3NldGFncykKICAgIHJlcyA8PCAi
# XG4iCWlmIG5vdCBwcmV2aW91cyhbXSwgW1RleHRdKS5raW5kX29mPyhDb21t
# ZW50KQogICAgbGluZXMJPSBAdGV4dC5nc3ViKC8oPCEtLXwtLT4pLywgIiIp
# LmxmLnNwbGl0KC9cbi8pCiAgICBpZiBsaW5lcy5sZW5ndGggPT0gMQogICAg
# ICByZXMgPDwgIiAgIiooQGxldmVsLTEpICsgIjwhLS0gIiArIGxpbmVzWzBd
# LnN0cmlwICsgIiAtLT4iICsgIlxuIgogICAgZWxzZQogICAgICByZXMgPDwg
# IiAgIiooQGxldmVsLTEpICsgIjwhLS0iICsgIlxuIgogICAgICByZXMgPDwg
# bGluZXMuY29sbGVjdHt8c3wgIiAgIiooQGxldmVsLTEpICsgcy5zdHJpcH0u
# ZGVsZXRlX2lme3xzfCBzLmNvbXByZXNzLmVtcHR5P30uam9pbigiXG4iKQog
# ICAgICByZXMgPDwgIlxuIgogICAgICByZXMgPDwgIiAgIiooQGxldmVsLTEp
# ICsgIi0tPiIgKyAiXG4iCiAgICAgIHJlcyA8PCAiXG4iCiAgICBlbmQKICBl
# bmQKZW5kCgpjbGFzcyBTcGVjaWFsIDwgU0dNTE9iamVjdAogIGRlZiBwcmVj
# aGlsZHJlbl90b194KHJlcywgY2xvc2V0YWdzKQogICAgcmVzIDw8ICIgICIq
# KEBsZXZlbC0xKSArIEB0ZXh0LmNvbXByZXNzICsgIlxuIgogIGVuZAplbmQK
# CmNsYXNzIEluc3RydWN0aW9uIDwgU0dNTE9iamVjdAogIGRlZiBwcmVjaGls
# ZHJlbl90b194KHJlcywgY2xvc2V0YWdzKQogICAgcmVzIDw8ICIgICIqKEBs
# ZXZlbC0xKSArIEB0ZXh0LmNvbXByZXNzICsgIlxuIgogIGVuZAplbmQKCmNs
# YXNzIE9wZW5UYWcgPCBUYWcKICBkZWYgcHJlY2hpbGRyZW5fdG9feChyZXMs
# IGNsb3NldGFncykKICAgIGEJPSBbQHN1YnR5cGVdCgogICAgYXJncwk9IEBh
# cmdzLmR1cAogICAgYXJncy5kZWxldGUoImlkIikKICAgIGFyZ3MuZGVsZXRl
# KCJuYW1lIikKICAgIGFyZ3MJPSBhcmdzLnNvcnQKICAgIGFyZ3MudW5zaGlm
# dChbImlkIiwgQGFyZ3NbImlkIl1dKQkJaWYgQGFyZ3MuaW5jbHVkZT8oImlk
# IikKICAgIGFyZ3MudW5zaGlmdChbIm5hbWUiLCBAYXJnc1sibmFtZSJdXSkJ
# aWYgQGFyZ3MuaW5jbHVkZT8oIm5hbWUiKQoKICAgIGFyZ3MuZWFjaCBkbyB8
# aywgdnwKICAgICAgaWYgbm90IHYuaW5jbHVkZT8oIiciKQogICAgICAgIGEg
# PDwgIiN7a309JyN7dn0nIgogICAgICBlbHNlCiAgICAgICAgaWYgbm90IHYu
# aW5jbHVkZT8oJyInKQogICAgICAgICAgYSA8PCAiI3trfT1cIiN7dn1cIiIK
# ICAgICAgICBlbHNlCiAgICAgICAgICBhIDw8ICIje2t9PScje3YuZ3N1Yigv
# XCcvLCAnIicpfSciCiAgICAgICAgZW5kCiAgICAgIGVuZAogICAgZW5kCgog
# ICAgaWYgQGNoaWxkcmVuLmxlbmd0aCA9PSAwIG9yIChAY2hpbGRyZW4ubGVu
# Z3RoID09IDEgYW5kIEBjaGlsZHJlblswXS5raW5kX29mPyhUZXh0KSBhbmQg
# QGNoaWxkcmVuWzBdLnRleHQuY29tcHJlc3MuZW1wdHk/KQogICAgICByZXMg
# PDwgIiAgIiooQGxldmVsLTEpICsgIjwje2Euam9pbigiICIpfS8+IiArICJc
# biIKICAgIGVsc2UKICAgICAgaWYgQGNoaWxkcmVuLmxlbmd0aCA9PSAxIGFu
# ZCBAY2hpbGRyZW5bMF0ua2luZF9vZj8oVGV4dCkgYW5kIEBjaGlsZHJlblsw
# XS50ZXh0LmxmLnNwbGl0KC9cbi8pLmxlbmd0aCA9PSAxCiAgICAgICAgcmVz
# IDw8ICIgICIqKEBsZXZlbC0xKSArICI8I3thLmpvaW4oIiAiKX0+IgogICAg
# ICBlbHNlCiAgICAgICAgcmVzIDw8ICIgICIqKEBsZXZlbC0xKSArICI8I3th
# LmpvaW4oIiAiKX0+IiArICJcbiIKICAgICAgZW5kCiAgICBlbmQKICBlbmQK
# CiAgZGVmIHBvc3RjaGlsZHJlbl90b194KHJlcywgY2xvc2V0YWdzKQogICAg
# aWYgY2xvc2V0YWdzCiAgICAgIHVubGVzcyBAY2hpbGRyZW4ubGVuZ3RoID09
# IDAgb3IgKEBjaGlsZHJlbi5sZW5ndGggPT0gMSBhbmQgQGNoaWxkcmVuWzBd
# LmtpbmRfb2Y/KFRleHQpIGFuZCBAY2hpbGRyZW5bMF0udGV4dC5jb21wcmVz
# cy5lbXB0eT8pCiAgICAgICAgcmVzIDw8ICJcbiIJCWlmIEBjaGlsZHJlbi5s
# ZW5ndGggPT0gMSBhbmQgQGNoaWxkcmVuWzBdLmtpbmRfb2Y/KFRleHQpIGFu
# ZCBAY2hpbGRyZW5bMF0udGV4dC5sZi5zcGxpdCgvXG4vKS5sZW5ndGggPiAx
# CiAgICAgICAgcmVzIDw8ICIgICIqKEBsZXZlbC0xKQl1bmxlc3MgQGNoaWxk
# cmVuLmxlbmd0aCA9PSAxIGFuZCBAY2hpbGRyZW5bMF0ua2luZF9vZj8oVGV4
# dCkgYW5kIEBjaGlsZHJlblswXS50ZXh0LmxmLnNwbGl0KC9cbi8pLmxlbmd0
# aCA9PSAxCiAgICAgICAgcmVzIDw8ICI8LyN7QHN1YnR5cGV9PiIKICAgICAg
# ICByZXMgPDwgIlxuIgogICAgICBlbmQKICAgIGVuZAogIGVuZAplbmQKCmNs
# YXNzIFhNTCA8IFNHTUwKICBkZWYgdG9feChjbG9zZXRhZ3M9dHJ1ZSkKICAg
# IHJlcwk9ICIiCgogICAgcGFyc2V0cmVlKCJwcmVjaGlsZHJlbl90b194Iiwg
# InBvc3RjaGlsZHJlbl90b194IiwgcmVzLCBjbG9zZXRhZ3MpCgogICAgcmVz
# CiAgZW5kCmVuZAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAcnVieXdlYmRpYWxvZ3MvbGliL25ldC5saWIucmIAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAADAwMDA3NTUAMDAwMTc1MAAwMDAxNzUwADAwMDAwMDQ2
# MjI2ADEwMjUwMzIwNjIxADAxNjQ0MAAgMAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3RhciAgAGVy
# aWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZXJpawAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAwMDAwMDAwADAwMDAwMDAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAByZXF1aXJlICJldi9ydWJ5IgpyZXF1aXJl
# ICJldi9mdG9vbHMiCnJlcXVpcmUgImV2L21pbWUiCnJlcXVpcmUgIm5ldC9o
# dHRwIgpyZXF1aXJlICJzb2NrZXQiCnJlcXVpcmUgInVyaSIKcmVxdWlyZSAi
# Y2dpIgpyZXF1aXJlICJtZDUiCnJlcXVpcmUgInRocmVhZCIKCiRwcm94eQk9
# IEVOVlsiUFJPWFkiXQlpZiAkcHJveHkubmlsPwoKZmlsZQk9ICIje2hvbWV9
# Ly5ldm5ldCIKaWYgRmlsZS5maWxlPyhmaWxlKQogIEhhc2guZmlsZShmaWxl
# KS5lYWNoIGRvIHxrLCB2fAogICAgZXZhbCAiJCN7a30gPSAnI3t2fSciCXVu
# bGVzcyBrPX4gL15cIy8KICBlbmQKZW5kCgpkZWYgdXJpMnR4dChzKQoJIyA/
# Pz8gV2Vya3QgbmlldCBnb2VkCiAgaQk9IHMuaW5kZXgoLyVbWzpkaWdpdDpd
# XXsyfS8pCiAgd2hpbGUgbm90IGkubmlsPwogICAgcwk9IHNbMC4uKGktMSld
# ICsgc1soaSsxKS4uKGkrMildLnVucGFjaygnSDInKS5zaGlmdC50b19pLmNo
# ciArIHNbKGkrMykuLi0xXQogICAgaQk9IHMuaW5kZXgoLyVbWzpkaWdpdDpd
# XXsyfS8pCiAgZW5kCiAgcwplbmQKCmNsYXNzIFRDUFNlcnZlcgogIGRlZiBz
# ZWxmLmZyZWVwb3J0KGZyb20sIHRvLCByZW1vdGU9ZmFsc2UpCiAgICBpZiB3
# aW5kb3dzPyBvciBjeWd3aW4/CiAgICAgIFRDUFNlcnZlci5mcmVlcG9ydF93
# aW5kb3dzKGZyb20sIHRvLCByZW1vdGUpCiAgICBlbHNlCiAgICAgIFRDUFNl
# cnZlci5mcmVlcG9ydF9saW51eChmcm9tLCB0bywgcmVtb3RlKQogICAgZW5k
# CiAgZW5kCgogIGRlZiBzZWxmLmZyZWVwb3J0X2xpbnV4KGZyb20sIHRvLCBy
# ZW1vdGUpCiAgICBwb3J0cwk9IChmcm9tLi50bykudG9fYQogICAgcG9ydAk9
# IG5pbAogICAgcmVzCQk9IG5pbAoKICAgIHdoaWxlIHJlcy5uaWw/IGFuZCBu
# b3QgcG9ydHMuZW1wdHk/CiAgICAgIGJlZ2luCiAgICAgICAgcG9ydAk9IHBv
# cnRzWzBdCiAgICAgICAgcG9ydHMuZGVsZXRlKHBvcnQpCgogICAgICAgIGlv
# CT0gVENQU2VydmVyLm5ldyhyZW1vdGUgPyAiMC4wLjAuMCIgOiAibG9jYWxo
# b3N0IiwgcG9ydCkKCiAgICAgICAgcmVzCT0gW3BvcnQsIGlvXQogICAgICBy
# ZXNjdWUKICAgICAgZW5kCiAgICBlbmQKCiAgICByZXMJPSBbbmlsLCBuaWxd
# CWlmIHJlcy5uaWw/CgogICAgcG9ydCwgaW8JPSByZXMKCiAgICByZXR1cm4g
# cG9ydCwgaW8KICBlbmQKCiAgZGVmIHNlbGYuZnJlZXBvcnRfd2luZG93cyhm
# cm9tLCB0bywgcmVtb3RlKQogICAgcG9ydHMJPSAoZnJvbS4udG8pLnRvX2EK
# ICAgIHBvcnQJPSBuaWwKICAgIHJlcwkJPSBuaWwKCiAgICB3aGlsZSByZXMu
# bmlsPyBhbmQgbm90IHBvcnRzLmVtcHR5PwogICAgICBiZWdpbgogICAgICAg
# IHBvcnQJPSBwb3J0cy5hbnkKICAgICAgICBwb3J0cy5kZWxldGUocG9ydCkK
# CiAgICAgICAgaW8JPSBUQ1BTb2NrZXQubmV3KCJsb2NhbGhvc3QiLCBwb3J0
# KQogICAgICAgIGlvLmNsb3NlCiAgICAgIHJlc2N1ZQogICAgICAgIHJlcwk9
# IHBvcnQKICAgICAgZW5kCiAgICBlbmQKCiAgICBwb3J0LCBpbwk9IHJlcwoK
# ICAgIHJldHVybiBwb3J0LCBpbwogIGVuZAoKICBkZWYgc2VsZi5mcmVlcG9y
# dF93aW5kb3dzMihmcm9tLCB0bywgcmVtb3RlKQogICAgcmVzCT0gbmlsCiAg
# ICBwb3J0CT0gZnJvbQoKICAgIHdoaWxlIHJlcy5uaWw/IGFuZCBwb3J0IDw9
# IHRvCiAgICAgIGJlZ2luCiAgICAgICAgaW8JPSBUQ1BTb2NrZXQubmV3KCJs
# b2NhbGhvc3QiLCBwb3J0KQogICAgICAgIGlvLmNsb3NlCgogICAgICAgIHBv
# cnQgKz0gMQogICAgICByZXNjdWUKICAgICAgICByZXMJPSBwb3J0CiAgICAg
# IGVuZAogICAgZW5kCgogICAgcmV0dXJuIHJlcwogIGVuZAoKICBkZWYgc2Vs
# Zi51c2VkcG9ydHMoZnJvbSwgdG8pCiAgICB0aHJlYWRzCT0gW10KICAgIHJl
# cwkJPSBbXQoKICAgIGZyb20udXB0byh0bykgZG8gfHBvcnR8CiAgICAgIHRo
# cmVhZHMgPDwgVGhyZWFkLm5ldyBkbwogICAgICAgIGJlZ2luCiAgICAgICAg
# ICBpbwk9IFRDUFNvY2tldC5uZXcoImxvY2FsaG9zdCIsIHBvcnQpCiAgICAg
# ICAgICBpby5jbG9zZQoKICAgICAgICAgIHBvcnQKICAgICAgICByZXNjdWUK
# ICAgICAgICAgIG5pbAogICAgICAgIGVuZAogICAgICBlbmQKICAgIGVuZAoK
# ICAgIHRocmVhZHMuZWFjaCBkbyB8dGhyZWFkfAogICAgICBwb3J0CT0gdGhy
# ZWFkLnZhbHVlCiAgICAgIHJlcyA8PCBwb3J0CXVubGVzcyBwb3J0Lm5pbD8K
# ICAgIGVuZAoKICAgIHJldHVybiByZXMKICBlbmQKZW5kCgpjbGFzcyBFVlVS
# SQogIGF0dHJfcmVhZGVyIDpwcm90b2NvbAogIGF0dHJfd3JpdGVyIDpwcm90
# b2NvbAogIGF0dHJfcmVhZGVyIDp1c2VycGFzcwogIGF0dHJfd3JpdGVyIDp1
# c2VycGFzcwogIGF0dHJfcmVhZGVyIDpob3N0CiAgYXR0cl93cml0ZXIgOmhv
# c3QKICBhdHRyX3JlYWRlciA6cG9ydAogIGF0dHJfd3JpdGVyIDpwb3J0CiAg
# YXR0cl9yZWFkZXIgOnBhdGgKICBhdHRyX3dyaXRlciA6cGF0aAogIGF0dHJf
# cmVhZGVyIDp2YXJzCiAgYXR0cl93cml0ZXIgOnZhcnMKICBhdHRyX3JlYWRl
# ciA6YW5jaG9yCiAgYXR0cl93cml0ZXIgOmFuY2hvcgoKICBkZWYgaW5pdGlh
# bGl6ZSh1cmwpCiAgICBiZWdpbgogICAgICBAcHJvdG9jb2wsIEB1c2VycGFz
# cywgQGhvc3QsIEBwb3J0LCBkMSwgQHBhdGgsIGQyLCBAdmFycywgQGFuY2hv
# cgk9IFVSSS5zcGxpdCh1cmwudG9fcykKICAgIHJlc2N1ZQogICAgZW5kCgog
# ICAgQHBhdGgJCT0gIi8iCQlpZiAobm90IEBwYXRoLm5pbD8gYW5kIEBwYXRo
# LmVtcHR5PyBhbmQgQHByb3RvY29sID09ICJodHRwIikKCiAgICBAcHJvdG9j
# b2wJCT0gIiIJCWlmIEBwcm90b2NvbC5uaWw/CiAgICBAdXNlcnBhc3MJCT0g
# IiIJCWlmIEB1c2VycGFzcy5uaWw/CiAgICBAaG9zdAkJPSAiIgkJaWYgQGhv
# c3QubmlsPwogICAgQHBvcnQJCT0gMAkJaWYgQHBvcnQubmlsPwogICAgQHBh
# dGgJCT0gIiIJCWlmIEBwYXRoLm5pbD8KICAgIEB2YXJzCQk9ICIiCQlpZiBA
# dmFycy5uaWw/CiAgICBAYW5jaG9yCQk9ICIiCQlpZiBAYW5jaG9yLm5pbD8K
# CiAgICByZXMJCQk9IHt9CiAgICBAdmFyc3ZvbGdvcmRlCT0gW10KICAgIEB2
# YXJzLnNwbGl0KC8mLykuZWFjaHt8dmFyfCBrLCB2ID0gdmFyLnNwbGl0KC89
# LykgOyByZXNba10gPSB2IDsgQHZhcnN2b2xnb3JkZSA8PCBrfQogICAgQHZh
# cnMJCT0gcmVzCgogICAgQHBvcnQJCT0gQHBvcnQudG9faQogIGVuZAoKICBk
# ZWYgKyh1cmwyKQogICAgdXJsMQk9IHNlbGYudG9fcwogICAgdXJsMgk9IHVy
# bDIudG9fcwlpZiB1cmwyLmtpbmRfb2Y/KHNlbGYuY2xhc3MpCgogICAgcmV0
# dXJuIEVWVVJJLm5ldygoVVJJOjpHZW5lcmljLm5ldygqVVJJLnNwbGl0KHVy
# bDEpKSArIFVSSTo6R2VuZXJpYy5uZXcoKlVSSS5zcGxpdCh1cmwyKSkpLnRv
# X3MpCXJlc2N1ZSBuaWwKICBlbmQKCiAgZGVmIHRvX3MKICAgIHByb3RvY29s
# CT0gQHByb3RvY29sCiAgICB1c2VycGFzcwk9IEB1c2VycGFzcwogICAgaG9z
# dAk9IEBob3N0CiAgICBwb3J0CT0gQHBvcnQKICAgIHBhdGgJPSBAcGF0aAog
# ICAgdmFycwk9IHZhcnN0cmluZwogICAgYW5jaG9yCT0gQGFuY2hvcgoKICAg
# IHByb3RvY29sCT0gbmlsCWlmIEBwcm90b2NvbC5lbXB0eT8KICAgIHVzZXJw
# YXNzCT0gbmlsCWlmIEB1c2VycGFzcy5lbXB0eT8KICAgIGhvc3QJPSBuaWwJ
# aWYgQGhvc3QuZW1wdHk/CiAgICBwb3J0CT0gbmlsCWlmIEBwb3J0Lnplcm8/
# CiAgICBwYXRoCT0gbmlsCWlmIEBwYXRoLmVtcHR5PwogICAgdmFycwk9IG5p
# bAlpZiBAdmFycy5lbXB0eT8KICAgIGFuY2hvcgk9IG5pbAlpZiBAYW5jaG9y
# LmVtcHR5PwoKICAgIHJlcwk9IFVSSTo6SFRUUC5uZXcoQHByb3RvY29sLCBA
# dXNlcnBhc3MsIEBob3N0LCBwb3J0LCBuaWwsIEBwYXRoLCBuaWwsIHZhcnMs
# IEBhbmNob3IpLnRvX3MuZnJvbV9odG1sCgogICAgcmVzLmdzdWIhKC9ALywg
# IiIpCWlmIChAdXNlcnBhc3MubmlsPyBvciBAdXNlcnBhc3MuZW1wdHk/KQoK
# ICAgIHJlcy5nc3ViISgvXCMkLywgIiIpCgogICAgcmV0dXJuIHJlcwogIGVu
# ZAoKICBkZWYgbG9jYWxuYW1lCiAgICBwcm90b2NvbAk9IEBwcm90b2NvbAog
# ICAgdXNlcnBhc3MJPSBAdXNlcnBhc3MKICAgIGhvc3QJPSBAaG9zdAogICAg
# cG9ydAk9IEBwb3J0CiAgICBwYXRoCT0gQHBhdGgKICAgIHZhcnMJPSB2YXJz
# dHJpbmcKICAgIGFuY2hvcgk9IEBhbmNob3IKCiAgICBwcm90b2NvbAk9IG5p
# bAlpZiBAcHJvdG9jb2wuZW1wdHk/CiAgICB1c2VycGFzcwk9IG5pbAlpZiBA
# dXNlcnBhc3MuZW1wdHk/CiAgICBob3N0CT0gbmlsCWlmIEBob3N0LmVtcHR5
# PwogICAgcG9ydAk9IG5pbAlpZiBAcG9ydC56ZXJvPwogICAgcGF0aAk9IG5p
# bAlpZiBAcGF0aC5lbXB0eT8KICAgIHZhcnMJPSBuaWwJaWYgQHZhcnMuZW1w
# dHk/CiAgICBhbmNob3IJPSBuaWwJaWYgQGFuY2hvci5lbXB0eT8KCiAgICBw
# YXRoCT0gIiN7cGF0aH0uIglpZiBwYXRoID1+IC9bXC9cXF0kLwoKICAgIGYJ
# PSBNRDUubmV3KHByb3RvY29sLnRvX3MgKyB1c2VycGFzcy50b19zICsgaG9z
# dC50b19zICsgcG9ydC50b19zICsgRmlsZS5kaXJuYW1lKHBhdGgudG9fcykg
# KyB2YXJzLnRvX3MpLnRvX3MKICAgIGUJPSBGaWxlLmJhc2VuYW1lKHBhdGgu
# dG9fcykuZ3N1YigvW15cd1wuXC1dLywgIl8iKS5nc3ViKC9fKy8sICJfIikK
# ICAgIHJlcwk9IGYgKyAiLiIgKyBlCiAgICByZXMuZ3N1YiEoL1teXHddKyQv
# LCAiIikKCiAgICByZXR1cm4gcmVzCiAgZW5kCgogIGRlZiB2YXJzdHJpbmcK
# ICAgIHJlcwkJPSBbXQogICAgdmFycwk9IEB2YXJzLmR1cAoKICAgIEB2YXJz
# dm9sZ29yZGUuZWFjaCBkbyB8a3wKICAgICAgaWYgdmFycy5pbmNsdWRlPyhr
# KQogICAgICAgIHYJPSB2YXJzW2tdCiAgICAgICAgdmFycy5kZWxldGUoaykK
# CiAgICAgICAgcmVzIDw8ICh2Lm5pbD8gPyBrIDogIiN7a309I3t2fSIpCiAg
# ICAgIGVuZAogICAgZW5kCgogICAgcmVzLmNvbmNhdCh2YXJzLmNvbGxlY3R7
# fGssIHZ8IHYubmlsPyA/IGsgOiAiI3trfT0je3Z9In0pCgogICAgcmV0dXJu
# IHJlcy5qb2luKCImIikKICBlbmQKZW5kCgpjbGFzcyBIVFRQQ2xpZW50CiAg
# QEB2ZXJzaWUJPSAxCiAgQEBtdXRleAk9IE11dGV4Lm5ldwogIEBAaG9zdHMJ
# PSB7fQoKICBjbGFzcyBIZWFkZXIKICAgIGF0dHJfcmVhZGVyIDpoZWFkZXIK
# ICAgIGF0dHJfcmVhZGVyIDpwcm90b2NvbAogICAgYXR0cl9yZWFkZXIgOmNv
# ZGUKICAgIGF0dHJfcmVhZGVyIDp0ZXh0CgogICAgZGVmIGluaXRpYWxpemUo
# aGVhZGVyKQogICAgICBAaGVhZGVyCT0ge30KCiAgICAgIGlmIG5vdCBoZWFk
# ZXIubmlsPwogICAgICAgIGZpcnN0bGluZSwgcmVzdAk9IGhlYWRlci5zcGxp
# dCgvXHIqXG4vLCAyKQoKICAgICAgICBAcHJvdG9jb2wsIEBjb2RlLCBAdGV4
# dAk9IGZpcnN0bGluZS5zcGxpdCgvICAqLywgMykKCiAgICAgICAgQGNvZGUJ
# PSBAY29kZS50b19pCgogICAgICAgIGlmIG5vdCByZXN0Lm5pbD8KICAgICAg
# ICAgIHJlc3Quc3BsaXQoL1xyKlxuLykuZWFjaCBkbyB8bGluZXwKICAgICAg
# ICAgICAga2V5LCB2YWx1ZQk9IGxpbmUuc3BsaXQoLyAvLCAyKQogICAgICAg
# ICAgICBAaGVhZGVyW2tleS5zdWIoLzokLywgIiIpLmRvd25jYXNlXQk9IHZh
# bHVlCiAgICAgICAgICBlbmQKICAgICAgICBlbmQKICAgICAgZW5kCiAgICBl
# bmQKCiAgICBkZWYgdG9fcwogICAgICByZXMJPSAiIgoKICAgICAgcmVzIDw8
# ICIlcyAlcyAlc1xuIiAlIFtAcHJvdG9jb2wsIEBjb2RlLCBAdGV4dF0KCiAg
# ICAgIEBoZWFkZXIuZWFjaCBkbyB8aywgdnwKICAgICAgICByZXMgPDwgIiVz
# PSVzXG4iICUgW2ssIHZdCiAgICAgIGVuZAoKICAgICAgcmV0dXJuIHJlcwog
# ICAgZW5kCiAgZW5kCgogIGNsYXNzIENodW5rCiAgICBkZWYgaW5pdGlhbGl6
# ZShkYXRhKQogICAgICBAZGF0YQk9ICIiCiAgICAgIGxpbmUsIGRhdGEJPSBk
# YXRhLnNwbGl0KC9ccipcbi8sIDIpCiAgICAgIHNpemUsIGV4dAkJPSBsaW5l
# LnNwbGl0KC87LywgMikKICAgICAgc2l6ZQkJPSBzaXplLmhleAogICAgICB3
# aGlsZSBub3Qgc2l6ZS56ZXJvPyBhbmQgbm90IGRhdGEubmlsPwogICAgICAg
# IEBkYXRhCQkrPSBkYXRhWzAuLihzaXplLTEpXQogICAgICAgIGRhdGEJCT0g
# ZGF0YVtzaXplLi4tMV0KICAgICAgICBpZiBub3QgZGF0YS5uaWw/CiAgICAg
# ICAgICBkYXRhLmdzdWIhKC9eXHIqXG4vLCAiIikKICAgICAgICAgIGxpbmUs
# IGRhdGEJPSBkYXRhLnNwbGl0KC9ccipcbi8sIDIpCiAgICAgICAgICBzaXpl
# LCBleHQJPSBsaW5lLnNwbGl0KC87LywgMikKICAgICAgICAgIHNpemUJCT0g
# c2l6ZS5oZXgKICAgICAgICBlbmQKICAgICAgZW5kCiAgICBlbmQKCiAgICBk
# ZWYgdG9fcwogICAgICBAZGF0YQogICAgZW5kCiAgZW5kCgogIGNsYXNzIE5v
# QWRkcmVzc0V4Y2VwdGlvbiA8IFN0YW5kYXJkRXJyb3IKICBlbmQKCiAgZGVm
# IHNlbGYuZ2V0YWRkcmVzcyhob3N0KQogICAgaWYgbm90IEBAaG9zdHMuaW5j
# bHVkZT8oaG9zdCkKICAgICAgQEBob3N0c1tob3N0XQk9ICIiCiAgICAgIGV2
# dGltZW91dCg1KSBkbwkjID8/PyBEb2V0ICd1dCBuaWV0Py4uLgogICAgICAg
# IEBAaG9zdHNbaG9zdF0JPSBJUFNvY2tldC5nZXRhZGRyZXNzKGhvc3QpCiAg
# ICAgIGVuZAogICAgZW5kCgogICAgcmFpc2UgTm9BZGRyZXNzRXhjZXB0aW9u
# LCBob3N0CWlmIEBAaG9zdHNbaG9zdF0uZW1wdHk/CgogICAgQEBob3N0c1to
# b3N0XQogIGVuZAoKICBkZWYgc2VsZi5oZWFkKHVyaSwgZm9ybT17fSwgcmVj
# dXJzaXZlPXRydWUpCiAgICBoZWFkZXIJPSBIZWFkZXIubmV3KG5pbCkKCiAg
# ICBiZWdpbgogICAgICB3aGlsZSBub3QgdXJpLm5pbD8KICAgICAgICB1cmkJ
# CT0gRVZVUkkubmV3KHVyaSkgaWYgdXJpLmtpbmRfb2Y/IFN0cmluZwogICAg
# ICAgIGhvc3QJCT0gdXJpLmhvc3QKICAgICAgICBwb3J0CQk9IHVyaS5wb3J0
# CgogICAgICAgIGlmICRwcm94eS5uaWw/IG9yICRwcm94eS5lbXB0eT8gb3Ig
# aG9zdCA9PSAibG9jYWxob3N0IgogICAgICAgICAgaW8JCT0gbmlsCgogICAg
# ICAgICAgQEBtdXRleC5zeW5jaHJvbml6ZSBkbwogICAgICAgICAgICBpbwkJ
# CT0gVENQU29ja2V0Lm5ldyhnZXRhZGRyZXNzKGhvc3QpLCBwb3J0Lnplcm8/
# ID8gODAgOiBwb3J0KQogICAgICAgICAgZW5kCgogICAgICAgICAgaW8ud3Jp
# dGUoIkhFQUQgI3t1cmkucGF0aCBvciAnLyd9I3t1cmkudmFyc3RyaW5nLmVt
# cHR5PyA/ICcnIDogJz8nICsgdXJpLnZhcnN0cmluZ30gSFRUUC8xLjBcclxu
# SG9zdDogI3tob3N0fVxyXG5cclxuIikKICAgICAgICBlbHNlCiAgICAgICAg
# ICBwcm94eQkJPSBFVlVSSS5uZXcoJHByb3h5KQogICAgICAgICAgaW8JCT0g
# VENQU29ja2V0Lm5ldyhwcm94eS5ob3N0LCBwcm94eS5wb3J0Lnplcm8/ID8g
# ODA4MCA6IHByb3h5LnBvcnQpCgogICAgICAgICAgaW8ud3JpdGUoIkhFQUQg
# I3t1cml9IEhUVFAvMS4wXHJcbiN7IlByb3h5LUF1dGhvcml6YXRpb246IEJh
# c2ljICIrJHByb3h5X2F1dGgrIlxyXG4iIGlmIG5vdCAkcHJveHlfYXV0aC5u
# aWw/fVxyXG5cclxuIikKICAgICAgICBlbmQKCiAgICAgICAgaW8uY2xvc2Vf
# d3JpdGUKCiAgICAgICAgcmVzCT0gaW8ucmVhZAoKICAgICAgICBpby5jbG9z
# ZV9yZWFkCgogICAgICAgIGhlYWRlciwgZGF0YQk9IG5pbCwgbmlsCiAgICAg
# ICAgaGVhZGVyLCBkYXRhCT0gcmVzLnNwbGl0KC9ccipcblxyKlxuLywgMikJ
# aWYgbm90IHJlcy5uaWw/CiAgICAgICAgaGVhZGVyCQk9IEhlYWRlci5uZXco
# aGVhZGVyKQoKICAgICAgICBpZiByZWN1cnNpdmUgYW5kIGhlYWRlci5oZWFk
# ZXJbImxvY2F0aW9uIl0gIT0gdXJpLnRvX3MKICAgICAgICAgIHVyaQk9IEVW
# VVJJLm5ldyh1cmkpICsgaGVhZGVyLmhlYWRlclsibG9jYXRpb24iXQogICAg
# ICAgIGVsc2UKICAgICAgICAgIHVyaQk9IG5pbAogICAgICAgIGVuZAogICAg
# ICBlbmQKICAgIHJlc2N1ZSBFcnJubzo6RUNPTk5SRVNFVCwgRXJybm86OkVI
# T1NUVU5SRUFDSCA9PiBlCiAgICAgICRzdGRlcnIucHV0cyBlLm1lc3NhZ2UK
# ICAgICAgc2xlZXAgMQogICAgICByZXRyeQogICAgcmVzY3VlIEVycm5vOjpF
# Q09OTlJFRlVTRUQgPT4gZQogICAgICBkYXRhCT0gbmlsCiAgICByZXNjdWUg
# Tm9BZGRyZXNzRXhjZXB0aW9uID0+IGUKICAgICAgJHN0ZGVyci5wdXRzIGUu
# bWVzc2FnZQogICAgICBoZWFkZXIJPSBIZWFkZXIubmV3KG5pbCkKICAgIGVu
# ZAoKICAgIEdDLnN0YXJ0CgogICAgcmV0dXJuIGhlYWRlcgogIGVuZAoKICBk
# ZWYgc2VsZi5nZXQodXJpLCBodHRwaGVhZGVyPXt9LCBmb3JtPXt9KQogICAg
# cG9zdAk9IEFycmF5Lm5ldwogICAgZm9ybS5lYWNoX3BhaXIgZG8gfHZhciwg
# dmFsdWV8CiAgICAgIHBvc3QgPDwgIiN7dmFyLnRvX2h0bWx9PSN7dmFsdWUu
# dG9faHRtbH0iCiAgICBlbmQKICAgIHBvc3QJPSBwb3N0LmpvaW4oIj8iKQoK
# ICAgIGRhdGEJPSBuaWwKCiAgICBiZWdpbgogICAgICB3aGlsZSBub3QgdXJp
# Lm5pbD8KICAgICAgICB1cmkJPSBFVlVSSS5uZXcodXJpKSBpZiB1cmkua2lu
# ZF9vZj8gU3RyaW5nCiAgICAgICAgaG9zdAk9IHVyaS5ob3N0CiAgICAgICAg
# cG9ydAk9IHVyaS5wb3J0CgogICAgICAgIGlmICRwcm94eS5uaWw/IG9yICRw
# cm94eS5lbXB0eT8gb3IgaG9zdCA9PSAibG9jYWxob3N0IgogICAgICAgICAg
# aW8JPSBuaWwKICAgICAgICAgIEBAbXV0ZXguc3luY2hyb25pemUgZG8KICAg
# ICAgICAgICAgaW8JCQk9IFRDUFNvY2tldC5uZXcoZ2V0YWRkcmVzcyhob3N0
# KSwgcG9ydC56ZXJvPyA/IDgwIDogcG9ydCkKICAgICAgICAgIGVuZAoKICAg
# ICAgICAgIGlmIHBvc3QuZW1wdHk/CiAgICAgICAgICAgIGlvLndyaXRlICJH
# RVQgJXMlcyBIVFRQLzEuMFxyXG4iICUgWyh1cmkucGF0aCBvciAnLycpLCAo
# dXJpLnZhcnN0cmluZy5lbXB0eT8gPyAnJyA6ICc/JyArIHVyaS52YXJzdHJp
# bmcpXQogICAgICAgICAgZWxzZQogICAgICAgICAgICBpby53cml0ZSAiUE9T
# VCAlcyVzIEhUVFAvMS4wXHJcbiIgJSBbKHVyaS5wYXRoIG9yICcvJyksICh1
# cmkudmFyc3RyaW5nLmVtcHR5PyA/ICcnIDogJz8nICsgdXJpLnZhcnN0cmlu
# ZyldCiAgICAgICAgICBlbmQKICAgICAgICBlbHNlCiAgICAgICAgICBwcm94
# eQk9IEVWVVJJLm5ldygkcHJveHkpCiAgICAgICAgICBpbwk9IFRDUFNvY2tl
# dC5uZXcocHJveHkuaG9zdCwgcHJveHkucG9ydC56ZXJvPyA/IDgwODAgOiBw
# cm94eS5wb3J0KQoKICAgICAgICAgIGlmIHBvc3QuZW1wdHk/CiAgICAgICAg
# ICAgIGlvLndyaXRlICJHRVQgJXMgSFRUUC8xLjBcclxuIiAlIHVyaQogICAg
# ICAgICAgZWxzZQogICAgICAgICAgICBpby53cml0ZSAiUE9TVCAlcyBIVFRQ
# LzEuMFxyXG4iICUgdXJpCiAgICAgICAgICBlbmQKICAgICAgICBlbmQKCiAg
# ICAgICAgaW8ud3JpdGUgIkhvc3Q6ICVzXHJcbiIgJSBob3N0CiAgICAgICAg
# aW8ud3JpdGUgIlVzZXItQWdlbnQ6IHh5elxyXG4iCiAgICAgICAgaW8ud3Jp
# dGUgIlByb3h5LUF1dGhvcml6YXRpb246IEJhc2ljICVzXHJcbiIgJSAkcHJv
# eHlfYXV0aAl1bmxlc3MgJHByb3h5X2F1dGgubmlsPwogICAgICAgICNpby53
# cml0ZSAiQWNjZXB0LUVuY29kaW5nOiBkZWZsYXRlXHJcbiIKICAgICAgICAj
# aW8ud3JpdGUgIkFjY2VwdC1DaGFyc2V0OiBJU08tODg1OS0xXHJcbiIKICAg
# ICAgICBpby53cml0ZSAiQ29ubmVjdGlvbjogY2xvc2VcclxuIgogICAgICAg
# IGlvLndyaXRlICJDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL3gtd3d3LWZv
# cm0tdXJsZW5jb2RlZFxyXG4iCXVubGVzcyBwb3N0LmVtcHR5PwogICAgICAg
# IGlvLndyaXRlICJDb250ZW50LUxlbmd0aDogJXNcclxuIiAlIHBvc3QubGVu
# Z3RoCQkJdW5sZXNzIHBvc3QuZW1wdHk/CiAgICAgICAgaHR0cGhlYWRlci5l
# YWNoIGRvIHxrLCB2fAogICAgICAgICAgJHN0ZGVyci5wdXRzICIlczogJXNc
# clxuIiAlIFtrLCB2XQogICAgICAgICAgaW8ud3JpdGUgIiVzOiAlc1xyXG4i
# ICUgW2ssIHZdCiAgICAgICAgZW5kCiAgICAgICAgaW8ud3JpdGUgIlxyXG4i
# CiAgICAgICAgaW8ud3JpdGUgcG9zdAkJCQkJCQl1bmxlc3MgcG9zdC5lbXB0
# eT8KCiAgICAgICAgaW8uY2xvc2Vfd3JpdGUKCiAgICAgICAgcmVzCQk9IGlv
# LnJlYWQKCiAgICAgICAgaW8uY2xvc2VfcmVhZAoKICAgICAgICBoZWFkZXIs
# IGRhdGEJPSBuaWwsIG5pbAogICAgICAgIGhlYWRlciwgZGF0YQk9IHJlcy5z
# cGxpdCgvXHIqXG5ccipcbi8sIDIpCWlmIG5vdCByZXMubmlsPwoKICAgICAg
# ICBoZWFkZXIJPSBIZWFkZXIubmV3KGhlYWRlcikKICAgICAgICBsZW5ndGgJ
# PSBoZWFkZXIuaGVhZGVyWyJjb250ZW50LWxlbmd0aCJdCiAgICAgICAgZGF0
# YQk9ICIiCWlmIGxlbmd0aCA9PSAiMCIKCiAgICAgICAgaWYgaGVhZGVyLmhl
# YWRlclsibG9jYXRpb24iXSAhPSB1cmkudG9fcwogICAgICAgICAgdXJpCT0g
# RVZVUkkubmV3KHVyaSkgKyBoZWFkZXIuaGVhZGVyWyJsb2NhdGlvbiJdCiAg
# ICAgICAgZWxzZQogICAgICAgICAgdXJpCT0gbmlsCiAgICAgICAgZW5kCgog
# ICAgICAgIGlmIGhlYWRlci5oZWFkZXJbInRyYW5zZmVyLWVuY29kaW5nIl0g
# PT0gImNodW5rZWQiCiAgICAgICAgICBkYXRhCT0gQ2h1bmsubmV3KGRhdGEp
# LnRvX3MJaWYgbm90IGRhdGEubmlsPwogICAgICAgIGVuZAoKICAgICAgICAj
# aWYgaGVhZGVyLmhlYWRlclsiY29udGVudC1lbmNvZGluZyJdID09ICJnemlw
# IgogICAgICAgICAgI2RhdGEJPSAiZ3ppcCAtZCIuZXhlYyhkYXRhKQlpZiBu
# b3QgZGF0YS5uaWw/CiAgICAgICAgI2VuZAoKICAgICAgICBkYXRhCT0gbmls
# CXVubGVzcyBoZWFkZXIuY29kZSA9PSAyMDAKICAgICAgZW5kCiAgICByZXNj
# dWUgRXJybm86OkVDT05OUkVTRVQsIEVycm5vOjpFSE9TVFVOUkVBQ0ggPT4g
# ZQogICAgICAkc3RkZXJyLnB1dHMgZS5tZXNzYWdlCiAgICAgIHNsZWVwIDEK
# ICAgICAgcmV0cnkKICAgIHJlc2N1ZSBFcnJubzo6RUNPTk5SRUZVU0VEID0+
# IGUKICAgICAgZGF0YQk9IG5pbAogICAgcmVzY3VlIE5vQWRkcmVzc0V4Y2Vw
# dGlvbiwgRXJybm86OkVDT05OUkVGVVNFRCA9PiBlCiAgICAgICRzdGRlcnIu
# cHV0cyBlLm1lc3NhZ2UKICAgICAgZGF0YQk9IG5pbAogICAgZW5kCgogICAg
# R0Muc3RhcnQKCiAgICByZXR1cm4gZGF0YQogIGVuZAoKICBkZWYgc2VsZi5o
# ZWFkX2Zyb21fY2FjaGUodXJpLCBmb3JtPXt9KQogICAgZnJvbV9jYWNoZSgi
# aGVhZCIsIHVyaSwgZm9ybSkKICBlbmQKCiAgZGVmIHNlbGYuZ2V0X2Zyb21f
# Y2FjaGUodXJpLCBmb3JtPXt9KQogICAgZnJvbV9jYWNoZSgiZ2V0IiwgdXJp
# LCBmb3JtKQogIGVuZAoKICBkZWYgc2VsZi5mcm9tX2NhY2hlKGFjdGlvbiwg
# dXJpLCBmb3JtKQogICAgbG9jCQk9IHVyaS50b19zICsgZm9ybS5zb3J0Lmlu
# c3BlY3QKICAgIGhhc2gJPSBNRDUubmV3KCIje0BAdmVyc2llfSAje2xvY30i
# KQoKICAgIGRpcgkJPSAiI3t0ZW1wfS9ldmNhY2hlLiN7dXNlcn0vaHR0cGNs
# aWVudC4je2FjdGlvbn0iCiAgICBmaWxlCT0gIiN7ZGlyfS8je2hhc2h9Igog
# ICAgZGF0YQk9IG5pbAoKICAgIEZpbGUubWtwYXRoKGRpcikKCiAgICBleHBp
# cmUJPSAzNTYqMjQqNjAqNjAKCiAgICBpZiBGaWxlLmZpbGU/KGZpbGUpIGFu
# ZCAoVGltZS5uZXcudG9fZiAtIEZpbGUuc3RhdChmaWxlKS5tdGltZS50b19m
# IDwgZXhwaXJlKQogICAgICBAQG11dGV4LnN5bmNocm9uaXplIGRvCiAgICAg
# ICAgRmlsZS5vcGVuKGZpbGUsICJyYiIpCXt8ZnwgZGF0YSA9IGYucmVhZH0K
# ICAgICAgZW5kCiAgICBlbHNlCiAgICAgIGRhdGEJPSBtZXRob2QoYWN0aW9u
# KS5jYWxsKHVyaSwgZm9ybSkKCiAgICAgIGlmIG5vdCBkYXRhLm5pbD8KICAg
# ICAgICBAQG11dGV4LnN5bmNocm9uaXplIGRvCiAgICAgICAgICBGaWxlLm9w
# ZW4oZmlsZSwgIndiIikJe3xmfCBmLndyaXRlIGRhdGF9CiAgICAgICAgZW5k
# CiAgICAgIGVuZAogICAgZW5kCgogICAgcmV0dXJuIGRhdGEKICBlbmQKZW5k
# CgpjbGFzcyBSZXF1ZXN0R2V0IDwgSGFzaAogIGRlZiBpbml0aWFsaXplKGRh
# dGEpCiAgICBDR0kucGFyc2UoZGF0YSkuZWFjaCBkbyB8aywgdnwKICAgICAg
# c2VsZltrXQk9IHYKICAgIGVuZAogIGVuZAplbmQKCmNsYXNzIFJlcXVlc3RQ
# b3N0IDwgSGFzaAogIGRlZiBpbml0aWFsaXplKGRhdGEpCiAgICBDR0kucGFy
# c2UoZGF0YSkuZWFjaCBkbyB8aywgdnwKICAgICAgc2VsZltrXQk9IHYKICAg
# IGVuZAogIGVuZAplbmQKCmNsYXNzIFJlcXVlc3RSZXF1ZXN0CiAgYXR0cl9y
# ZWFkZXIgOm1ldGhvZAogIGF0dHJfcmVhZGVyIDp1cmkKICBhdHRyX3JlYWRl
# ciA6cGF0aAogIGF0dHJfcmVhZGVyIDpkYXRhCiAgYXR0cl9yZWFkZXIgOnBy
# b3RvY29sCgogIGRlZiBpbml0aWFsaXplKGZpcnN0bGluZSkKICAgIEBtZXRo
# b2QsIEB1cmksIEBwcm90b2NvbAk9IGZpcnN0bGluZS5zcGxpdCgvIC8pCiAg
# ICBAcGF0aCwgQGRhdGEJCT0gQHVyaS5zcGxpdCgvXD8vKQogICAgQGRhdGEJ
# CQk9ICIiCQkJaWYgQGRhdGEubmlsPwkjIFRPRE8KCiMgICAgaQk9IEBwYXRo
# LmluZGV4KC8lW1s6ZGlnaXQ6XV17Mn0vKQojICAgIHdoaWxlIG5vdCBpLm5p
# bD8KIyAgICAgIEBwYXRoCT0gQHBhdGhbMC4uKGktMSldICsgQHBhdGhbKGkr
# MSkuLihpKzIpXS51bnBhY2soJ0gyJykuc2hpZnQudG9faS5jaHIgKyBAcGF0
# aFsoaSszKS4uLTFdCiMgICAgICBpCT0gQHBhdGguaW5kZXgoLyVbWzpkaWdp
# dDpdXXsyfS8pCiMgICAgZW5kCiAgZW5kCgogIGRlZiB0b19zCiAgICAiI3tA
# bWV0aG9kfSAje0B1cml9ICN7QHByb3RvY29sfVxyXG4iCiAgZW5kCgogIGRl
# ZiBpbnNwZWN0CiAgICAiKFJlcXVlc3RSZXF1ZXN0OiAlcykiICUgW0BtZXRo
# b2QsIEBwYXRoLCBAZGF0YSwgQHByb3RvY29sXS5qb2luKCIsICIpCiAgZW5k
# CmVuZAoKY2xhc3MgUmVxdWVzdCA8IEhhc2gKICBhdHRyX3JlYWRlciA6cGVl
# cmFkZHIKICBhdHRyX3JlYWRlciA6cmVxdWVzdAogIGF0dHJfcmVhZGVyIDpj
# b29raWVzCiAgYXR0cl9yZWFkZXIgOnZhcnMKICBhdHRyX3JlYWRlciA6dXNl
# cgogIGF0dHJfd3JpdGVyIDp1c2VyCgogIGRlZiBpbml0aWFsaXplKGlvKQog
# ICAgQGlvCQk9IGlvCgogICAgZmlyc3RsaW5lCT0gQGlvLmdldHMKCiAgICBy
# ZXR1cm4JaWYgZmlyc3RsaW5lLm5pbD8KCiAgICBAcmVxdWVzdAk9IFJlcXVl
# c3RSZXF1ZXN0Lm5ldyhmaXJzdGxpbmUuc3RyaXApCgogICAgbGluZQk9IEBp
# by5nZXRzCiAgICBsaW5lCT0gbGluZS5zdHJpcAl1bmxlc3MgbGluZS5uaWw/
# CiAgICB3aGlsZSBub3QgbGluZS5uaWw/IGFuZCBub3QgbGluZS5lbXB0eT8K
# ICAgICAga2V5LCB2YWx1ZQk9IGxpbmUuc3BsaXQoIiAiLCAyKQogICAgICBz
# ZWxmW2tleS5zdWIoLzokLywgIiIpLmRvd25jYXNlXQk9IHZhbHVlCgogICAg
# ICBsaW5lCT0gQGlvLmdldHMKICAgICAgbGluZQk9IGxpbmUuc3RyaXAJdW5s
# ZXNzIGxpbmUubmlsPwogICAgZW5kCgogICAgY29va2llCT0gc2VsZlsiY29v
# a2llIl0KICAgIGNvb2tpZQk9ICIiCWlmIGNvb2tpZS5uaWw/CiAgICBAY29v
# a2llcwk9IHt9CiAgICBjb29raWUuc3BsaXQoLzsvKS5lYWNoIGRvIHxzfAog
# ICAgICBrLCB2CQk9IHMuc3RyaXAuc3BsaXQoLz0vLCAyKQogICAgICBAY29v
# a2llc1trXQk9IHYKICAgIGVuZAoKICAgIGlmIG5vdCBAcmVxdWVzdC5tZXRo
# b2QubmlsPwogICAgICBjYXNlIEByZXF1ZXN0Lm1ldGhvZC51cGNhc2UKICAg
# ICAgd2hlbiAiSEVBRCIKICAgICAgd2hlbiAiR0VUIgogICAgICAgIEB2YXJz
# CT0gUmVxdWVzdEdldC5uZXcoQHJlcXVlc3QuZGF0YS5uaWw/ID8gIiIgOiBA
# cmVxdWVzdC5kYXRhKQogICAgICB3aGVuICJQT1NUIgogICAgICAgIGRhdGEJ
# PSAoQGlvLnJlYWQoc2VsZlsiY29udGVudC1sZW5ndGgiXS50b19pKSBvciAi
# IikKICAgICAgICBAdmFycwk9IFJlcXVlc3RQb3N0Lm5ldygoc2VsZlsiY29u
# dGVudC10eXBlIl0gPT0gImFwcGxpY2F0aW9uL3gtd3d3LWZvcm0tdXJsZW5j
# b2RlZCIpID8gZGF0YSA6ICIiKQogICAgICBlbHNlCiAgICAgICAgJHN0ZGVy
# ci5wdXRzICJVbmtub3duIHJlcXVlc3QgKCcje2ZpcnN0bGluZX0nKS4iCiAg
# ICAgIGVuZAogICAgZW5kCgogICAgQHBlZXJhZGRyCT0gQGlvLnBlZXJhZGRy
# CgogICAgQHBkYQk9IGZhbHNlCiAgICBAcGRhCT0gdHJ1ZQlpZiAoc2VsZi5p
# bmNsdWRlPygidXNlci1hZ2VudCIpIGFuZCBzZWxmWyJ1c2VyLWFnZW50Il0u
# ZG93bmNhc2UuaW5jbHVkZT8oIndpbmRvd3MgY2UiKSkKICAgIEBwZGEJPSB0
# cnVlCWlmIChzZWxmLmluY2x1ZGU/KCJ1c2VyLWFnZW50IikgYW5kIHNlbGZb
# InVzZXItYWdlbnQiXS5kb3duY2FzZS5pbmNsdWRlPygiaGFuZGh0dHAiKSkK
# CiAgICBAaW8uY2xvc2VfcmVhZAogIGVuZAoKICBkZWYgcGRhPwogICAgQHBk
# YQogIGVuZAoKICBkZWYgdG9fcwogICAgcmVzID0gQHJlcXVlc3QudG9fcwog
# ICAgc2VsZi5lYWNoIGRvIHxrLCB2fAogICAgICByZXMgPDwgIiN7a306ICN7
# dn1cclxuIgogICAgZW5kCiAgICByZXMKICBlbmQKCiAgZGVmIGluc3BlY3QK
# ICAgICIoUmVxdWVzdDogJXMpIiAlIFtAcGVlcmFkZHIsIEByZXF1ZXN0Lmlu
# c3BlY3QsIEB2YXJzLmluc3BlY3QsIEBjb29raWVzLmluc3BlY3QsIHN1cGVy
# XS5qb2luKCIsICIpCiAgZW5kCmVuZAoKY2xhc3MgUmVzcG9uc2UgPCBIYXNo
# CiAgYXR0cl93cml0ZXIgOnJlc3BvbnNlCiAgYXR0cl93cml0ZXIgOmZpbGUK
# ICBhdHRyX3JlYWRlciA6Y29va2llcwogIGF0dHJfcmVhZGVyIDpzdG9wCiAg
# YXR0cl9yZWFkZXIgOmF0X3N0b3AKCiAgZGVmIGluaXRpYWxpemUoaW8pCiAg
# ICBAaW8JCT0gaW8KICAgIEByZXNwb25zZQk9ICJIVFRQLzEuMCAyMDAgT0si
# CiAgICBAY29va2llcwk9IHt9CiAgICBAZGF0YQk9ICIiCiAgICBAc3luY2QJ
# PSBmYWxzZQogICAgQHN0b3AJPSBmYWxzZQogICAgQGF0X3N0b3AJPSBsYW1i
# ZGF7fQogICAgQGZpbGUJPSBuaWwKICBlbmQKCiAgZGVmIGZsdXNoCiAgICBz
# eW5jCgogICAgaWYgQGZpbGUKICAgICAgRmlsZS5vcGVuKEBmaWxlLCAicmIi
# KSBkbyB8ZnwKICAgICAgICB3aGlsZSBkYXRhID0gZi5yZWFkKDEwXzAwMCkK
# ICAgICAgICAgIEBpby53cml0ZSBkYXRhCiAgICAgICAgZW5kCiAgICAgIGVu
# ZAogICAgZW5kCgogICAgQGlvLmNsb3NlCiAgZW5kCgogIGRlZiB0b19zCiAg
# ICByZXMgPSAiI3tAcmVzcG9uc2V9XHJcbiIKICAgIHNlbGYuZWFjaCBkbyB8
# aywgdnwKICAgICAgcmVzIDw8ICIje2t9OiAje3Z9XHJcbiIKICAgIGVuZAoK
# ICAgIEBjb29raWVzLmVhY2ggZG8gfGssIHZ8CiAgICAgIHJlcyA8PCAiU2V0
# LUNvb2tpZTogJXM9JXM7XHJcbiIgJSBbaywgdl0KICAgIGVuZAoKICAgIHJl
# cwogIGVuZAoKICBkZWYgc3luYwogICAgc2l6ZQk9IChAZGF0YSBvciAiIiku
# bGVuZ3RoCgogICAgaWYgQGZpbGUKICAgICAgZXh0CT0gQGZpbGUuc2Nhbigv
# XC5bXlwuXSokLykKICAgICAgZXh0CT0gZXh0LnNoaWZ0CiAgICAgIGV4dAk9
# IGV4dFsxLi4tMV0JdW5sZXNzIGV4dC5uaWw/CiAgICAgIG1pbWV0eXBlCT0g
# RVZNaW1lOjpNaW1lVHlwZVtleHRdCgogICAgICBzZWxmWyJDb250ZW50LVR5
# cGUiXQk9IG1pbWV0eXBlCQl1bmxlc3MgbWltZXR5cGUubmlsPwoKICAgICAg
# c2l6ZSArPSBGaWxlLnNpemUoQGZpbGUpCWlmIEZpbGUuZmlsZT8oQGZpbGUp
# CiAgICBlbmQKCiAgICBzZWxmWyJDb250ZW50LUxlbmd0aCJdCT0gc2l6ZQoK
# ICAgIEBpby53cml0ZSgiI3t0b19zfVxyXG4iKQl1bmxlc3MgQHN5bmNkCiAg
# ICBAaW8ud3JpdGUoQGRhdGEpCiAgICBAZGF0YQk9ICIiCiAgICBAc3luY2QJ
# PSB0cnVlCiAgZW5kCgogIGRlZiA8PCAocykKICAgIEBkYXRhIDw8IHMKICBl
# bmQKCiAgZGVmIGNsZWFuCiAgICBAZGF0YQk9ICIiCiAgZW5kCgogIGRlZiBp
# bnNwZWN0CiAgICAiKFJlc3BvbnNlOiAlcykiICUgW0ByZXNwb25zZSwgQGRh
# dGFdLmpvaW4oIiwgIikKICBlbmQKCiAgZGVmIHN0b3AoJmJsb2NrKQogICAg
# QHN0b3AJPSB0cnVlCiAgICBAYXRfc3RvcAk9IGJsb2NrCXVubGVzcyBibG9j
# ay5uaWw/CiAgZW5kCgogIGRlZiBzdG9wPwogICAgQHN0b3AKICBlbmQKZW5k
# CgpjbGFzcyBIVFRQU2VydmVyRXhjZXB0aW9uIDwgRXhjZXB0aW9uCmVuZAoK
# Y2xhc3MgSFRUUFNlcnZlcgogIGRlZiBzZWxmLnNlcnZlKHBvcnRpbz04MCwg
# cmVtb3RlPWZhbHNlLCBhdXRoPW5pbCwgcmVhbG09ImV2L25ldCIpCiAgICBw
# b3J0LCBzZXJ2ZXIJPSBwb3J0aW8KCiAgICBiZWdpbgogICAgICBzZXJ2ZXIJ
# PSBUQ1BTZXJ2ZXIubmV3KHJlbW90ZSA/ICIwLjAuMC4wIiA6ICJsb2NhbGhv
# c3QiLCBwb3J0KQlpZiBzZXJ2ZXIubmlsPwoKICAgICAgJHN0ZGVyci5wdXRz
# ICJKdXN0IHBvaW50IHlvdXIgYnJvd3NlciB0byBodHRwOi8vbG9jYWxob3N0
# OiN7cG9ydH0vIC4uLiIKICAgIHJlc2N1ZQogICAgICBzZXJ2ZXIJPSBuaWwK
# CiAgICAgICRzdGRlcnIucHV0cyAiUG9ydCAje3BvcnR9IGlzIGluIHVzZS4i
# CiAgICBlbmQKCiAgICBpZiBub3Qgc2VydmVyLm5pbD8KICAgICAgY291bnQJ
# PSAwCgogICAgICBhdF9leGl0IGRvCiAgICAgICAgIyRzdGRlcnIucHV0cyAi
# UmVjZWl2ZWQgI3tjb3VudH0gcmVxdWVzdHMiCiAgICAgIGVuZAoKICAgICAg
# c2VydmVydGhyZWFkID0KICAgICAgVGhyZWFkLm5ldyBkbwogICAgICAgIG11
# dGV4CT0gTXV0ZXgubmV3CgogICAgICAgIFRocmVhZC5jdXJyZW50WyJ0aHJl
# YWRzIl0JPSBbXQoKICAgICAgICBldmVyeSgxLCBUaHJlYWQuY3VycmVudCkg
# ZG8gfHRocmVhZHwKICAgICAgICAgIG11dGV4LnN5bmNocm9uaXplIGRvCiAg
# ICAgICAgICAgIHRocmVhZFsidGhyZWFkcyJdLmRlbGV0ZV9pZnt8dHwgKG5v
# dCB0LmFsaXZlPyl9CiAgICAgICAgICBlbmQKICAgICAgICBlbmQKCiAgICAg
# ICAgbG9vcCBkbwogICAgICAgICAgaW8JPSBzZXJ2ZXIuYWNjZXB0CiAgICAg
# ICAgICBjb3VudCArPSAxCgogICAgICAgICAgdGhyZWFkID0KICAgICAgICAg
# IFRocmVhZC5uZXcoVGhyZWFkLmN1cnJlbnQsIGNvdW50KSBkbyB8cGFyZW50
# dGhyZWFkLCBjb3VudDJ8CiAgICAgICAgICAgIHN0b3AJPSBmYWxzZQoKICAg
# ICAgICAgICAgYmVnaW4KICAgICAgICAgICAgICBiZWdpbgogICAgICAgICAg
# ICAgICAgcmVxCT0gUmVxdWVzdC5uZXcoaW8pCiAgICAgICAgICAgICAgICBy
# ZXNwCT0gUmVzcG9uc2UubmV3KGlvKQogICAgICAgICAgICAgIHJlc2N1ZQog
# ICAgICAgICAgICAgICAgcmFpc2UgSFRUUFNlcnZlckV4Y2VwdGlvbgogICAg
# ICAgICAgICAgIGVuZAoKICAgICAgICAgICAgICBiZWdpbgogICAgICAgICAg
# ICAgICAgaXAJPSByZXEucGVlcmFkZHJbM10KICAgICAgICAgICAgICByZXNj
# dWUgTmFtZUVycm9yCiAgICAgICAgICAgICAgICByYWlzZSBIVFRQU2VydmVy
# RXhjZXB0aW9uCiAgICAgICAgICAgICAgZW5kCgogICAgICAgICAgICAgIGlm
# IChub3QgcmVtb3RlKSBvciAocmVtb3RlIGFuZCAoYXV0aC5uaWw/IG9yIGF1
# dGguZW1wdHk/IG9yIGF1dGhlbnRpY2F0ZShhdXRoLCByZWFsbSwgcmVxLCBy
# ZXNwKSkpCiAgICAgICAgICAgICAgICAkc3RkZXJyLnB1dHMgIiN7Y291bnQy
# fSAje1RpbWUubmV3LnN0cmZ0aW1lKCIlWS0lbS0lZCAlSDolTTolUyIpfSAj
# e2lwfSAje3JlcS51c2VyfSAje3JlcS5yZXF1ZXN0LnRvX3Muc3RyaXB9IgoK
# ICAgICAgICAgICAgICAgIGJlZ2luCiAgICAgICAgICAgICAgICAgIHlpZWxk
# KHJlcSwgcmVzcCkKICAgICAgICAgICAgICAgIHJlc2N1ZSBFeGNlcHRpb24g
# PT4gZQogICAgICAgICAgICAgICAgICBtdXRleC5zeW5jaHJvbml6ZSBkbwog
# ICAgICAgICAgICAgICAgICAgICRzdGRlcnIucHV0cyBlLmNsYXNzLnRvX3Mg
# KyAiOiAiICsgZS5tZXNzYWdlCiAgICAgICAgICAgICAgICAgICAgJHN0ZGVy
# ci5wdXRzIGUuYmFja3RyYWNlLmNvbGxlY3R7fHN8ICJcdCIrc30uam9pbigi
# XG4iKQogICAgICAgICAgICAgICAgICBlbmQKICAgICAgICAgICAgICAgICAg
# cmVzcFsiQ29udGVudC1UeXBlIl0JPSAidGV4dC9wbGFpbiIKICAgICAgICAg
# ICAgICAgICAgcmVzcC5yZXNwb25zZQkJPSAiSFRUUC8xLjAgMjAwID8/PyIK
# ICAgICAgICAgICAgICAgICAgcmVzcC5jbGVhbgogICAgICAgICAgICAgICAg
# ICByZXNwIDw8IGUuY2xhc3MudG9fcyArICI6ICIgKyBlLm1lc3NhZ2UKICAg
# ICAgICAgICAgICAgICAgcmVzcCA8PCAiXG4iCiAgICAgICAgICAgICAgICAg
# IHJlc3AgPDwgIlxuIgogICAgICAgICAgICAgICAgICByZXNwIDw8IGUuYmFj
# a3RyYWNlLmNvbGxlY3R7fHN8ICJcdCIrc30uam9pbigiXG4iKQogICAgICAg
# ICAgICAgICAgICByZXNwIDw8ICJcbiIKICAgICAgICAgICAgICAgICAgcmVz
# cCA8PCAiXG4iCiAgICAgICAgICAgICAgICAgIHJlc3AgPDwgIihZb3UgY2Fu
# IHVzZSB0aGUgYmFjayBidXR0b24gYW5kIHN0b3AgdGhlIGFwcGxpY2F0aW9u
# IHByb3Blcmx5LCBpZiBhcHByb3ByaWF0ZS4pIgogICAgICAgICAgICAgICAg
# ZW5kCgogICAgICAgICAgICAgICAgc3RvcAk9IHRydWUJaWYgcmVzcC5zdG9w
# PwogICAgICAgICAgICAgIGVuZAoKICAgICAgICAgICAgICBiZWdpbgogICAg
# ICAgICAgICAgICAgcmVzcC5mbHVzaAkJCQogICAgICAgICAgICAgIHJlc2N1
# ZQogICAgICAgICAgICAgICAgcmFpc2UgSFRUUFNlcnZlckV4Y2VwdGlvbgog
# ICAgICAgICAgICAgIGVuZAogICAgICAgICAgICByZXNjdWUgSFRUUFNlcnZl
# ckV4Y2VwdGlvbgogICAgICAgICAgICBlbmQKCiAgICAgICAgICAgIHBhcmVu
# dHRocmVhZFsic3RvcCJdCT0gcmVzcAlpZiBzdG9wCiAgICAgICAgICBlbmQK
# CiAgICAgICAgICBtdXRleC5zeW5jaHJvbml6ZSBkbwogICAgICAgICAgICBU
# aHJlYWQuY3VycmVudFsidGhyZWFkcyJdIDw8IHRocmVhZAogICAgICAgICAg
# ZW5kCiAgICAgICAgZW5kCiAgICAgIGVuZAoKICAgICAgc2xlZXAgMC4xCXdo
# aWxlIG5vdCBzZXJ2ZXJ0aHJlYWRbInN0b3AiXQoKICAgICAgc2VydmVydGhy
# ZWFkWyJ0aHJlYWRzIl0uZWFjaCB7fHR8IHQuam9pbn0KCiAgICAgIHNlcnZl
# cnRocmVhZFsic3RvcCJdLmF0X3N0b3AuY2FsbAoKICAgICAgc2VydmVydGhy
# ZWFkLmtpbGwKICAgIGVuZAogIGVuZAoKICBkZWYgc2VsZi5hdXRoZW50aWNh
# dGUoYXV0aCwgcmVhbG0sIHJlcSwgcmVzcCkKICAgIGlmIGF1dGgua2luZF9v
# Zj8gU3RyaW5nCiAgICAgIGZpbGUJPSAiI3tob21lfS8je2F1dGh9IgogICAg
# ICBhdXRocwk9IHt9CiAgICAgIGF1dGhzCT0gSGFzaC5maWxlKGZpbGUpCWlm
# IEZpbGUuZmlsZT8oZmlsZSkKICAgIGVsc2UKICAgICAgYXV0aHMJPSBhdXRo
# CiAgICBlbmQKCiAgICBhdXRodXNlcnBhc3N3b3JkCT0gcmVxWyJhdXRob3Jp
# emF0aW9uIl0KICAgIGlmIG5vdCBhdXRodXNlcnBhc3N3b3JkLm5pbD8KICAg
# ICAgYXV0aHR5cGUsIHVzZXJwYXNzd29yZAk9IGF1dGh1c2VycGFzc3dvcmQu
# c3BsaXQoLyAvKQogICAgICBpZiBhdXRodHlwZSA9PSAiQmFzaWMiIGFuZCBu
# b3QgdXNlcnBhc3N3b3JkLm5pbD8KICAgICAgICB1LCBwCT0gdXNlcnBhc3N3
# b3JkLnVucGFjaygibSIpLnNoaWZ0LnNwbGl0KC86LykKICAgICAgZW5kCiAg
# ICBlbmQKCiAgICBvawk9IChhdXRocy5pbmNsdWRlPyh1KSBhbmQgYXV0aHNb
# dV0gPT0gcCkKCiAgICB1bmxlc3Mgb2sKICAgICAgcmVzcFsiV1dXLUF1dGhl
# bnRpY2F0ZSJdCT0gIkJhc2ljIHJlYWxtPVwiI3tyZWFsbX1cIiIKICAgICAg
# cmVzcC5yZXNwb25zZQkJPSAiSFRUUC8xLjAgNDAxIFVuYXV0aG9yaXplZCIK
# ICAgIGVuZAoKICAgIHJlcS51c2VyCT0gdQoKICAgIHJldHVybiBvawogIGVu
# ZAplbmQKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAABydWJ5d2ViZGlhbG9ncy9saWIvdHJlZS5saWIucmIAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAwMDE3NTAAMDAw
# MDAwMTcxNjMAMTAyNTAzMjA2MjEAMDE2NjA3ACAwAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFy
# ICAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlrAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgImV2L3J1YnkiCnJl
# cXVpcmUgImV2L25ldCIKcmVxdWlyZSAibWQ1IgpyZXF1aXJlICJ0aHJlYWQi
# CgpTYW1lCT0gMApEb3duCT0gMQpVcAk9IDIKRHVtbXkJPSAzCgptb2R1bGUg
# VGV4dEFycmF5CiAgZGVmIHRleHRhcnJheQogICAgQGNoaWxkcmVuLmNvbGxl
# Y3QgZG8gfG9ianwKICAgICAgW29iai50ZXh0XSA8PCBvYmoudGV4dGFycmF5
# CiAgICBlbmQuZmxhdHRlbi5jb21wYWN0CiAgZW5kCmVuZAoKCm1vZHVsZSBQ
# YXJzZVRyZWUKICBkZWYgcGFyc2V0cmVlKHByZW1ldGhvZD0icHJlY2hpbGRy
# ZW4iLCBwb3N0bWV0aG9kPSJwb3N0Y2hpbGRyZW4iLCAqYXJncykKICAgIGlm
# IEB2aXNpYmxlCiAgICAgIG1ldGhvZChwcmVtZXRob2QpLmNhbGwoKmFyZ3Mp
# CWlmIHJlc3BvbmRfdG8/KHByZW1ldGhvZCkKCiAgICAgIEBjaGlsZHJlbi5l
# YWNoIGRvIHxvYmp8CiAgICAgICAgb2JqLnBhcnNldHJlZShwcmVtZXRob2Qs
# IHBvc3RtZXRob2QsICphcmdzKQogICAgICBlbmQKCiAgICAgIG1ldGhvZChw
# b3N0bWV0aG9kKS5jYWxsKCphcmdzKQlpZiByZXNwb25kX3RvPyhwb3N0bWV0
# aG9kKQogICAgZW5kCiAgZW5kCgogICNkZWYgcGFyc2V0cmVlKHByZW1ldGhv
# ZD0icHJlY2hpbGRyZW4iLCBwb3N0bWV0aG9kPSJwb3N0Y2hpbGRyZW4iLCAq
# YXJncykKICAjICBzdGFjawk9IFtzZWxmXQogICMgIGRvbmUJPSBbXQogICMK
# ICAjICB3aGlsZSBub3Qgc3RhY2suZW1wdHk/CiAgIyAgICBvYmoJPSBzdGFj
# ay5wb3AKICAjCiAgIyAgICBpZiBub3QgZG9uZS5pbmNsdWRlPyhvYmopCiAg
# IyAgICAgIG9iai5tZXRob2QocHJlbWV0aG9kKS5jYWxsKCphcmdzKQlpZiBv
# YmoucmVzcG9uZF90bz8ocHJlbWV0aG9kKQogICMKICAjICAgICAgc3RhY2su
# cHVzaChvYmopCiAgIyAgICAgIGRvbmUucHVzaChvYmopCiAgIwogICMgICAg
# ICBzdGFjay5jb25jYXQgb2JqLmNoaWxkcmVuLnJldmVyc2UKICAjICAgICAg
# I29iai5jaGlsZHJlbi5yZXZlcnNlLmVhY2ggZG8gfGNvYmp8CiAgIyAgICAg
# ICAgI3N0YWNrLnB1c2goY29iaikKICAjICAgICAgI2VuZAogICMgICAgZWxz
# ZQogICMgICAgICBvYmoubWV0aG9kKHBvc3RtZXRob2QpLmNhbGwoKmFyZ3Mp
# CWlmIG9iai5yZXNwb25kX3RvPyhwb3N0bWV0aG9kKQogICMgICAgZW5kCiAg
# IyAgZW5kCiAgI2VuZAplbmQKCmNsYXNzIFRyZWVPYmplY3QKICBhdHRyX3Jl
# YWRlciA6c3VidHlwZQogIGF0dHJfd3JpdGVyIDpzdWJ0eXBlCiAgYXR0cl9y
# ZWFkZXIgOnVwb3Jkb3duCiAgYXR0cl93cml0ZXIgOnVwb3Jkb3duCiAgYXR0
# cl9yZWFkZXIgOmxldmVsCiAgYXR0cl93cml0ZXIgOmxldmVsCiAgYXR0cl9y
# ZWFkZXIgOnBhcmVudAogIGF0dHJfd3JpdGVyIDpwYXJlbnQKICBhdHRyX3Jl
# YWRlciA6Y2hpbGRyZW4KICBhdHRyX3dyaXRlciA6Y2hpbGRyZW4KICBhdHRy
# X3JlYWRlciA6Y2xvc2VkCiAgYXR0cl93cml0ZXIgOmNsb3NlZAogIGF0dHJf
# cmVhZGVyIDp0ZXh0CiAgYXR0cl93cml0ZXIgOnRleHQKICBhdHRyX3JlYWRl
# ciA6dmlzaWJsZQogIGF0dHJfd3JpdGVyIDp2aXNpYmxlCgogIGluY2x1ZGUg
# VGV4dEFycmF5CiAgaW5jbHVkZSBQYXJzZVRyZWUKCiAgZGVmIGluaXRpYWxp
# emUoc3VidHlwZT1uaWwpCiAgICBAc3VidHlwZQk9IHN1YnR5cGUKICAgIEB1
# cG9yZG93bgk9IFNhbWUKICAgIEBsZXZlbAk9IG5pbAogICAgQHBhcmVudAk9
# IG5pbAogICAgQGNoaWxkcmVuCT0gW10KICAgIEBjbG9zZWQJPSBuaWwKICAg
# IEB2aXNpYmxlCT0gdHJ1ZQogIGVuZAoKICBkZWYgaW5zcGVjdAogICAgcGFy
# ZW50LCBjaGlsZHJlbgk9IEBwYXJlbnQsIEBjaGlsZHJlbgoKICAgIEBwYXJl
# bnQsIEBjaGlsZHJlbgk9IHBhcmVudC5vYmplY3RfaWQsIGNoaWxkcmVuLmNv
# bGxlY3R7fG9ianwgb2JqLm9iamVjdF9pZH0KCiAgICByZXMgPSAiICAiICog
# KGxldmVsLTEpICsgIiN7c2VsZi5jbGFzc30oI3tAc3VidHlwZX0pICN7c3Vw
# ZXJ9IgoKICAgIEBwYXJlbnQsIEBjaGlsZHJlbgk9IHBhcmVudCwgY2hpbGRy
# ZW4KCiAgICByZXMKICBlbmQKCiAgZGVmIHByZXZpb3VzKGtsYXNzPVtdLCBz
# a2lwPVtdKQogICAga2xhc3MJPSBba2xhc3NdLmZsYXR0ZW4KICAgIHNraXAJ
# PSBbc2tpcF0uZmxhdHRlbgoKICAgIHBvCT0gQHBhcmVudAogICAgcmV0dXJu
# IG5pbAlpZiBwby5uaWw/CgogICAgY2gJPSBwby5jaGlsZHJlbgogICAgcmV0
# dXJuIG5pbAlpZiBjaC5uaWw/CgogICAgbgk9IGNoLmluZGV4KHNlbGYpCiAg
# ICByZXR1cm4gbmlsCWlmIG4ubmlsPwoKICAgIHJlcwk9IG5pbAogICAgaWYg
# a2xhc3MubmlsPwogICAgICBuIC09IDEKICAgICAgcmVzCT0gY2hbbl0KICAg
# IGVsc2UKICAgICAgYmVnaW4KICAgICAgICBuIC09IDEKICAgICAgICByZXMJ
# PSBjaFtuXQogICAgICBlbmQgd2hpbGUgKGtsYXNzLmVtcHR5PyBvciBrbGFz
# cy5jb2xsZWN0e3xrfCBjaFtuLTFdLmtpbmRfb2Y/KGspfS5zb3J0LnVuaXEg
# PT0gW3RydWVdKSBcCiAgICAgICAgICAgIGFuZCAoc2tpcC5lbXB0eT8gb3Ig
# c2tpcC5jb2xsZWN0e3xrfCBjaFtuLTFdLmtpbmRfb2Y/KGspfS5zb3J0LnVu
# aXEgPT0gW2ZhbHNlXSkKICAgIGVuZAoKICAgIHJlcwogIGVuZAplbmQKCmNs
# YXNzIFRyZWUKICBAQHZlcnNpZQk9IDEKICBAQG11dGV4CT0gTXV0ZXgubmV3
# CgogIGF0dHJfcmVhZGVyIDpkYXRhCiAgYXR0cl93cml0ZXIgOmRhdGEKICBh
# dHRyX3JlYWRlciA6cGFyZW50CiAgYXR0cl93cml0ZXIgOnBhcmVudAogIGF0
# dHJfcmVhZGVyIDpjaGlsZHJlbgogIGF0dHJfd3JpdGVyIDpjaGlsZHJlbgog
# IGF0dHJfcmVhZGVyIDp2aXNpYmxlCiAgYXR0cl93cml0ZXIgOnZpc2libGUK
# CiAgaW5jbHVkZSBUZXh0QXJyYXkKICBpbmNsdWRlIFBhcnNlVHJlZQoKICBk
# ZWYgaW5pdGlhbGl6ZShzdHJpbmcpCiAgICBzdHJpbmcgPSBzdHJpbmcuam9p
# bigiIikgaWYgc3RyaW5nLmtpbmRfb2Y/KEFycmF5KQoKICAgIEBkYXRhCQk9
# IHN0cmluZwogICAgQHBhcmVudAkJPSBuaWwKICAgIEBjaGlsZHJlbgkJPSBb
# XQogICAgQG9iamVjdHMJCT0gW10KICAgIEB2aXNpYmxlCQk9IHRydWUKICAg
# IEBjaGVja3Zpc2liaWxpdHkJPSBmYWxzZQoKICAgIGJ1aWxkb2JqZWN0cyhz
# dHJpbmcpCiAgICBidWlsZHBhcmVudHMKICAgIGJ1aWxkY2hpbGRyZW4KICAg
# IG1hcmtjbG9zZWQKICAgIGRlbGV0ZWR1bW1pZXMKCiAgICBAY2hlY2t2aXNp
# YmlsaXR5CT0gdHJ1ZQogIGVuZAoKICBkZWYgc2VsZi5maWxlKGZpbGUpCiAg
# ICBuZXcoRmlsZS5uZXcoZmlsZSkucmVhZGxpbmVzKQogIGVuZAoKICBkZWYg
# c2VsZi5sb2NhdGlvbih1cmwsIGZvcm09SGFzaC5uZXcpCiAgICBzCT0gSFRU
# UENsaWVudC5nZXQodXJsLCB7fSwgZm9ybSkKICAgIHMJPSAiIglpZiBzLm5p
# bD8KICAgIG5ldyhzKQogIGVuZAoKICBkZWYgc2VsZi5uZXdfZnJvbV9jYWNo
# ZTIoZGF0YSkKICAgIG5ldyhkYXRhKQogIGVuZAoKICBkZWYgc2VsZi5uZXdf
# ZnJvbV9jYWNoZShkYXRhKQogICAgaGFzaAk9IE1ENS5uZXcoIiN7QEB2ZXJz
# aWV9ICN7ZGF0YX0iKQoKICAgIGRpcgkJPSAiI3t0ZW1wfS9ldmNhY2hlLiN7
# dXNlcn0vdHJlZS5uZXciCiAgICBmaWxlCT0gIiN7ZGlyfS8je2hhc2h9IgoK
# ICAgIHRyZWUJPSBuaWwKCiAgICBGaWxlLm1rcGF0aChkaXIpCgogICAgaWYg
# RmlsZS5maWxlPyhmaWxlKQogICAgICBAQG11dGV4LnN5bmNocm9uaXplIGRv
# CiAgICAgICAgdHJlZQk9IE1hcnNoYWwucmVzdG9yZShGaWxlLm5ldyhmaWxl
# LCAicmIiKSkKICAgICAgZW5kCiAgICBlbHNlCiAgICAgIHRyZWUJPSBuZXco
# ZGF0YSkKCiAgICAgIGlmIG5vdCB0cmVlLm5pbD8KICAgICAgICBAQG11dGV4
# LnN5bmNocm9uaXplIGRvCiAgICAgICAgICBGaWxlLm9wZW4oZmlsZSwgIndi
# Iikge3xmfCBNYXJzaGFsLmR1bXAodHJlZSwgZil9CiAgICAgICAgZW5kCiAg
# ICAgIGVuZAogICAgZW5kCgogICAgcmV0dXJuIHRyZWUKICBlbmQKCiAgZGVm
# IGluc3BlY3QKICAgIEBvYmplY3RzLmNvbGxlY3QgZG8gfG9ianwKICAgICAg
# b2JqLmluc3BlY3QKICAgIGVuZC5qb2luKCJcbiIpCiAgZW5kCgogIGRlZiBi
# dWlsZG9iamVjdHMoc3RyaW5nKQogICAgcmFpc2UgIkhhcyB0byBiZSBkZWZp
# bmVkIGluIHRoZSBzdWJjbGFzcy4iCiAgZW5kCgogIGRlZiBidWlsZHBhcmVu
# dHMKICAgIGxldmVsCT0gMQogICAgbGV2ZWxzCT0gSGFzaC5uZXcKICAgIGxl
# dmVsc1swXQk9IG5pbAogICAgcGFyc2UgZG8gfHR5cGUsIG9ianwKICAgICAg
# Y2FzZSBvYmoudXBvcmRvd24KICAgICAgd2hlbiBEb3duCiAgICAgICAgb2Jq
# LmxldmVsCT0gbGV2ZWwKICAgICAgICBvYmoucGFyZW50CT0gbGV2ZWxzW2xl
# dmVsLTFdCiAgICAgICAgbGV2ZWxzW2xldmVsXQk9IG9iagogICAgICAgIGxl
# dmVsICs9IDEKICAgICAgd2hlbiBVcCwgRHVtbXkKICAgICAgICBwbCA9IGxl
# dmVsCiAgICAgICAgMS51cHRvKGxldmVsLTEpIGRvIHxsfAogICAgICAgICAg
# cG8gPSBsZXZlbHNbbF0KICAgICAgICAgIHBsID0gbCBpZiBwby5zdWJ0eXBl
# ID09IG9iai5zdWJ0eXBlCiAgICAgICAgZW5kCiAgICAgICAgbGV2ZWwgPSBw
# bAogICAgICAgIG9iai5sZXZlbAk9IGxldmVsCiAgICAgICAgb2JqLnBhcmVu
# dAk9IGxldmVsc1tsZXZlbC0xXQogICAgICB3aGVuIFNhbWUKICAgICAgICBv
# YmoubGV2ZWwJPSBsZXZlbAogICAgICAgIG9iai5wYXJlbnQJPSBsZXZlbHNb
# bGV2ZWwtMV0KICAgICAgZW5kCiAgICBlbmQKICBlbmQKCiAgZGVmIGJ1aWxk
# Y2hpbGRyZW4KICAgIEBvYmplY3RzLmVhY2ggZG8gfG9ianwKICAgICAgb2Jq
# LmNoaWxkcmVuID0gW10KICAgIGVuZAoKICAgIHBhcnNlIGRvIHx0eXBlLCBv
# Ymp8CiAgICAgIGlmIG5vdCBvYmoucGFyZW50Lm5pbD8KICAgICAgICBwbyA9
# IG9iai5wYXJlbnQKICAgICAgICBwby5jaGlsZHJlbiA8PCBvYmoKICAgICAg
# ZWxzZQogICAgICAgIEBjaGlsZHJlbiA8PCBvYmoKICAgICAgZW5kCiAgICBl
# bmQKICBlbmQKCiAgZGVmIG1hcmtjbG9zZWQKICAgIChbc2VsZl0gKyBAb2Jq
# ZWN0cykuZWFjaCBkbyB8b2JqfAogICAgICBvYmouY2hpbGRyZW4uZWFjaF9p
# bmRleCBkbyB8aXwKICAgICAgICBjbzEJCT0gb2JqLmNoaWxkcmVuW2ldCiAg
# ICAgICAgY28yCQk9IG9iai5jaGlsZHJlbltpKzFdCgogICAgICAgIGNvMS5j
# bG9zZWQJPSAobm90IGNvMi5uaWw/IGFuZCBjbzEudXBvcmRvd24gPT0gRG93
# biBhbmQgKGNvMi51cG9yZG93biA9PSBVcCBvciBjbzIudXBvcmRvd24gPT0g
# RHVtbXkpIGFuZCBjbzEuc3VidHlwZSA9PSBjbzIuc3VidHlwZSkKICAgICAg
# ZW5kCiAgICBlbmQKICBlbmQKCiAgZGVmIGRlbGV0ZWR1bW1pZXMKICAgIChb
# c2VsZl0gKyBAb2JqZWN0cykuZWFjaCBkbyB8b2JqfAogICAgICBvYmouY2hp
# bGRyZW4uZGVsZXRlX2lmIGRvIHxvYmoyfAogICAgICAgIG9iajIudXBvcmRv
# d24gPT0gRHVtbXkKICAgICAgZW5kCiAgICBlbmQKCiAgICBAb2JqZWN0cy5k
# ZWxldGVfaWYgZG8gfG9ianwKICAgICAgb2JqLnVwb3Jkb3duID09IER1bW15
# CiAgICBlbmQKICBlbmQKCiAgZGVmIHBhcnNlKHR5cGVzPVtdLCBzdWJ0eXBl
# cz1bXSwgb25jZT1mYWxzZSkKICAgIHR5cGVzCT0gW3R5cGVzXQlpZiB0eXBl
# cy5jbGFzcyA9PSBDbGFzcwogICAgc3VidHlwZXMJPSBbc3VidHlwZXNdCWlm
# IHN1YnR5cGVzLmNsYXNzID09IFN0cmluZwogICAgaGlkZWxldmVsCT0gbmls
# CgogICAgY2F0Y2ggOm9uY2UgZG8KICAgICAgQG9iamVjdHMuZWFjaCBkbyB8
# b2JqfAogICAgICAgIGlmIChAY2hlY2t2aXNpYmlsaXR5IGFuZCBoaWRlbGV2
# ZWwubmlsPyBhbmQgKG5vdCBvYmoudmlzaWJsZSkpCiAgICAgICAgICBoaWRl
# bGV2ZWwJPSBvYmoubGV2ZWwKICAgICAgICBlbHNlCiAgICAgICAgICBpZiAo
# QGNoZWNrdmlzaWJpbGl0eSBhbmQgKG5vdCBoaWRlbGV2ZWwubmlsPykgYW5k
# IG9iai52aXNpYmxlIGFuZCBvYmoubGV2ZWwgPD0gaGlkZWxldmVsKQogICAg
# ICAgICAgICBoaWRlbGV2ZWwJPSBuaWwKICAgICAgICAgIGVuZAogICAgICAg
# IGVuZAoKICAgICAgICBpZiBoaWRlbGV2ZWwubmlsPwogICAgICAgICAgb2sg
# PSBmYWxzZQogICAgICAgICAgY2F0Y2ggOnN0b3AgZG8KICAgICAgICAgICAg
# aWYgdHlwZXMuZW1wdHk/CiAgICAgICAgICAgICAgaWYgc3VidHlwZXMuZW1w
# dHk/CiAgICAgICAgICAgICAgICBvayA9IHRydWUKICAgICAgICAgICAgICAg
# IHRocm93IDpzdG9wCiAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAg
# ICAgc3VidHlwZXMuZWFjaCBkbyB8c3R8CiAgICAgICAgICAgICAgICAgIGlm
# IG9iai5zdWJ0eXBlID09IHN0CiAgICAgICAgICAgICAgICAgICAgb2sgPSB0
# cnVlCiAgICAgICAgICAgICAgICAgICAgdGhyb3cgOnN0b3AKICAgICAgICAg
# ICAgICAgICAgZW5kCiAgICAgICAgICAgICAgICBlbmQKICAgICAgICAgICAg
# ICBlbmQKICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgIGlmIHN1YnR5
# cGVzLmVtcHR5PwogICAgICAgICAgICAgICAgdHlwZXMuZWFjaCBkbyB8dHwK
# ICAgICAgICAgICAgICAgICAgaWYgb2JqLmtpbmRfb2Y/KHQpCiAgICAgICAg
# ICAgICAgICAgICAgb2sgPSB0cnVlCiAgICAgICAgICAgICAgICAgICAgdGhy
# b3cgOnN0b3AKICAgICAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgICAg
# ICBlbmQKICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICB0eXBl
# cy5lYWNoIGRvIHx0fAogICAgICAgICAgICAgICAgICBzdWJ0eXBlcy5lYWNo
# IGRvIHxzdHwKICAgICAgICAgICAgICAgICAgICBpZiBvYmoua2luZF9vZj8o
# dCkgYW5kIG9iai5zdWJ0eXBlID09IHN0CiAgICAgICAgICAgICAgICAgICAg
# ICBvayA9IHRydWUKICAgICAgICAgICAgICAgICAgICAgIHRocm93IDpzdG9w
# CiAgICAgICAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgICAgICAgIGVu
# ZAogICAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgICAgZW5kCiAgICAg
# ICAgICAgIGVuZAogICAgICAgICAgZW5kCgogICAgICAgICAgaWYgb2sKICAg
# ICAgICAgICAgeWllbGQob2JqLmNsYXNzLnRvX3MsIG9iaikKCiAgICAgICAg
# ICAgIHRocm93IDpvbmNlCWlmIG9uY2UKICAgICAgICAgIGVuZAogICAgICAg
# IGVuZAogICAgICBlbmQKICAgIGVuZAogIGVuZAoKICBkZWYgcGF0aChwYWQp
# CiAgICBwMQk9IHNlbGYKCiAgICB1bmxlc3MgcGFkLm5pbD8KICAgICAgcGFk
# LnNwbGl0KC9cLy8pLmVhY2ggZG8gfGRlZWx8CiAgICAgICAgdGFnLCB2b29y
# a29tZW4JPSBkZWVsLnNwbGl0KC86LykKCiAgICAgICAgaWYgKG5vdCB0YWcu
# bmlsPykgYW5kIChub3QgcDEubmlsPykKICAgICAgICAgIHZvb3Jrb21lbgk9
# IDEJaWYgdm9vcmtvbWVuLm5pbD8KICAgICAgICAgIHZvb3Jrb21lbgk9IHZv
# b3Jrb21lbi50b19pCgogICAgICAgICAgdGVsbGVyCT0gMAogICAgICAgICAg
# cDIJPSBuaWwKICAgICAgICAgIHAxLmNoaWxkcmVuLmVhY2hfaW5kZXggZG8g
# fGl8CiAgICAgICAgICAgICNpZiBwMS5jaGlsZHJlbltpXS51cG9yZG93biA9
# PSBEb3duCiAgICAgICAgICAgICAgdW5sZXNzICBwMS5jaGlsZHJlbltpXS5z
# dWJ0eXBlLm5pbD8KICAgICAgICAgICAgICAgIGlmIHAxLmNoaWxkcmVuW2ld
# LnN1YnR5cGUubm9xdW90ZXMgPT0gdGFnLm5vcXVvdGVzCiAgICAgICAgICAg
# ICAgICAgIHRlbGxlciArPSAxCiAgICAgICAgICAgICAgICAgIHAyCT0gcDEu
# Y2hpbGRyZW5baV0JaWYgdGVsbGVyID09IHZvb3Jrb21lbgogICAgICAgICAg
# ICAgICAgZW5kCiAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgICNlbmQK
# ICAgICAgICAgIGVuZAogICAgICAgICAgcDEJPSBwMgogICAgICAgIGVuZAog
# ICAgICBlbmQKICAgIGVuZAoKICAgIHAxCiAgZW5kCmVuZAoAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcnVieXdlYmRpYWxvZ3MvbGli
# L2Jyb3dzZXIubGliLnJiAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDA3NTUA
# MDAwMTc1MAAwMDAxNzUwADAwMDAwMDA1MjA3ADEwMjUwMzIwNjIxADAxNzMy
# NwAgMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAB1c3RhciAgAGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAw
# MDAwADAwMDAwMDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABy
# ZXF1aXJlICJldi9ydWJ5IgpyZXF1aXJlICJldi9uZXQiCgpiZWdpbgogIHJl
# cXVpcmUgIndpbjMyb2xlIgogIHJlcXVpcmUgIndpbjMyL3JlZ2lzdHJ5Igpy
# ZXNjdWUgTG9hZEVycm9yCiAgJCIucHVzaCAid2luMzJvbGUuc28iCiAgJCIu
# cHVzaCAid2luMzIvcmVnaXN0cnkucmIiCmVuZAoKZGVmIHdpbmRvd3Nicm93
# c2VyCiAgJHN0ZGVyci5wdXRzICJMb29raW5nIGZvciBkZWZhdWx0IGJyb3dz
# ZXIuLi4iCgogIGZpbGV0eXBlCT0gImh0bWxmaWxlIgogIGFwcGxpY2F0aW9u
# CT0gbmlsCgogIGJlZ2luCiAgICBXaW4zMjo6UmVnaXN0cnk6OkhLRVlfQ0xB
# U1NFU19ST09ULm9wZW4oIi5odG1sIikgZG8gfHJlZ3wKICAgICAgZmlsZXR5
# cGUJCT0gcmVnWyIiXQogICAgZW5kCgogICAgV2luMzI6OlJlZ2lzdHJ5OjpI
# S0VZX0NMQVNTRVNfUk9PVC5vcGVuKGZpbGV0eXBlICsgIlxcc2hlbGxcXG9w
# ZW5cXGNvbW1hbmQiKSBkbyB8cmVnfAogICAgICBhcHBsaWNhdGlvbgk9IHJl
# Z1siIl0KICAgIGVuZAogIHJlc2N1ZSBOYW1lRXJyb3IKICAgICRzdGRlcnIu
# cHV0cyAiT25seSBhdmFpbGFibGUgZm9yIFdpbmRvd3MgYW5kIEN5Z3dpbi4i
# CiAgZW5kCgogIGFwcGxpY2F0aW9uCmVuZAoKZGVmIGN5Z3dpbmJyb3dzZXIK
# ICBicm93c2VyLCAqYXJncwk9IHdpbmRvd3Nicm93c2VyLnNwbGl0d29yZHMK
# ICBicm93c2VyCQk9IGJyb3dzZXIuZ3N1YigvXFwvLCAiLyIpCiAgI2Jyb3dz
# ZXIJCT0gYnJvd3NlcgoKICBhcmdzLmNvbGxlY3Qhe3xhfCBhLmdzdWIoL1xc
# LywgIi8iKX0KICAjYXJncy5jb2xsZWN0IXt8YXwgIlwiJXNcIiIgJSBbYS5n
# c3ViKC9cXC8sICIvIildfQogICNhcmdzLmNvbGxlY3Qhe3xhfCAiXCIlc1wi
# IiAlIFthXX0KCiAgcmVzCT0gIlwiJXNcIiAlcyIgJSBbYnJvd3NlciwgYXJn
# cy5qb2luKCIgIildCiAgcmVzCmVuZAoKZGVmIGxpbnV4YnJvd3NlcgogIGFw
# cGxpY2F0aW9uCT0gIiIKCiAgYXBwbGljYXRpb24JPSBgd2hpY2ggZ2FsZW9u
# CQkyPiAvZGV2L251bGxgLmNob21wCWlmIGFwcGxpY2F0aW9uLmVtcHR5Pwog
# IGFwcGxpY2F0aW9uCT0gYHdoaWNoIG1vemlsbGEJMj4gL2Rldi9udWxsYC5j
# aG9tcAlpZiBhcHBsaWNhdGlvbi5lbXB0eT8KICBhcHBsaWNhdGlvbgk9IGB3
# aGljaCBmaXJlZm94CTI+IC9kZXYvbnVsbGAuY2hvbXAJaWYgYXBwbGljYXRp
# b24uZW1wdHk/CiAgYXBwbGljYXRpb24JPSBgd2hpY2ggb3BlcmEJCTI+IC9k
# ZXYvbnVsbGAuY2hvbXAJaWYgYXBwbGljYXRpb24uZW1wdHk/CiAgYXBwbGlj
# YXRpb24JPSBgd2hpY2gga29ucXVlcm9yCTI+IC9kZXYvbnVsbGAuY2hvbXAJ
# aWYgYXBwbGljYXRpb24uZW1wdHk/CiAgYXBwbGljYXRpb24JPSBgd2hpY2gg
# aHRtbHZpZXcJMj4gL2Rldi9udWxsYC5jaG9tcAlpZiBhcHBsaWNhdGlvbi5l
# bXB0eT8KICBhcHBsaWNhdGlvbgk9IG5pbAkJCQkJCWlmIGFwcGxpY2F0aW9u
# LmVtcHR5PwoKICBhcHBsaWNhdGlvbgplbmQKCmRlZiBkZWZhdWx0YnJvd3Nl
# cgogIHJlcwk9IG5pbAogIHJlcwk9IHdpbmRvd3Nicm93c2VyCWlmIHdpbmRv
# d3M/CiAgcmVzCT0gY3lnd2luYnJvd3NlcgkJaWYgY3lnd2luPwogIHJlcwk9
# IGxpbnV4YnJvd3NlcgkJaWYgbGludXg/CiAgcmVzCmVuZAoKZGVmIHNob3d1
# cmxpbmJyb3dzZXIodXJsLCBicm93c2VyPWRlZmF1bHRicm93c2VyKQogIGNv
# bW1hbmQJPSAiI3ticm93c2VyfSBcIiN7dXJsfVwiIgoKICBzeXN0ZW0oY29t
# bWFuZCkJb3IgJHN0ZGVyci5wdXRzICJTdGFydGluZyBvZiB0aGUgYnJvd3Nl
# ciBmYWlsZWQsIG9yIHRoZSBicm93c2VyIHRlcm1pbmF0ZWQgYWJub3JtYWxs
# eS5cbkNvbW1hbmQgPT4gI3tjb21tYW5kfSIKZW5kCgpkZWYgc2hvd2luYnJv
# d3NlcihodG1sLCBicm93c2VyPWRlZmF1bHRicm93c2VyKQogIHBvcnQsIGlv
# CT0gVENQU2VydmVyLmZyZWVwb3J0KDc3MDEsIDc3MDkpCgogIHVubGVzcyBi
# cm93c2VyLm5pbD8KICAgIFRocmVhZC5uZXcgZG8KICAgICAgYmVnaW4KCVRo
# cmVhZC5wYXNzCgogICAgICAgIHNob3d1cmxpbmJyb3dzZXIoImh0dHA6Ly9s
# b2NhbGhvc3Q6I3twb3J0fS8iLCBicm93c2VyKQogICAgICByZXNjdWUKICAg
# ICAgZW5kCiAgICBlbmQKICBlbmQKCiAgSFRUUFNlcnZlci5zZXJ2ZShbcG9y
# dCwgaW9dKSBkbyB8cmVxLCByZXNwfAogICAgcmVzcCA8PCBodG1sCgogICAg
# cmVzcC5zdG9wCiAgZW5kCmVuZAoKZGVmIHRhYjJodG1sKHRhYikKICByZXMJ
# PSAiIgoKICB0YWIJPSB0YWIudG9faHRtbChmYWxzZSkKCiAgcmVzIDw8ICI8
# aHRtbD5cbiIKICByZXMgPDwgIjxib2R5PlxuIgogIHJlcyA8PCAiPHRhYmxl
# IGFsaWduPSdjZW50ZXInIGJvcmRlcj0nMScgY2VsbHNwYWNpbmc9JzAnIGNl
# bGxwYWRkaW5nPSczJz5cbiIKICByZXMgPDwgIjx0Ym9keT5cbiIKCiAgdGFi
# LnNwbGl0KC9ccipcbi8pLmVhY2ggZG8gfGxpbmV8CiAgICByZXMgPDwgIjx0
# cj5cbiIKCiAgICBsaW5lLnNwbGl0KC9cdC8sIC0xKS5lYWNoIGRvIHx2ZWxk
# fAogICAgICB2ZWxkCT0gIiZuYnNwOyIJaWYgdmVsZC5jb21wcmVzcy5lbXB0
# eT8KCiAgICAgIHJlcyA8PCAiPHRkPiVzPC90ZD5cbiIgJSB2ZWxkCiAgICBl
# bmQKCiAgICByZXMgPDwgIjwvdHI+XG4iCiAgZW5kCgogIHJlcyA8PCAiPC90
# Ym9keT5cbiIKICByZXMgPDwgIjwvdGFibGU+XG4iCiAgcmVzIDw8ICI8L2Jv
# ZHk+XG4iCiAgcmVzIDw8ICI8L2h0bWw+XG4iCgogIHJlcwplbmQKAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAABydWJ5d2ViZGlhbG9ncy9saWIvZnRvb2xzLmxpYi5yYgAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAwMDE3NTAA
# MDAwMDAwMDY1MTYAMTAyNTAzMjA2MjEAMDE3MTU2ACAwAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVz
# dGFyICAAZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlrAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgImZ0b29scyIK
# CmNsYXNzIERpcgogIGRlZiBzZWxmLmNvcHkoZnJvbSwgdG8pCiAgICBpZiBG
# aWxlLmRpcmVjdG9yeT8oZnJvbSkKICAgICAgcGRpcgk9IERpci5wd2QKICAg
# ICAgdG9kaXIJPSBGaWxlLmV4cGFuZF9wYXRoKHRvKQoKICAgICAgRmlsZS5t
# a3BhdGgodG9kaXIpCgogICAgICBEaXIuY2hkaXIoZnJvbSkKICAgICAgICBE
# aXIubmV3KCIuIikuZWFjaCBkbyB8ZXwKICAgICAgICAgIERpci5jb3B5KGUs
# IHRvZGlyKyIvIitlKQlpZiBub3QgWyIuIiwgIi4uIl0uaW5jbHVkZT8oZSkK
# ICAgICAgICBlbmQKICAgICAgRGlyLmNoZGlyKHBkaXIpCiAgICBlbHNlCiAg
# ICAgIHRvZGlyCT0gRmlsZS5kaXJuYW1lKEZpbGUuZXhwYW5kX3BhdGgodG8p
# KQoKICAgICAgRmlsZS5ta3BhdGgodG9kaXIpCgogICAgICBGaWxlLmNvcHko
# ZnJvbSwgdG8pCiAgICBlbmQKICBlbmQKCiAgZGVmIHNlbGYubW92ZShmcm9t
# LCB0bykKICAgIERpci5jb3B5KGZyb20sIHRvKQogICAgRGlyLnJtX3JmKGZy
# b20pCiAgZW5kCgogIGRlZiBzZWxmLnJtX3JmKGVudHJ5KQogICAgRmlsZS5j
# aG1vZCgwNzU1LCBlbnRyeSkKCiAgICBpZiBGaWxlLmZ0eXBlKGVudHJ5KSA9
# PSAiZGlyZWN0b3J5IgogICAgICBwZGlyCT0gRGlyLnB3ZAoKICAgICAgRGly
# LmNoZGlyKGVudHJ5KQogICAgICAgIERpci5uZXcoIi4iKS5lYWNoIGRvIHxl
# fAogICAgICAgICAgRGlyLnJtX3JmKGUpCWlmIG5vdCBbIi4iLCAiLi4iXS5p
# bmNsdWRlPyhlKQogICAgICAgIGVuZAogICAgICBEaXIuY2hkaXIocGRpcikK
# CiAgICAgIGJlZ2luCiAgICAgICAgRGlyLmRlbGV0ZShlbnRyeSkKICAgICAg
# cmVzY3VlID0+IGUKICAgICAgICAkc3RkZXJyLnB1dHMgZS5tZXNzYWdlCiAg
# ICAgIGVuZAogICAgZWxzZQogICAgICBiZWdpbgogICAgICAgIEZpbGUuZGVs
# ZXRlKGVudHJ5KQogICAgICByZXNjdWUgPT4gZQogICAgICAgICRzdGRlcnIu
# cHV0cyBlLm1lc3NhZ2UKICAgICAgZW5kCiAgICBlbmQKICBlbmQKCiAgZGVm
# IHNlbGYuZmluZChlbnRyeT1uaWwsIG1hc2s9bmlsKQogICAgZW50cnkJPSAi
# LiIJaWYgZW50cnkubmlsPwoKICAgIGVudHJ5CT0gZW50cnkuZ3N1YigvW1wv
# XFxdKiQvLCAiIikJdW5sZXNzIGVudHJ5Lm5pbD8KCiAgICBtYXNrCT0gL14j
# e21hc2t9JC9pCWlmIG1hc2sua2luZF9vZj8oU3RyaW5nKQoKICAgIHJlcwk9
# IFtdCgogICAgaWYgRmlsZS5kaXJlY3Rvcnk/KGVudHJ5KQogICAgICBwZGly
# CT0gRGlyLnB3ZAoKICAgICAgcmVzICs9IFsiJXMvIiAlIGVudHJ5XQlpZiBt
# YXNrLm5pbD8gb3IgZW50cnkgPX4gbWFzawoKICAgICAgYmVnaW4KICAgICAg
# ICBEaXIuY2hkaXIoZW50cnkpCgogICAgICAgIGJlZ2luCiAgICAgICAgICBE
# aXIubmV3KCIuIikuZWFjaCBkbyB8ZXwKICAgICAgICAgICAgcmVzICs9IERp
# ci5maW5kKGUsIG1hc2spLmNvbGxlY3R7fGV8IGVudHJ5KyIvIitlfQl1bmxl
# c3MgWyIuIiwgIi4uIl0uaW5jbHVkZT8oZSkKICAgICAgICAgIGVuZAogICAg
# ICAgIGVuc3VyZQogICAgICAgICAgRGlyLmNoZGlyKHBkaXIpCiAgICAgICAg
# ZW5kCiAgICAgIHJlc2N1ZSBFcnJubzo6RUFDQ0VTID0+IGUKICAgICAgICAk
# c3RkZXJyLnB1dHMgZS5tZXNzYWdlCiAgICAgIGVuZAogICAgZWxzZQogICAg
# ICByZXMgKz0gW2VudHJ5XQlpZiBtYXNrLm5pbD8gb3IgZW50cnkgPX4gbWFz
# awogICAgZW5kCgogICAgcmVzCiAgZW5kCmVuZAoKY2xhc3MgRmlsZQogIGRl
# ZiBzZWxmLnJvbGxiYWNrdXAoZmlsZSwgbW9kZT1uaWwpCiAgICBiYWNrdXBm
# aWxlCT0gZmlsZSArICIuUkIuQkFDS1VQIgogICAgY29udHJvbGZpbGUJPSBm
# aWxlICsgIi5SQi5DT05UUk9MIgogICAgcmVzCQk9IG5pbAoKICAgIEZpbGUu
# dG91Y2goZmlsZSkgICAgdW5sZXNzIEZpbGUuZmlsZT8oZmlsZSkKCgkjIFJv
# bGxiYWNrCgogICAgaWYgRmlsZS5maWxlPyhiYWNrdXBmaWxlKSBhbmQgRmls
# ZS5maWxlPyhjb250cm9sZmlsZSkKICAgICAgJHN0ZGVyci5wdXRzICJSZXN0
# b3JpbmcgI3tmaWxlfS4uLiIKCiAgICAgIEZpbGUuY29weShiYWNrdXBmaWxl
# LCBmaWxlKQkJCQkjIFJvbGxiYWNrIGZyb20gcGhhc2UgMwogICAgZW5kCgoJ
# IyBSZXNldAoKICAgIEZpbGUuZGVsZXRlKGJhY2t1cGZpbGUpCWlmIEZpbGUu
# ZmlsZT8oYmFja3VwZmlsZSkJIyBSZXNldCBmcm9tIHBoYXNlIDIgb3IgMwog
# ICAgRmlsZS5kZWxldGUoY29udHJvbGZpbGUpCWlmIEZpbGUuZmlsZT8oY29u
# dHJvbGZpbGUpCSMgUmVzZXQgZnJvbSBwaGFzZSAzIG9yIDQKCgkjIEJhY2t1
# cAoKICAgIEZpbGUuY29weShmaWxlLCBiYWNrdXBmaWxlKQkJCQkJIyBFbnRl
# ciBwaGFzZSAyCiAgICBGaWxlLnRvdWNoKGNvbnRyb2xmaWxlKQkJCQkJIyBF
# bnRlciBwaGFzZSAzCgoJIyBUaGUgcmVhbCB0aGluZwoKICAgIGlmIGJsb2Nr
# X2dpdmVuPwogICAgICBpZiBtb2RlLm5pbD8KICAgICAgICByZXMJPSB5aWVs
# ZAogICAgICBlbHNlCiAgICAgICAgRmlsZS5vcGVuKGZpbGUsIG1vZGUpIGRv
# IHxmfAogICAgICAgICAgcmVzCT0geWllbGQoZikKICAgICAgICBlbmQKICAg
# ICAgZW5kCiAgICBlbmQKCgkjIENsZWFudXAKCiAgICBGaWxlLmRlbGV0ZShi
# YWNrdXBmaWxlKQkJCQkJIyBFbnRlciBwaGFzZSA0CiAgICBGaWxlLmRlbGV0
# ZShjb250cm9sZmlsZSkJCQkJCSMgRW50ZXIgcGhhc2UgNQoKCSMgUmV0dXJu
# LCBsaWtlIEZpbGUub3BlbgoKICAgIHJlcwk9IEZpbGUub3BlbihmaWxlLCAo
# bW9kZSBvciAiciIpKQl1bmxlc3MgYmxvY2tfZ2l2ZW4/CgogICAgcmVzCiAg
# ZW5kCgogIGRlZiBzZWxmLnRvdWNoKGZpbGUpCiAgICBpZiBGaWxlLmV4aXN0
# cz8oZmlsZSkKICAgICAgRmlsZS51dGltZShUaW1lLm5vdywgRmlsZS5tdGlt
# ZShmaWxlKSwgZmlsZSkKICAgIGVsc2UKICAgICAgRmlsZS5vcGVuKGZpbGUs
# ICJhIil7fGZ8fQogICAgZW5kCiAgZW5kCgogIGRlZiBzZWxmLndoaWNoKGZp
# bGUpCiAgICByZXMJPSBuaWwKCiAgICBpZiB3aW5kb3dzPwogICAgICBmaWxl
# CT0gZmlsZS5nc3ViKC9cLmV4ZSQvaSwgIiIpICsgIi5leGUiCiAgICAgIHNl
# cAkJPSAiOyIKICAgIGVsc2UKICAgICAgc2VwCQk9ICI6IgogICAgZW5kCgog
# ICAgY2F0Y2ggOnN0b3AgZG8KICAgICAgRU5WWyJQQVRIIl0uc3BsaXQoLyN7
# c2VwfS8pLnJldmVyc2UuZWFjaCBkbyB8ZHwKICAgICAgICBpZiBGaWxlLmRp
# cmVjdG9yeT8oZCkKICAgICAgICAgIERpci5uZXcoZCkuZWFjaCBkbyB8ZXwK
# ICAgICAgICAgICAgIGlmIGUuZG93bmNhc2UgPT0gZmlsZS5kb3duY2FzZQog
# ICAgICAgICAgICAgICByZXMJPSBGaWxlLmV4cGFuZF9wYXRoKGUsIGQpCiAg
# ICAgICAgICAgICAgIHRocm93IDpzdG9wCiAgICAgICAgICAgIGVuZAogICAg
# ICAgICAgZW5kCiAgICAgICAgZW5kCiAgICAgIGVuZAogICAgZW5kCgogICAg
# cmVzCiAgZW5kCmVuZAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAcnVieXdlYmRpYWxvZ3MvbGliL3J1YnkubGliLnJiAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDA3NTUAMDAwMTc1MAAwMDAxNzUw
# ADAwMDAwMDQwMjYwADEwMjUwMzIwNjIxADAxNjYyMwAgMAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1
# c3RhciAgAGVyaWsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZXJpawAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwMDAwADAwMDAwMDAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAByZXF1aXJlICJjZ2kiCnJl
# cXVpcmUgInJiY29uZmlnIgpyZXF1aXJlICJ0aHJlYWQiCgpUaHJlYWQuYWJv
# cnRfb25fZXhjZXB0aW9uCT0gdHJ1ZQoKJERFQlVHCT0gKCRERUJVRyBvciBF
# TlZbIlJVQllERUJVRyJdIG9yIGZhbHNlKQoKI3Rla2Vucwk9ICdcd1x+XEBc
# I1wkXCVcXlwmXCpcLVwrJwp0ZWtlbnMJCT0gJ15cc1xyXG5cYFwhXChcKVxb
# XF1ce1x9XDxcPlwsXC5cL1w/XFxcfFw9XDtcOlwiJwoKI3Rla2VuczExCT0g
# J1x3Jwp0ZWtlbnMxMQk9IHRla2VucyArICInIgoKdGVrZW5zMjEJPSB0ZWtl
# bnMgKyAiJyIKdGVrZW5zMjIJPSB0ZWtlbnMKdGVrZW5zMjMJPSB0ZWtlbnMg
# KyAiJyIKCnRla2VuczMxCT0gJ1x3XHNcclxuJwoKUmVnRXhwU3RyaW5nV29y
# ZAk9ICIoWyN7dGVrZW5zMTF9XSspIgkJCQkJCQkJCTsgUmVnRXhwV29yZAkJ
# PSBSZWdleHAubmV3KFJlZ0V4cFN0cmluZ1dvcmQpClJlZ0V4cFN0cmluZ1dv
# cmQyCT0gIihbI3t0ZWtlbnMyMX1dKFsje3Rla2VuczIyfV0qWyN7dGVrZW5z
# MjN9XSk/KSIJCQkJCTsgUmVnRXhwV29yZDIJCT0gUmVnZXhwLm5ldyhSZWdF
# eHBTdHJpbmdXb3JkMikKUmVnRXhwU3RyaW5nVGV4dAk9ICIoWyN7dGVrZW5z
# MzF9XSspIgkJCQkJCQkJCTsgUmVnRXhwVGV4dAkJPSBSZWdleHAubmV3KFJl
# Z0V4cFN0cmluZ1RleHQpClJlZ0V4cFN0cmluZ0ZpbGUJPSAnKFx3W1x3XC5c
# LV0qKScJCQkJCQkJCQk7IFJlZ0V4cEZpbGUJCT0gUmVnZXhwLm5ldyhSZWdF
# eHBTdHJpbmdGaWxlKQpSZWdFeHBTdHJpbmdFbWFpbAk9ICcoW1x3XC1cLl0r
# QFtcd1wtXC5dKyknCQkJCQkJCQk7IFJlZ0V4cEVtYWlsCQk9IFJlZ2V4cC5u
# ZXcoUmVnRXhwU3RyaW5nRW1haWwpClJlZ0V4cFN0cmluZ1VSTAkJPSAnKFx3
# KzpcL1wvW1x3XC5cLV0rKDpcZCopP1wvW1x3XC5cLVwvXCNcP1w9XCVdKikn
# CQkJCQk7IFJlZ0V4cFVSTAkJPSBSZWdleHAubmV3KFJlZ0V4cFN0cmluZ1VS
# TCkKUmVnRXhwU3RyaW5nUHJpbnQJPSAnKFtcdyBcdFxyXG5cYFx+XCFcQFwj
# XCRcJVxeXCZcKlwoXClcLVwrXD1cW1xdXHtcfVw7XDpcJ1wiXCxcLlwvXDxc
# Plw/XFxcfF0rKScJOyBSZWdFeHBQcmludAkJPSBSZWdleHAubmV3KFJlZ0V4
# cFN0cmluZ1ByaW50KQpSZWdFeHBTdHJpbmdEaWZmCT0gJyheW1wtXCtdKFte
# XC1cK10uKik/KScJCQkJCQkJCTsgUmVnRXhwRGlmZgkJPSBSZWdleHAubmV3
# KFJlZ0V4cFN0cmluZ0RpZmYpClJlZ0V4cFN0cmluZ0hUSExpbmsJPSAnKGBb
# XHdcLF0qXGJhXGJbXmBdKmApJwkJCQkJCQkJOyBSZWdFeHBIVEhMaW5rCQk9
# IFJlZ2V4cC5uZXcoUmVnRXhwU3RyaW5nSFRITGluaykKUmVnRXhwU3RyaW5n
# SFRIU3BlY2lhbAk9ICcoYFteYF0qYCknCQkJCQkJCQkJCTsgUmVnRXhwSFRI
# U3BlY2lhbAk9IFJlZ2V4cC5uZXcoUmVnRXhwU3RyaW5nSFRIU3BlY2lhbCkK
# Cm1vZHVsZSBFbnVtZXJhYmxlCiAgZGVmIGRlZXBfZHVwCiAgICBNYXJzaGFs
# Ojpsb2FkKE1hcnNoYWw6OmR1bXAoZHVwKSkKICBlbmQKCiAgZGVmIGRlZXBf
# Y2xvbmUKICAgIE1hcnNoYWw6OmxvYWQoTWFyc2hhbDo6ZHVtcChjbG9uZSkp
# CiAgZW5kCmVuZAoKY2xhc3MgVGhyZWFkCiAgZGVmIHNlbGYuYmFja2dyb3Vu
# ZCgqYXJncykKICAgIG5ldygqYXJncykgZG8gfCphcmdzfAogICAgICBUaHJl
# YWQucGFzcwoKICAgICAgeWllbGQoKmFyZ3MpCiAgICBlbmQKICBlbmQKZW5k
# CgpjbGFzcyBPYmplY3QKICBhbGlhcyBkZWVwX2R1cCA6ZHVwCiAgYWxpYXMg
# ZGVlcF9jbG9uZSA6Y2xvbmUKCiAgZGVmIHRvX2ZzCiAgICB0b19zCiAgZW5k
# CgogIGRlZiBpZHMKICAgIGlkCiAgZW5kCmVuZAoKY2xhc3MgTnVtZXJpYwog
# IGRlZiB0b19mcwogICAgdG9fZgogIGVuZAoKICBkZWYgdG9faHRtbChlb2xj
# b252ZXJzaW9uPXRydWUpCiAgICBzZWxmLnRvX3MudG9faHRtbChlb2xjb252
# ZXJzaW9uKQogIGVuZAplbmQKCmNsYXNzIEludGVnZXIKICBkZWYgb2N0CiAg
# ICBuCT0gc2VsZgogICAgcmVzCT0gW10KCiAgICB3aGlsZSBuID4gOAogICAg
# ICBuLCB4CT0gbi5kaXZtb2QoOCkKICAgICAgcmVzIDw8IHgKICAgIGVuZAog
# ICAgcmVzIDw8IG4KCiAgICByZXMucmV2ZXJzZS5qb2luKCIiKQogIGVuZApl
# bmQKCmNsYXNzIFN0cmluZwogIGRlZiBjaG9tcCEoZHVtbXk9bmlsKQogICAg
# c2VsZi5nc3ViISgvW1xyXG5dKlx6LywgIiIpCiAgZW5kCgogIGRlZiBjaG9t
# cChkdW1teT1uaWwpCiAgICBzZWxmLmdzdWIoL1tcclxuXSpcei8sICIiKQog
# IGVuZAoKICBkZWYgbGYKICAgIHNlbGYuZ3N1YigvXHIqXG4vLCAiXG4iKS5n
# c3ViKC9cblx6LywgIiIpICsgIlxuIgogIGVuZAoKICBkZWYgY3JsZgogICAg
# c2VsZi5nc3ViKC9ccipcbi8sICJcclxuIikuZ3N1YigvXHJcblx6LywgIiIp
# ICsgIlxyXG4iCiAgZW5kCgogIGRlZiBzdHJpcAogICAgc2VsZi5zdHJpcGJl
# Zm9yZS5zdHJpcGFmdGVyCiAgZW5kCgogIGRlZiBzdHJpcGJlZm9yZQogICAg
# c2VsZi5nc3ViKC9cQVtbOmJsYW5rOl1cclxuXSovLCAiIikKICBlbmQKCiAg
# ZGVmIHN0cmlwYWZ0ZXIKICAgIHNlbGYuZ3N1YigvW1s6Ymxhbms6XVxyXG5d
# Klx6LywgIiIpCiAgZW5kCgogIGRlZiBjb21wcmVzcwogICAgc2VsZi5nc3Vi
# KC9bWzpibGFuazpdXHJcbl0rLywgIiAiKS5zdHJpcAogIGVuZAoKICBkZWYg
# Y29tcHJlc3NzcGFjZXMKICAgIHNlbGYuZ3N1YigvW1s6Ymxhbms6XV0rLywg
# IiAiKQogIGVuZAoKICBkZWYgY29tcHJlc3NwZXJsaW5lCiAgICByZXMJPSBz
# ZWxmLnNwbGl0KC9cbi8pCiAgICByZXMuY29sbGVjdCF7fGxpbmV8IGxpbmUu
# Y29tcHJlc3N9CiAgICByZXMuZGVsZXRlX2lme3xsaW5lfCBsaW5lLmVtcHR5
# P30KICAgIHJlcy5qb2luKCJcbiIpCiAgZW5kCgogIGRlZiBudW1lcmljPwog
# ICAgZCwgYSwgbgk9IFtzZWxmXS50b19wYXIKCiAgICBub3Qgbi5lbXB0eT8K
# ICBlbmQKCiAgZGVmIGV4ZWMoaW5wdXQ9bmlsLCBvdXRwdXQ9dHJ1ZSkKICAg
# IHJlcwk9IFtdCgogICAgSU8ucG9wZW4oc2VsZiwgIncrIikgZG8gfGZ8CiAg
# ICAgIGYucHV0cyBpbnB1dAl1bmxlc3MgaW5wdXQubmlsPwogICAgICBmLmNs
# b3NlX3dyaXRlCgogICAgICByZXMJPSBmLnJlYWRsaW5lcyBpZiBvdXRwdXQK
# ICAgIGVuZAoKICAgIHJlcy5qb2luKCIiKQogIGVuZAoKICBkZWYgZXZhbAog
# ICAgS2VybmVsOjpldmFsKHNlbGYpCiAgZW5kCgogIGRlZiBzcGVhawogICAg
# cmVxdWlyZSAiZHJiIgoKICAgIERSYi5zdGFydF9zZXJ2aWNlCiAgICBEUmJP
# YmplY3QubmV3KG5pbCwgImRydWJ5Oi8vbG9jYWxob3N0OjMxMDAiKS5zcGVh
# ayhzZWxmKQogIGVuZAoKICBkZWYgc3BsaXRibG9ja3MoKmRlbGltaXRlcnMp
# CiAgICBiZWdpbmRlbGltaXRlcnMJPSBbXQogICAgZW5kZGVsaW1pdGVycwk9
# IFtdCgogICAgZGVsaW1pdGVycy5lYWNoIGRvIHxrLCB2fAogICAgICBiZWdp
# bmRlbGltaXRlcnMJPDwgay5kb3duY2FzZQogICAgICBlbmRkZWxpbWl0ZXJz
# CTw8IHYuZG93bmNhc2UKICAgIGVuZAoKICAgIGJkCT0gYmVnaW5kZWxpbWl0
# ZXJzLmNvbGxlY3QJe3xzfCBSZWdleHAuZXNjYXBlKHMpfQogICAgZWQJPSBl
# bmRkZWxpbWl0ZXJzLmNvbGxlY3QJCXt8c3wgUmVnZXhwLmVzY2FwZShzKX0K
# CiAgICBiZQk9IGJkLmpvaW4oInwiKQogICAgZWUJPSBlZC5qb2luKCJ8IikK
# CiAgICByZXMJCT0gW10KICAgIHR5cGUJPSAwCiAgICB0bXAJCT0gIiIKICAg
# IGJzCQk9ICIiCiAgICBlcwkJPSAiIgoKICAgIHNlbGYuc3BsaXQoLygje2Vl
# fXwje2JlfSkvaSkuZWFjaCBkbyB8c3wKICAgICAgaWYgdHlwZSA9PSAwCiAg
# ICAgICAgaWYgYmVnaW5kZWxpbWl0ZXJzLmluY2x1ZGU/KHMuZG93bmNhc2Up
# CiAgICAgICAgICBpCT0gYmVnaW5kZWxpbWl0ZXJzLmluZGV4KHMuZG93bmNh
# c2UpCiAgICAgICAgICB0eXBlCT0gaSsxCiAgICAgICAgICB0bXAJPSBzCiAg
# ICAgICAgICBicwk9IHMuZG93bmNhc2UKICAgICAgICAgIGVzCT0gZW5kZGVs
# aW1pdGVyc1tpXQogICAgICAgIGVsc2UKICAgICAgICAgIHJlcyA8PCBbMCwg
# c10JdW5sZXNzIHMuZW1wdHk/CiAgICAgICAgZW5kCiAgICAgIGVsc2UKICAg
# ICAgICBpZiBzLmRvd25jYXNlID09IGVzCiAgICAgICAgICByZXMgPDwgW3R5
# cGUsIHRtcCArIHNdCiAgICAgICAgICB0eXBlCT0gMAogICAgICAgICAgdG1w
# CT0gIiIKICAgICAgICAgIGJzCT0gIiIKICAgICAgICAgIGVzCT0gIiIKICAg
# ICAgICBlbHNlCiAgICAgICAgICBpZiBzLmRvd25jYXNlID09IGJzCiAgICAg
# ICAgICAgIHJlcyA8PCBbMCwgdG1wXQogICAgICAgICAgICB0bXAJPSBzCiAg
# ICAgICAgICBlbHNlCiAgICAgICAgICAgIHRtcAk9IHRtcCArIHMKICAgICAg
# ICAgIGVuZAogICAgICAgIGVuZAogICAgICBlbmQKICAgIGVuZAoKICAgIHJl
# cyA8PCBbMCwgdG1wXQl1bmxlc3MgdG1wLmVtcHR5PwoKICAgIHJldHVybiBy
# ZXMKICBlbmQKCiAgZGVmIHNwbGl0d29yZHModG9rZW5zPVtdKQogICAgdG9r
# ZW5zCQk9IFt0b2tlbnNdCXVubGVzcyB0b2tlbnMua2luZF9vZj8oQXJyYXkp
# CiAgICByZXMJCQk9IFtdCgogICAgc2VsZi5zcGxpdGJsb2NrcyhbIiciLCAi
# JyJdLCBbJyInLCAnIiddKS5lYWNoIGRvIHx0eXBlLCBzfAogICAgICBjYXNl
# IHR5cGUKICAgICAgd2hlbiAwCiAgICAgICAgdG9rZW5zLmVhY2ggZG8gfHRv
# a2VufAogICAgICAgICAgdG9rZW4yCT0gdG9rZW4KICAgICAgICAgIHRva2Vu
# Mgk9IFJlZ2V4cC5lc2NhcGUodG9rZW4yKQlpZiB0b2tlbjIua2luZF9vZj8o
# U3RyaW5nKQogICAgICAgICAgcy5nc3ViISgvI3t0b2tlbjJ9LywgIiAje3Rv
# a2VufSAiKQogICAgICAgIGVuZAogICAgICAgIHMuc3BsaXQoKS5lYWNoIGRv
# IHx3fAogICAgICAgICAgcmVzIDw8IHcKICAgICAgICBlbmQKICAgICAgd2hl
# biAxLCAyCiAgICAgICAgcmVzIDw8IHNbMS4uLTJdCiAgICAgIGVuZAogICAg
# ZW5kCgogICAgcmV0dXJuIHJlcwogIGVuZAoKICBkZWYgdW5jb21tZW50CiAg
# ICByZXMJPSBbXQoKICAgIHNlbGYuc3BsaXRibG9ja3MoWyInIiwgIiciXSwg
# WyciJywgJyInXSwgWyIjIiwgIlxuIl0pLmVhY2ggZG8gfHR5cGUsIHN8CiAg
# ICAgIGNhc2UgdHlwZQogICAgICB3aGVuIDAsIDEsIDIJdGhlbglyZXMgPDwg
# cwogICAgICB3aGVuIDMJCXRoZW4JcmVzIDw8ICJcbiIKICAgICAgZW5kCiAg
# ICBlbmQKCiAgICByZXMuam9pbigiIikKICBlbmQKCiAgZGVmIG5vcXVvdGVz
# CiAgICBzZWxmLnN1YigvXEFbJyJdLywgIiIpLnN1YigvWyciXVx6LywgIiIp
# CiAgZW5kCgogIGRlZiB0b19odG1sKGVvbGNvbnZlcnNpb249dHJ1ZSkKICAg
# IHMJPSBDR0kuZXNjYXBlSFRNTChzZWxmKQoKICAgIHMuZ3N1YiEoL1wiLywg
# IlwmIzM0OyIpCiAgICBzLmdzdWIhKC9cJy8sICJcJiMxODA7IikKCiAgICBp
# ZiBlb2xjb252ZXJzaW9uCiAgICAgIHMuZ3N1YiEoL1xuLyAsICI8YnI+IikK
# ICAgIGVuZAoKICAgIHMKICBlbmQKCiAgZGVmIGZyb21faHRtbChlb2xjb252
# ZXJzaW9uPXRydWUpCiAgICBzCT0gc2VsZgoKICAgIHMuZ3N1YiEoLyYjMzQ7
# LyAsICJcIiIpCiAgICBzLmdzdWIhKC8mIzE4MDsvLCAiXCciKQoKICAgIHMJ
# PSBDR0kudW5lc2NhcGVIVE1MKHNlbGYpCgogICAgaWYgZW9sY29udmVyc2lv
# bgogICAgICBzLmdzdWIhKC88YnI+LywgIlxuIikKICAgIGVuZAoKICAgIHMK
# ICBlbmQKCiAgZGVmIHRvX2ZzCiAgICBpZiBudW1lcmljPwogICAgICB0b19m
# CiAgICBlbHNlCiAgICAgIHRvX3MKICAgIGVuZAogIGVuZAplbmQKCmNsYXNz
# IEFycmF5CiAgZGVmIGNob21wIQogICAgc2VsZi5jb2xsZWN0IXt8c3wgcy5j
# aG9tcH0KICBlbmQKCiAgZGVmIGNob21wCiAgICBzZWxmLmNvbGxlY3R7fHN8
# IHMuY2hvbXB9CiAgZW5kCgogIGRlZiBjb21wcmVzcwogICAgc2VsZi5jb2xs
# ZWN0e3xzfCBzLmNvbXByZXNzfQogIGVuZAoKICBkZWYgdW5jb21tZW50CiAg
# ICBzZWxmLmpvaW4oIlwwIikudW5jb21tZW50LnNwbGl0KCJcMCIpCiAgZW5k
# CgogIGRlZiBzdHJpcAogICAgc2VsZi5jb2xsZWN0e3xzfCBzLnN0cmlwfQog
# IGVuZAoKICBkZWYgc3VtCiAgICByZXMJPSAwCiAgICBzZWxmLmVhY2ggZG8g
# fG58CiAgICAgIHJlcyArPSBuCiAgICBlbmQKICAgIHJlcwogIGVuZAoKICBk
# ZWYgcHJvZHVjdAogICAgcmVzCT0gMQogICAgc2VsZi5lYWNoIGRvIHxufAog
# ICAgICByZXMgKj0gbgogICAgZW5kCiAgICByZXMKICBlbmQKCiAgZGVmIGpv
# aW53b3JkcyhzZXA9IiAiLCBxdW90ZT0nIicpCiAgICBzZWxmLmNvbGxlY3Qg
# ZG8gfHN8CiAgICAgIHMJPSBxdW90ZSArIHMgKyBxdW90ZQlpZiBzID1+IC9b
# WzpibGFuazpdXS8KICAgICAgcwogICAgZW5kLmpvaW4oc2VwKQogIGVuZAoK
# ICBkZWYgZG9taW5vKHRhYmVsbGVuLCBrb2xvbT1uaWwsIG9ubHltYXRjaGlu
# Z2xpbmVzPWZhbHNlKQogICAgbGlua3MJPSBzZWxmCiAgICByZXMJCT0gW10K
# ICAgIHJlcwkJPSBzZWxmLmR1cAl1bmxlc3Mgb25seW1hdGNoaW5nbGluZXMK
# CiAgICB0YWJlbGxlbi5lYWNoIGRvIHxyZWNodHN8CiAgICAgIHRtcAk9IFtd
# CgogICAgICBsaW5rcy5lYWNoIGRvIHxsfAogICAgICAgIGlmIGtvbG9tLm5p
# bD8gb3IgbC5sZW5ndGggPT0ga29sb20KICAgICAgICAgIHJlY2h0cy5lYWNo
# IGRvIHxyfAogICAgICAgICAgICB0bXAgPDwgbCArIHJbMS4uLTFdCWlmIGxb
# LTFdID09IHJbMF0KICAgICAgICAgIGVuZAogICAgICAgIGVuZAogICAgICBl
# bmQKCiAgICAgIGxpbmtzCT0gdG1wCiAgICAgIHJlcy5jb25jYXQodG1wKQog
# ICAgZW5kCgogICAgcmVzCT0gcmVzLnNvcnQudW5pcQogIGVuZAoKICBkZWYg
# ZG9taW5vbG9vcCh0YWJlbGxlbikKICAgIGxyZXMJPSBbXQogICAgcmVzCQk9
# IHNlbGYuZHVwCiAgICBrb2xvbQk9IDIKCiAgICB3aGlsZSBscmVzLmxlbmd0
# aCAhPSByZXMubGVuZ3RoIGRvCiAgICAgIGxyZXMJPSByZXMuZHVwCiAgICAg
# IHJlcwk9IHJlcy5kb21pbm8odGFiZWxsZW4sIGtvbG9tKQoKICAgICAgcmVz
# LmVhY2ggZG8gfGxpbmV8CiAgICAgICAgbGluZSA8PCAiKiIJaWYgKGxpbmUu
# bGVuZ3RoICE9IGxpbmUudW5pcS5sZW5ndGggYW5kIGxpbmVbLTFdICE9ICIq
# IikKICAgICAgZW5kCgogICAgICAkc3RkZXJyLnByaW50ICIjezEwMCoocmVz
# Lmxlbmd0aCkvKGxyZXMubGVuZ3RoKX0lICIKCiAgICAgIGtvbG9tICs9IDEK
# ICAgIGVuZAoKICAgICRzdGRlcnIucHV0cyAiIgoKICAgIHJldHVybiByZXMK
# ICBlbmQKCiAgZGVmIGJ1aWxkdHJlZQogICAgc2VsZi5kb21pbm9sb29wKFtz
# ZWxmXSkKICBlbmQKCiAgZGVmIHN1YnNldChmaWVsZHMsIHZhbHVlcywgcmVz
# dWx0cywgZXhhY3Q9dHJ1ZSwgZW1wdHlsaW5lPW5pbCwgam9pbndpdGg9bmls
# KQogICAgZmllbGRzCT0gW2ZpZWxkc10JCXVubGVzcyBmaWVsZHMua2luZF9v
# Zj8gQXJyYXkKICAgIHZhbHVlcwk9IFt2YWx1ZXNdCQl1bmxlc3MgdmFsdWVz
# LmtpbmRfb2Y/IEFycmF5CiAgICByZXN1bHRzCT0gW3Jlc3VsdHNdCQl1bmxl
# c3MgcmVzdWx0cy5raW5kX29mPyBBcnJheQogICAgZW1wdHlsaW5lCT0gZW1w
# dHlsaW5lLmRvd25jYXNlCXVubGVzcyBlbXB0eWxpbmUubmlsPwogICAgcmVz
# CQk9IHNlbGYuZHVwCiAgICByZXMuZGVsZXRlX2lmIHt0cnVlfQoKICAgIHNl
# bGYuZWFjaCBkbyB8bHwKICAgICAgb2sJPSB0cnVlCgogICAgICBjYXNlIGwu
# Y2xhc3MudG9fcwogICAgICB3aGVuICJTdHJpbmciCiAgICAgICAgYwkJPSBs
# LnNwbGl0d29yZHMKICAgICAgICBjb3JyZWN0aW9uCT0gMQogICAgICAgIGpv
# aW53aXRoCT0gIiAiCWlmIGpvaW53aXRoLm5pbD8KICAgICAgd2hlbiAiQXJy
# YXkiCiAgICAgICAgYwkJPSBsCiAgICAgICAgY29ycmVjdGlvbgk9IDAKICAg
# ICAgZW5kCgogICAgICAjY2F0Y2ggOnN0b3AgZG8KICAgICAgICB2YWx1ZXMy
# CT0gdmFsdWVzLmR1cAogICAgICAgIGZpZWxkcy5lYWNoIGRvIHxmfAogICAg
# ICAgICAgdgk9IHZhbHVlczIuc2hpZnQKICAgICAgICAgIHYJPSB2LmRvd25j
# YXNlCXVubGVzcyB2Lm5pbD8KICAgICAgICAgIGlmIGVtcHR5bGluZS5uaWw/
# IG9yIChub3QgdiA9PSBlbXB0eWxpbmUpCiAgICAgICAgICAgIGlmIGV4YWN0
# CiAgICAgICAgICAgICAgdW5sZXNzICh2Lm5pbD8gb3IgY1tmLWNvcnJlY3Rp
# b25dLmRvd25jYXNlID09IHYpCiAgICAgICAgICAgICAgICBvawk9IGZhbHNl
# CiAgICAgICAgICAgICAgICAjdGhyb3cgOnN0b3AKICAgICAgICAgICAgICBl
# bmQKICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgIHVubGVzcyAodi5u
# aWw/IG9yIGNbZi1jb3JyZWN0aW9uXS5kb3duY2FzZS5pbmNsdWRlPyh2KSkK
# ICAgICAgICAgICAgICAgIG9rCT0gZmFsc2UKICAgICAgICAgICAgICAgICN0
# aHJvdyA6c3RvcAogICAgICAgICAgICAgIGVuZAogICAgICAgICAgICBlbmQK
# ICAgICAgICAgIGVuZAogICAgICAgIGVuZAogICAgICAjZW5kCgogICAgICBp
# ZiBvawogICAgICAgIHJlczIJPSBbXQogICAgICAgIHJlc3VsdHMuZWFjaCBk
# byB8bnwKICAgICAgICAgIHJlczIgPDwgY1tuLTFdCiAgICAgICAgZW5kCiAg
# ICAgICAgcmVzMgk9IHJlczIuam9pbihqb2lud2l0aCkJdW5sZXNzIGpvaW53
# aXRoLm5pbD8KICAgICAgICByZXMgPDwgcmVzMgogICAgICBlbmQKICAgIGVu
# ZAoKICAgIHJldHVybiByZXMKICBlbmQKCiAgZGVmIGZvcm1hdChmb3JtYXQp
# CiAgICBmb3JtYXQJPSBmb3JtYXQuZ3N1YigvXHMvLCAiIikKICAgIHJlcwkJ
# PSBbXQoKICAgIFtmb3JtYXQubGVuZ3RoLCBzZWxmLmxlbmd0aF0ubWluLnRp
# bWVzIGRvIHxufAogICAgICBjYXNlIGZvcm1hdFtuXS5jaHIuZG93bmNhc2UK
# ICAgICAgd2hlbiAiaSIJdGhlbglyZXMgPDwgc2VsZltuXS50b19pCiAgICAg
# IHdoZW4gInMiCXRoZW4JcmVzIDw8IHNlbGZbbl0udG9fcwogICAgICBlbHNl
# CQlyZXMgPDwgc2VsZltuXQogICAgICBlbmQKICAgIGVuZAoKICAgIHJlcwog
# IGVuZAoKICBkZWYgdG9faQogICAgY29sbGVjdHt8Y3wgYy50b19pfQogIGVu
# ZAoKICBkZWYgdG9fcGFyCiAgICBkYXNoCT0gc2VsZi5kdXAKICAgIGFscGhh
# CT0gc2VsZi5kdXAKICAgIG51bWVyaWMJPSBzZWxmLmR1cAoKICAgIGRhc2gu
# ZGVsZXRlX2lmIGRvIHxzfAogICAgICBub3QgKHMgPX4gL1xBLS8pIG9yCiAg
# ICAgIChzID1+IC9cQS0/W1s6ZGlnaXQ6XVwuXStcei8pIG9yCiAgICAgIChz
# ID1+IC9eLSskLykKICAgIGVuZAoKICAgIGFscGhhLmRlbGV0ZV9pZiBkbyB8
# c3wKICAgICAgKChzID1+IC9cQS0vKSBvcgogICAgICAgKHMgPX4gL1xBLT9b
# WzpkaWdpdDpdXC5dK1x6LykpIGFuZAogICAgICBub3QgKChzID1+IC9eXC4r
# JC8pIG9yIChzID1+IC9eLSskLykpCiAgICBlbmQKCiAgICBudW1lcmljLmRl
# bGV0ZV9pZiBkbyB8c3wKICAgICAgbm90IChzID1+IC9cQS0/W1s6ZGlnaXQ6
# XVwuXStcei8pIG9yCiAgICAgIChzID1+IC9eXC4rJC8pCiAgICBlbmQKCiAg
# ICByYWlzZSAiT29wcyEiCWlmIGRhc2gubGVuZ3RoICsgYWxwaGEubGVuZ3Ro
# ICsgbnVtZXJpYy5sZW5ndGggIT0gbGVuZ3RoCgogICAgcmV0dXJuIGRhc2gs
# IGFscGhhLCBudW1lcmljCiAgZW5kCgogIGRlZiBzZWxmLmZpbGUoZmlsZSkK
# ICAgIHJlcwk9IG5ldwoKICAgIEZpbGUub3BlbihmaWxlKSBkbyB8ZnwKICAg
# ICAgZi5yZWFkbGluZXMudW5jb21tZW50LmNob21wLmVhY2ggZG8gfGxpbmV8
# CiAgICAgICAgcmVzIDw8IGxpbmUKICAgICAgZW5kCiAgICBlbmQKCiAgICBy
# ZXMKICBlbmQKCiAgZGVmIG51bXNvcnQKICAgIHNvcnQgZG8gfGEsIGJ8CiAg
# ICAgIGEyCT0gYS50b19mcwogICAgICBiMgk9IGIudG9fZnMKCiAgICAgIGlm
# IGEyLmNsYXNzICE9IGIyLmNsYXNzCiAgICAgICAgYTIJPSBhCiAgICAgICAg
# YjIJPSBiCiAgICAgIGVuZAoKICAgICAgYTIgPD0+IGIyCiAgICBlbmQKICBl
# bmQKCiAgZGVmIHRvX2ZzCiAgICBjb2xsZWN0e3xzfCBzLnRvX2ZzfQogIGVu
# ZAoKICBkZWYgY2hhb3MKICAgIHJlcwk9IHNlbGYuZHVwCgogICAgKGxlbmd0
# aF4yKS50aW1lcyBkbwogICAgICBhCT0gcmFuZChsZW5ndGgpCiAgICAgIGIJ
# PSByYW5kKGxlbmd0aCkKCiAgICAgIHJlc1thXSwgcmVzW2JdCT0gcmVzW2Jd
# LCByZXNbYV0KICAgIGVuZAoKICAgIHJlcwogIGVuZAoKICBkZWYgYW55CiAg
# ICBpZiBlbXB0eT8KICAgICAgbmlsCiAgICBlbHNlCiAgICAgIHNlbGZbcmFu
# ZChzZWxmLmxlbmd0aCldCiAgICBlbmQKICBlbmQKCiAgZGVmIG1pbm1heAog
# ICAgbWluLCB2YWx1ZSwgbWF4CT0gc2VsZgogICAgW21pbiwgW3ZhbHVlLCBt
# YXhdLm1pbl0ubWF4CiAgZW5kCgogIGRlZiBpZHMKICAgIGNvbGxlY3R7fGV8
# IGUuaWRzfQogIGVuZAoKICBkZWYgcm90YXRlCiAgICByYWlzZSAiQXJyYXkg
# aGFzIHRvIGJlIDJEIChBbiBBcnJheSBvZiBBcnJheXMpLiIJdW5sZXNzIHNl
# bGYuZHVwLmRlbGV0ZV9pZnt8YXwgYS5raW5kX29mPyhBcnJheSl9LmVtcHR5
# PwoKICAgIHJlcwk9IFtdCgogICAgc2VsZlswXS5sZW5ndGgudGltZXMgZG8g
# fHh8CiAgICAgIGEJPSBbXQoKICAgICAgc2VsZi5sZW5ndGgudGltZXMgZG8g
# fHl8CiAgICAgICAgYSA8PCBzZWxmW3ldW3hdCiAgICAgIGVuZAoKICAgICAg
# cmVzIDw8IGEKICAgIGVuZAoKICAgIHJlcwogIGVuZAoKICBkZWYgdG9faAog
# ICAgcmFpc2UgIkFycmF5IGhhcyB0byBiZSAyRCAoQW4gQXJyYXkgb2YgQXJy
# YXlzKS4iCXVubGVzcyBzZWxmLmR1cC5kZWxldGVfaWZ7fGF8IGEua2luZF9v
# Zj8oQXJyYXkpfS5lbXB0eT8KCiAgICByZXMJPSB7fQoKICAgIHNlbGYuZWFj
# aCBkbyB8aywgdiwgKnJlc3R8CiAgICAgIHJlc1trXQk9IHYKICAgIGVuZAoK
# ICAgIHJlcwogIGVuZAplbmQKCmNsYXNzIEhhc2gKICBkZWYgc2F2ZShmaWxl
# LCBhcHBlbmQ9ZmFsc2UpCiAgICBvcmcJPSB7fQogICAgb3JnCT0gSGFzaC5m
# aWxlKGZpbGUpCWlmIChhcHBlbmQgYW5kIEZpbGUuZmlsZT8oZmlsZSkpCgog
# ICAgc2VsZi5zb3J0LmVhY2ggZG8gfGssIHZ8CiAgICAgIG9yZ1trXQk9IHYK
# ICAgIGVuZAoKICAgIEZpbGUub3BlbihmaWxlLCAidyIpIGRvIHxmfAogICAg
# ICBvcmcuc29ydC5lYWNoIGRvIHxrLCB2fAogICAgICAgIGYucHV0cyAiJXNc
# dD0gJXMiICUgW2ssIHZdCiAgICAgIGVuZAogICAgZW5kCiAgZW5kCgogIGRl
# ZiBzdWJzZXQoZmllbGRzLCB2YWx1ZXMsIHJlc3VsdHM9bmlsLCBleGFjdD10
# cnVlLCBlbXB0eWxpbmU9bmlsLCBqb2lud2l0aD1uaWwpCiAgICBmaWVsZHMJ
# PSBbZmllbGRzXQkJdW5sZXNzIGZpZWxkcy5raW5kX29mPyBBcnJheQogICAg
# dmFsdWVzCT0gW3ZhbHVlc10JCXVubGVzcyB2YWx1ZXMua2luZF9vZj8gQXJy
# YXkKICAgIHJlc3VsdHMJPSBbcmVzdWx0c10JCXVubGVzcyByZXN1bHRzLmtp
# bmRfb2Y/IEFycmF5CiAgICBlbXB0eWxpbmUJPSBlbXB0eWxpbmUuZG93bmNh
# c2UJdW5sZXNzIGVtcHR5bGluZS5uaWw/CiAgICByZXMJCT0gc2VsZi5kdXAK
# ICAgIHJlcy5kZWxldGVfaWYge3RydWV9CgogICAgc2VsZi5lYWNoIGRvIHxr
# LCBsfAogICAgICBvawk9IHRydWUKCiAgICAgIGNhc2UgbC5jbGFzcy50b19z
# CiAgICAgIHdoZW4gIlN0cmluZyIKICAgICAgICBjCQk9IGwuc3BsaXR3b3Jk
# cwogICAgICAgIGNvcnJlY3Rpb24JPSAxCiAgICAgICAgam9pbndpdGgJPSAi
# ICIJaWYgam9pbndpdGgubmlsPwogICAgICB3aGVuICJBcnJheSIKICAgICAg
# ICBjCQk9IGwKICAgICAgICBjb3JyZWN0aW9uCT0gMAogICAgICBlbmQKCiAg
# ICAgICNjYXRjaCA6c3RvcCBkbwogICAgICAgIHZhbHVlczIJPSB2YWx1ZXMu
# ZHVwCiAgICAgICAgZmllbGRzLmVhY2ggZG8gfGZ8CiAgICAgICAgICB2CT0g
# dmFsdWVzMi5zaGlmdAogICAgICAgICAgdgk9IHYuZG93bmNhc2UJdW5sZXNz
# IHYubmlsPwogICAgICAgICAgaWYgZW1wdHlsaW5lLm5pbD8gb3IgKG5vdCB2
# ID09IGVtcHR5bGluZSkKICAgICAgICAgICAgaWYgZXhhY3QKICAgICAgICAg
# ICAgICB1bmxlc3MgKHYubmlsPyBvciBjW2YtY29ycmVjdGlvbl0uZG93bmNh
# c2UgPT0gdikKICAgICAgICAgICAgICAgIG9rCT0gZmFsc2UKICAgICAgICAg
# ICAgICAgICN0aHJvdyA6c3RvcAogICAgICAgICAgICAgIGVuZAogICAgICAg
# ICAgICBlbHNlCiAgICAgICAgICAgICAgdW5sZXNzICh2Lm5pbD8gb3IgY1tm
# LWNvcnJlY3Rpb25dLmRvd25jYXNlLmluY2x1ZGU/KHYpKQogICAgICAgICAg
# ICAgICAgb2sJPSBmYWxzZQogICAgICAgICAgICAgICAgI3Rocm93IDpzdG9w
# CiAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgIGVuZAogICAgICAgICAg
# ZW5kCiAgICAgICAgZW5kCiAgICAgICNlbmQKCiAgICAgIGlmIG9rCiAgICAg
# ICAgcmVzMgk9IFtdCiAgICAgICAgaWYgcmVzdWx0cyA9PSBbbmlsXQogICAg
# ICAgICAgcmVzMgk9IGMKICAgICAgICBlbHNlCiAgICAgICAgICByZXN1bHRz
# LmVhY2ggZG8gfG58CiAgICAgICAgICAgIHJlczIgPDwgY1tuLWNvcnJlY3Rp
# b25dCiAgICAgICAgICBlbmQKICAgICAgICBlbmQKICAgICAgICByZXMyCT0g
# cmVzMi5qb2luKGpvaW53aXRoKQl1bmxlc3Mgam9pbndpdGgubmlsPwogICAg
# ICAgIHJlc1trXQk9IHJlczIKICAgICAgZW5kCiAgICBlbmQKCiAgICByZXR1
# cm4gcmVzCiAgZW5kCgogIGRlZiB0b19pCiAgICBjb2xsZWN0e3xrLCB2fCB2
# LnRvX2l9CiAgZW5kCgogIGRlZiBzZWxmLmZpbGUoZmlsZSkKICAgIHJlcwk9
# IG5ldwoKICAgIEZpbGUub3BlbihmaWxlKSBkbyB8ZnwKICAgICAgI2YucmVh
# ZGxpbmVzLmNob21wLmVhY2ggZG8gfGxpbmV8CiAgICAgIHdoaWxlIGxpbmUg
# PSBmLmdldHMgZG8KICAgICAgICBsaW5lLmNob21wIQoKICAgICAgICB1bmxl
# c3MgbGluZS5lbXB0eT8KICAgICAgICAgIGssIHYJPSBsaW5lLnNwbGl0KC9c
# cyo9XHMqLywgMikKICAgICAgICAgIHJlc1trXQk9IHYKICAgICAgICBlbmQK
# ICAgICAgZW5kCiAgICBlbmQKCiAgICByZXMKICBlbmQKCiAgZGVmIGlkcwog
# ICAgY29sbGVjdHt8aywgdnwgW2ssIHZdLmlkc30KICBlbmQKZW5kCgpkZWYg
# aWQycmVmKGlkKQogIE9iamVjdFNwYWNlLl9pZDJyZWYoaWQpCmVuZAoKZGVm
# IGFmdGVyKHNlY29uZHMsICphcmdzKQogIGlmIG5vdCBzZWNvbmRzLm5pbD8g
# YW5kIG5vdCBzZWNvbmRzLnplcm8/CiAgICBUaHJlYWQubmV3KCphcmdzKSBk
# byB8KmFyZ3MyfAogICAgICBzbGVlcCBzZWNvbmRzCiAgICAgIHlpZWxkKCph
# cmdzMikKICAgIGVuZAogIGVuZAplbmQKCmRlZiBldmVyeShzZWNvbmRzLCAq
# YXJncykKICBpZiBub3Qgc2Vjb25kcy5uaWw/IGFuZCBub3Qgc2Vjb25kcy56
# ZXJvPwogICAgVGhyZWFkLm5ldygqYXJncykgZG8gfCphcmdzMnwKICAgICAg
# bG9vcCBkbwogICAgICAgIHNsZWVwIHNlY29uZHMKICAgICAgICB5aWVsZCgq
# YXJnczIpCiAgICAgIGVuZAogICAgZW5kCiAgZW5kCmVuZAoKZGVmIGV2dGlt
# ZW91dChzZWNvbmRzKQogIGJlZ2luCiAgICB0aW1lb3V0KHNlY29uZHMpIGRv
# CiAgICAgIHlpZWxkCiAgICBlbmQKICByZXNjdWUgVGltZW91dEVycm9yCiAg
# ZW5kCmVuZAoKZGVmIGV2dGltZW91dHJldHJ5KHNlY29uZHMpCiAgb2sJPSBm
# YWxzZQoKICB3aGlsZSBub3Qgb2sKICAgIGV2dGltZW91dChzZWNvbmRzKSBk
# bwogICAgICB5aWVsZAogICAgICBvawk9IHRydWUKICAgIGVuZAogIGVuZApl
# bmQKCmRlZiB0cmFwKHNpZ25hbCkKICBLZXJuZWw6OnRyYXAoc2lnbmFsKSBk
# bwogICAgeWllbGQKICBlbmQKCgkjIFNlZW1zIHBvaW50bGVzcywgYnV0IGl0
# J3MgZm9yIGNhdGNoaW5nIF5DIHVuZGVyIFdpbmRvd3MuLi4KCiAgZXZlcnko
# MSkJe30JaWYgd2luZG93cz8KZW5kCgpkZWYgbGludXg/CiAgbm90ICh0YXJn
# ZXRfb3MuZG93bmNhc2UgPX4gL2xpbnV4LykubmlsPwplbmQKCmRlZiBkYXJ3
# aW4/CiAgbm90ICh0YXJnZXRfb3MuZG93bmNhc2UgPX4gL2Rhcndpbi8pLm5p
# bD8KZW5kCgpkZWYgd2luZG93cz8KICBub3QgKHRhcmdldF9vcy5kb3duY2Fz
# ZSA9fiAvMzIvKS5uaWw/CmVuZAoKZGVmIGN5Z3dpbj8KICBub3QgKHRhcmdl
# dF9vcy5kb3duY2FzZSA9fiAvY3lnLykubmlsPwplbmQKCmRlZiB0YXJnZXRf
# b3MKICBDb25maWc6OkNPTkZJR1sidGFyZ2V0X29zIl0gb3IgIiIKZW5kCgpk
# ZWYgdXNlcgogIEVOVlsiVVNFUiJdIG9yIEVOVlsiVVNFUk5BTUUiXQplbmQK
# CmRlZiBob21lCiAgKEVOVlsiSE9NRSJdIG9yIEVOVlsiVVNFUlBST0ZJTEUi
# XSBvciAoRmlsZS5kaXJlY3Rvcnk/KCJoOi8iKSA/ICJoOiIgOiAiYzoiKSku
# Z3N1YigvXFwvLCAiLyIpCmVuZAoKZGVmIHRlbXAKICAoRU5WWyJUTVBESVIi
# XSBvciBFTlZbIlRNUCJdIG9yIEVOVlsiVEVNUCJdIG9yICIvdG1wIikuZ3N1
# YigvXFwvLCAiLyIpCmVuZAoKZGVmIHN0ZHRtcAogICRzdGRlcnIgPSAkc3Rk
# b3V0ID0gRmlsZS5uZXcoIiN7dGVtcH0vcnVieS4je1Byb2Nlc3MucGlkfS5s
# b2ciLCAiYSIpCmVuZApzdGR0bXAJaWYgZGVmaW5lZD8oUlVCWVNDUklQVDJF
# WEUpIGFuZCAoUlVCWVNDUklQVDJFWEUgPX4gL3J1Ynl3L2kpCgokbm9ibQk9
# IGZhbHNlCgpkZWYgbm9ibQogICRub2JtCT0gdHJ1ZQplbmQKCmRlZiBibShs
# YWJlbD0iIikKICBpZiAkbm9ibQogICAgaWYgYmxvY2tfZ2l2ZW4/CiAgICAg
# IHJldHVybiB5aWVsZAogICAgZWxzZQogICAgICByZXR1cm4gbmlsCiAgICBl
# bmQKICBlbmQKCiAgbGFiZWwJPSBsYWJlbC5pbnNwZWN0CSN1bmxlc3MgbGFi
# ZWwua2luZF9vZj8oU3RyaW5nKQogIHJlcwk9IG5pbAoKICAkYm1fbXV0ZXgJ
# PSAoJGJtX211dGV4IG9yIE11dGV4Lm5ldykKCiAgJGJtX211dGV4LnN5bmNo
# cm9uaXplIGRvCiAgICBpZiAkYm0ubmlsPwogICAgICByZXF1aXJlICJldi9i
# bSIKCiAgICAgICRibQkJPSB7fQoKICAgICAgYXRfZXhpdCBkbwogICAgICAg
# IGwJPSAkYm0ua2V5cy5jb2xsZWN0e3xzfCBzLmxlbmd0aH0ubWF4CgkjZm9y
# bWF0MQk9ICIlMTBzICUxMHMgJTEwcyAlMTBzICUxMHMgJTEwcyAgICVzIgoJ
# I2Zvcm1hdDIJPSAiJTEwLjZmICUxMC42ZiAlMTAuNmYgJTEwLjZmICUxMC42
# ZiAlMTBkICAgJXMiCgkjJHN0ZGVyci5wdXRzIGZvcm1hdDEgJSBbIlVTRVJD
# UFUiLCAiU1lTQ1BVIiwgIkNVU0VSQ1BVIiwgIkNTWVNDUFUiLCAiRUxBUFNF
# RCIsICJDT1VOVCIsICJMQUJFTCJdCgkjJGJtLnNvcnR7fGEsIGJ8IFtiWzFd
# LCBiWzBdXSA8PT4gW2FbMV0sIGFbMF1dfS5lYWNoIGRvIHxrLCB2fAoJICAj
# JHN0ZGVyci5wdXRzIGZvcm1hdDIgJSAodiArIFtrXSkKCSNlbmQKCglmb3Jt
# YXQxCT0gIiUxMHMgJTEwcyAlMTBzICAgJXMiCglmb3JtYXQyCT0gIiUxMC42
# ZiAlMTAuNmYgJTEwZCAgICVzIgogICAgICAgICRibS5lYWNoIGRvIHxrLCB2
# fAogICAgICAgICAgJGJtW2tdCT0gW3ZbMF0rdlsxXSwgdls0XSwgdls1XV0K
# ICAgICAgICBlbmQKCSRzdGRlcnIucHV0cyBmb3JtYXQxICUgWyJDUFUiLCAi
# RUxBUFNFRCIsICJDT1VOVCIsICJMQUJFTCJdCgkkYm0uc29ydHt8YSwgYnwg
# W2JbMV0sIGJbMF1dIDw9PiBbYVsxXSwgYVswXV19LmVhY2ggZG8gfGssIHZ8
# CgkgICRzdGRlcnIucHV0cyBmb3JtYXQyICUgKHYgKyBba10pCgllbmQKICAg
# ICAgZW5kCiAgICBlbmQKCiAgICAkYm1bbGFiZWxdID0gWzAuMF0qNSArIFsw
# XQl1bmxlc3MgJGJtLmluY2x1ZGU/KGxhYmVsKQogICAgJGJtW2xhYmVsXVs1
# XSArPSAxCiAgZW5kCgogIGlmIGJsb2NrX2dpdmVuPwogICAgYm0JPSBCZW5j
# aG1hcmsubWVhc3VyZXtyZXMgPSB5aWVsZH0KICAgIGJtYQk9IGJtLnRvX2EJ
# IyBbZHVtbXkgbGFiZWwsIHVzZXIgQ1BVIHRpbWUsIHN5c3RlbSBDUFUgdGlt
# ZSwgY2hpbGRyZW5zIHVzZXIgQ1BVIHRpbWUsIGNoaWxkcmVucyBzeXN0ZW0g
# Q1BVIHRpbWUsIGVsYXBzZWQgcmVhbCB0aW1lXQoKICAgICRibV9sYXN0CT0g
# Ym1hCgogICAgJGJtX211dGV4LnN5bmNocm9uaXplIGRvCiAgICAgIGUJPSAk
# Ym1bbGFiZWxdCiAgICAgIDAudXB0byg0KSBkbyB8bnwKICAgICAgICBlW25d
# ICs9IGJtYVtuKzFdCiAgICAgIGVuZAogICAgZW5kCiAgZW5kCgogIHJlcwpl
# bmQKCmRlZiB0cmFjZQogIHJlcwk9bmlsCgogIHNldF90cmFjZV9mdW5jIGxh
# bWJkYSB7IHxldmVudCwgZmlsZSwgbGluZSwgaWQsIGJpbmRpbmcsIGNsYXNz
# bmFtZXwKICAgICRzdGRlcnIucHJpbnRmICIlOHMgJXM6JS0yZCAlMTBzICU4
# c1xuIiwgZXZlbnQsIGZpbGUsIGxpbmUsIGlkLCBjbGFzc25hbWUKICB9Cgog
# IGlmIGJsb2NrX2dpdmVuPwogICAgcmVzCT0geWllbGQKCiAgICBub3RyYWNl
# CiAgZW5kCgogIHJlcwplbmQKCmRlZiBub3RyYWNlCiAgc2V0X3RyYWNlX2Z1
# bmMgbmlsCmVuZAoKZGVmIGxhbWJkYV9jYWNoZWQoJmJsb2NrKQogIGhhc2gJ
# PSB7fQogIGxhbWJkYSBkbyB8KmFyZ3N8CiAgICByZXMJPSBoYXNoW2FyZ3Nd
# CiAgICBpZiByZXMubmlsPwogICAgICByZXMJCT0gYmxvY2suY2FsbCgqYXJn
# cykKICAgICAgaGFzaFthcmdzXQk9IHJlcwogICAgZW5kCiAgICByZXMKICBl
# bmQKZW5kCgpkZWYgYXNrKG9wdGlvbnMsIHRleHQ9ZmFsc2UpCiAgaQk9IDAK
# ICAkc3RkZXJyLnB1dHMgIiIKICBvcHRpb25zLmVhY2ggZG8gfHN8CiAgICAk
# c3RkZXJyLnB1dHMgIiAlZCAlcyIgJSBbaSs9MSwgc10KICBlbmQKICAkc3Rk
# ZXJyLnB1dHMgIiIKICAkc3RkZXJyLnByaW50ICI/ICIKICByZXMJPSAkc3Rk
# aW4uZ2V0cwogIHVubGVzcyByZXMubmlsPwogICAgcmVzCT0gcmVzLnN0cmlw
# CiAgICByZXMJPSBvcHRpb25zW3Jlcy50b19pLTFdCWlmIHRleHQgYW5kIG5v
# dCByZXMuZW1wdHk/CiAgZW5kCiAgcmVzCmVuZAoAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAABydWJ5d2ViZGlhbG9ncy9saWIvcndkLmxpYi5yYgAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAwMDE3NTAAMDAwMDAy
# MDI1MTYAMTAyNTAzMjA2MjEAMDE2NDQyACAwAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAA
# ZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlrAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgImV2L3J1YnkiCnJlcXVp
# cmUgImV2L3htbCIKcmVxdWlyZSAiZXYvbmV0IgpyZXF1aXJlICJldi9icm93
# c2VyIgpyZXF1aXJlICJldi90aHJlYWQiCnJlcXVpcmUgIm1kNSIKcmVxdWly
# ZSAicmJjb25maWciCgpiZWdpbgogIHJlcXVpcmUgIndpbjMyb2xlIgogIHJl
# cXVpcmUgIndpbjMyL3JlZ2lzdHJ5IgpyZXNjdWUgTG9hZEVycm9yCiAgJCIu
# cHVzaCAid2luMzJvbGUuc28iCiAgJCIucHVzaCAid2luMzIvcmVnaXN0cnku
# cmIiCmVuZAoKJHJ3ZF9leGl0CT0gQVJHVi5pbmNsdWRlPygiLS1yd2QtZXhp
# dCIpCSMgSGFjayA/Pz8KJHJ3ZF9leGl0CT0gdHJ1ZQlpZiBkZWZpbmVkPyhS
# RVFVSVJFMkxJQikKJHJ3ZF9kZWJ1Zwk9ICgkcndkX2RlYnVnIG9yICRERUJV
# RyBvciBmYWxzZSkKJHJ3ZF9ib3JkZXIJPSAoJHJ3ZF9ib3JkZXIgb3IgMCkK
# JHJ3ZF9kaXIJPSBEaXIucHdkCiRyd2RfZmlsZXMJPSBGaWxlLmV4cGFuZF9w
# YXRoKCJyd2RfZmlsZXMiLCBEaXIucHdkKQokcndkX2h0bWwJPSB7fQoKQVJH
# Vi5kZWxldGVfaWYgZG8gfGFyZ3wKICBhcmcgPX4gL14tLXJ3ZC0vCmVuZAoK
# UldERW1wdHlsaW5lCT0gIi4uLiIKCiNtb2R1bGUgUldECgpyY2ZpbGUJPSBu
# aWwKcwk9IEVOVlsiSE9NRSJdCQk7IHMgPSBGaWxlLmV4cGFuZF9wYXRoKCIu
# cndkcmMiLCBzKQl1bmxlc3Mgcy5uaWw/CTsgcmNmaWxlID0gcwlpZiAobm90
# IHMubmlsPyBhbmQgcmNmaWxlLm5pbD8gYW5kIEZpbGUuZmlsZT8ocykpCnMJ
# PSBFTlZbIlVTRVJQUk9GSUxFIl0JOyBzID0gRmlsZS5leHBhbmRfcGF0aCgi
# cndkLmNmZyIsIHMpCXVubGVzcyBzLm5pbD8JOyByY2ZpbGUgPSBzCWlmIChu
# b3Qgcy5uaWw/IGFuZCByY2ZpbGUubmlsPyBhbmQgRmlsZS5maWxlPyhzKSkK
# cwk9IEVOVlsid2luZGlyIl0JCTsgcyA9IEZpbGUuZXhwYW5kX3BhdGgoInJ3
# ZC5jZmciLCBzKQl1bmxlc3Mgcy5uaWw/CTsgcmNmaWxlID0gcwlpZiAobm90
# IHMubmlsPyBhbmQgcmNmaWxlLm5pbD8gYW5kIEZpbGUuZmlsZT8ocykpCgpB
# TAk9ICJhbGlnbj0nbGVmdCciCkFDCT0gImFsaWduPSdjZW50ZXInIgpBUgk9
# ICJhbGlnbj0ncmlnaHQnIgpWQQk9ICJ2YWxpZ249J21pZGRsZSciCgpGb3Jt
# YXQJPSAiXG48IS0tICUtMTBzICUtMTBzIC0tPlx0IgoKdW5sZXNzIHJjZmls
# ZS5uaWw/CiAgcHV0cyAiUmVhZGluZyAje3JjZmlsZX0gLi4uIgoKICBIYXNo
# LmZpbGUocmNmaWxlKS5lYWNoIGRvIHxrLCB2fAogICAgRU5WW2tdCT0gdgl1
# bmxlc3MgRU5WLmluY2x1ZGU/KGspCiAgZW5kCmVuZAoKRU5WWyJSV0RCUk9X
# U0VSIl0JPSAoRU5WWyJSV0RCUk9XU0VSIl0gb3IgZGVmYXVsdGJyb3dzZXIp
# IG9yIHB1dHMgIk5vIGJyb3dzZXIgZm91bmQuIgpFTlZbIlJXRFBPUlRTIl0J
# CT0gKEVOVlsiUldEUE9SVFMiXSBvciAiNzcwMS03NzA5IikKRU5WWyJSV0RU
# SEVNRSJdCQk9IChFTlZbIlJXRFRIRU1FIl0gb3IgIkRFRkFVTFQiKQoKI3Ry
# YXAoIklOVCIpCXtwdXRzICJUZXJtaW5hdGluZy4uLiIgOyBleGl0fQoKJFNB
# RkUJPSAyCgpjbGFzcyBJRQogIGRlZiBpbml0aWFsaXplKHVybCkKICAgIEBp
# ZSA9IFdJTjMyT0xFLm5ldygiSW50ZXJuZXRFeHBsb3Jlci5BcHBsaWNhdGlv
# biIpCiAgICBAZXYJPSBXSU4zMk9MRV9FVkVOVC5uZXcoQGllLCAiRFdlYkJy
# b3dzZXJFdmVudHMyIikKCiAgICBAaWUubmF2aWdhdGUodXJsKQoKICAgIEBp
# ZS5tZW51YmFyCQk9IGZhbHNlCiAgICBAaWUudG9vbGJhcgkJPSBmYWxzZQog
# ICAgQGllLmFkZHJlc3NiYXIJPSBmYWxzZQogICAgQGllLnN0YXR1c2Jhcgk9
# IGZhbHNlCgogICAgQGllLnZpc2libGUJCT0gdHJ1ZQoKICAgIGF0X2V4aXQg
# ZG8KICAgICAgQGllLnZpc2libGUJPSBmYWxzZQogICAgZW5kCgogICAgQGV2
# Lm9uX2V2ZW50KCJPblF1aXQiKSBkbwogICAgICBUaHJlYWQubWFpbi5leGl0
# CiAgICBlbmQKCiAgICBUaHJlYWQubmV3IGRvCiAgICAgIGxvb3AgZG8KICAg
# ICAgICBXSU4zMk9MRV9FVkVOVC5tZXNzYWdlX2xvb3AKICAgICAgZW5kCiAg
# ICBlbmQKICBlbmQKZW5kCgpjbGFzcyBBcnJheQogIGRlZiByd2Rfb3B0aW9u
# cyhlbXB0eWxpbmU9bmlsKQogICAgaWYgZW1wdHlsaW5lLm5pbD8KICAgICAg
# YQk9IHNlbGYKICAgIGVsc2UKICAgICAgYQk9IFtlbXB0eWxpbmVdLmNvbmNh
# dChzZWxmKQogICAgZW5kCgogICAgYS5udW1zb3J0LmNvbGxlY3R7fHN8ICI8
# b3B0aW9uPiN7cy50b19zLnRvX2h0bWx9PC9vcHRpb24+IiB9LmpvaW4oIlxu
# IikKICBlbmQKCiAgZGVmIHJ3ZF9tZXRob2QobWV0aG9kKQogICAgcmVzCT0g
# IiIKCiAgICBzZWxmLmVhY2ggZG8gfHN8CiAgICAgIHMJCT0gcy5qb2luKCIv
# IikJaWYgcy5raW5kX29mPyhBcnJheSkKICAgICAgczIJPSBzLmR1cAogICAg
# ICBzMlswLi4wXQk9IHMyWzAuLjBdLnVwY2FzZQogICAgICByZXMJPSByZXMg
# KyAiPHAgYWxpZ249J2xlZnQnPjxhIGFjdGlvbj0nI3ttZXRob2R9LyN7cy50
# b19odG1sfSc+I3tzMi50b19odG1sfTwvYT48L3A+IgogICAgZW5kCgogICAg
# cmV0dXJuIHJlcwogIGVuZAoKICBkZWYgcndkX3JvdyhrZXk9bmlsLCB2YWx1
# ZT1uaWwsIGJvbGQ9ZmFsc2UpCiAgICByZXMJPSAiIgoKICAgIHJlcwk9IHJl
# cyArICI8cm93IHZhbGlnbj0ndG9wJz4iCiAgICByZXMJPSByZXMgKyAiPHJh
# ZGlvIG5hbWU9JyN7a2V5LnRvX2h0bWx9JyB2YWx1ZT0nI3t2YWx1ZS50b19o
# dG1sfScvPiIJdW5sZXNzIGtleS5uaWw/CiAgICByZXMJPSByZXMgKyBzZWxm
# LmNvbGxlY3R7fHN8ICI8cCBhbGlnbj0nI3socy5raW5kX29mPyhOdW1lcmlj
# KSBvciBzID1+IC9eXGQrXC5cZCskLykgPyAicmlnaHQiIDogImxlZnQifSc+
# I3siPGI+IiBpZiBib2xkfSN7cy50b19zLnRvX2h0bWx9I3siPC9iPiIgaWYg
# Ym9sZH08L3A+In0uam9pbigiIikKICAgIHJlcwk9IHJlcyArICI8L3Jvdz4i
# CgogICAgcmV0dXJuIHJlcwogIGVuZAoKICBkZWYgcndkX3RhYmxlKGhlYWRl
# cnM9bmlsLCBoaWdobGlnaHRyb3dzPVtdKQogICAgcmVzCT0gIiIKCiAgICBo
# aWdobGlnaHRyb3dzCT0gW2hpZ2hsaWdodHJvd3NdLmZsYXR0ZW4KCiAgICBu
# CT0gLTEKCiAgICByZXMJPSByZXMgKyAiPHRhYmxlPiIKICAgIHJlcwk9IHJl
# cyArIGhlYWRlcnMucndkX3JvdyhuaWwsIG5pbCwgdHJ1ZSkJdW5sZXNzIGhl
# YWRlcnMubmlsPwogICAgcmVzCT0gcmVzICsgc2VsZi5jb2xsZWN0e3xhfCBh
# LnJ3ZF9yb3cobmlsLCBuaWwsIGhpZ2hsaWdodHJvd3MuaW5jbHVkZT8obis9
# MSkpfS5qb2luKCIiKQogICAgcmVzCT0gcmVzICsgIjwvdGFibGU+IgoKICAg
# IHJldHVybiByZXMKICBlbmQKCiAgZGVmIHJ3ZF9oZWFkZXJzKGVtcHR5Zmll
# bGQ9ZmFsc2UpCiAgICByZXMJPSAiIgoKICAgIHJlcwk9IHJlcyArICI8cm93
# PiIKICAgIHJlcwk9IHJlcyArICI8cC8+IglpZiBlbXB0eWZpZWxkCiAgICBy
# ZXMJPSByZXMgKyBzZWxmLmNvbGxlY3R7fHN8ICI8cCBhbGlnbj0nbGVmdCc+
# PGI+I3tzLnRvX2h0bWx9PC9iPjwvcD4iIH0uam9pbigiIikKICAgIHJlcwk9
# IHJlcyArICI8L3Jvdz4iCgogICAgcmV0dXJuIHJlcwogIGVuZAoKICBkZWYg
# cndkX2Zvcm0ocHJlZml4LCB2YWx1ZXM9W10sIHR3b3BhcnRzPTAsIG9wdGlv
# bnM9e30pCiAgICByZXMJPSBbXQoKICAgIHJlcyA8PCAiPHRhYmxlPiIKICAg
# IHNlbGYuZWFjaF9pbmRleCBkbyB8bnwKICAgICAgbmFtZQk9ICIje3ByZWZp
# eC50b19odG1sfSN7c2VsZltuXS5kb3duY2FzZS50b19odG1sfSIKCiAgICAg
# IHJlcyA8PCAiPHJvdz4iCiAgICAgIHJlcyA8PCAiPHAgYWxpZ249J3JpZ2h0
# Jz4iCiAgICAgIHJlcyA8PCAiI3tzZWxmW25dLnRvX2h0bWx9OiIKICAgICAg
# cmVzIDw8ICI8L3A+IgoKICAgICAgaWYgb3B0aW9ucy5rZXlzLmluY2x1ZGU/
# KHNlbGZbbl0pCiAgICAgICAgcmVzIDw8ICI8c2VsZWN0IG5hbWU9JyN7bmFt
# ZX0nPiIKICAgICAgICByZXMgPDwgb3B0aW9uc1tzZWxmW25dXS5yd2Rfb3B0
# aW9ucyhSV0RFbXB0eWxpbmUpCiAgICAgICAgcmVzIDw8ICI8L3NlbGVjdD4i
# CiAgICAgIGVsc2UKICAgICAgICBzCT0gIiIKCiAgICAgICAgcyA8PCAiPHRl
# eHQgbmFtZT0nI3tuYW1lfSciCiAgICAgICAgcyA8PCAiIHZhbHVlPScje3Zh
# bHVlc1tuXS50b19zLnRvX2h0bWx9JyIJaWYgbiA8IHZhbHVlcy5sZW5ndGgK
# ICAgICAgICBzIDw8ICIvPiIKCiAgICAgICAgcmVzIDw8IHMKICAgICAgZW5k
# CgogICAgICByZXMgPDwgIjwvcm93PiIKCiAgICAgIGlmIHR3b3BhcnRzID4g
# MCBhbmQgbiA9PSB0d29wYXJ0cy0xCiAgICAgICAgcmVzIDw8ICI8cm93Pjxl
# bXB0eS8+PC9yb3c+IgogICAgICBlbmQKICAgIGVuZAogICAgcmVzIDw8ICI8
# L3RhYmxlPiIKCiAgICByZXR1cm4gcmVzLmpvaW4oIlxuIikKICBlbmQKZW5k
# CgpjbGFzcyBIYXNoCiAgZGVmIHJ3ZF90YWJsZShmaWVsZD1uaWwsIGpvaW53
# aXRoPW5pbCwgaGVhZGVycz1uaWwpCiAgICByZXMJPSBbXQoKICAgIHJlcyA8
# PCAiPHRhYmxlPiIKICAgIHJlcyA8PCBoZWFkZXJzLnJ3ZF9oZWFkZXJzKChu
# b3QgZmllbGQubmlsPykpCWlmIG5vdCBoZWFkZXJzLm5pbD8KICAgIHNlbGYu
# a2V5cy5udW1zb3J0LmVhY2ggZG8gfGtleXwKICAgICAga2V5Mgk9IGtleQog
# ICAgICB2YWx1ZTIJPSBzZWxmW2tleV0KCiAgICAgIGtleTIJPSBrZXkyLmpv
# aW4oam9pbndpdGgpCWlmIGtleTIua2luZF9vZj8oQXJyYXkpCiAgICAgIHZh
# bHVlMgk9IFt2YWx1ZTJdCQlpZiB2YWx1ZTIua2luZF9vZj8oU3RyaW5nKQoK
# ICAgICAgcmVzIDw8IHZhbHVlMi5yd2Rfcm93KGZpZWxkLCBrZXkyKQogICAg
# ZW5kCiAgICByZXMgPDwgIjwvdGFibGU+IgoKICAgIHJlcy5qb2luKCJcbiIp
# CiAgZW5kCmVuZAoKY2xhc3MgRVZUYWJsZQogIGRlZiByd2RfdGFibGUoZmll
# bGQ9bmlsLCBqb2lud2l0aD1Ac2VwKQogICAgc3VwZXIoZmllbGQsIGpvaW53
# aXRoLCBAaGVhZGVycykKICBlbmQKCiAgZGVmIHJ3ZF9mb3JtKHByZWZpeD0i
# Iiwga2V5PW5pbCwgdHdvcGFydHM9ZmFsc2UpCiAgICB2YWx1ZXMJPSBzZWxm
# W2tleV0JaWYgbm90IGtleS5uaWw/CiAgICB2YWx1ZXMJPSBbXQkJaWYgdmFs
# dWVzLm5pbD8KICAgIG9wdGlvbnMJPSB7fQoKICAgIGlmIEZpbGUuZmlsZT8o
# b2xkbG9jYXRpb24oImNvbnN0cmFpbnRzLnRzdiIpKQogICAgICB0YWJsZQk9
# IEZpbGUuYmFzZW5hbWUoQGZpbGUpLmdzdWIoL1wudHN2JC8sICIiKQoKICAg
# ICAgVFNWRmlsZS5uZXcob2xkbG9jYXRpb24oImNvbnN0cmFpbnRzLnRzdiIp
# KS5zdWJzZXQoWyJUYWJsZSIsICJDb25zdHJhaW50Il0sIFt0YWJsZSwgImtl
# eSJdLCBbIkNvbHVtbiIsICJWYWx1ZSJdKS52YWx1ZXMuZWFjaCBkbyB8Y29s
# dW1uLCB0YWJsZTJ8CiAgICAgICAgb3B0aW9uc1tjb2x1bW5dCT0gVFNWRmls
# ZS5uZXcob2xkbG9jYXRpb24oIiN7dGFibGUyfS50c3YiKSkua2V5cy5jb2xs
# ZWN0e3xhfCBhLmpvaW4oIlx0Iil9CiAgICAgIGVuZAogICAgZW5kCgogICAg
# QGhlYWRlcnMucndkX2Zvcm0ocHJlZml4LCB2YWx1ZXMsIHR3b3BhcnRzID8g
# QGtleSA6IDAsIG9wdGlvbnMpCiAgZW5kCgogIGRlZiByd2RfbWV0YWRhdGEK
# ICAgIHJlcwk9IFtdCgogICAgcmVzIDw8ICI8dGFibGU+IgogICAgcmVzIDw8
# ICI8cm93PiIKICAgIHJlcyA8PCAiICA8ZW1wdHkvPiIKICAgIHJlcyA8PCAi
# ICA8dGV4dCBuYW1lPSdoZWFkZXJfbmV3JyB2YWx1ZT0nJy8+IgogICAgcmVz
# IDw8ICI8L3Jvdz4iCiAgICBAaGVhZGVycy5lYWNoX2luZGV4IGRvIHxufAog
# ICAgICByZXMgPDwgIjxyb3c+IgogICAgICByZXMgPDwgIiAgPHRleHQgbmFt
# ZT0naGVhZGVyXyN7bn1fb2xkJyB2YWx1ZT0nI3tAaGVhZGVyc1tuXX0nLz4i
# CiAgICAgIHJlcyA8PCAiICA8dGV4dCBuYW1lPSdoZWFkZXJfI3tufV9uZXcn
# IHZhbHVlPScnLz4iCiAgICAgIHJlcyA8PCAiPC9yb3c+IgogICAgZW5kCiAg
# ICByZXMgPDwgIjwvdGFibGU+IgoKICAgIHJldHVybiByZXMuam9pbigiXG4i
# KQogIGVuZAplbmQKCmNsYXNzIE9wZW5UYWcKICBkZWYgcHJlY2hpbGRyZW4o
# cmVzLCBiZWZvcmUsIGFmdGVyLCB2YXJzaHRtbCwgdmFyc3N0cmluZywgc3dp
# dGNoZXMsIGhlbHAsIG9uZW9ybW9yZWZpZWxkcywgZmlyc3RhY3Rpb24sIHRh
# YnMsIHRhYiwgcGRhKQogICAgYmVmCT0gYmVmb3JlWy0xXQogICAgcmVzIDw8
# IEZvcm1hdCAlIFsiQmVmb3JlIiwgQHN1YnR5cGVdCWlmICgkcndkX2RlYnVn
# IGFuZCBub3QgYmVmLm5pbD8pCiAgICByZXMgPDwgYmVmCWlmIG5vdCBiZWYu
# bmlsPwoKICAgIHJlcyA8PCBGb3JtYXQgJSBbIlByZSIsIEBzdWJ0eXBlXQlp
# ZiAkcndkX2RlYnVnCgogICAgYWxpZ24JPSBBQwogICAgYWxpZ24JPSAiYWxp
# Z249JyN7QGFyZ3NbImFsaWduIl19JyIJaWYgQGFyZ3MuaW5jbHVkZT8oImFs
# aWduIikKCiAgICB2YWxpZ24JPSBWQQogICAgdmFsaWduCT0gInZhbGlnbj0n
# I3tAYXJnc1sidmFsaWduIl19JyIJaWYgQGFyZ3MuaW5jbHVkZT8oInZhbGln
# biIpCgogICAgdmFsdWUxCT0gIiIKICAgIHZhbHVlMQk9IHZhcnNodG1sW0Bh
# cmdzWyJuYW1lIl1dCWlmIHZhcnNodG1sLmluY2x1ZGU/KEBhcmdzWyJuYW1l
# Il0pCiAgICB2YWx1ZTEJPSBAYXJnc1sidmFsdWUiXQkJaWYgQGFyZ3MuaW5j
# bHVkZT8oInZhbHVlIikKCiAgICB2YWx1ZTIJPSAiIgogICAgdmFsdWUyCT0g
# dmFyc3N0cmluZ1tAYXJnc1sibmFtZSJdXQlpZiB2YXJzc3RyaW5nLmluY2x1
# ZGU/KEBhcmdzWyJuYW1lIl0pCiAgICB2YWx1ZTIJPSBAYXJnc1sidmFsdWUi
# XQkJaWYgQGFyZ3MuaW5jbHVkZT8oInZhbHVlIikKCiAgICBjZWxsc3BhY2lu
# Zwk9IDMKICAgIGNlbGxzcGFjaW5nCT0gMAlpZiBwZGEKCiAgICBjYXNlIEBz
# dWJ0eXBlCiAgICB3aGVuICJhcHBsaWNhdGlvbiIKICAgIHdoZW4gIndpbmRv
# dyIsICJoZWxwd2luZG93IgogICAgICBhcmdzCT0gQGFyZ3MuZGVlcF9kdXAK
# CiAgICAgIGFyZ3NbIm5vaGVscGJ1dHRvbiJdCT0gKG5vdCBoZWxwKQoKICAg
# ICAgdGVtcGxhdGUJPSAkcndkX2h0bWxfMQogICAgICB0ZW1wbGF0ZQk9ICRy
# d2RfaHRtbF9QREFfMQlpZiBwZGEKCiAgICAgIHJlcyA8PCAodGVtcGxhdGUo
# dGVtcGxhdGUsIGFyZ3MpKQogICAgd2hlbiAicCIJCXRoZW4gcmVzIDw8ICI8
# cCAje2FsaWdufT4iCiAgICB3aGVuICJwcmUiCQl0aGVuIHJlcyA8PCAiPHBy
# ZSAje2FsaWdufT4iCiAgICB3aGVuICJiaWciCQl0aGVuIHJlcyA8PCAiPHAg
# I3thbGlnbn0+PGJpZz4iCiAgICB3aGVuICJzbWFsbCIJdGhlbiByZXMgPDwg
# IjxwICN7YWxpZ259PjxzbWFsbD4iCiAgICB3aGVuICJsaXN0IgkJdGhlbiBy
# ZXMgPDwgIjx1bCAje2FsaWdufT4iCiAgICB3aGVuICJpdGVtIgkJdGhlbiBy
# ZXMgPDwgIjxsaSAje2FsaWdufT4iCiAgICB3aGVuICJlbXB0eSIJdGhlbiBy
# ZXMgPDwgIjxwPjxicj4iCiAgICB3aGVuICJpbWFnZSIKICAgICAgd2lkdGgJ
# PSAid2lkdGg9JyN7QGFyZ3NbIndpZHRoIl19IglpZiBAYXJncy5pbmNsdWRl
# Pygid2lkdGgiKQogICAgICBoZWlnaHQJPSAiaGVpZ2h0PScje0BhcmdzWyJo
# ZWlnaHQiXX0nIglpZiBAYXJncy5pbmNsdWRlPygiaGVpZ2h0IikKCiAgICAg
# IHJlcyA8PCAiPGltZyBzcmM9JyN7QGFyZ3NbInNyYyJdfScgYWx0PScje0Bh
# cmdzWyJhbHQiXX0nICN7d2lkdGh9ICN7aGVpZ2h0fT4iCiAgICB3aGVuICJw
# cm9ncmVzc2JhciIKICAgICAgd2lkdGgJPSAyMDAKCiAgICAgIHJlcyA8PCAi
# PHRhYmxlPiIKICAgICAgcmVzIDw8ICIgIDx0cj4iCiAgICAgIHJlcyA8PCAi
# ICAgIDx0ZCBjb2xzcGFuPScyJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicg
# aGVpZ2h0PScxJyB3aWR0aD0nI3t3aWR0aCs1fSc+PC90ZD4iCiAgICAgIHJl
# cyA8PCAiICA8L3RyPiIKICAgICAgcmVzIDw8ICIgIDx0cj4iCiAgICAgIHJl
# cyA8PCAiICAgIDx0ZCBiZ2NvbG9yPScjREREREREJz48aW1nIHNyYz0ncndk
# X3BpeGVsLmdpZicgaGVpZ2h0PScxMCcgd2lkdGg9JyN7KHdpZHRoKkBhcmdz
# WyJ2YWx1ZSJdLnRvX2YpLnRvX2l9Jz48L3RkPiIKICAgICAgcmVzIDw8ICIg
# ICAgPHRkIGJnY29sb3I9JyNFRUVFRUUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwu
# Z2lmJyBoZWlnaHQ9JzEwJyB3aWR0aD0nI3sod2lkdGgqKDEuMC1AYXJnc1si
# dmFsdWUiXS50b19mKSkudG9faX0nPjwvdGQ+IgogICAgICByZXMgPDwgIiAg
# PC90cj4iCiAgICAgIHJlcyA8PCAiPC90YWJsZT4iCiAgICB3aGVuICJiciIJ
# CXRoZW4gcmVzIDw8ICI8YnI+IgogICAgd2hlbiAiaHIiCQl0aGVuIHJlcyA8
# PCAiPGhyPiIKICAgIHdoZW4gImIiCQl0aGVuIHJlcyA8PCAiPGI+IgogICAg
# d2hlbiAiaSIJCXRoZW4gcmVzIDw8ICI8aT4iCiAgICB3aGVuICJhIgogICAg
# ICBpZiBAYXJncy5pbmNsdWRlPygiaHJlZiIpCiAgICAgICAgcmVzIDw8ICI8
# YSBocmVmPScje0BhcmdzWyJocmVmIl19JyB0YXJnZXQ9JyN7QGFyZ3NbInRh
# cmdldCJdIG9yICJfYmxhbmsifSc+IgogICAgICBlbHNlCiAgICAgICAgcmVz
# IDw8ICI8YSBocmVmPSdqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnJ3
# ZF9hY3Rpb24udmFsdWU9XCIje0BhcmdzWyJhY3Rpb24iXX1cIjtkb2N1bWVu
# dC5ib2R5Zm9ybS5zdWJtaXQoKTsnPiIKICAgICAgZW5kCiAgICB3aGVuICJ2
# ZXJ0aWNhbCIJdGhlbiByZXMgPDwgIjx0YWJsZSAje0FDfSBib3JkZXI9JyN7
# JHJ3ZF9ib3JkZXJ9JyBjZWxsc3BhY2luZz0nI3tjZWxsc3BhY2luZ30nIGNl
# bGxwYWRkaW5nPScwJz4iCiAgICB3aGVuICJob3Jpem9udGFsIgl0aGVuIHJl
# cyA8PCAiPHRhYmxlICN7QUN9IGJvcmRlcj0nI3skcndkX2JvcmRlcn0nIGNl
# bGxzcGFjaW5nPScje2NlbGxzcGFjaW5nfScgY2VsbHBhZGRpbmc9JzAnPjx0
# ciAje2FsaWdufSAje3ZhbGlnbn0+IgogICAgd2hlbiAidGFibGUiCXRoZW4g
# cmVzIDw8ICI8dGFibGUgI3tBQ30gYm9yZGVyPScjeyRyd2RfYm9yZGVyfScg
# Y2VsbHNwYWNpbmc9JyN7Y2VsbHNwYWNpbmd9JyBjZWxscGFkZGluZz0nMCc+
# IgogICAgd2hlbiAicm93IgkJdGhlbiByZXMgPDwgIjx0ciAje2FsaWdufSAj
# e3ZhbGlnbn0+IgogICAgd2hlbiAiaGlkZGVuIgl0aGVuIHJlcyA8PCAiPHAg
# I3thbGlnbn0+PGlucHV0IG5hbWU9JyN7QGFyZ3NbIm5hbWUiXX0nIHZhbHVl
# PScje3ZhbHVlMX0nIHR5cGU9J2hpZGRlbic+IgogICAgd2hlbiAidGV4dCIK
# ICAgICAgbWF4bGVuZ3RoCT0gIiIKICAgICAgbWF4bGVuZ3RoCT0gIm1heGxl
# bmd0aD0nJXMnIiAlIEBhcmdzWyJtYXhsZW5ndGgiXQlpZiBAYXJncy5pbmNs
# dWRlPygibWF4bGVuZ3RoIikKICAgICAgc2l6ZQk9ICIiCiAgICAgIHNpemUJ
# PSAic2l6ZT0nJXMnIiAlIEBhcmdzWyJzaXplIl0JCWlmIEBhcmdzLmluY2x1
# ZGU/KCJzaXplIikKICAgICAgc2l6ZQk9ICJzaXplPSclcyciICUgMTAJCQlp
# ZiBwZGEKICAgICAgcmVzIDw8ICI8cCAje2FsaWdufT48aW5wdXQgbmFtZT0n
# I3tAYXJnc1sibmFtZSJdfScgdmFsdWU9JyN7dmFsdWUxfScgdHlwZT0ndGV4
# dCcgI3ttYXhsZW5ndGh9ICN7c2l6ZX0+IgogICAgICBvbmVvcm1vcmVmaWVs
# ZHMJPDwgInRydWUiCiAgICB3aGVuICJ0ZXh0YXJlYSIKICAgICAgcmVzIDw8
# ICI8cCAje2FsaWdufT48dGV4dGFyZWEgbmFtZT0nI3tAYXJnc1sibmFtZSJd
# fScgcm93cz0nMjUnIGNvbHM9JzgwJz4je3ZhbHVlMi5jcmxmfTwvdGV4dGFy
# ZWE+IgogICAgICBvbmVvcm1vcmVmaWVsZHMJPDwgInRydWUiCiAgICB3aGVu
# ICJwYXNzd29yZCIKICAgICAgbWF4bGVuZ3RoCT0gIiIKICAgICAgbWF4bGVu
# Z3RoCT0gIm1heGxlbmd0aD0nJXMnIiAlIEBhcmdzWyJtYXhsZW5ndGgiXQlp
# ZiBAYXJncy5pbmNsdWRlPygibWF4bGVuZ3RoIikKICAgICAgc2l6ZQk9ICIi
# CiAgICAgIHNpemUJPSAic2l6ZT0nJXMnIiAlIDEwCQkJaWYgcGRhCiAgICAg
# IHJlcyA8PCAiPHAgI3thbGlnbn0+PGlucHV0IG5hbWU9JyN7QGFyZ3NbIm5h
# bWUiXX0nIHZhbHVlPScje3ZhbHVlMX0nIHR5cGU9J3Bhc3N3b3JkJyAje21h
# eGxlbmd0aH0gI3tzaXplfT4iCiAgICAgIG9uZW9ybW9yZWZpZWxkcwk8PCAi
# dHJ1ZSIKICAgIHdoZW4gImNoZWNrYm94IgogICAgICBpZiB2YXJzaHRtbFtA
# YXJnc1sibmFtZSJdXSA9PSAib24iCiAgICAgICAgc3dpdGNoZXNbQGFyZ3Nb
# Im5hbWUiXV0JPSB0cnVlCiAgICAgICAgcmVzIDw8ICI8cCAje2FsaWdufT48
# aW5wdXQgbmFtZT0nI3tAYXJnc1sibmFtZSJdfScgY2hlY2tlZD0nb24nIHR5
# cGU9J2NoZWNrYm94Jz4iCiAgICAgIGVsc2UKICAgICAgICBzd2l0Y2hlc1tA
# YXJnc1sibmFtZSJdXQk9IGZhbHNlCiAgICAgICAgcmVzIDw8ICI8cCAje2Fs
# aWdufT48aW5wdXQgbmFtZT0nI3tAYXJnc1sibmFtZSJdfScgdHlwZT0nY2hl
# Y2tib3gnPiIKICAgICAgZW5kCiAgICAgIG9uZW9ybW9yZWZpZWxkcwk8PCAi
# dHJ1ZSIKICAgIHdoZW4gInJhZGlvIgogICAgICBpZiB2YXJzaHRtbFtAYXJn
# c1sibmFtZSJdXSA9PSB2YWx1ZTEJIyA/Pz8gMSBvciAyPwogICAgICAgIHJl
# cyA8PCAiPHAgI3thbGlnbn0+PGlucHV0IG5hbWU9JyN7QGFyZ3NbIm5hbWUi
# XX0nIGNoZWNrZWQ9J29uJyB2YWx1ZT0nI3t2YWx1ZTF9JyB0eXBlPSdyYWRp
# byc+IgogICAgICBlbHNlCiAgICAgICAgcmVzIDw8ICI8cCAje2FsaWdufT48
# aW5wdXQgbmFtZT0nI3tAYXJnc1sibmFtZSJdfScgdmFsdWU9JyN7dmFsdWUx
# fScgdHlwZT0ncmFkaW8nPiIKICAgICAgZW5kCiAgICAgIG9uZW9ybW9yZWZp
# ZWxkcwk8PCAidHJ1ZSIKICAgIHdoZW4gInNlbGVjdCIKICAgICByZXMgPDwg
# IjxzZWxlY3QgI3thbGlnbn0gbmFtZT0nI3tAYXJnc1sibmFtZSJdfScgd2lk
# dGg9JyN7QGFyZ3NbIndpZHRoIl19IHNpemU9JyN7QGFyZ3NbInNpemUiXX0n
# PiIJIyA/Pz8gTWlzc2NoaWVuIG5vZyBpZXRzIG1ldCAnbXVsdGlwbGUnPwog
# ICAgICBuYW1lCT0gQGFyZ3NbIm5hbWUiXQogICAgICAkc2VsZWN0CT0gdmFy
# c2h0bWxbbmFtZV0KICAgICAgb25lb3Jtb3JlZmllbGRzCTw8ICJ0cnVlIgog
# ICAgd2hlbiAib3B0aW9uIgogICAgICBpZiAkc2VsZWN0ID09IEBjaGlsZHJl
# blswXS50ZXh0CiAgICAgICAgcmVzIDw8ICI8b3B0aW9uIHNlbGVjdGVkPSd0
# cnVlJz4iCiAgICAgIGVsc2UKICAgICAgICByZXMgPDwgIjxvcHRpb24+Igog
# ICAgICBlbmQKICAgIHdoZW4gImJ1dHRvbiIKICAgICAgcmVzIDw8ICI8aW5w
# dXQgdHlwZT0nc3VibWl0JyB2YWx1ZT0nI3tAYXJnc1siY2FwdGlvbiJdfScg
# b25jbGljaz0nZG9jdW1lbnQuYm9keWZvcm0ucndkX2FjdGlvbi52YWx1ZT1c
# IiN7QGFyZ3NbImFjdGlvbiJdfVwiOyc+IgogICAgICBmaXJzdGFjdGlvbgk8
# PCBAYXJnc1siYWN0aW9uIl0JaWYgKGZpcnN0YWN0aW9uLmVtcHR5PyBhbmQg
# QGFyZ3MuaW5jbHVkZT8oImFjdGlvbiIpKQogICAgICBvbmVvcm1vcmVmaWVs
# ZHMJPDwgInRydWUiCiAgICB3aGVuICJiYWNrIgogICAgICByZXMgPDwgIjxp
# bnB1dCB0eXBlPSdzdWJtaXQnIHZhbHVlPSdCYWNrJyBvbmNsaWNrPSdkb2N1
# bWVudC5ib2R5Zm9ybS5yd2RfYWN0aW9uLnZhbHVlPVwicndkX2JhY2tcIjsn
# PiIKICAgICAgZmlyc3RhY3Rpb24JPDwgInJ3ZF9iYWNrIglpZiBmaXJzdGFj
# dGlvbi5lbXB0eT8KICAgICAgb25lb3Jtb3JlZmllbGRzCTw8ICJ0cnVlIgog
# ICAgd2hlbiAiY2FuY2VsIgogICAgICByZXMgPDwgIjxpbnB1dCB0eXBlPSdz
# dWJtaXQnIHZhbHVlPSdDYW5jZWwnIG9uY2xpY2s9J2RvY3VtZW50LmJvZHlm
# b3JtLnJ3ZF9hY3Rpb24udmFsdWU9XCJyd2RfY2FuY2VsXCI7Jz4iCiAgICAg
# IGZpcnN0YWN0aW9uCTw8ICJyd2RfY2FuY2VsIglpZiBmaXJzdGFjdGlvbi5l
# bXB0eT8KICAgICAgb25lb3Jtb3JlZmllbGRzCTw8ICJ0cnVlIgogICAgd2hl
# biAiaGVscCIKICAgICAgcmVzIDw8ICI8aW5wdXQgdHlwZT0nc3VibWl0JyB2
# YWx1ZT0nSGVscCcgb25jbGljaz0nZG9jdW1lbnQuYm9keWZvcm0ucndkX2Fj
# dGlvbi52YWx1ZT1cInJ3ZF9oZWxwXCI7Jz4iCiAgICAgIGZpcnN0YWN0aW9u
# CTw8ICJyd2RfaGVscCIJaWYgZmlyc3RhY3Rpb24uZW1wdHk/CiAgICAgIG9u
# ZW9ybW9yZWZpZWxkcwk8PCAidHJ1ZSIKICAgIHdoZW4gInF1aXQiCiAgICAg
# IHJlcyA8PCAiPGlucHV0IHR5cGU9J3N1Ym1pdCcgdmFsdWU9J1F1aXQnIG9u
# Y2xpY2s9J2RvY3VtZW50LmJvZHlmb3JtLnJ3ZF9hY3Rpb24udmFsdWU9XCJy
# d2RfcXVpdFwiOyc+IgogICAgICBmaXJzdGFjdGlvbgk8PCAicndkX3F1aXQi
# CWlmIGZpcnN0YWN0aW9uLmVtcHR5PwogICAgICBvbmVvcm1vcmVmaWVsZHMJ
# PDwgInRydWUiCiAgICB3aGVuICJjbG9zZSIKICAgICAgcmVzIDw8ICI8aW5w
# dXQgdHlwZT0nc3VibWl0JyB2YWx1ZT0nQ2xvc2UnIG9uY2xpY2s9J3dpbmRv
# dy5jbG9zZSgpOyc+IgogICAgICBmaXJzdGFjdGlvbgk8PCAicndkX3F1aXQi
# CWlmIGZpcnN0YWN0aW9uLmVtcHR5PwogICAgICBvbmVvcm1vcmVmaWVsZHMJ
# PDwgInRydWUiCiAgICB3aGVuICJtYWluIgogICAgICByZXMgPDwgIjxpbnB1
# dCB0eXBlPSdzdWJtaXQnIHZhbHVlPSdNYWluJyBvbmNsaWNrPSdkb2N1bWVu
# dC5ib2R5Zm9ybS5yd2RfYWN0aW9uLnZhbHVlPVwicndkX21haW5cIjsnPiIK
# ICAgICAgZmlyc3RhY3Rpb24JPDwgInJ3ZF9tYWluIglpZiBmaXJzdGFjdGlv
# bi5lbXB0eT8KICAgICAgb25lb3Jtb3JlZmllbGRzCTw8ICJ0cnVlIgogICAg
# d2hlbiAicmVzZXQiCiAgICAgIHJlcyA8PCAiPGlucHV0IHR5cGU9J3Jlc2V0
# JyAgdmFsdWU9J1Jlc2V0Jz4iCiAgICAgIGZpcnN0YWN0aW9uCTw8ICJyd2Rf
# cXVpdCIJaWYgZmlyc3RhY3Rpb24uZW1wdHk/CSMgPz8/CiAgICAgIG9uZW9y
# bW9yZWZpZWxkcwk8PCAidHJ1ZSIKICAgIHdoZW4gImNsb3Nld2luZG93Igog
# ICAgICAjcmVzIDw8ICI8c2NyaXB0IHR5cGU9J3RleHQvamF2YXNjcmlwdCc+
# XG4iCSMgPz8/CiAgICAgICNyZXMgPDwgIjwhLS1cbiIKICAgICAgI3JlcyA8
# PCAiICB3aW5kb3cuY2xvc2UoKTtcbiIKICAgICAgI3JlcyA8PCAiLy8tLT5c
# biIKICAgICAgI3JlcyA8PCAiPC9zY3JpcHQ+IgogICAgd2hlbiAidGFicyIK
# ICAgICAgcmVzIDw8ICI8dGFibGUgI3tBQ30gYm9yZGVyPScjeyRyd2RfYm9y
# ZGVyfScgY2VsbHNwYWNpbmc9JzAnIGNlbGxwYWRkaW5nPScwJz4iCiAgICAg
# IHJlcyA8PCAiICA8dHIgI3tBTH0+IgogICAgICByZXMgPDwgIiAgICA8dGQg
# I3tBTH0gY2xhc3M9J3RhYnMnPiIKICAgICAgcmVzIDw8ICIgICAgICA8dGFi
# bGUgI3tBTH0gYm9yZGVyPScjeyRyd2RfYm9yZGVyfScgY2VsbHNwYWNpbmc9
# JzAnIGNlbGxwYWRkaW5nPScwJz4iCiAgICAgIHJlcyA8PCAiICAgICAgICA8
# dHIgI3tBTH0+IgogICAgICAjcmVzIDw8ICIgICAgICAgICAgPHRkIGNsYXNz
# PSdub3RhYic+Jm5ic3A7PC90ZD4iCiAgICAgIHRhYnMuZWFjaCBkbyB8b2Jq
# fAogICAgICAgIG5hbWUJPSBvYmouYXJnc1sibmFtZSJdCiAgICAgICAgY2Fw
# dGlvbgk9IG9iai5hcmdzWyJjYXB0aW9uIl0KCiAgICAgICAgcmVzIDw8ICI8
# dGQgI3tBTH0gY2xhc3M9J25vdGFiJz4mbmJzcDs8L3RkPiIJdW5sZXNzIG9i
# aiA9PSB0YWJzWzBdCgogICAgICAgIGlmIG5hbWUgPT0gdGFiCiAgICAgICAg
# ICByZXMgPDwgIjx0ZCAje0FDfSBjbGFzcz0nYWN0aXZldGFiJz48dHQ+Jm5i
# c3A7I3tjYXB0aW9ufSZuYnNwOzwvdHQ+PC90ZD4iCiAgICAgICAgZWxzZQog
# ICAgICAgICAgcmVzIDw8ICI8dGQgI3tBQ30gY2xhc3M9J3Bhc3NpdmV0YWIn
# PjxhIGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9keWZvcm0ucndkX2Fj
# dGlvbi52YWx1ZT1cInJ3ZF90YWJfI3tuYW1lfVwiO2RvY3VtZW50LmJvZHlm
# b3JtLnN1Ym1pdCgpOyc+PHR0PiZuYnNwOyN7Y2FwdGlvbn0mbmJzcDs8L3R0
# PjwvYT48L3RkPiIKICAgICAgICBlbmQKICAgICAgZW5kCiAgICAgIHJlcyA8
# PCAiICAgICAgICAgIDx0ZCBjbGFzcz0nbm90YWInIHdpZHRoPScxMDAlJz4m
# bmJzcDs8L3RkPiIKICAgICAgcmVzIDw8ICIgICAgICAgIDwvdHI+IgogICAg
# ICByZXMgPDwgIiAgICAgIDwvdGFibGU+IgogICAgICByZXMgPDwgIiAgICA8
# L3RkPiIKICAgICAgcmVzIDw8ICIgIDwvdHI+IgogICAgICByZXMgPDwgIiAg
# PHRyICN7YWxpZ259PiIKICAgICAgcmVzIDw8ICIgICAgPHRkICN7YWxpZ259
# IGNsYXNzPSd0YWJibGFkJz4iCiAgICB3aGVuICJ0YWIiCiAgICAgIHJlcyA8
# PCAiPHRhYmxlICN7QUN9IGJvcmRlcj0nI3skcndkX2JvcmRlcn0nIGNlbGxz
# cGFjaW5nPSczJyBjZWxscGFkZGluZz0nMCc+IgogICAgd2hlbiAicGFuZWwi
# CiAgICAgIGxldmVsCT0gKEBhcmdzWyJsZXZlbCJdIG9yICJub3JtYWwiKQog
# ICAgICByZXMgPDwgIjx0YWJsZSAje0FDfSBib3JkZXI9JyN7JHJ3ZF9ib3Jk
# ZXJ9JyBjZWxsc3BhY2luZz0nMCcgY2VsbHBhZGRpbmc9JzAnPiIKICAgICAg
# cmVzIDw8ICIgIDx0ciAje2FsaWdufT4iCiAgICAgIHJlcyA8PCAiICAgIDx0
# ZCAje2FsaWdufSBjbGFzcz0ncGFuZWwxJz4iCQlpZiBsZXZlbCA9PSAibm9y
# bWFsIgogICAgICByZXMgPDwgIiAgICA8dGQgI3thbGlnbn0gY2xhc3M9J3Bh
# bmVsMWhpZ2gnPiIJaWYgbGV2ZWwgPT0gImhpZ2giCiAgICAgIHJlcyA8PCAi
# ICAgIDx0ZCAje2FsaWdufSBjbGFzcz0ncGFuZWwxbG93Jz4iCWlmIGxldmVs
# ID09ICJsb3ciCiAgICAgIHJlcyA8PCAiICAgICAgPHRhYmxlICN7QUN9IGJv
# cmRlcj0nI3skcndkX2JvcmRlcn0nIGNlbGxzcGFjaW5nPScwJyBjZWxscGFk
# ZGluZz0nMCc+IgogICAgICByZXMgPDwgIiAgICAgICAgPHRyICN7YWxpZ259
# PiIKICAgICAgcmVzIDw8ICIgICAgICAgICAgPHRkICN7YWxpZ259IGNsYXNz
# PSdwYW5lbDInPiIJCWlmIGxldmVsID09ICJub3JtYWwiCiAgICAgIHJlcyA8
# PCAiICAgICAgICAgIDx0ZCAje2FsaWdufSBjbGFzcz0ncGFuZWwyaGlnaCc+
# IglpZiBsZXZlbCA9PSAiaGlnaCIKICAgICAgcmVzIDw8ICIgICAgICAgICAg
# PHRkICN7YWxpZ259IGNsYXNzPSdwYW5lbDJsb3cnPiIJaWYgbGV2ZWwgPT0g
# ImxvdyIKICAgICAgcmVzIDw8ICIgICAgICAgICAgICA8dGFibGUgI3tBQ30g
# Ym9yZGVyPScjeyRyd2RfYm9yZGVyfScgY2VsbHNwYWNpbmc9JzMnIGNlbGxw
# YWRkaW5nPScwJz4iCiAgICBlbHNlCiAgICAgIHB1dHMgIjwje0BzdWJ0eXBl
# fT4iCiAgICAgIHJlcyA8PCAiJmx0OyN7QHN1YnR5cGV9Jmd0OyIKICAgIGVu
# ZAoKICAgIGJlZgk9IG5pbAogICAgYWZ0CT0gbmlsCgogICAgY2FzZSBAc3Vi
# dHlwZQogICAgd2hlbiAidmVydGljYWwiLCAid2luZG93IiwgImhlbHB3aW5k
# b3ciLCAidGFiIiwgInBhbmVsIgogICAgICByZXMgPDwgRm9ybWF0ICUgWyJB
# ZnRQcmUiLCBAc3VidHlwZV0JaWYgJHJ3ZF9kZWJ1ZwogICAgICBpZiBAYXJn
# cy5pbmNsdWRlPygic3BhY2luZyIpCiAgICAgICAgcwk9ICI8dHI+PHRkPiZu
# YnNwOzwvdGQ+PC90cj4iICogKEBhcmdzWyJzcGFjaW5nIl0udG9faSkKICAg
# ICAgZWxzZQogICAgICAgIHMJPSAiIgogICAgICBlbmQKICAgICAgYmVmCT0g
# IiN7c308dHIgI3thbGlnbn0gI3t2YWxpZ259Pjx0ZCAje2FsaWdufT4iCiAg
# ICAgIGFmdAk9ICI8L3RkPjwvdHI+IgogICAgd2hlbiAiaG9yaXpvbnRhbCIs
# ICJyb3ciCiAgICAgIHJlcyA8PCBGb3JtYXQgJSBbIkFmdFByZSIsIEBzdWJ0
# eXBlXQlpZiAkcndkX2RlYnVnCiAgICAgIGJlZgk9ICI8dGQgI3thbGlnbn0+
# IgogICAgICBhZnQJPSAiPC90ZD4iCiAgICBlbmQKCiAgICBiZWZvcmUucHVz
# aChiZWYpCiAgICBhZnRlci5wdXNoKGFmdCkKICBlbmQKCiAgZGVmIHBvc3Rj
# aGlsZHJlbihyZXMsIGJlZm9yZSwgYWZ0ZXIsIHZhcnNodG1sLCB2YXJzc3Ry
# aW5nLCBzd2l0Y2hlcywgaGVscCwgb25lb3Jtb3JlZmllbGRzLCBmaXJzdGFj
# dGlvbiwgdGFicywgdGFiLCBwZGEpCiAgICBjYXNlIEBzdWJ0eXBlCiAgICB3
# aGVuICJ2ZXJ0aWNhbCIsICJ3aW5kb3ciLCAiaGVscHdpbmRvdyIsICJ0YWIi
# LCAicGFuZWwiCiAgICAgIHJlcyA8PCBGb3JtYXQgJSBbIkJlZlBvc3QiLCBA
# c3VidHlwZV0JaWYgJHJ3ZF9kZWJ1ZwogICAgICBpZiBAYXJncy5pbmNsdWRl
# Pygic3BhY2luZyIpCiAgICAgICAgcmVzIDw8ICI8dHI+PHRkPiZuYnNwOzwv
# dGQ+PC90cj4iICogKEBhcmdzWyJzcGFjaW5nIl0udG9faSkKICAgICAgZW5k
# CiAgICB3aGVuICJob3Jpem9udGFsIiwgInJvdyIKICAgICAgcmVzIDw8IEZv
# cm1hdCAlIFsiQmVmUG9zdCIsIEBzdWJ0eXBlXQlpZiAkcndkX2RlYnVnCiAg
# ICBlbmQKCiAgICByZXMgPDwgRm9ybWF0ICUgWyJQb3N0IiwgQHN1YnR5cGVd
# CQlpZiAkcndkX2RlYnVnCgogICAgY2FzZSBAc3VidHlwZQogICAgd2hlbiAi
# YXBwbGljYXRpb24iCiAgICB3aGVuICJ3aW5kb3ciLCAiaGVscHdpbmRvdyIK
# ICAgICAgYXJncwk9IEBhcmdzLmRlZXBfZHVwCgogICAgICBhcmdzWyJub2hl
# bHBidXR0b24iXQk9IChub3QgaGVscCkKCiAgICAgIHRlbXBsYXRlCT0gJHJ3
# ZF9odG1sXzIKICAgICAgdGVtcGxhdGUJPSAkcndkX2h0bWxfUERBXzIJaWYg
# cGRhCgogICAgICByZXMgPDwgKHRlbXBsYXRlKHRlbXBsYXRlLCBhcmdzKSkK
# ICAgIHdoZW4gInAiCQl0aGVuIHJlcyA8PCAiPC9wPiIKICAgIHdoZW4gInBy
# ZSIJCXRoZW4gcmVzIDw8ICI8L3ByZT4iCiAgICB3aGVuICJiaWciCQl0aGVu
# IHJlcyA8PCAiPC9iaWc+PC9wPiIKICAgIHdoZW4gInNtYWxsIgl0aGVuIHJl
# cyA8PCAiPC9zbWFsbD48L3A+IgogICAgd2hlbiAibGlzdCIJCXRoZW4gcmVz
# IDw8ICI8L3VsPiIKICAgIHdoZW4gIml0ZW0iCQl0aGVuIHJlcyA8PCAiPC9s
# aT4iCiAgICB3aGVuICJlbXB0eSIJdGhlbiByZXMgPDwgIjwvcD4iCiAgICB3
# aGVuICJpbWFnZSIJdGhlbiByZXMgPDwgIiIKICAgIHdoZW4gInByb2dyZXNz
# YmFyIgl0aGVuIHJlcyA8PCAiIgogICAgd2hlbiAiYnIiCQl0aGVuIHJlcyA8
# PCAiIgogICAgd2hlbiAiaHIiCQl0aGVuIHJlcyA8PCAiIgogICAgd2hlbiAi
# YiIJCXRoZW4gcmVzIDw8ICI8L2I+IgogICAgd2hlbiAiaSIJCXRoZW4gcmVz
# IDw8ICI8L2k+IgogICAgd2hlbiAiYSIJCXRoZW4gcmVzIDw8ICI8L2E+Igog
# ICAgd2hlbiAidmVydGljYWwiCXRoZW4gcmVzIDw8ICI8L3RhYmxlPiIKICAg
# IHdoZW4gImhvcml6b250YWwiCXRoZW4gcmVzIDw8ICI8L3RyPjwvdGFibGU+
# IgogICAgd2hlbiAidGFibGUiCXRoZW4gcmVzIDw8ICI8L3RhYmxlPiIKICAg
# IHdoZW4gInJvdyIJCXRoZW4gcmVzIDw8ICI8L3RyPiIKICAgIHdoZW4gImhp
# ZGRlbiIJdGhlbiByZXMgPDwgIjwvcD4iCiAgICB3aGVuICJ0ZXh0IgkJdGhl
# biByZXMgPDwgIjwvcD4iCiAgICB3aGVuICJ0ZXh0YXJlYSIJdGhlbiByZXMg
# PDwgIjwvcD4iCiAgICB3aGVuICJwYXNzd29yZCIJdGhlbiByZXMgPDwgIjwv
# cD4iCiAgICB3aGVuICJjaGVja2JveCIJdGhlbiByZXMgPDwgIjwvcD4iCiAg
# ICB3aGVuICJyYWRpbyIJdGhlbiByZXMgPDwgIjwvcD4iCiAgICB3aGVuICJz
# ZWxlY3QiCiAgICAgIHJlcyA8PCAiPC9zZWxlY3Q+IgogICAgICAkc2VsZWN0
# CT0gbmlsCiAgICB3aGVuICJvcHRpb24iCXRoZW4gcmVzIDw8ICI8L29wdGlv
# bj4iCiAgICB3aGVuICJidXR0b24iCXRoZW4gcmVzIDw8ICIiCiAgICB3aGVu
# ICJiYWNrIgkJdGhlbiByZXMgPDwgIiIKICAgIHdoZW4gImNhbmNlbCIJdGhl
# biByZXMgPDwgIiIKICAgIHdoZW4gImhlbHAiCQl0aGVuIHJlcyA8PCAiIgog
# ICAgd2hlbiAicXVpdCIJCXRoZW4gcmVzIDw8ICIiCiAgICB3aGVuICJjbG9z
# ZSIJdGhlbiByZXMgPDwgIiIKICAgIHdoZW4gIm1haW4iCQl0aGVuIHJlcyA8
# PCAiIgogICAgd2hlbiAicmVzZXQiCXRoZW4gcmVzIDw8ICIiCiAgICB3aGVu
# ICJjbG9zZXdpbmRvdyIJdGhlbiByZXMgPDwgIiIKICAgIHdoZW4gInRhYnMi
# CiAgICAgIHJlcyA8PCAiICAgIDwvdGQ+IgogICAgICByZXMgPDwgIiAgPC90
# cj4iCiAgICAgIHJlcyA8PCAiPC90YWJsZT4iCiAgICB3aGVuICJ0YWIiCiAg
# ICAgIHJlcyA8PCAiPC90YWJsZT4iCiAgICB3aGVuICJwYW5lbCIKICAgICAg
# cmVzIDw8ICIgICAgICAgICAgICA8L3RhYmxlPiIKICAgICAgcmVzIDw8ICIg
# ICAgICAgICAgPC90ZD4iCiAgICAgIHJlcyA8PCAiICAgICAgICA8L3RyPiIK
# ICAgICAgcmVzIDw8ICIgICAgICA8L3RhYmxlPiIKICAgICAgcmVzIDw8ICIg
# ICAgPC90ZD4iCiAgICAgIHJlcyA8PCAiICA8L3RyPiIKICAgICAgcmVzIDw8
# ICI8L3RhYmxlPiIKICAgIGVsc2UKICAgICAgcHV0cyAiPC8je0BzdWJ0eXBl
# fT4iCiAgICAgIHJlcyA8PCAiJmx0Oy8je0BzdWJ0eXBlfSZndDsiCiAgICBl
# bmQKCiAgICBiZWZvcmUucG9wCiAgICBhZnRlci5wb3AKCiAgICBhZnQJPSBh
# ZnRlclstMV0KICAgIHJlcyA8PCBGb3JtYXQgJSBbIkFmdGVyIiwgQHN1YnR5
# cGVdCQlpZiAoJHJ3ZF9kZWJ1ZyBhbmQgbm90IGFmdC5uaWw/KQogICAgcmVz
# IDw8IGFmdAlpZiBub3QgYWZ0Lm5pbD8KICBlbmQKCiAgZGVmIHRlbXBsYXRl
# KGh0bWwsIHZhcnMpCiAgICByZXMJPSBbXQoKICAgIGEJPSB7fQoKICAgIHZh
# cnMuZWFjaCBkbyB8aywgdnwKICAgICAgYVtrLnVwY2FzZV0JPSB2CiAgICBl
# bmQKCiAgICBsb2dvCT0gbmlsCiAgICBsb2dvCT0gRmlsZS5leHBhbmRfcGF0
# aCh2YXJzWyJsb2dvIl0sICRyd2RfZmlsZXMpCQlpZiB2YXJzLmluY2x1ZGU/
# KCJsb2dvIikKICAgIGxvZ28JPSBuaWwJCQkJCQkJdW5sZXNzIGxvZ28ubmls
# PyBvciBGaWxlLmZpbGU/KGxvZ28pCgogICAgd2F0ZXJtYXJrCT0gbmlsCiAg
# ICB3YXRlcm1hcmsJPSBGaWxlLmV4cGFuZF9wYXRoKHZhcnNbIndhdGVybWFy
# ayJdLCAkcndkX2ZpbGVzKQlpZiB2YXJzLmluY2x1ZGU/KCJ3YXRlcm1hcmsi
# KQogICAgd2F0ZXJtYXJrCT0gbmlsCQkJCQkJCXVubGVzcyB3YXRlcm1hcmsu
# bmlsPyBvciBGaWxlLmZpbGU/KHdhdGVybWFyaykKCiAgICBhWyJMT0dPIl0J
# CT0gIiIJdW5sZXNzIG5vdCBsb2dvLm5pbD8KICAgIGFbIldBVEVSTUFSSyJd
# CT0gIiIJdW5sZXNzIG5vdCB3YXRlcm1hcmsubmlsPwoKICAgIGFbIkhFTFBC
# VVRUT04iXQk9IChub3QgKHZhcnNbIm5vaGVscGJ1dHRvbiJdKSkKICAgIGFb
# IkJBQ0tCVVRUT05TIl0JPSAobm90ICh2YXJzWyJub2JhY2tidXR0b25zIl0p
# KQogICAgYVsiQkFDS0JVVFRPTlMiXQk9IChub3QgKHZhcnNbIm5vYmFja2J1
# dHRvbnMiXSkpCiAgICBhWyJDTE9TRUJVVFRPTiJdCT0gKG5vdCAodmFyc1si
# bm9jbG9zZWJ1dHRvbiJdKSkKCiAgICBpZiBhLmluY2x1ZGU/KCJXSURUSCIp
# CiAgICAgIGFbIldJRFRIMSJdCT0gIndpZHRoPScje2FbIldJRFRIIl19JyIK
# ICAgICAgYVsiV0lEVEgyIl0JPSBhWyJXSURUSCJdCiAgICBlbHNlCiAgICAg
# IGFbIldJRFRIMSJdCT0gIiAiCiAgICAgIGFbIldJRFRIMiJdCT0gIjEiCiAg
# ICBlbmQKCiAgICBodG1sLnNwbGl0KC9ccipcbi8pLmVhY2ggZG8gfGxpbmV8
# CiAgICAgIGlmIGxpbmUgPX4gLyVbQS1aMC05XSslLwogICAgICAgIGEuZWFj
# aCBkbyB8aywgdnwKICAgICAgICAgIHYJPSBmYWxzZQlpZiAodi5raW5kX29m
# PyhTdHJpbmcpIGFuZCB2LmVtcHR5PykKCiAgICAgICAgICBpZiBsaW5lLmlu
# Y2x1ZGU/KCIlI3trfSUiKQogICAgICAgICAgICBsaW5lLmdzdWIhKCIlI3tr
# fSUiLCAiI3t2fSIpCWlmIHYKICAgICAgICAgIGVuZAogICAgICAgIGVuZAoK
# ICAgICAgICBsaW5lCT0gIjwhLS0gI3tsaW5lLnNjYW4oLyVbQS1aMC05XSsl
# Lykuam9pbigiICIpfSAtLT4iCWlmIGxpbmUgPX4gLyVbQS1aMC05XSslLwog
# ICAgICBlbmQKCiAgICAgIHJlcyA8PCBsaW5lCiAgICBlbmQKCiAgICByZXMu
# am9pbigiXG4iKQogIGVuZAplbmQKCmNsYXNzIFRleHQKICBkZWYgcHJlY2hp
# bGRyZW4ocmVzLCBiZWZvcmUsIGFmdGVyLCB2YXJzaHRtbCwgdmFyc3N0cmlu
# Zywgc3dpdGNoZXMsIGhlbHAsIG9uZW9ybW9yZWZpZWxkcywgZmlyc3RhY3Rp
# b24sIHRhYnMsIHRhYiwgcGRhKQogICAgaWYgbm90IEB0ZXh0LnNjYW4oL1te
# IFx0XHJcbl0vKS5lbXB0eT8KICAgICAgcmVzIDw8IEZvcm1hdCAlIFsiVGV4
# dCIsICIiXQlpZiAkcndkX2RlYnVnCiAgICAgIHJlcyA8PCAiI3tAdGV4dH0i
# CiAgICBlbmQKICBlbmQKZW5kCgpjbGFzcyBSV0RUcmVlIDwgWE1MCmVuZAoK
# Y2xhc3MgUldEV2luZG93CiAgQEB3aW5kb3dzCT0ge30JIyBLaW5kIG9mIGNh
# Y2hpbmcuCiAgQEBoZWxwd2luZG93cwk9IHt9CSMgS2luZCBvZiBjYWNoaW5n
# LgoKICBkZWYgaW5pdGlhbGl6ZShyd2QsIHdpbmRvdz1uaWwpCiAgICByd2QJ
# PSByd2Quam9pbigiXG4iKQlpZiByd2Qua2luZF9vZj8oQXJyYXkpCgogICAg
# aWYgQEB3aW5kb3dzW3J3ZF0ubmlsPwogICAgICBAQHdpbmRvd3NbcndkXQkJ
# PSB7fQogICAgICBAQGhlbHB3aW5kb3dzW3J3ZF0JPSB7fQoKICAgICAgdHJl
# ZQk9IFhNTC5uZXcocndkKQoKICAgICAgdHJlZS5wYXJzZShPcGVuVGFnLCAi
# d2luZG93IikgZG8gfHR5cGUsIG9ianwKICAgICAgICAkcndkX2FwcHZhcnMu
# ZWFjaHt8aywgdnwgb2JqLmFyZ3Nba10gPSB2fQogICAgICAgIEBAd2luZG93
# c1tyd2RdW29iai5hcmdzWyJuYW1lIl1dCT0gb2JqLnRvX2gKICAgICAgZW5k
# CgogICAgICB0cmVlLnBhcnNlKE9wZW5UYWcsICJoZWxwd2luZG93IikgZG8g
# fHR5cGUsIG9ianwKICAgICAgICAkcndkX2FwcHZhcnMuZWFjaHt8aywgdnwg
# b2JqLmFyZ3Nba10gPSB2fQogICAgICAgIEBAaGVscHdpbmRvd3NbcndkXVtv
# YmouYXJnc1sibmFtZSJdXQk9IG9iai50b19oCiAgICAgIGVuZAogICAgZW5k
# CgogICAgQHJ3ZAk9IChAQHdpbmRvd3NbcndkXVt3aW5kb3ddIG9yICIiKS5k
# dXAKICAgIEBoZWxwcndkCT0gKEBAaGVscHdpbmRvd3NbcndkXVt3aW5kb3dd
# IG9yICIiKS5kdXAKICBlbmQKCiAgZGVmIHJlbmRlcihwZGEsIGFjdGlvbj1u
# aWwsIHZhcnM9SGFzaC5uZXcsIHN3aXRjaGVzPUhhc2gubmV3LCBoZWxwPWZh
# bHNlLCB0YWI9IiIpCiAgICB2YXJzaHRtbAkJPSBIYXNoLm5ldwogICAgdmFy
# c3N0cmluZwkJPSBIYXNoLm5ldwogICAgb25lb3Jtb3JlZmllbGRzCT0gIiIK
# ICAgIGZpcnN0YWN0aW9uCQk9ICIiCiAgICBodG1sCQk9IFtdCgogICAgdmFy
# cwk9IHZhcnMuZGVlcF9kdXAKCiAgICB2YXJzLmVhY2ggZG8gfGtleSwgdmFs
# dWV8CiAgICAgIGlmIG5vdCBrZXkuZW1wdHk/CiAgICAgICAgaWYgdmFsdWUu
# cmVzcG9uZF90bz8gInRvX3MiCiAgICAgICAgICBAcndkLmdzdWIhKC8lJSN7
# a2V5fSUlLywgdmFsdWUudG9fcykKICAgICAgICAgIEByd2QuZ3N1YiEoLyUj
# e2tleX0lLywgdmFsdWUudG9fcy50b19odG1sKQoKICAgICAgICAgIEBoZWxw
# cndkLmdzdWIhKC8lJSN7a2V5fSUlLywgdmFsdWUudG9fcykKICAgICAgICAg
# IEBoZWxwcndkLmdzdWIhKC8lI3trZXl9JS8sIHZhbHVlLnRvX3MudG9faHRt
# bCkKCiAgICAgICAgICB2YXJzaHRtbFtrZXldCQk9IHZhbHVlLnRvX3MudG9f
# aHRtbAogICAgICAgICAgdmFyc3N0cmluZ1trZXldCT0gdmFsdWUudG9fcwog
# ICAgICAgIGVuZAogICAgICBlbmQKICAgIGVuZAoKICAgIHdpbmRvd29iamVj
# dAk9IFJXRFRyZWUubmV3KEByd2QpLmNoaWxkcmVuLmR1cC5kZWxldGVfaWZ7
# fG9ianwgb2JqLnN1YnR5cGUgIT0gIndpbmRvdyJ9WzBdCiAgICBoZWxwb2Jq
# ZWN0CQk9IFJXRFRyZWUubmV3KEBoZWxwcndkKS5jaGlsZHJlbi5kdXAuZGVs
# ZXRlX2lme3xvYmp8IG9iai5zdWJ0eXBlICE9ICJoZWxwd2luZG93In1bMF0K
# CiAgICB0YWJzb2JqCT0gd2luZG93b2JqZWN0LmNoaWxkcmVuLmR1cC5kZWxl
# dGVfaWZ7fG9ianwgb2JqLnN1YnR5cGUgIT0gInRhYnMifVswXQoKICAgIGlm
# IG5vdCB0YWJzb2JqLm5pbD8KICAgICAgdGFicwk9IHRhYnNvYmouY2hpbGRy
# ZW4uZHVwLmRlbGV0ZV9pZnt8b2JqfCAobm90IG9iai5raW5kX29mPyhPcGVu
# VGFnKSkgb3IgKG9iai5zdWJ0eXBlICE9ICJ0YWIiKX0KCiAgICAgIGlmIHRh
# Yi5lbXB0eT8KICAgICAgICB0YWIJCQk9IHRhYnNbMF0uYXJnc1sibmFtZSJd
# CiAgICAgIGVuZAoKICAgICAgdGFic29iai5jaGlsZHJlbi5kZWxldGVfaWZ7
# fG9ianwgKG9iai5raW5kX29mPyhPcGVuVGFnKSkgYW5kIChvYmouc3VidHlw
# ZSA9PSAidGFiIikgYW5kIG9iai5hcmdzWyJuYW1lIl0gIT0gdGFifQogICAg
# ZW5kCgogICAgaWYgaGVscAogICAgICBoZWxwb2JqZWN0LnBhcnNldHJlZSgi
# cHJlY2hpbGRyZW4iLCAicG9zdGNoaWxkcmVuIiwgaHRtbCwgWyIiXSwgWyIi
# XSwgdmFyc2h0bWwsIHZhcnNzdHJpbmcsIHN3aXRjaGVzLCBmYWxzZSwgb25l
# b3Jtb3JlZmllbGRzLCBmaXJzdGFjdGlvbiwgdGFicywgdGFiLCBwZGEpCiAg
# ICBlbHNlCiAgICAgIHdpbmRvd29iamVjdC5wYXJzZXRyZWUoInByZWNoaWxk
# cmVuIiwgInBvc3RjaGlsZHJlbiIsIGh0bWwsIFsiIl0sIFsiIl0sIHZhcnNo
# dG1sLCB2YXJzc3RyaW5nLCBzd2l0Y2hlcywgKG5vdCBAaGVscHJ3ZC5lbXB0
# eT8pLCBvbmVvcm1vcmVmaWVsZHMsIGZpcnN0YWN0aW9uLCB0YWJzLCB0YWIs
# IHBkYSkKICAgIGVuZAoKICAgIGh0bWwJPSBodG1sLmpvaW4oIiIpCSMgPz8/
# CgogICAgaHRtbC5nc3ViISgvJSUqW1s6YWxudW06XV9cLV0rJSUqLywgIiIp
# CWlmIG5vdCAkcndkX2RlYnVnCiAgICBodG1sLmdzdWIhKC8lJS8sICIlIikK
# ICAgIGh0bWwuZ3N1YiEoL1xuXG4qLywgIlxuIikKCiAgICBpZiBvbmVvcm1v
# cmVmaWVsZHMuZW1wdHk/CiAgICAgIGZvY3VzCT0gIiIKICAgIGVsc2UKICAg
# ICAgZm9jdXMJPSAiZG9jdW1lbnQuYm9keWZvcm0uZWxlbWVudHNbMF0uZm9j
# dXMoKTsiCiAgICBlbmQKCiAgICBmaXJzdGFjdGlvbgk9IGFjdGlvbglpZiB3
# aW5kb3dvYmplY3QuYXJncy5rZXlzLmluY2x1ZGU/KCJyZWZyZXNoIikJdW5s
# ZXNzIGFjdGlvbi5uaWw/CgogICAgaHRtbC5nc3ViISgvXCRSV0RfRklSU1RB
# Q1RJT05cJC8JLCBmaXJzdGFjdGlvbikKICAgIGh0bWwuZ3N1YiEoL1wkUldE
# X0ZPQ1VTXCQvCQksIGZvY3VzKQoKICAgIGh0bWwKICBlbmQKZW5kCgpjbGFz
# cyBSV0RNZXNzYWdlIDwgUldEV2luZG93CiAgZGVmIGluaXRpYWxpemUobXNn
# KQogICAgc3VwZXIoIjx3aW5kb3cgdGl0bGU9J1JXRCBNZXNzYWdlJyBub2Jh
# Y2tidXR0b25zIG5vY2xvc2VidXR0b24+PHA+I3ttc2d9PC9wPjxiYWNrLz48
# L3dpbmRvdz4iKQogIGVuZAplbmQKCmNsYXNzIFJXREVycm9yIDwgUldEV2lu
# ZG93CiAgZGVmIGluaXRpYWxpemUobXNnKQogICAgc3VwZXIoIjx3aW5kb3cg
# dGl0bGU9J1JXRCBFcnJvcicgbm9iYWNrYnV0dG9ucyBub2Nsb3NlYnV0dG9u
# PjxwPjxiPkVycm9yOjwvYj4gI3ttc2d9PC9wPjxiYWNrLz48L3dpbmRvdz4i
# KQogIGVuZAplbmQKCmNsYXNzIFJXRFByb2dyZXNzQmFyIDwgUldEV2luZG93
# CiAgZGVmIGluaXRpYWxpemUocmVmcmVzaCwgcHJvZ3Jlc3MpCiAgICBzCT0g
# IiIKICAgIHMgPDwgIjx3aW5kb3cgdGl0bGU9J1JXRCBQcm9ncmVzcycgbm9i
# YWNrYnV0dG9ucyBub2Nsb3NlYnV0dG9uIHJlZnJlc2g9JyN7cmVmcmVzaH0n
# PiIKICAgIGlmIHByb2dyZXNzLmxlbmd0aCA9PSAxCiAgICAgIHByb2dyZXNz
# LmVhY2ggZG8gfGNhcHRpb24sIHZhbHVlfAogICAgICAgIHMgPDwgIjxwPiN7
# Y2FwdGlvbn08L3A+PHByb2dyZXNzYmFyIHZhbHVlPScje3ZhbHVlfScvPjxw
# PiN7KDEwMCp2YWx1ZSkudG9faX0lJTwvcD4iCiAgICAgIGVuZAogICAgZWxz
# ZQogICAgICBzIDw8ICI8dGFibGU+IgogICAgICBwcm9ncmVzcy5lYWNoIGRv
# IHxjYXB0aW9uLCB2YWx1ZXwKICAgICAgICBzIDw8ICI8cm93PjxwIGFsaWdu
# PSdsZWZ0Jz4je2NhcHRpb259PC9wPjxwcm9ncmVzc2JhciB2YWx1ZT0nI3t2
# YWx1ZX0nLz48cCBhbGlnbj0ncmlnaHQnPiN7KDEwMCp2YWx1ZSkudG9faX0l
# JTwvcD48L3Jvdz4iCiAgICAgIGVuZAogICAgICBzIDw8ICI8L3RhYmxlPiIK
# ICAgIGVuZAogICAgcyA8PCAiPGNhbmNlbC8+IgogICAgcyA8PCAiPC93aW5k
# b3c+IgogICAgc3VwZXIocykKICBlbmQKZW5kCgpjbGFzcyBSV0REb25lIDwg
# UldEV2luZG93CiAgZGVmIGluaXRpYWxpemUoZXhpdGJyb3dzZXIpCiAgICBz
# dXBlcigiPHdpbmRvdyB0aXRsZT0nUldEIE1lc3NhZ2UnIG5vYmFja2J1dHRv
# bnMgbm9jbG9zZWJ1dHRvbj48cD5Eb25lLjwvcD48aT4oU29tZSBicm93c2Vy
# cyBkb24ndCBjbG9zZSw8YnI+YmVjYXVzZSBvZiBzZWN1cml0eSByZWFzb25z
# Lik8L2k+PGhvcml6b250YWw+PGNsb3NlLz4je2V4aXRicm93c2VyID8gIiIg
# OiAiPGJ1dHRvbiBjYXB0aW9uPSdBZ2FpbicvPiJ9PC9ob3Jpem9udGFsPiN7
# ZXhpdGJyb3dzZXIgPyAiPGNsb3Nld2luZG93Lz4iIDogIiJ9PC93aW5kb3c+
# IikKICBlbmQKZW5kCgpjbGFzcyBSV0RpYWxvZwogIGRlZiBpbml0aWFsaXpl
# KHhtbCkKICAgIEByd2RfeG1sCQkJPSB4bWwKICAgIEByd2RfZXhpdGJyb3dz
# ZXIJCT0gZmFsc2UKICAgIEByd2RfaGlzdG9yeQkJPSBbXQogICAgQHJ3ZF9p
# Z25vcmVfdmFycwkJPSBbXQogICAgQHJ3ZF9jYWxsX2FmdGVyX2JhY2sJPSBb
# XQogICAgQHJ3ZF90aW1lCQkJPSBUaW1lLm5vdwoKICAgICRyd2RfYXBwdmFy
# cwk9IHt9CWlmICRyd2RfYXBwdmFycy5uaWw/CiAgICBYTUwubmV3KHhtbCku
# cGFyc2UoT3BlblRhZywgImFwcGxpY2F0aW9uIikgZG8gfHR5cGUsIG9ianwK
# ICAgICAgb2JqLmFyZ3MuZGVlcF9kdXAuZWFjaCBkbyB8aywgdnwKICAgICAg
# ICAkcndkX2FwcHZhcnNba10JPSB2CiAgICAgIGVuZAogICAgZW5kCiAgZW5k
# CgogIGRlZiBzZWxmLmZpbGUocndkZmlsZSwgKmFyZ3MpCiAgICBuZXcoRmls
# ZS5uZXcocndkZmlsZSkucmVhZGxpbmVzLCAqYXJncykKICBlbmQKCiAgZGVm
# IHNlcnZlKHBvcnQ9bmlsLCBhdXRoPW5pbCwgcmVhbG09c2VsZi5jbGFzcy50
# b19zKQogICAgZXhpdAlpZiAkcndkX2V4aXQKCiAgICByYWlzZSAiUldEIGlz
# IG5vdCBpbml0aWFsaXplZC4iCWlmIEByd2RfeG1sLm5pbD8KCiAgICBsb3cs
# IGhpZ2gJPSBFTlZbIlJXRFBPUlRTIl0uc3BsaXQoL1teXGQrXS8pCiAgICBo
# aWdoCT0gbG93CWlmIGhpZ2gubmlsPwogICAgbG93LCBoaWdoCT0gbG93LnRv
# X2ksIGhpZ2gudG9faQoKICAgIGlvCQk9IG5pbAoKICAgIHBvcnQsIGlvCT0g
# VENQU2VydmVyLmZyZWVwb3J0KGxvdywgaGlnaCwgKG5vdCBhdXRoLm5pbD8p
# KQlpZiBwb3J0Lm5pbD8KICAgIHJhaXNlICJObyBmcmVlIFRDUCBwb3J0LiIJ
# CQkJCQlpZiBwb3J0Lm5pbD8KCiAgICBwb3J0CT0gcG9ydC50b19pCgogICAg
# QHJ3ZF9zZXJ2ZXIJPSBSV0RTZXJ2ZXIubmV3KHNlbGYsIHBvcnQsIGlvLCBh
# dXRoLCByZWFsbSkKCiAgICBzZWxmCiAgZW5kCgogIGRlZiByZW5kZXIocmVz
# LCBwYXRoLCBwb3N0LCBkb3dubG9hZCwgZG93bmxvYWRmaWxlLCBwZGEsIHNl
# c3Npb25pZCkKCQkjIEF2b2lkIGEgdGltZW91dC4KCiAgICBAcndkX3RpbWUJ
# CT0gVGltZS5ub3cKCgkJIyBJbml0aWFsaXplIHNvbWUgdmFycy4KCiAgICB2
# YXJzCQk9IEhhc2gubmV3CWlmIHZhcnMubmlsPwogICAgQHJ3ZF9zd2l0Y2hl
# cwk9IEhhc2gubmV3CWlmIEByd2Rfc3dpdGNoZXMubmlsPwoKICAgIGRvbmUJ
# CT0gZmFsc2UKICAgIGhlbHAJCT0gZmFsc2UKICAgIGJhY2sJCT0gZmFsc2UK
# ICAgIHRhYgkJCT0gIiIKICAgIEByd2RfbXNndHlwZQk9IG5pbAlpZiBAcndk
# X3Byb2dyZXNzX3RocmVhZC5uaWw/CiAgICBAcndkX2Rvd25sb2FkCT0gbmls
# CiAgICBAcndkX2Rvd25sb2FkX2ZpbGUJPSBuaWwKCgkJIyBTd2l0Y2hlcyBh
# cmUgdXNlZCBmb3IgY2hlY2tib3hlcy4KCiAgICBAcndkX3N3aXRjaGVzLmVh
# Y2ggZG8gfGtleSwgdmFsdWV8CiAgICAgIHZhcnNba2V5XQk9ICJvZmYiCiAg
# ICBlbmQKCiAgICBAcndkX3N3aXRjaGVzCT0gSGFzaC5uZXcKCgkJIyBDb3B5
# IHRoZSB2YXJzIGZyb20gdGhlIHdpbmRvdyB0byB2YXJzLiB2YXJzIHdpbCBs
# YXRlciBvbiBiZSBjb3BpZWQgdG8gaW5zdGFuY2UgdmFyaWFibGVzLgoKICAg
# IHBvc3Quc29ydC5lYWNoIGRvIHxrZXksIHZhbHVlfAogICAgICBwdXRzICJQ
# b3N0OiAje2tleX0gLT4gI3t2YWx1ZS5mcm9tX2h0bWwuaW5zcGVjdH0iCWlm
# ICRyd2RfZGVidWcKCiAgICAgIHZhcnNba2V5XQk9IHZhbHVlLmZyb21faHRt
# bAogICAgZW5kCgoJCSMgU3RhY2sgaGFuZGxpbmcgZm9yIHJ3ZF9hY3Rpb24s
# IHJ3ZF93aW5kb3cgYW5kIHJ3ZF90YWIuCgogICAgQHJ3ZF9hY3Rpb24JCQk9
# IHZhcnNbInJ3ZF9hY3Rpb24iXQkJaWYgdmFycy5pbmNsdWRlPygicndkX2Fj
# dGlvbiIpCiAgICBAcndkX2FjdGlvbiwgQHJ3ZF9hcmdzCT0gQHJ3ZF9hY3Rp
# b24uc3BsaXQoL1wvLywgMikJdW5sZXNzIEByd2RfYWN0aW9uLm5pbD8KICAg
# IEByd2RfYWN0aW9uLCByZXN0CQk9IEByd2RfYWN0aW9uLnNwbGl0KC9cPy8p
# CXVubGVzcyBAcndkX2FjdGlvbi5uaWw/CgogICAgQHJ3ZF9yZWZyZXNoX2Fj
# dGlvbgkJPSAoQHJ3ZF9hY3Rpb24gb3IgQHJ3ZF9yZWZyZXNoX2FjdGlvbiBv
# ciAibWFpbiIpCgogICAgdW5sZXNzIHJlc3QubmlsPwogICAgICByZXN0LmVh
# Y2ggZG8gfHN8CiAgICAgICAgaywgdgk9IHMuc3BsaXQoLz0vLCAyKQogICAg
# ICAgIHZhcnNba10JPSB2CiAgICAgIGVuZAogICAgZW5kCgogICAgaWYgQHJ3
# ZF9hY3Rpb24gPT0gInJ3ZF9jYW5jZWwiCiAgICAgIEByd2RfcHJvZ3Jlc3Nf
# dGhyZWFkLmtpbGwJCXVubGVzcyBAcndkX3Byb2dyZXNzX3RocmVhZC5uaWw/
# CiAgICAgIEByd2RfcHJvZ3Jlc3NfdGhyZWFkCT0gbmlsCiAgICAgIEByd2Rf
# YWN0aW9uCQk9ICJyd2RfYmFjayIKICAgIGVuZAoKICAgIEByd2RfaGlzdG9y
# eQk9IFtbIm1haW4iLCBbXSwgIm1haW4iLCAiIl1dCWlmIEByd2RfaGlzdG9y
# eS5lbXB0eT8KCiAgICBpZiBAcndkX2FjdGlvbiA9fiAvXnJ3ZF90YWJfLwog
# ICAgICBAcndkX3RhYgk9IEByd2RfYWN0aW9uLnN1YigvXnJ3ZF90YWJfLywg
# IiIpCiAgICAgIEByd2RfaGlzdG9yeVstMV1bM10JPSBAcndkX3RhYgogICAg
# ZWxzZQogICAgICBjYXNlIEByd2RfYWN0aW9uCiAgICAgIHdoZW4gInJ3ZF9i
# YWNrIgogICAgICAgIEByd2RfaGlzdG9yeS5wb3AKICAgICAgICBAcndkX2Fj
# dGlvbgkJCT0gKEByd2RfaGlzdG9yeVstMV0gb3IgW25pbCwgbmlsLCBuaWxd
# KVswXQogICAgICAgIEByd2RfYXJncwkJCT0gKEByd2RfaGlzdG9yeVstMV0g
# b3IgW25pbCwgbmlsLCBuaWxdKVsxXQogICAgICAgIEByd2Rfd2luZG93CQkJ
# PSAoQHJ3ZF9oaXN0b3J5Wy0xXSBvciBbbmlsLCBuaWwsIG5pbF0pWzJdCiAg
# ICAgICAgQHJ3ZF90YWIJCQk9IChAcndkX2hpc3RvcnlbLTFdIG9yIFtuaWws
# IG5pbCwgbmlsXSlbM10KICAgICAgICBiYWNrCQkJCT0gdHJ1ZQogICAgICB3
# aGVuICJyd2RfaGVscCIKICAgICAgICBoZWxwCQkJCT0gdHJ1ZQogICAgICB3
# aGVuICJyd2RfbWFpbiIKICAgICAgICBAcndkX2FjdGlvbgkJCT0gbmlsCiAg
# ICAgICAgQHJ3ZF93aW5kb3cJCQk9IG5pbAogICAgICAgIEByd2RfdGFiCQkJ
# PSBuaWwKICAgICAgICBAcndkX2hpc3RvcnkJCQk9IFtdCiAgICAgIHdoZW4g
# InJ3ZF9xdWl0IgogICAgICAgIGRvbmUJCQkJPSB0cnVlCiAgICAgIGVsc2UK
# ICAgICAgZW5kCgoJCSMgSGlzdG9yeSBzdHVmZgoKICAgICAgQHJ3ZF9oaXN0
# b3J5CT0gQHJ3ZF9oaXN0b3J5Wy0xMDAuLi0xXQlpZiBAcndkX2hpc3Rvcnku
# bGVuZ3RoID49IDEwMAogICAgICBAcndkX2FjdGlvbgk9ICJtYWluIgkJCWlm
# IEByd2RfYWN0aW9uLm5pbD8KICAgICAgQHJ3ZF9hY3Rpb24JPSAibWFpbiIJ
# CQlpZiBAcndkX2FjdGlvbi5lbXB0eT8KICAgICAgQHJ3ZF93aW5kb3cJPSAi
# bWFpbiIJCQlpZiBAcndkX3dpbmRvdy5uaWw/CiAgICAgIEByd2Rfd2luZG93
# CT0gIm1haW4iCQkJaWYgQHJ3ZF93aW5kb3cuZW1wdHk/CiAgICAgIEByd2Rf
# dGFiCQk9ICIiCQkJCWlmIEByd2RfdGFiLm5pbD8KICAgICAgQHJ3ZF9hcmdz
# CQk9IFtdCQkJCWlmIEByd2RfYXJncy5uaWw/CiAgICAgIEByd2RfYXJncwkJ
# PSBbXQkJCQlpZiBAcndkX2FjdGlvbiA9PSAibWFpbiIKCiAgICAgIHZhcnNb
# InJ3ZF9hY3Rpb24iXQk9IEByd2RfYWN0aW9uCiAgICAgIHZhcnNbInJ3ZF93
# aW5kb3ciXQk9IEByd2Rfd2luZG93CiAgICAgIHZhcnNbInJ3ZF90YWIiXQkJ
# PSBAcndkX3RhYgoKCQkjIENvcHkgdmFycyBmcm9tIHdpbmRvdyB0byBpbnN0
# YW5jZS4KCiAgICAgIHZhcnMuZWFjaCBkbyB8aywgdnwKICAgICAgICBpbnN0
# YW5jZV9ldmFsICJAI3trfQk9IHZhcnNbJyN7a30nXSIJCWlmICgobm90IGsu
# ZW1wdHk/KSBhbmQgay5zY2FuKC9ecndkXy8pLmVtcHR5PyBhbmQgbm90IEBy
# d2RfaWdub3JlX3ZhcnMuaW5jbHVkZT8oIkAje2t9IikpCiAgICAgIGVuZAoK
# CQkjIENhbGxiYWNrLgoKICAgICAgaWYgKG5vdCBiYWNrKSBvciBAcndkX2Nh
# bGxfYWZ0ZXJfYmFjay5pbmNsdWRlPyhAcndkX2FjdGlvbikKICAgICAgICB1
# bmxlc3MgQHJ3ZF9hY3Rpb24gPX4gL15yd2RfLwogICAgICAgICAgcHV0cyAi
# TWV0aG9kOiAje0Byd2RfYWN0aW9ufSgje0Byd2RfYXJncy5qb2luKCIsICIp
# fSkiCWlmICRyd2RfZGVidWcKICAgICAgICAgIGlmIG1ldGhvZHMuaW5jbHVk
# ZT8oQHJ3ZF9hY3Rpb24pCiAgICAgICAgICAgIG1ldGhvZChAcndkX2FjdGlv
# bikuY2FsbCgqQHJ3ZF9hcmdzKQogICAgICAgICAgZWxzZQogICAgICAgICAg
# ICBwdXRzICJNZXRob2QgJyVzJyBpcyBub3QgZGVmaW5lZC4iICUgQHJ3ZF9h
# Y3Rpb24KICAgICAgICAgIGVuZAogICAgICAgIGVuZAoKCQkjIEhpc3Rvcnkg
# c3R1ZmYKCiAgICAgICAgQHJ3ZF9oaXN0b3J5CT0gW1sibWFpbiIsIFtdLCAi
# bWFpbiIsICIiXV0JaWYgQHJ3ZF9hY3Rpb24gPT0gIm1haW4iCiAgICAgICAg
# QHJ3ZF9oaXN0b3J5CT0gW1sibWFpbiIsIFtdLCAibWFpbiIsICIiXV0JaWYg
# QHJ3ZF9oaXN0b3J5LmVtcHR5PwoKICAgICAgICBhCQk9IFtAcndkX2FjdGlv
# biwgQHJ3ZF9hcmdzLCBAcndkX3dpbmRvdywgQHJ3ZF90YWJdCgogICAgICAg
# IEByd2RfaGlzdG9yeS5wdXNoIGEJCQkJaWYgKEByd2RfaGlzdG9yeVstMV0g
# IT0gYSBvciBub3QgQHJ3ZF9tc2d0eXBlLm5pbD8pCgogICAgICAgIGlmIEBy
# d2Rfd2luZG93ID09ICJyd2RfYmFjayIKICAgICAgICAgIEByd2RfaGlzdG9y
# eS5wb3AKICAgICAgICAgIEByd2RfaGlzdG9yeS5wb3AKICAgICAgICAgIEBy
# d2RfYWN0aW9uCQkJPSAoQHJ3ZF9oaXN0b3J5Wy0xXSBvciBbbmlsLCBuaWws
# IG5pbF0pWzBdCiAgICAgICAgICBAcndkX2FyZ3MJCQk9IChAcndkX2hpc3Rv
# cnlbLTFdIG9yIFtuaWwsIG5pbCwgbmlsXSlbMV0KICAgICAgICAgIEByd2Rf
# d2luZG93CQkJPSAoQHJ3ZF9oaXN0b3J5Wy0xXSBvciBbbmlsLCBuaWwsIG5p
# bF0pWzJdCiAgICAgICAgICBAcndkX3RhYgkJCT0gKEByd2RfaGlzdG9yeVst
# MV0gb3IgW25pbCwgbmlsLCBuaWxdKVszXQogICAgICAgIGVuZAogICAgICBl
# bmQKICAgIGVuZAoKCQkjIENvcHkgdmFycyBmcm9tIGluc3RhbmNlIHRvIHdp
# bmRvdy4KCiAgICBpbnN0YW5jZV92YXJpYWJsZXMuZWFjaCBkbyB8a3wKICAg
# ICAgay5zdWIhKC9eQC8sICIiKQogICAgICBpbnN0YW5jZV9ldmFsICJ2YXJz
# Wycje2t9J10gPSBAI3trfS50b19zIglpZiAoay5zY2FuKC9ecndkXy8pLmVt
# cHR5PyBhbmQgbm90IEByd2RfaWdub3JlX3ZhcnMuaW5jbHVkZT8oIkAje2t9
# IikpCiAgICBlbmQKCgkJIyBqdXN0IGlnbm9yZS4KCiAgICB2YXJzLnNvcnQu
# ZWFjaCBkbyB8a2V5LCB2YWx1ZXwKICAgICAgcHV0cyAiUHJlOiAje2tleX0g
# LT4gI3t2YWx1ZS5pbnNwZWN0fSIJaWYgJHJ3ZF9kZWJ1ZwogICAgZW5kCgoK
# CQkjIEFuc3dlciB0byBicm93c2VyLgoKICAgIGlmIGRvbmUKICAgICAgcmVz
# IDw8IFJXRERvbmUubmV3KEByd2RfZXhpdGJyb3dzZXIpLnJlbmRlcihwZGEp
# CiAgICBlbHNlCiAgICAgIGlmIG5vdCBAcndkX2Rvd25sb2FkLm5pbD8KICAg
# ICAgICBwdXRzICJEb3dubG9hZDogI3tAcndkX3dpbmRvd30iCQlpZiAkcndk
# X2RlYnVnCgogICAgICAgIGRvd25sb2FkCTw8IEByd2RfZG93bmxvYWQKICAg
# ICAgICBkb3dubG9hZGZpbGUJPDwgQHJ3ZF9kb3dubG9hZF9maWxlCiAgICAg
# IGVsc2UKICAgICAgICBpZiBub3QgQHJ3ZF9wcm9ncmVzc190aHJlYWQubmls
# PwogICAgICAgICAgcmVzIDw8IFJXRFByb2dyZXNzQmFyLm5ldyhAcndkX3By
# b2dyZXNzX3JlZnJlc2gsIEByd2RfcHJvZ3Jlc3NfcHJvZ3Jlc3MpLnJlbmRl
# cihwZGEsIEByd2RfcmVmcmVzaF9hY3Rpb24pCiAgICAgICAgZWxzZQogICAg
# ICAgICAgaWYgbm90IEByd2RfbXNndHlwZS5uaWw/CiAgICAgICAgICAgIHJl
# cyA8PCBSV0RNZXNzYWdlLm5ldyhAcndkX21zZykucmVuZGVyKHBkYSkJaWYg
# QHJ3ZF9tc2d0eXBlID09ICJtZXNzYWdlIgogICAgICAgICAgICByZXMgPDwg
# UldERXJyb3IubmV3KEByd2RfbXNnKS5yZW5kZXIocGRhKQlpZiBAcndkX21z
# Z3R5cGUgPT0gImVycm9yIgogICAgICAgICAgICByZXMgPDwgQHJ3ZF9tc2cJ
# CQkJaWYgQHJ3ZF9tc2d0eXBlID09ICJ0ZXh0IgogICAgICAgICAgZWxzZQog
# ICAgICAgICAgICBwdXRzICJXaW5kb3c6ICN7QHJ3ZF93aW5kb3d9IgkJaWYg
# JHJ3ZF9kZWJ1ZwogICAgICAgICAgICBwdXRzICJUYWI6ICN7QHJ3ZF90YWJ9
# IgkJaWYgJHJ3ZF9kZWJ1ZwoKICAgICAgICAgICAgcmVzIDw8IFJXRFdpbmRv
# dy5uZXcoQHJ3ZF94bWwsIEByd2Rfd2luZG93KS5yZW5kZXIocGRhLCBAcndk
# X3JlZnJlc2hfYWN0aW9uLCB2YXJzLCBAcndkX3N3aXRjaGVzLCBoZWxwLCBA
# cndkX3RhYikKICAgICAgICAgIGVuZAogICAgICAgIGVuZAogICAgICBlbmQK
# ICAgIGVuZAoKICAgIHJldHVybiBkb25lCiAgZW5kCgogIGRlZiBzYW1ld2lu
# ZG93PwogICAgQHJ3ZF9oaXN0b3J5Wy0xXVsyXSA9PSBAcndkX3dpbmRvdwog
# IGVuZAoKICBkZWYgbWVzc2FnZShtc2csICZibG9jaykKICAgIEByd2RfbXNn
# CQk9IG1zZwogICAgQHJ3ZF9tc2d0eXBlCT0gIm1lc3NhZ2UiCiAgZW5kCgog
# IGRlZiBlcnJvcihtc2csICZibG9jaykKICAgIEByd2RfbXNnCQk9IG1zZwog
# ICAgQHJ3ZF9tc2d0eXBlCT0gImVycm9yIgogIGVuZAoKICBkZWYgdGV4dCht
# c2cpCiAgICBAcndkX21zZwkJPSAiPGh0bWw+PGJvZHk+PHByZT4je21zZ308
# L3ByZT48L2JvZHk+PC9odG1sPiIKICAgIEByd2RfbXNndHlwZQk9ICJ0ZXh0
# IgogIGVuZAoKICBkZWYgcHJvZ3Jlc3NiYXIocmVmcmVzaCwgKnByb2dyZXNz
# KQogICAgQHJ3ZF9wcm9ncmVzc19yZWZyZXNoCT0gKHJlZnJlc2ggb3IgMSkK
# ICAgIEByd2RfcHJvZ3Jlc3NfcHJvZ3Jlc3MJPSBbXQoKICAgIHdoaWxlIG5v
# dCBwcm9ncmVzcy5lbXB0eT8KICAgICAgcwk9IChwcm9ncmVzcy5zaGlmdCBv
# ciAiIikKICAgICAgaWYgcy5raW5kX29mPyhBcnJheSkKICAgICAgICBjYXB0
# aW9uLCB2YWx1ZQk9IHMKICAgICAgICB2YWx1ZQk9ICh2YWx1ZSBvciAwLjAp
# LnRvX2YKICAgICAgZWxzZQogICAgICAgIGNhcHRpb24JPSBzCiAgICAgICAg
# dmFsdWUJPSAocHJvZ3Jlc3Muc2hpZnQgb3IgMC4wKS50b19mCiAgICAgIGVu
# ZAoKICAgICAgQHJ3ZF9wcm9ncmVzc19wcm9ncmVzcyA8PCBbY2FwdGlvbiwg
# dmFsdWVdCiAgICBlbmQKCiAgICBpZiBAcndkX3Byb2dyZXNzX3RocmVhZC5u
# aWw/CiAgICAgIEByd2RfcHJvZ3Jlc3NfcHJvZ3Jlc3MuZWFjaCBkbyB8YXwK
# ICAgICAgICBhWzFdCT0gMC4wCiAgICAgIGVuZAoKICAgICAgQHJ3ZF9wcm9n
# cmVzc190aHJlYWQgPQogICAgICBUaHJlYWQubmV3IGRvCiAgICAgICAgeWll
# bGQKICAgICAgZW5kCiAgICAgIFRocmVhZC5wYXNzCiAgICBlbmQKCiAgICBA
# cndkX3Byb2dyZXNzX3RocmVhZAk9IG5pbAl1bmxlc3MgQHJ3ZF9wcm9ncmVz
# c190aHJlYWQuYWxpdmU/CiAgZW5kCgogIGRlZiBkb3dubG9hZChkYXRhLCBm
# aWxlbmFtZT0iIikKICAgIEByd2RfZG93bmxvYWQJPSBkYXRhCiAgICBAcndk
# X2Rvd25sb2FkX2ZpbGUJPSBmaWxlbmFtZQogIGVuZAoKICBkZWYgZXhpdGJy
# b3dzZXIKICAgIEByd2RfZXhpdGJyb3dzZXIJPSB0cnVlCiAgZW5kCgogIGRl
# ZiB0aW1lb3V0KHRpbWVvdXQsIGludGVydmFsPTEpCiAgICBAcndkX3RpbWVv
# dXQJPSB0aW1lb3V0CgogICAgdW5sZXNzIEByd2RfdGltZW91dF90aHJlYWQK
# ICAgICAgQHJ3ZF90aW1lb3V0X3RocmVhZCA9CiAgICAgIFRocmVhZC5uZXcg
# ZG8KICAgICAgICBsb29wIGRvCiAgICAgICAgICBpZiBUaW1lLm5vdyAtIEBy
# d2RfdGltZSA+IEByd2RfdGltZW91dAogICAgICAgICAgICAkc3RkZXJyLnB1
# dHMgIkV4aXRpbmcgZHVlIHRvIHRpbWVvdXQgKCN7QHJ3ZF90aW1lb3V0fSBz
# ZWNvbmRzKS4iCiAgICAgICAgICAgIGV4aXQgMQogICAgICAgICAgZW5kCiAg
# ICAgICAgICBzbGVlcCBpbnRlcnZhbAogICAgICAgIGVuZAogICAgICBlbmQK
# ICAgIGVuZAogIGVuZAplbmQKCmNsYXNzIFJXRExvZ2luIDwgUldEaWFsb2cK
# ICBkZWYgaW5pdGlhbGl6ZShyZWFsbSkKICAgIHN1cGVyKCI8d2luZG93IG5h
# bWU9J21haW4nIHRpdGxlPSdSV0QgTG9naW4gZm9yICN7cmVhbG19JyBub2Jh
# Y2tidXR0b25zIG5vY2xvc2VidXR0b24+PHRhYmxlPjxyb3c+PHAgYWxpZ249
# J3JpZ2h0Jz5Vc2VybmFtZTo8L3A+PHRleHQgbmFtZT0ncndkX2EnLz48L3Jv
# dz48cm93PjxwIGFsaWduPSdyaWdodCc+UGFzc3dvcmQ6PC9wPjxwYXNzd29y
# ZCBuYW1lPSdyd2RfYicvPjwvcm93PjwvdGFibGU+PGJ1dHRvbiBjYXB0aW9u
# PSdMb2dpbicvPjwvd2luZG93PiIpCiAgZW5kCmVuZAoKY2xhc3MgUldEVGlt
# ZU91dCA8IFJXRGlhbG9nCiAgZGVmIGluaXRpYWxpemUKICAgIHN1cGVyKCI8
# d2luZG93IG5hbWU9J21haW4nIHRpdGxlPSdSV0QgRXJyb3InIG5vYmFja2J1
# dHRvbnMgbm9jbG9zZWJ1dHRvbj48cD48Yj5FcnJvcjo8L2I+IFNlc3Npb24g
# aGFzIGV4cGlyZWQuPC9wPjxidXR0b24gY2FwdGlvbj0nTmV3IHNlc3Npb24n
# Lz48L3dpbmRvdz4iKQogIGVuZAplbmQKCmNsYXNzIFNlc3Npb25DbGVhbnVw
# CiAgZGVmIGluaXRpYWxpemUoc2Vzc2lvbnMsIGludGVydmFsLCB0aW1lb3V0
# KQogICAgZXZlcnkoaW50ZXJ2YWwpIGRvCiAgICAgIHNlc3Npb25zLmRlbGV0
# ZV9pZiBkbyB8aWQsIHNlc3Npb258CiAgICAgICAgdGltZQk9IFRpbWUubm93
# LnRvX2kgLSBzZXNzaW9uLmxhc3RhY2Nlc3MudG9faQoKICAgICAgICBwdXRz
# ICJTZXNzaW9uICVzIGRlbGV0ZWQiICUgaWQJaWYgdGltZSA+IHRpbWVvdXQK
# CiAgICAgICAgdGltZSA+IHRpbWVvdXQKICAgICAgZW5kCiAgICBlbmQKICBl
# bmQKZW5kCgpjbGFzcyBTZXNzaW9ucwogIGRlZiBpbml0aWFsaXplKHJhY2ss
# IGNsZWFudXApCiAgICBAcmFjawk9IHJhY2sudG9fcwogICAgQGNsZWFudXAJ
# PSBTZXNzaW9uQ2xlYW51cC5uZXcoc2VsZiwgMzYwMCwgMjQqMzYwMCkJaWYg
# Y2xlYW51cAogICAgQHNlc3Npb25zCT0ge30KICBlbmQKCiAgZGVmIFtdKHNl
# c3Npb25pZCkKICAgIEBzZXNzaW9uc1tzZXNzaW9uaWRdCiAgZW5kCgogIGRl
# ZiBbXT0oc2Vzc2lvbmlkLCB2YWx1ZSkKICAgIEBzZXNzaW9uc1tzZXNzaW9u
# aWRdCT0gdmFsdWUKICBlbmQKCiAgZGVmIGRlbGV0ZShzZXNzaW9uaWQpCiAg
# ICBAc2Vzc2lvbnMuZGVsZXRlKHNlc3Npb25pZCkKICBlbmQKCiAgZGVmIGRl
# bGV0ZV9pZigmYmxvY2spCiAgICBAc2Vzc2lvbnMuZGVsZXRlX2lme3xrLCB2
# fCBibG9jay5jYWxsKGssIHYpfQogIGVuZAoKICBkZWYgaW5jbHVkZT8oc2Vz
# c2lvbmlkKQogICAgQHNlc3Npb25zLmluY2x1ZGU/KHNlc3Npb25pZCkKICBl
# bmQKZW5kCgpjbGFzcyBSV0RTZXNzaW9uIDwgSGFzaAogIGF0dHJfcmVhZGVy
# IDpzZXNzaW9uaWQKICBhdHRyX3JlYWRlciA6bGFzdGFjY2VzcwogIGF0dHJf
# cmVhZGVyIDphdXRoZW50aWNhdGVkCiAgYXR0cl93cml0ZXIgOmF1dGhlbnRp
# Y2F0ZWQKCiAgZGVmIGluaXRpYWxpemUoc2Vzc2lvbmlkPW5pbCkKICAgIEBz
# ZXNzaW9uaWQJCT0gc2Vzc2lvbmlkCiAgICBAbGFzdGFjY2VzcwkJPSBUaW1l
# Lm5vdwogICAgQGF1dGhlbnRpY2F0ZWQJPSBmYWxzZQogIGVuZAoKICBkZWYg
# dG91Y2gKICAgIEBsYXN0YWNjZXNzCT0gVGltZS5ub3cKICBlbmQKCiAgZGVm
# IHJlbmRlcihyZXMsIHBhdGgsIHBvc3QsIGRvd25sb2FkLCBkb3dubG9hZGZp
# bGUsIHBkYSkKICAgIGRvbmUJPSBzZWxmWyJvYmplY3QiXS5yZW5kZXIocmVz
# LCBwYXRoLCBwb3N0LCBkb3dubG9hZCwgZG93bmxvYWRmaWxlLCBwZGEsIEBz
# ZXNzaW9uaWQpCgogICAgcmVzLmdzdWIhKC9cJFJXRF9TRVNTSU9OXCQvLCBk
# b25lID8gIiIgOiAiI3tAc2Vzc2lvbmlkfSIpCgogICAgcmV0dXJuIGRvbmUK
# ICBlbmQKZW5kCgpjbGFzcyBSV0RTZXJ2ZXIKICBkZWYgaW5pdGlhbGl6ZShv
# YmosIHBvcnQsIGlvLCBhdXRoLCByZWFsbSkKICAgIEBvYmplY3QJCT0gb2Jq
# CiAgICBAbG9jYWxicm93c2luZwk9IGZhbHNlCiAgICBAYnJvd3NlcnN0YXJ0
# ZWQJPSBmYWxzZQogICAgQHNlc3Npb25zCQk9IFNlc3Npb25zLm5ldyhvYmou
# Y2xhc3MsIChub3QgYXV0aC5uaWw/KSkKCiAgICBpZiBhdXRoLm5pbD8KICAg
# ICAgQGxvY2FsYnJvd3NpbmcJPSB0cnVlCgogICAgICBpZiBFTlYuaW5jbHVk
# ZT8oIlJXREJST1dTRVIiKSBhbmQgbm90IEVOVlsiUldEQlJPV1NFUiJdLm5p
# bD8gYW5kIG5vdCBFTlZbIlJXREJST1dTRVIiXS5lbXB0eT8KICAgICAgICBA
# YnJvd3NlcnN0YXJ0ZWQJPSB0cnVlCiAgICAgICAgQG9iamVjdC5leGl0YnJv
# d3NlcgoKCSMgU3RhcnQgYnJvd3Nlci4KCiAgICAgICAgQGJyb3dzZXJ0aHJl
# YWQJPQogICAgICAgIFRocmVhZC5uZXcgZG8KICAgICAgICAgIHB1dHMgIlN0
# YXJ0aW5nIHRoZSBicm93c2VyLi4uIgoKICAgICAgICAgICNpZiBFTlZbIlJX
# REJST1dTRVIiXS5kb3duY2FzZSA9fiAvaWV4cGxvcmUvCSMgPz8/CiAgICAg
# ICAgICAgICNAaWUJPSBJRS5uZXcoImh0dHA6Ly9sb2NhbGhvc3Q6I3twb3J0
# fS8iKQogICAgICAgICAgI2Vsc2UKICAgICAgICAgICAgYnJvd3Nlcgk9IEVO
# VlsiUldEQlJPV1NFUiJdLmR1cAogICAgICAgICAgICB1cmwJCT0gImh0dHA6
# Ly9sb2NhbGhvc3Q6JXMvIiAlIFtwb3J0XQoKICAgICAgICAgICAgcmUJCT0g
# L1skJV0xXGIvCiAgICAgICAgICAgIGNvbW1hbmQJPSAiJXMgXCIlc1wiIiAl
# IFticm93c2VyLCB1cmxdCiAgICAgICAgICAgIGNvbW1hbmQJPSBicm93c2Vy
# LmdzdWIocmUsIHVybCkJaWYgYnJvd3NlciA9fiByZQoKICAgICAgICAgICAg
# Y29tbWFuZC5nc3ViISgvJXBvcnQlLywgcG9ydC50b19zKQoKICAgICAgICAg
# ICAgc3lzdGVtKGNvbW1hbmQpIG9yICRzdGRlcnIucHV0cyAiU3RhcnRpbmcg
# b2YgdGhlIGJyb3dzZXIgZmFpbGVkLCBvciB0aGUgYnJvd3NlciB0ZXJtaW5h
# dGVkIGFibm9ybWFsbHkuXG5Db21tYW5kID0+ICN7Y29tbWFuZH0iCiAgICAg
# ICAgICAjZW5kCgogICAgICAgICAgcHV0cyAiVGhlIGJyb3dzZXIgaGFzIHRl
# cm1pbmF0ZWQuIgogICAgICAgIGVuZAogICAgICBlbmQKICAgIGVuZAoKCSMg
# U3RhcnQgc2VydmVyLgoKICAgIHBvcnRpbwkJPSBwb3J0CiAgICBwb3J0aW8J
# CT0gW3BvcnQsIGlvXQl1bmxlc3MgaW8ubmlsPwogICAgdGhyZWFkbGltaXRl
# cgk9IFRocmVhZExpbWl0ZXIubmV3KDEpCgogICAgSFRUUFNlcnZlci5zZXJ2
# ZShwb3J0aW8sIChub3QgYXV0aC5uaWw/KSkgZG8gfHJlcSwgcmVzcHwKICAg
# ICAgdGhyZWFkbGltaXRlci53YWl0IGRvCiAgICAgICAgdmFycwk9IHt9CiAg
# ICAgICAgcmVxLnZhcnMuZWFjaCBkbyB8aywgdnwKICAgICAgICAgIHZhcnNb
# a10JPSB2LmpvaW4oIlx0IikKICAgICAgICBlbmQKICAgICAgICBwYWQJPSAo
# cmVxLnJlcXVlc3QucGF0aCBvciAiLyIpCgogICAgICAgIGlmIGF1dGgua2lu
# ZF9vZj8gU3RyaW5nCiAgICAgICAgICBmaWxlCT0gIiN7aG9tZX0vI3thdXRo
# fSIKICAgICAgICAgIGF1dGhzCT0ge30KICAgICAgICAgIGF1dGhzCT0gSGFz
# aC5maWxlKGZpbGUpCWlmIEZpbGUuZmlsZT8oZmlsZSkKICAgICAgICBlbHNl
# CiAgICAgICAgICBhdXRocwk9IGF1dGgKICAgICAgICBlbmQKCiAgICAgICAg
# I29sZHNlc3Npb25pZAk9IHZhcnNbInJ3ZF9zZXNzaW9uIl0KICAgICAgICBv
# bGRzZXNzaW9uaWQJPSByZXEuY29va2llc1sic2Vzc2lvbmlkIl0KCgkJIyBS
# ZXRyaWV2ZSBzZXNzaW9uLgoKICAgICAgICBzZXNzaW9uCT0gQHNlc3Npb25z
# W29sZHNlc3Npb25pZF0KCgkJIyBFdmVudHVhbGx5IGNyZWF0ZSBuZXcgc2Vz
# c2lvbi4KCiAgICAgICAgaWYgc2Vzc2lvbi5uaWw/CiAgICAgICAgICBzZXNz
# aW9uaWQJPSBNRDUubmV3KHJlcS5wZWVyYWRkclszXS50b19zICsgQG9iamVj
# dC5pbnNwZWN0LnRvX3MgKyAoIiUxLjZmIiAlIFRpbWUubm93LnRvX2YpKS50
# b19zCXdoaWxlIChzZXNzaW9uaWQgPT0gbmlsIG9yIEBzZXNzaW9ucy5pbmNs
# dWRlPyhzZXNzaW9uaWQpKQogICAgICAgICAgc2Vzc2lvbgkJPSBSV0RTZXNz
# aW9uLm5ldyhzZXNzaW9uaWQpCgogICAgICAgICAgaWYgYXV0aC5uaWw/CiAg
# ICAgICAgICAgIHNlc3Npb25bIm9iamVjdCJdCQk9IEBvYmplY3QKICAgICAg
# ICAgIGVsc2UKICAgICAgICAgICAgc2Vzc2lvblsib2JqZWN0Il0JCT0gQG9i
# amVjdC5jbG9uZQogICAgICAgICAgZW5kCgogICAgICAgICAgaWYgb2xkc2Vz
# c2lvbmlkLm5pbD8gb3Igb2xkc2Vzc2lvbmlkLmVtcHR5PwogICAgICAgICAg
# ICBpZiBub3QgYXV0aC5uaWw/IGFuZCBub3QgYXV0aC5lbXB0eT8gYW5kIG5v
# dCBzZXNzaW9uLmF1dGhlbnRpY2F0ZWQgYW5kIHBhZCAhfiAvXlwvcndkXy8K
# CgkJIyBDaGVjayBhdXRoZW50aWNhdGlvbgoKICAgICAgICAgICAgICB1cwk9
# IHZhcnNbInJ3ZF9hIl0KICAgICAgICAgICAgICBwYQk9IHZhcnNbInJ3ZF9i
# Il0KCiAgICAgICAgICAgICAgaWYgdXMubmlsPyBvciBwYS5uaWw/IG9yIGF1
# dGhzW3VzXSAhPSBwYQogICAgICAgICAgICAgICAgc2Vzc2lvbgkJCQk9IFJX
# RFNlc3Npb24ubmV3CiAgICAgICAgICAgICAgICBzZXNzaW9uWyJvYmplY3Qi
# XQkJPSBSV0RMb2dpbi5uZXcocmVhbG0pCiAgICAgICAgICAgICAgICBwYWQJ
# CQkJPSAiLyIKICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBz
# ZXNzaW9uLmF1dGhlbnRpY2F0ZWQJCT0gdHJ1ZQogICAgICAgICAgICAgICAg
# QHNlc3Npb25zW3Nlc3Npb24uc2Vzc2lvbmlkXQk9IHNlc3Npb24KICAgICAg
# ICAgICAgICBlbmQKICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgIHNl
# c3Npb24uYXV0aGVudGljYXRlZAkJPSB0cnVlCiAgICAgICAgICAgICAgQHNl
# c3Npb25zW3Nlc3Npb24uc2Vzc2lvbmlkXQk9IHNlc3Npb24KICAgICAgICAg
# ICAgZW5kCiAgICAgICAgICBlbHNlCiAgICAgICAgICAgIHNlc3Npb24JCT0g
# UldEU2Vzc2lvbi5uZXcKICAgICAgICAgICAgc2Vzc2lvblsib2JqZWN0Il0J
# PSBSV0RUaW1lT3V0Lm5ldwogICAgICAgICAgZW5kCgogICAgICAgICAgdmFy
# cwk9IHt9CiAgICAgICAgZW5kCgoJCSMgQXZvaWQgdGltZW91dC4KCiAgICAg
# ICAgc2Vzc2lvbi50b3VjaAoKICAgICAgICBpZiBwYWQgPT0gIi8iCgoJCSMg
# U2VydmUgbWV0aG9kcy9jYWxsYmFja3MuCgoJCSMgQnVpbGQgbmV3IHBhZ2Uu
# CgogICAgICAgICAgZG93bmxvYWQJPSAiIgogICAgICAgICAgZG93bmxvYWRm
# aWxlCT0gIiIKICAgICAgICAgIHJlcwkJPSAiIgoKICAgICAgICAgIGRvbmUJ
# PSBzZXNzaW9uLnJlbmRlcihyZXMsIHBhZCwgdmFycywgZG93bmxvYWQsIGRv
# d25sb2FkZmlsZSwgcmVxLnBkYT8pCgogICAgICAgICAgYmVnaW4KICAgICAg
# ICAgICAgaWYgZG93bmxvYWQuZW1wdHk/CiAgICAgICAgICAgICAgcmVzcFsi
# Q29udGVudC1UeXBlIl0JCT0gInRleHQvaHRtbCIKICAgICAgICAgICAgICBp
# ZiBkb25lCiAgICAgICAgICAgICAgICByZXNwLmNvb2tpZXNbInNlc3Npb25p
# ZCJdCT0gIiIKICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBy
# ZXNwLmNvb2tpZXNbInNlc3Npb25pZCJdCT0gc2Vzc2lvbi5zZXNzaW9uaWQK
# ICAgICAgICAgICAgICBlbmQKCiAgICAgICAgICAgICAgcmVzcCA8PCByZXMK
# ICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgIHJlc3BbIkNvbnRlbnQt
# VHlwZSJdCQk9ICJhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW0iCiAgICAgICAg
# ICAgICAgcmVzcFsiQ29udGVudC1EaXNwb3NpdGlvbiJdCT0gImF0dGFjaG1l
# bnQ7IgogICAgICAgICAgICAgIHJlc3BbIkNvbnRlbnQtRGlzcG9zaXRpb24i
# XQk9ICJhdHRhY2htZW50OyBmaWxlbmFtZT0lcyIgJSBkb3dubG9hZGZpbGUJ
# dW5sZXNzIGRvd25sb2FkZmlsZS5lbXB0eT8KCiAgICAgICAgICAgICAgcmVz
# cCA8PCBkb3dubG9hZAogICAgICAgICAgICBlbmQKICAgICAgICAgIHJlc2N1
# ZQogICAgICAgICAgICBwdXRzICJTZW5kaW5nIHJlc3BvbnNlIHRvIGJyb3dz
# ZXIgZmFpbGVkLiIKCiAgICAgICAgICAgIEBzZXNzaW9ucy5kZWxldGUoc2Vz
# c2lvbi5zZXNzaW9uaWQpCiAgICAgICAgICBlbmQKCgkJIyBFdmVudHVhbGx5
# IGRlbGV0ZSB0aGlzIHNlc3Npb24uCgogICAgICAgICAgaWYgZG9uZQogICAg
# ICAgICAgICBAc2Vzc2lvbnMuZGVsZXRlKHNlc3Npb24uc2Vzc2lvbmlkKQoK
# ICAgICAgICAgICAgaWYgQGxvY2FsYnJvd3NpbmcKICAgICAgICAgICAgICBy
# ZXNwLnN0b3AKCiAgICAgICAgICAgICAgaWYgQGJyb3dzZXJzdGFydGVkIGFu
# ZCBub3QgQGJyb3dzZXJ0aHJlYWQubmlsPyBhbmQgQGJyb3dzZXJ0aHJlYWQu
# YWxpdmU/CiAgICAgICAgICAgICAgICByZXNwLnN0b3AgZG8KICAgICAgICAg
# ICAgICAgICAgcHV0cyAiV2FpdGluZyBmb3IgdGhlIGJyb3dzZXIgdG8gdGVy
# bWluYXRlLi4uIgoKICAgICAgICAgICAgICAgICAgQGJyb3dzZXJ0aHJlYWQu
# am9pbgogICAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgICAgZW5kCiAg
# ICAgICAgICAgIGVuZAogICAgICAgICAgZW5kCgogICAgICAgIGVsc2UKCgkJ
# IyBTZXJ2ZSBmaWxlcy4KCiAgICAgICAgICBpZiBwYWQgPT0gIi9yd2RfcGl4
# ZWwuZ2lmIgogICAgICAgICAgICByZXNwWyJDYWNoZS1Db250cm9sIl0JPSAi
# bWF4LWFnZT04NjQwMCIKICAgICAgICAgICAgcmVzcFsiQ29udGVudC1UeXBl
# Il0JPSAiaW1hZ2UvZ2lmIgogICAgICAgICAgICByZXNwIDw8ICRyd2RfcGl4
# ZWwKICAgICAgICAgIGVsc2UKICAgICAgICAgICAgaWYgc2Vzc2lvbi5hdXRo
# ZW50aWNhdGVkCiAgICAgICAgICAgICAgcHdkCT0gRGlyLnB3ZAogICAgICAg
# ICAgICAgIGZpbGUJPSBGaWxlLmV4cGFuZF9wYXRoKHBhZC5nc3ViKC9eXC8q
# LywgIiIpLCAkcndkX2ZpbGVzKQoKICAgICAgICAgICAgICBpZiBub3QgZmls
# ZS5pbmRleChwd2QpID09IDAKICAgICAgICAgICAgICAgIHJlc3BbIkNvbnRl
# bnQtVHlwZSJdCT0gInRleHQvaHRtbCIKICAgICAgICAgICAgICAgIHJlc3Au
# cmVzcG9uc2UJCT0gIkhUVFAvMS4wIDQwMCBCQUQgUkVRVUVTVCIKICAgICAg
# ICAgICAgICAgIHJlc3AgPDwgIjxodG1sPjxib2R5PjxwPjxiPkJhZCBSZXF1
# ZXN0LjwvYj4gKDx0dD4je3BhZH08L3R0Pik8L3A+PC9ib2R5PjwvaHRtbD4i
# CiAgICAgICAgICAgICAgZWxzaWYgRmlsZS5maWxlPyhmaWxlKQogICAgICAg
# ICAgICAgICAgcmVzcCA8PCBGaWxlLm5ldyhmaWxlLCAicmIiKS5yZWFkCXJl
# c2N1ZSBuaWwKICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBy
# ZXNwWyJDb250ZW50LVR5cGUiXQk9ICJ0ZXh0L2h0bWwiCiAgICAgICAgICAg
# ICAgICByZXNwLnJlc3BvbnNlCQk9ICJIVFRQLzEuMCA0MDQgTk9UIEZPVU5E
# IgogICAgICAgICAgICAgICAgcmVzcCA8PCAiPGh0bWw+PGJvZHk+PHA+PGI+
# Tm90IGZvdW5kLjwvYj4gKDx0dD4je3BhZH08L3R0Pik8L3A+PC9ib2R5Pjwv
# aHRtbD4iCiAgICAgICAgICAgICAgZW5kCiAgICAgICAgICAgIGVsc2UKICAg
# ICAgICAgICAgICByZXNwWyJDb250ZW50LVR5cGUiXQk9ICJ0ZXh0L2h0bWwi
# CiAgICAgICAgICAgICAgcmVzcC5yZXNwb25zZQkJPSAiSFRUUC8xLjAgPz8/
# IE5PVCBBVVRIT1JJWkVEIgogICAgICAgICAgICAgIHJlc3AgPDwgIjxodG1s
# Pjxib2R5PjxwPjxiPk5vdCBBdXRob3JpemVkLjwvYj48L3A+PC9ib2R5Pjwv
# aHRtbD4iCiAgICAgICAgICAgIGVuZAogICAgICAgICAgZW5kCgogICAgICAg
# IGVuZAoKICAgICAgZW5kCiAgICBlbmQKICBlbmQKZW5kCgokcndkX2h0bWxb
# IkRFRkFVTFQiXQk9ICIKPCEtLSBHZW5lcmF0ZWQgYnkgUnVieVdlYkRpYWxv
# Zy4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
# ICAgIC0tPgo8IS0tIEZvciBtb3JlIGluZm9ybWF0aW9uLCBwbGVhc2UgY29u
# dGFjdCBFcmlrIFZlZW5zdHJhIDxyd2RAZXJpa3ZlZW4uZGRzLm5sPi4gLS0+
# CjxodG1sPgogIDxoZWFkPgogICAgPHRpdGxlPiVUSVRMRSU8L3RpdGxlPgoK
# ICAgIDxtZXRhIGh0dHAtZXF1aXY9J0NvbnRlbnQtVHlwZScgY29udGVudD0n
# dGV4dC9odG1sOyBjaGFyc2V0PSVDSEFSU0VUJSc+CiAgICA8bWV0YSBodHRw
# LWVxdWl2PSdDb250ZW50LVN0eWxlLVR5cGUnIGNvbnRlbnQ9J3RleHQvY3Nz
# Jz4KICAgIDxtZXRhIGh0dHAtZXF1aXY9J1JlZnJlc2gnIGNvbnRlbnQ9JyVS
# RUZSRVNIJSwgamF2YXNjcmlwdDpkb2N1bWVudC5ib2R5Zm9ybS5zdWJtaXQo
# KTsnPgoKICAgIDxsaW5rIHJlbD0nc2hvcnRjdXQgaWNvbicgaHJlZj0nJUxP
# R08lJz4KCiAgICA8c3R5bGUgdHlwZT0ndGV4dC9jc3MnPgogICAgPCEtLQoK
# CWJvZHkgewoJCWJhY2tncm91bmQJCTogdXJsKCVXQVRFUk1BUkslKSB3aGl0
# ZSBjZW50ZXIgY2VudGVyIG5vLXJlcGVhdCBmaXhlZDsKCX0KCglhIHsKCQl0
# ZXh0LWRlY29yYXRpb24JCTogbm9uZTsKCX0KCglhOmhvdmVyIHsKCQliYWNr
# Z3JvdW5kCQk6ICNBQUFBQUE7Cgl9CgoJdGQucGFuZWwxIHsKCQlib3JkZXIt
# Y29sb3IJCTogIzg4ODg4OCAjRUVFRUVFICNFRUVFRUUgIzg4ODg4ODsKCQli
# b3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJOiBzb2xpZCBz
# b2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5wYW5lbDIgewoJCWJvcmRlci1j
# b2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVFRUVFOwoJCWJv
# cmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IHNvbGlkIHNv
# bGlkIHNvbGlkIHNvbGlkOwoJfQoKCXRkLnBhbmVsMWhpZ2ggewoJCWJvcmRl
# ci1jb2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVFRUVFOwoJ
# CWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IHNvbGlk
# IHNvbGlkIHNvbGlkIHNvbGlkOwoJfQoKCXRkLnBhbmVsMmhpZ2ggewoJCWJv
# cmRlci1jb2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVFRUVF
# OwoJCWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IG5v
# bmUgbm9uZSBub25lIG5vbmU7Cgl9CgoJdGQucGFuZWwxbG93IHsKCQlib3Jk
# ZXItY29sb3IJCTogIzg4ODg4OCAjRUVFRUVFICNFRUVFRUUgIzg4ODg4ODsK
# CQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJOiBzb2xp
# ZCBzb2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5wYW5lbDJsb3cgewoJCWJv
# cmRlci1jb2xvcgkJOiAjODg4ODg4ICNFRUVFRUUgI0VFRUVFRSAjODg4ODg4
# OwoJCWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IG5v
# bmUgbm9uZSBub25lIG5vbmU7Cgl9CgoJdGQudGFiYmxhZCB7CgkJYm9yZGVy
# LWNvbG9yCQk6ICNFRUVFRUUgIzg4ODg4OCAjODg4ODg4ICNFRUVFRUU7CgkJ
# Ym9yZGVyLXdpZHRoCQk6IDFwdDsKCQlib3JkZXItc3R5bGUJCTogbm9uZSBz
# b2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5wYXNzaXZldGFiIHsKICAgICAg
# ICAgICAgICAgIGJhY2tncm91bmQtY29sb3IJOiAjQkJCQkJCOwoJCWJvcmRl
# ci1jb2xvcgkJOiAjREREREREICNEREREREQgI0VFRUVFRSAjREREREREOwoJ
# CWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IHNvbGlk
# IHNvbGlkIHNvbGlkIHNvbGlkOwoJfQoKCXRkLmFjdGl2ZXRhYiB7CgkJYm9y
# ZGVyLWNvbG9yCQk6ICNFRUVFRUUgIzg4ODg4OCAjODg4ODg4ICNFRUVFRUU7
# CgkJYm9yZGVyLXdpZHRoCQk6IDFwdDsKCQlib3JkZXItc3R5bGUJCTogc29s
# aWQgc29saWQgbm9uZSBzb2xpZDsKCX0KCgl0ZC5ub3RhYiB7CgkJYm9yZGVy
# LWNvbG9yCQk6ICNFRUVFRUUgI0VFRUVFRSAjRUVFRUVFICNFRUVFRUU7CgkJ
# Ym9yZGVyLXdpZHRoCQk6IDFwdDsKCQlib3JkZXItc3R5bGUJCTogbm9uZSBu
# b25lIHNvbGlkIG5vbmU7Cgl9CgogICAgLy8tLT4KICAgIDwvc3R5bGU+Cgog
# ICAgPHNjcmlwdCB0eXBlPSd0ZXh0L2phdmFzY3JpcHQnPgogICAgPCEtLQog
# ICAgICBmdW5jdGlvbiBCb2R5R28oKSB7CiAgICAgICAgJFJXRF9GT0NVUyQK
# ICAgICAgfQogICAgLy8tLT4KICAgIDwvc2NyaXB0PgogIDwvaGVhZD4KCiAg
# PGJvZHkgYmdjb2xvcj0nd2hpdGUnIG9ubG9hZD0nQm9keUdvKCknIGxpbms9
# JyMwMDAwMDAnIHZsaW5rPScjMDAwMDAwJyBhbGluaz0nIzAwMDAwMCc+CiAg
# ICA8Zm9ybSBuYW1lPSdib2R5Zm9ybScgYWN0aW9uPScvJyBtZXRob2Q9J3Bv
# c3QnPgogICAgICA8dGFibGUgYWxpZ249J2NlbnRlcicgYm9yZGVyPScwJyBj
# ZWxsc3BhY2luZz0nMCcgY2VsbHBhZGRpbmc9JzAnIHdpZHRoPScxMDAlJyBo
# ZWlnaHQ9JzEwMCUnPgogICAgICAgIDx0ciBhbGlnbj0nY2VudGVyJyB2YWxp
# Z249J21pZGRsZSc+CiAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcic+Cgog
# ICAgICAgICAgICA8dGFibGUgYWxpZ249J2NlbnRlcicgYm9yZGVyPScwJyBj
# ZWxsc3BhY2luZz0nMCcgY2VsbHBhZGRpbmc9JzAnPgoKICAgICAgICAgICAg
# ICA8dHIgYWxpZ249J2NlbnRlcic+CiAgICAgICAgICAgICAgICA8dGQgYWxp
# Z249J2NlbnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4
# ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAg
# ICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48aW1n
# IHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90
# ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyAgICAgICAg
# ICAgICAgICA+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScg
# d2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAg
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSdibGFj
# ayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9
# JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicg
# Ymdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWln
# aHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFs
# aWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48aW1nIHNyYz0ncndkX3Bp
# eGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAg
# ICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyAgICAgICAgICAgICAgICA+PGlt
# ZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwv
# dGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgICAgICAg
# ICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEn
# IHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdj
# ZW50ZXInICAgICAgICAgICAgICAgID48aW1nIHNyYz0ncndkX3BpeGVsLmdp
# ZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICA8
# L3RyPgoKICAgICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+CiAgICAg
# ICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgICAgICAgICAgICAgICAg
# PjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScx
# Jz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAg
# ICAgICAgICAgICAgID48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0
# PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGln
# bj0nY2VudGVyJyBiZ2NvbG9yPSdibGFjayc+PGltZyBzcmM9J3J3ZF9waXhl
# bC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAg
# ICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcg
# c3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3Rk
# PgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9
# J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3
# aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2Vu
# dGVyJyBiZ2NvbG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYn
# IGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8
# dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdy
# d2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAg
# ICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNr
# Jz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0n
# MSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBi
# Z2NvbG9yPSdibGFjayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdo
# dD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxp
# Z249J2NlbnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4
# ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAg
# ICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48aW1n
# IHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90
# ZD4KICAgICAgICAgICAgICA8L3RyPgoKICAgICAgICAgICAgICA8dHIgYWxp
# Z249J2NlbnRlcic+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRl
# cicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBo
# ZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRk
# IGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48aW1nIHNyYz0ncndk
# X3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAg
# ICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSd3aGl0ZSc+
# PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEn
# PjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdj
# b2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9
# JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWdu
# PSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVs
# LmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAg
# ICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1n
# IHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90
# ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9y
# PSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScg
# d2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAg
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSdibGFj
# ayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9
# JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicg
# ICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWln
# aHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgIDwvdHI+Cgog
# ICAgICAgICAgICAgIDx0ciBhbGlnbj0nY2VudGVyJz4KICAgICAgICAgICAg
# ICAgIDx0ZCBhbGlnbj0nY2VudGVyJyAgICAgICAgICAgICAgICA+PGltZyBz
# cmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+
# CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0n
# YmxhY2snPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdp
# ZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50
# ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicg
# aGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0
# ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVF
# RUVFJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0
# aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVy
# JyBiZ2NvbG9yPScjRUVFRUVFJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicg
# aGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0
# ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVF
# RUVFJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0
# aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVy
# JyBiZ2NvbG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2Rf
# cGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICA8L3RyPgoKICAgICAgICAgICAgICA8dHIg
# YWxpZ249J2NlbnRlcic+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAg
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSd3aGl0
# ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9
# JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicg
# Ymdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2Rf
# cGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2Nv
# bG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0n
# MScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249
# J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhl
# bC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAg
# ICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcg
# c3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3Rk
# PgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9
# J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3
# aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2Vu
# dGVyJyBiZ2NvbG9yPSdibGFjayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYn
# IGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgPC90
# cj4KCiAgICAgICAgICAgICAgPHRyIGFsaWduPSdjZW50ZXInPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2Nv
# bG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0n
# MScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249
# J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhl
# bC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAg
# ICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGlt
# ZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwv
# dGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xv
# cj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEn
# IHdpZHRoPScxJz48L3RkPgoKICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0n
# Y2VudGVyJz4KCiAgICAgICAgICAgICAgICAgIDx0YWJsZSBhbGlnbj0nY2Vu
# dGVyJyBib3JkZXI9JzAnIGNlbGxzcGFjaW5nPScwJyBjZWxscGFkZGluZz0n
# MCcgJVdJRFRIMSU+CiAgICAgICAgICAgICAgICAgICAgPHRyIGFsaWduPSdj
# ZW50ZXInPgogICAgICAgICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50
# ZXInIGJnY29sb3I9JyM0NDQ0ODgnPgoKICAgICAgICAgICAgICAgICAgICAg
# ICAgPHRhYmxlIGFsaWduPSdsZWZ0JyBib3JkZXI9JzAnIGNlbGxzcGFjaW5n
# PScxJyBjZWxscGFkZGluZz0nMCc+CiAgICAgICAgICAgICAgICAgICAgICAg
# ICAgPHRyIGFsaWduPSdjZW50ZXInPgogICAgICAgICAgICAgICAgICAgICAg
# ICAgICAgPHRkIGFsaWduPSdib3JkZXInPjxpbWcgc3JjPSclTE9HTyUnIHdp
# ZHRoPScxNCcgaGVpZ2h0PScxNCc+PC90ZD4KICAgICAgICAgICAgICAgICAg
# ICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJz48Yj48c21hbGw+PGZvbnQg
# Y29sb3I9JyNGRkZGRkYnPiZuYnNwOyVUSVRMRSUmbmJzcDs8L2ZvbnQ+PC9z
# bWFsbD48L2I+PC90ZD4KICAgICAgICAgICAgICAgICAgICAgICAgICA8L3Ry
# PgogICAgICAgICAgICAgICAgICAgICAgICA8L3RhYmxlPgoKICAgICAgICAg
# ICAgICAgICAgICAgICAgPHRhYmxlIGFsaWduPSdyaWdodCcgYm9yZGVyPScw
# JyBjZWxsc3BhY2luZz0nMScgY2VsbHBhZGRpbmc9JzAnPgogICAgICAgICAg
# ICAgICAgICAgICAgICAgIDx0ciBhbGlnbj0nY2VudGVyJz4KICAgICAgICAg
# ICAgICAgICAgICAgICAgICAgIDwhLS0gJUhFTFBCVVRUT04lICAtLT48dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGI+PHNtYWxsPjxh
# IGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9keWZvcm0ucndkX2FjdGlv
# bi52YWx1ZT1cInJ3ZF9oZWxwXCI7ZG9jdW1lbnQuYm9keWZvcm0uc3VibWl0
# KCk7Jz4mbmJzcDs/Jm5ic3A7PC9hPjwvc21hbGw+PC9iPjwvdGQ+CiAgICAg
# ICAgICAgICAgICAgICAgICAgICAgICA8IS0tICVCQUNLQlVUVE9OUyUgLS0+
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9JyNFRUVFRUUnPjxiPjxzbWFs
# bD48YSBocmVmPSdqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnJ3ZF9h
# Y3Rpb24udmFsdWU9XCJyd2RfbWFpblwiO2RvY3VtZW50LmJvZHlmb3JtLnN1
# Ym1pdCgpOyc+Jm5ic3A7Jmx0OyZsdDsmbmJzcDs8L2E+PC9zbWFsbD48L2I+
# PC90ZD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwhLS0gJUJBQ0tC
# VVRUT05TJSAtLT48dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVF
# RSc+PGI+PHNtYWxsPjxhIGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9k
# eWZvcm0ucndkX2FjdGlvbi52YWx1ZT1cInJ3ZF9iYWNrXCI7ZG9jdW1lbnQu
# Ym9keWZvcm0uc3VibWl0KCk7Jz4mbmJzcDsmbHQ7Jm5ic3A7PC9hPjwvc21h
# bGw+PC9iPjwvdGQ+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8IS0t
# ICVDTE9TRUJVVFRPTiUgLS0+PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9
# JyNFRUVFRUUnPjxiPjxzbWFsbD48YSBocmVmPSdqYXZhc2NyaXB0OmRvY3Vt
# ZW50LmJvZHlmb3JtLnJ3ZF9hY3Rpb24udmFsdWU9XCJyd2RfcXVpdFwiO2Rv
# Y3VtZW50LmJvZHlmb3JtLnN1Ym1pdCgpOyc+Jm5ic3A7WCZuYnNwOzwvYT48
# L3NtYWxsPjwvYj48L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgIDwv
# dHI+CiAgICAgICAgICAgICAgICAgICAgICAgIDwvdGFibGU+CgogICAgICAg
# ICAgICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICAgICAgICA8L3Ry
# PgoKICAgICAgICAgICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+CiAg
# ICAgICAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xv
# cj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEn
# IHdpZHRoPSclV0lEVEgyJSc+PC90ZD4KICAgICAgICAgICAgICAgICAgICA8
# L3RyPgoKICAgICAgICAgICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+
# CiAgICAgICAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdj
# b2xvcj0nI0NDQ0NDQyc+CiAgICAgICAgICAgICAgICAgICAgICAgIDx0YWJs
# ZSBhbGlnbj0nY2VudGVyJyBib3JkZXI9JzAnIGNlbGxzcGFjaW5nPSczJyBj
# ZWxscGFkZGluZz0nMCc+CiAgICAgICAgICAgICAgICAgICAgICAgICAgJUJP
# RFklCiAgICAgICAgICAgICAgICAgICAgICAgIDwvdGFibGU+CgogICAgICAg
# ICAgICAgICAgICAgICAgICA8aW5wdXQgbmFtZT0ncndkX2FjdGlvbicgdmFs
# dWU9JyRSV0RfRklSU1RBQ1RJT04kJyB0eXBlPSdoaWRkZW4nPgogICAgICAg
# ICAgICAgICAgICAgICAgICA8aW5wdXQgbmFtZT0ncndkX3Nlc3Npb24nIHZh
# bHVlPSckUldEX1NFU1NJT04kJyB0eXBlPSdoaWRkZW4nPgogICAgICAgICAg
# ICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICAgICAgICA8L3RyPgog
# ICAgICAgICAgICAgICAgICA8L3RhYmxlPgoKICAgICAgICAgICAgICAgIDwv
# dGQ+CgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29s
# b3I9J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScx
# JyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0n
# Y2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1nIHNyYz0ncndkX3BpeGVs
# LmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAg
# ICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1n
# IHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90
# ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9y
# PSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScg
# d2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgIDwv
# dHI+CgogICAgICAgICAgICAgIDx0ciBhbGlnbj0nY2VudGVyJz4KICAgICAg
# ICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSdibGFjayc+
# PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEn
# PjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdj
# b2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9
# JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWdu
# PSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVs
# LmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAg
# ICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48aW1n
# IHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90
# ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9y
# PSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScg
# d2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAg
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjRUVF
# RUVFJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0
# aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVy
# JyBiZ2NvbG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2Rf
# cGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICA8L3RyPgoKICAgICAgICAgICAgICA8dHIg
# YWxpZ249J2NlbnRlcic+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2Nl
# bnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lm
# JyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAg
# PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48aW1nIHNyYz0n
# cndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAg
# ICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSd3aGl0
# ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9
# JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicg
# Ymdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3
# ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAg
# ICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVF
# RSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9
# JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicg
# Ymdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3
# ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAg
# ICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUn
# PjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScx
# Jz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJn
# Y29sb3I9J2JsYWNrJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0
# PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGln
# bj0nY2VudGVyJyAgICAgICAgICAgICAgICA+PGltZyBzcmM9J3J3ZF9waXhl
# bC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAg
# ICAgPC90cj4KCiAgICAgICAgICAgICAgPHRyIGFsaWduPSdjZW50ZXInPgog
# ICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAg
# ICAgID48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0
# aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVy
# JyBiZ2NvbG9yPSdibGFjayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2Rf
# cGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2Nv
# bG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0n
# MScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249
# J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGltZyBzcmM9J3J3ZF9waXhl
# bC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAg
# ICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nd2hpdGUnPjxpbWcg
# c3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3Rk
# PgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9
# J3doaXRlJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3
# aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2Vu
# dGVyJyBiZ2NvbG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYn
# IGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8
# dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdy
# d2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAg
# ICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAg
# ID48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0n
# MSc+PC90ZD4KICAgICAgICAgICAgICA8L3RyPgoKICAgICAgICAgICAgICA8
# dHIgYWxpZ249J2NlbnRlcic+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249
# J2NlbnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwu
# Z2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAg
# ICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48aW1nIHNy
# Yz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4K
# ICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSdi
# bGFjayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lk
# dGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRl
# cicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBo
# ZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRk
# IGFsaWduPSdjZW50ZXInIGJnY29sb3I9J3doaXRlJz48aW1nIHNyYz0ncndk
# X3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAg
# ICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSd3aGl0ZSc+
# PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEn
# PjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdj
# b2xvcj0nd2hpdGUnPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9
# JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWdu
# PSdjZW50ZXInIGJnY29sb3I9J2JsYWNrJz48aW1nIHNyYz0ncndkX3BpeGVs
# LmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAg
# ICAgIDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSdibGFjayc+PGltZyBz
# cmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+
# CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgICAgICAgICAg
# ICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdp
# ZHRoPScxJz48L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50
# ZXInICAgICAgICAgICAgICAgID48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicg
# aGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICA8L3Ry
# PgoKICAgICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+CiAgICAgICAg
# ICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgICAgICAgICAgICAgICAgPjxp
# bWcgc3JjPSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48
# L3RkPgogICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAg
# ICAgICAgICAgID48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScx
# JyB3aWR0aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0n
# Y2VudGVyJyAgICAgICAgICAgICAgICA+PGltZyBzcmM9J3J3ZF9waXhlbC5n
# aWYnIGhlaWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAg
# ICA8dGQgYWxpZ249J2NlbnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3Jj
# PSdyd2RfcGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgog
# ICAgICAgICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9J2Js
# YWNrJz48aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0
# aD0nMSc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVy
# JyBiZ2NvbG9yPSdibGFjayc+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhl
# aWdodD0nMScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nYmxhY2snPjxpbWcgc3JjPSdyd2Rf
# cGl4ZWwuZ2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAg
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48
# aW1nIHNyYz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+
# PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBhbGlnbj0nY2VudGVyJyAgICAg
# ICAgICAgICAgICA+PGltZyBzcmM9J3J3ZF9waXhlbC5naWYnIGhlaWdodD0n
# MScgd2lkdGg9JzEnPjwvdGQ+CiAgICAgICAgICAgICAgICA8dGQgYWxpZ249
# J2NlbnRlcicgICAgICAgICAgICAgICAgPjxpbWcgc3JjPSdyd2RfcGl4ZWwu
# Z2lmJyBoZWlnaHQ9JzEnIHdpZHRoPScxJz48L3RkPgogICAgICAgICAgICAg
# ICAgPHRkIGFsaWduPSdjZW50ZXInICAgICAgICAgICAgICAgID48aW1nIHNy
# Yz0ncndkX3BpeGVsLmdpZicgaGVpZ2h0PScxJyB3aWR0aD0nMSc+PC90ZD4K
# ICAgICAgICAgICAgICA8L3RyPgoKICAgICAgICAgICAgPC90YWJsZT4KCiAg
# ICAgICAgICA8L3RkPgogICAgICAgIDwvdHI+CiAgICAgIDwvdGFibGU+CiAg
# ICA8L2Zvcm0+CiAgPC9ib2R5Pgo8L2h0bWw+CiIKCiRyd2RfaHRtbFsiV0lO
# RE9XU0xPT0tBTElLRSJdCT0gIgo8IS0tIEdlbmVyYXRlZCBieSBSdWJ5V2Vi
# RGlhbG9nLiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
# ICAgICAgICAgLS0+CjwhLS0gRm9yIG1vcmUgaW5mb3JtYXRpb24sIHBsZWFz
# ZSBjb250YWN0IEVyaWsgVmVlbnN0cmEgPHJ3ZEBlcmlrdmVlbi5kZHMubmw+
# LiAtLT4KPGh0bWw+CiAgPGhlYWQ+CiAgICA8dGl0bGU+JVRJVExFJTwvdGl0
# bGU+CgogICAgPG1ldGEgaHR0cC1lcXVpdj0nQ29udGVudC1UeXBlJyBjb250
# ZW50PSd0ZXh0L2h0bWw7IGNoYXJzZXQ9JUNIQVJTRVQlJz4KICAgIDxtZXRh
# IGh0dHAtZXF1aXY9J0NvbnRlbnQtU3R5bGUtVHlwZScgY29udGVudD0ndGV4
# dC9jc3MnPgogICAgPG1ldGEgaHR0cC1lcXVpdj0nUmVmcmVzaCcgY29udGVu
# dD0nJVJFRlJFU0glLCBqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnN1
# Ym1pdCgpOyc+CgogICAgPGxpbmsgcmVsPSdzaG9ydGN1dCBpY29uJyBocmVm
# PSclTE9HTyUnPgoKICAgIDxzdHlsZSB0eXBlPSd0ZXh0L2Nzcyc+CiAgICA8
# IS0tCgoJYm9keSB7CgkJYmFja2dyb3VuZAkJOiB1cmwoJVdBVEVSTUFSSyUp
# IHdoaXRlIGNlbnRlciBjZW50ZXIgbm8tcmVwZWF0IGZpeGVkOwoJfQoKCWEg
# ewoJCXRleHQtZGVjb3JhdGlvbgkJOiBub25lOwoJfQoKCWE6aG92ZXIgewoJ
# CWJhY2tncm91bmQJCTogI0FBQUFBQTsKCX0KCgl0ZC53aW5kb3cgewoJCWJv
# cmRlci1jb2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVFRUVF
# OwoJCWJvcmRlci13aWR0aAkJOiAzcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IHNv
# bGlkIHNvbGlkIHNvbGlkIHNvbGlkOwoJfQoKCXRkLnBhbmVsMSB7CgkJYm9y
# ZGVyLWNvbG9yCQk6ICM4ODg4ODggI0VFRUVFRSAjRUVFRUVFICM4ODg4ODg7
# CgkJYm9yZGVyLXdpZHRoCQk6IDFwdDsKCQlib3JkZXItc3R5bGUJCTogc29s
# aWQgc29saWQgc29saWQgc29saWQ7Cgl9CgoJdGQucGFuZWwyIHsKCQlib3Jk
# ZXItY29sb3IJCTogI0VFRUVFRSAjODg4ODg4ICM4ODg4ODggI0VFRUVFRTsK
# CQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJOiBzb2xp
# ZCBzb2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5wYW5lbDFoaWdoIHsKCQli
# b3JkZXItY29sb3IJCTogI0VFRUVFRSAjODg4ODg4ICM4ODg4ODggI0VFRUVF
# RTsKCQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJOiBz
# b2xpZCBzb2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5wYW5lbDJoaWdoIHsK
# CQlib3JkZXItY29sb3IJCTogI0VFRUVFRSAjODg4ODg4ICM4ODg4ODggI0VF
# RUVFRTsKCQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJ
# OiBub25lIG5vbmUgbm9uZSBub25lOwoJfQoKCXRkLnBhbmVsMWxvdyB7CgkJ
# Ym9yZGVyLWNvbG9yCQk6ICM4ODg4ODggI0VFRUVFRSAjRUVFRUVFICM4ODg4
# ODg7CgkJYm9yZGVyLXdpZHRoCQk6IDFwdDsKCQlib3JkZXItc3R5bGUJCTog
# c29saWQgc29saWQgc29saWQgc29saWQ7Cgl9CgoJdGQucGFuZWwybG93IHsK
# CQlib3JkZXItY29sb3IJCTogIzg4ODg4OCAjRUVFRUVFICNFRUVFRUUgIzg4
# ODg4ODsKCQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJ
# OiBub25lIG5vbmUgbm9uZSBub25lOwoJfQoKCXRkLnRhYmJsYWQgewoJCWJv
# cmRlci1jb2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVFRUVF
# OwoJCWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IG5v
# bmUgc29saWQgc29saWQgc29saWQ7Cgl9CgoJdGQucGFzc2l2ZXRhYiB7CiAg
# ICAgICAgICAgICAgICBiYWNrZ3JvdW5kLWNvbG9yCTogI0JCQkJCQjsKCQli
# b3JkZXItY29sb3IJCTogI0RERERERCAjREREREREICNFRUVFRUUgI0RERERE
# RDsKCQlib3JkZXItd2lkdGgJCTogMXB0OwoJCWJvcmRlci1zdHlsZQkJOiBz
# b2xpZCBzb2xpZCBzb2xpZCBzb2xpZDsKCX0KCgl0ZC5hY3RpdmV0YWIgewoJ
# CWJvcmRlci1jb2xvcgkJOiAjRUVFRUVFICM4ODg4ODggIzg4ODg4OCAjRUVF
# RUVFOwoJCWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6
# IHNvbGlkIHNvbGlkIG5vbmUgc29saWQ7Cgl9CgoJdGQubm90YWIgewoJCWJv
# cmRlci1jb2xvcgkJOiAjRUVFRUVFICNFRUVFRUUgI0VFRUVFRSAjRUVFRUVF
# OwoJCWJvcmRlci13aWR0aAkJOiAxcHQ7CgkJYm9yZGVyLXN0eWxlCQk6IG5v
# bmUgbm9uZSBzb2xpZCBub25lOwoJfQoKICAgIC8vLS0+CiAgICA8L3N0eWxl
# PgoKICAgIDxzY3JpcHQgdHlwZT0ndGV4dC9qYXZhc2NyaXB0Jz4KICAgIDwh
# LS0KICAgICAgZnVuY3Rpb24gQm9keUdvKCkgewogICAgICAgICRSV0RfRk9D
# VVMkCiAgICAgIH0KICAgIC8vLS0+CiAgICA8L3NjcmlwdD4KICA8L2hlYWQ+
# CgogIDxib2R5IGJnY29sb3I9J3doaXRlJyBvbmxvYWQ9J0JvZHlHbygpJyBs
# aW5rPScjMDAwMDAwJyB2bGluaz0nIzAwMDAwMCcgYWxpbms9JyMwMDAwMDAn
# PgogICAgPGZvcm0gbmFtZT0nYm9keWZvcm0nIGFjdGlvbj0nLycgbWV0aG9k
# PSdwb3N0Jz4KICAgICAgPHRhYmxlIGFsaWduPSdjZW50ZXInIGJvcmRlcj0n
# MCcgY2VsbHNwYWNpbmc9JzAnIGNlbGxwYWRkaW5nPScwJyB3aWR0aD0nMTAw
# JScgaGVpZ2h0PScxMDAlJz4KICAgICAgICA8dHIgYWxpZ249J2NlbnRlcicg
# dmFsaWduPSdtaWRkbGUnPgogICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXIn
# PgoKICAgICAgICAgICAgPHRhYmxlIGFsaWduPSdjZW50ZXInIGJvcmRlcj0n
# MCcgY2VsbHNwYWNpbmc9JzAnIGNlbGxwYWRkaW5nPScwJz4KCiAgICAgICAg
# ICAgICAgPHRyIGFsaWduPSdjZW50ZXInPgogICAgICAgICAgICAgICAgPHRk
# IGFsaWduPSdjZW50ZXInIGNsYXNzPSd3aW5kb3cnPgoKICAgICAgICAgICAg
# ICAgICAgPHRhYmxlIGFsaWduPSdjZW50ZXInIGJvcmRlcj0nMCcgY2VsbHNw
# YWNpbmc9JzAnIGNlbGxwYWRkaW5nPScwJyAlV0lEVEgxJT4KICAgICAgICAg
# ICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+CiAgICAgICAgICAgICAg
# ICAgICAgICA8dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nIzQ0NDQ4OCc+
# CgogICAgICAgICAgICAgICAgICAgICAgICA8dGFibGUgYWxpZ249J2xlZnQn
# IGJvcmRlcj0nMCcgY2VsbHNwYWNpbmc9JzEnIGNlbGxwYWRkaW5nPScwJz4K
# ICAgICAgICAgICAgICAgICAgICAgICAgICA8dHIgYWxpZ249J2NlbnRlcic+
# CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGQgYWxpZ249J2JvcmRl
# cic+PGltZyBzcmM9JyVMT0dPJScgd2lkdGg9JzE0JyBoZWlnaHQ9JzE0Jz48
# L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHRkIGFsaWduPSdj
# ZW50ZXInPjxiPjxzbWFsbD48Zm9udCBjb2xvcj0nI0ZGRkZGRic+Jm5ic3A7
# JVRJVExFJSZuYnNwOzwvZm9udD48L3NtYWxsPjwvYj48L3RkPgogICAgICAg
# ICAgICAgICAgICAgICAgICAgIDwvdHI+CiAgICAgICAgICAgICAgICAgICAg
# ICAgIDwvdGFibGU+CgogICAgICAgICAgICAgICAgICAgICAgICA8dGFibGUg
# YWxpZ249J3JpZ2h0JyBib3JkZXI9JzAnIGNlbGxzcGFjaW5nPScxJyBjZWxs
# cGFkZGluZz0nMCc+CiAgICAgICAgICAgICAgICAgICAgICAgICAgPHRyIGFs
# aWduPSdjZW50ZXInPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPCEt
# LSAlSEVMUEJVVFRPTiUgIC0tPjx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9y
# PScjRUVFRUVFJz48Yj48c21hbGw+PGEgaHJlZj0namF2YXNjcmlwdDpkb2N1
# bWVudC5ib2R5Zm9ybS5yd2RfYWN0aW9uLnZhbHVlPVwicndkX2hlbHBcIjtk
# b2N1bWVudC5ib2R5Zm9ybS5zdWJtaXQoKTsnPiZuYnNwOz8mbmJzcDs8L2E+
# PC9zbWFsbD48L2I+PC90ZD4KICAgICAgICAgICAgICAgICAgICAgICAgICAg
# IDwhLS0gJUJBQ0tCVVRUT05TJSAtLT48dGQgYWxpZ249J2NlbnRlcicgYmdj
# b2xvcj0nI0VFRUVFRSc+PGI+PHNtYWxsPjxhIGhyZWY9J2phdmFzY3JpcHQ6
# ZG9jdW1lbnQuYm9keWZvcm0ucndkX2FjdGlvbi52YWx1ZT1cInJ3ZF9tYWlu
# XCI7ZG9jdW1lbnQuYm9keWZvcm0uc3VibWl0KCk7Jz4mbmJzcDsmbHQ7Jmx0
# OyZuYnNwOzwvYT48L3NtYWxsPjwvYj48L3RkPgogICAgICAgICAgICAgICAg
# ICAgICAgICAgICAgPCEtLSAlQkFDS0JVVFRPTlMlIC0tPjx0ZCBhbGlnbj0n
# Y2VudGVyJyBiZ2NvbG9yPScjRUVFRUVFJz48Yj48c21hbGw+PGEgaHJlZj0n
# amF2YXNjcmlwdDpkb2N1bWVudC5ib2R5Zm9ybS5yd2RfYWN0aW9uLnZhbHVl
# PVwicndkX2JhY2tcIjtkb2N1bWVudC5ib2R5Zm9ybS5zdWJtaXQoKTsnPiZu
# YnNwOyZsdDsmbmJzcDs8L2E+PC9zbWFsbD48L2I+PC90ZD4KICAgICAgICAg
# ICAgICAgICAgICAgICAgICAgIDwhLS0gJUNMT1NFQlVUVE9OJSAtLT48dGQg
# YWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGI+PHNtYWxsPjxh
# IGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9keWZvcm0ucndkX2FjdGlv
# bi52YWx1ZT1cInJ3ZF9xdWl0XCI7ZG9jdW1lbnQuYm9keWZvcm0uc3VibWl0
# KCk7Jz4mbmJzcDtYJm5ic3A7PC9hPjwvc21hbGw+PC9iPjwvdGQ+CiAgICAg
# ICAgICAgICAgICAgICAgICAgICAgPC90cj4KICAgICAgICAgICAgICAgICAg
# ICAgICAgPC90YWJsZT4KCiAgICAgICAgICAgICAgICAgICAgICA8L3RkPgog
# ICAgICAgICAgICAgICAgICAgIDwvdHI+CgogICAgICAgICAgICAgICAgICAg
# IDx0ciBhbGlnbj0nY2VudGVyJz4KICAgICAgICAgICAgICAgICAgICAgIDx0
# ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPSd3aGl0ZSc+PGltZyBzcmM9J3J3
# ZF9waXhlbC5naWYnIGhlaWdodD0nMScgd2lkdGg9JyVXSURUSDIlJz48L3Rk
# PgogICAgICAgICAgICAgICAgICAgIDwvdHI+CgogICAgICAgICAgICAgICAg
# ICAgIDx0ciBhbGlnbj0nY2VudGVyJz4KICAgICAgICAgICAgICAgICAgICAg
# IDx0ZCBhbGlnbj0nY2VudGVyJyBiZ2NvbG9yPScjQ0NDQ0NDJz4KICAgICAg
# ICAgICAgICAgICAgICAgICAgPHRhYmxlIGFsaWduPSdjZW50ZXInIGJvcmRl
# cj0nMCcgY2VsbHNwYWNpbmc9JzMnIGNlbGxwYWRkaW5nPScwJz4KICAgICAg
# ICAgICAgICAgICAgICAgICAgICAlQk9EWSUKICAgICAgICAgICAgICAgICAg
# ICAgICAgPC90YWJsZT4KCiAgICAgICAgICAgICAgICAgICAgICAgIDxpbnB1
# dCBuYW1lPSdyd2RfYWN0aW9uJyB2YWx1ZT0nJFJXRF9GSVJTVEFDVElPTiQn
# IHR5cGU9J2hpZGRlbic+CiAgICAgICAgICAgICAgICAgICAgICAgIDxpbnB1
# dCBuYW1lPSdyd2Rfc2Vzc2lvbicgdmFsdWU9JyRSV0RfU0VTU0lPTiQnIHR5
# cGU9J2hpZGRlbic+CiAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAg
# ICAgICAgICAgICAgICAgIDwvdHI+CiAgICAgICAgICAgICAgICAgIDwvdGFi
# bGU+CgogICAgICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICA8L3Ry
# PgoKICAgICAgICAgICAgPC90YWJsZT4KCiAgICAgICAgICA8L3RkPgogICAg
# ICAgIDwvdHI+CiAgICAgIDwvdGFibGU+CiAgICA8L2Zvcm0+CiAgPC9ib2R5
# Pgo8L2h0bWw+CiIKCiRyd2RfaHRtbFsiUERBIl0JPSAiCjwhLS0gR2VuZXJh
# dGVkIGJ5IFJ1YnlXZWJEaWFsb2cuICAgICAgICAgICAgICAgICAgICAgICAg
# ICAgICAgICAgICAgICAgICAgICAgICAtLT4KPCEtLSBGb3IgbW9yZSBpbmZv
# cm1hdGlvbiwgcGxlYXNlIGNvbnRhY3QgRXJpayBWZWVuc3RyYSA8cndkQGVy
# aWt2ZWVuLmRkcy5ubD4uIC0tPgo8aHRtbD4KICA8aGVhZD4KICAgIDx0aXRs
# ZT4lVElUTEUlPC90aXRsZT4KCiAgICA8bWV0YSBodHRwLWVxdWl2PSdDb250
# ZW50LVR5cGUnIGNvbnRlbnQ9J3RleHQvaHRtbDsgY2hhcnNldD0lQ0hBUlNF
# VCUnPgogICAgPG1ldGEgaHR0cC1lcXVpdj0nUmVmcmVzaCcgY29udGVudD0n
# JVJFRlJFU0glLCBqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnN1Ym1p
# dCgpOyc+CgogICAgPGxpbmsgcmVsPSdzaG9ydGN1dCBpY29uJyBocmVmPScl
# TE9HTyUnPgoKICAgIDxzY3JpcHQgdHlwZT0ndGV4dC9qYXZhc2NyaXB0Jz4K
# ICAgIDwhLS0KICAgICAgZnVuY3Rpb24gQm9keUdvKCkgewogICAgICAgICRS
# V0RfRk9DVVMkCiAgICAgIH0KICAgIC8vLS0+CiAgICA8L3NjcmlwdD4KICA8
# L2hlYWQ+CgogIDxib2R5IGJnY29sb3I9J3doaXRlJyBvbmxvYWQ9J0JvZHlH
# bygpJyBsaW5rPScjMDAwMDAwJyB2bGluaz0nIzAwMDAwMCcgYWxpbms9JyMw
# MDAwMDAnPgogICAgPGZvcm0gbmFtZT0nYm9keWZvcm0nIGFjdGlvbj0nLycg
# bWV0aG9kPSdwb3N0Jz4KICAgICAgPHRhYmxlIGFsaWduPSdjZW50ZXInIGJv
# cmRlcj0nMCcgY2VsbHNwYWNpbmc9JzAnIGNlbGxwYWRkaW5nPScwJyB3aWR0
# aD0nMTAwJScgaGVpZ2h0PScxMDAlJz4KCiAgICAgICAgPHRyIGFsaWduPSdj
# ZW50ZXInPgogICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9
# JyM0NDQ0ODgnPgoKICAgICAgICAgICAgPHRhYmxlIGFsaWduPSdsZWZ0JyBi
# b3JkZXI9JzAnIGNlbGxzcGFjaW5nPScxJyBjZWxscGFkZGluZz0nMCc+CiAg
# ICAgICAgICAgICAgPHRyIGFsaWduPSdjZW50ZXInPgogICAgICAgICAgICAg
# ICAgPHRkIGFsaWduPSdib3JkZXInPjxpbWcgc3JjPSclTE9HTyUnIHdpZHRo
# PScxNCcgaGVpZ2h0PScxNCc+PC90ZD4KICAgICAgICAgICAgICAgIDx0ZCBh
# bGlnbj0nY2VudGVyJz48Yj48c21hbGw+PGZvbnQgY29sb3I9JyNGRkZGRkYn
# PiZuYnNwOyVUSVRMRSUmbmJzcDs8L2ZvbnQ+PC9zbWFsbD48L2I+PC90ZD4K
# ICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICA8L3RhYmxlPgoKICAg
# ICAgICAgICAgPHRhYmxlIGFsaWduPSdyaWdodCcgYm9yZGVyPScwJyBjZWxs
# c3BhY2luZz0nMScgY2VsbHBhZGRpbmc9JzAnPgogICAgICAgICAgICAgIDx0
# ciBhbGlnbj0nY2VudGVyJz4KICAgICAgICAgICAgICAgIDwhLS0gJUhFTFBC
# VVRUT04lICAtLT48dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVF
# RSc+PGI+PHNtYWxsPjxhIGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9k
# eWZvcm0ucndkX2FjdGlvbi52YWx1ZT1cInJ3ZF9oZWxwXCI7ZG9jdW1lbnQu
# Ym9keWZvcm0uc3VibWl0KCk7Jz4mbmJzcDs/Jm5ic3A7PC9hPjwvc21hbGw+
# PC9iPjwvdGQ+CiAgICAgICAgICAgICAgICA8IS0tICVCQUNLQlVUVE9OUyUg
# LS0+PHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9JyNFRUVFRUUnPjxiPjxz
# bWFsbD48YSBocmVmPSdqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnJ3
# ZF9hY3Rpb24udmFsdWU9XCJyd2RfbWFpblwiO2RvY3VtZW50LmJvZHlmb3Jt
# LnN1Ym1pdCgpOyc+Jm5ic3A7Jmx0OyZsdDsmbmJzcDs8L2E+PC9zbWFsbD48
# L2I+PC90ZD4KICAgICAgICAgICAgICAgIDwhLS0gJUJBQ0tCVVRUT05TJSAt
# LT48dGQgYWxpZ249J2NlbnRlcicgYmdjb2xvcj0nI0VFRUVFRSc+PGI+PHNt
# YWxsPjxhIGhyZWY9J2phdmFzY3JpcHQ6ZG9jdW1lbnQuYm9keWZvcm0ucndk
# X2FjdGlvbi52YWx1ZT1cInJ3ZF9iYWNrXCI7ZG9jdW1lbnQuYm9keWZvcm0u
# c3VibWl0KCk7Jz4mbmJzcDsmbHQ7Jm5ic3A7PC9hPjwvc21hbGw+PC9iPjwv
# dGQ+CiAgICAgICAgICAgICAgICA8IS0tICVDTE9TRUJVVFRPTiUgLS0+PHRk
# IGFsaWduPSdjZW50ZXInIGJnY29sb3I9JyNFRUVFRUUnPjxiPjxzbWFsbD48
# YSBocmVmPSdqYXZhc2NyaXB0OmRvY3VtZW50LmJvZHlmb3JtLnJ3ZF9hY3Rp
# b24udmFsdWU9XCJyd2RfcXVpdFwiO2RvY3VtZW50LmJvZHlmb3JtLnN1Ym1p
# dCgpOyc+Jm5ic3A7WCZuYnNwOzwvYT48L3NtYWxsPjwvYj48L3RkPgogICAg
# ICAgICAgICAgIDwvdHI+CiAgICAgICAgICAgIDwvdGFibGU+CgogICAgICAg
# ICAgPC90ZD4KICAgICAgICA8L3RyPgoKICAgICAgICA8IS0tCiAgICAgICAg
# PHRyIGFsaWduPSdjZW50ZXInPgogICAgICAgICAgPHRkIGFsaWduPSdjZW50
# ZXInIGJnY29sb3I9JyNGRkZGRkYnPiZuYnNwOzwvdGQ+CiAgICAgICAgPC90
# cj4KICAgICAgICAtLT4KCiAgICAgICAgPHRyIGFsaWduPSdjZW50ZXInPgog
# ICAgICAgICAgPHRkIGFsaWduPSdjZW50ZXInIGJnY29sb3I9JyNGRkZGRkYn
# PgoKICAgICAgICAgICAgICA8dGFibGUgYWxpZ249J2NlbnRlcicgYm9yZGVy
# PScwJyBjZWxsc3BhY2luZz0nMCcgY2VsbHBhZGRpbmc9JzAnPgogICAgICAg
# ICAgICAgICAgJUJPRFklCiAgICAgICAgICAgICAgPC90YWJsZT4KCiAgICAg
# ICAgICAgICAgPGlucHV0IG5hbWU9J3J3ZF9hY3Rpb24nIHZhbHVlPSckUldE
# X0ZJUlNUQUNUSU9OJCcgdHlwZT0naGlkZGVuJz4KICAgICAgICAgICAgICA8
# aW5wdXQgbmFtZT0ncndkX3Nlc3Npb24nIHZhbHVlPSckUldEX1NFU1NJT04k
# JyB0eXBlPSdoaWRkZW4nPgogICAgICAgICAgPC90ZD4KICAgICAgICA8L3Ry
# PgoKICAgICAgPC90YWJsZT4KICAgIDwvZm9ybT4KICA8L2JvZHk+CjwvaHRt
# bD4KIgoKJHJ3ZF9waXhlbAk9ICIKUjBsR09EbGhBUUFCQU1JQUFBQUFBUC8v
# Lys3dTdrUkVpUC8vLy8vLy8vLy8vLy8vL3lINUJBRUtBQU1BCkxBQUFBQUFC
# QUFFQUFBTUNPQWtBT3c9PQoiLnVucGFjaygibSIpLnNoaWZ0CgokcndkX2xv
# Z28JPSAiClIwbEdPRGxoRUFBUUFNSUFBQUFBQVAvLy8rN3U3a1JFaVAvLy8v
# Ly8vLy8vLy8vLy95SDVCQUVLQUFRQQpMQUFBQUFBUUFCQUFBQU5DU0VyUS9r
# MjFRS3VscklyTnU4aGV1QUdVY0owQnVRVkQ2NzZEYXNLMHpOS3YKamVmQitv
# bzZsNkF4QkF4N00ySFJlUFFwaDV4Z2EwUnNKcWZFTFBJMkRTVUFBRHM9CiIu
# dW5wYWNrKCJtIikuc2hpZnQKCgokcndkX2h0bWxfMSwgJHJ3ZF9odG1sXzIJ
# CT0gJHJ3ZF9odG1sW0VOVlsiUldEVEhFTUUiXV0uc3BsaXQoL15ccyolQk9E
# WSVccypcciokLykKJHJ3ZF9odG1sX1BEQV8xLCAkcndkX2h0bWxfUERBXzIJ
# PSAkcndkX2h0bWxbIlBEQSJdLnNwbGl0KC9eXHMqJUJPRFklXHMqXHIqJC8p
# CgojZW5kCiMKI2NsYXNzIFJXRGlhbG9nIDwgUldEOjpSV0RpYWxvZwojZW5k
# CgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABy
# dWJ5d2ViZGlhbG9ncy9saWIvdGhyZWFkLmxpYi5yYgAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAwMDE3NTAAMDAwMDAwMDE2NDEA
# MTAyNTAzMjA2MjEAMDE3MTExACAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAAZXJpawAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlrAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgImV2L3J1YnkiCnJlcXVpcmUgInRo
# cmVhZCIKCmNsYXNzIEZha2VUaHJlYWQKICBkZWYgaW5pdGlhbGl6ZSgqYXJn
# cykKICAgIHlpZWxkKCphcmdzKQogIGVuZAoKICBkZWYgam9pbgogIGVuZApl
# bmQKCmNsYXNzIFRocmVhZExpbWl0ZXIKICBkZWYgaW5pdGlhbGl6ZShsaW1p
# dCkKICAgIEBsaW1pdAk9IGxpbWl0CiAgICBAY291bnQJPSAwCiAgICBAdGhy
# ZWFkcwk9IFtdCiAgICBAbXV0ZXgJPSBNdXRleC5uZXcKICAgIEBjdgkJPSBD
# b25kaXRpb25WYXJpYWJsZS5uZXcKCiAgICBldmVyeSgxKSBkbwogICAgICBA
# bXV0ZXguc3luY2hyb25pemUgZG8KICAgICAgICBAdGhyZWFkcy5kdXAuZWFj
# aCBkbyB8dHwKICAgICAgICAgIHVubGVzcyB0LmFsaXZlPwogICAgICAgICAg
# ICAkc3RkZXJyLnB1dHMgIkZvdW5kIGRlYWQgdGhyZWFkLiIKCiAgICAgICAg
# ICAgIEB0aHJlYWRzLmRlbGV0ZSh0KQoKICAgICAgICAgICAgQGNvdW50IC09
# IDEKCiAgICAgICAgICAgIEBjdi5zaWduYWwKICAgICAgICAgIGVuZAogICAg
# ICAgIGVuZAogICAgICBlbmQKICAgIGVuZAogIGVuZAoKICBkZWYgd2FpdAog
# ICAgaWYgYmxvY2tfZ2l2ZW4/CiAgICAgIHNlbGYud2FpdAogICAgICB5aWVs
# ZAogICAgICBzZWxmLnNpZ25hbAogICAgZWxzZQogICAgICBAbXV0ZXguc3lu
# Y2hyb25pemUgZG8KICAgICAgICBAdGhyZWFkcyA8PCBUaHJlYWQuY3VycmVu
# dAoKICAgICAgICBAY291bnQgKz0gMQoKICAgICAgICBAY3Yud2FpdChAbXV0
# ZXgpCWlmIEBjb3VudCA+IEBsaW1pdAogICAgICBlbmQKICAgIGVuZAogIGVu
# ZAoKICBkZWYgc2lnbmFsCiAgICBAbXV0ZXguc3luY2hyb25pemUgZG8KICAg
# ICAgQHRocmVhZHMuZGVsZXRlKFRocmVhZC5jdXJyZW50KQoKICAgICAgQGNv
# dW50IC09IDEKCiAgICAgIEBjdi5zaWduYWwKICAgIGVuZAogIGVuZAplbmQK
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAABydWJ5d2ViZGlhbG9ncy9pbnN0YWxsLnJiAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAMDAwMDc1NQAwMDAxNzUwADAwMDE3NTAAMDAwMDAw
# MDI2NDMAMTAyNTAzMjA2MjEAMDE2MDAwACAwAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAA
# ZXJpawAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlcmlrAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAADAwMDAwMDAAMDAwMDAwMAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHJlcXVpcmUgInJiY29uZmlnIgpyZXF1
# aXJlICJmdG9vbHMiCgppZiBfX0ZJTEVfXyA9PSAkMAoKICBEaXIuY2hkaXIo
# RmlsZS5kaXJuYW1lKCQwKSkKCiAgRnJvbURpcnMJPSBbIi4iLCAiLi9saWIi
# LCAiLi9ydWJ5bGliL2xpYiJdCiAgVG9EaXIJCT0gQ29uZmlnOjpDT05GSUdb
# InNpdGVsaWJkaXIiXSArICIvZXYiCgogIEZpbGUubWtwYXRoKFRvRGlyKQlp
# ZiBub3QgRmlsZS5kaXJlY3Rvcnk/KFRvRGlyKQoKICBGcm9tRGlycy5lYWNo
# IGRvIHxmcm9tZGlyfAogICAgZnJvbWRpcgk9IERpci5wd2QJaWYgZnJvbWRp
# ciA9PSAiLiIKCiAgICBpZiBGaWxlLmRpcmVjdG9yeT8oZnJvbWRpcikKICAg
# ICAgRGlyLm5ldyhmcm9tZGlyKS5lYWNoIGRvIHxmaWxlfAogICAgICAgIGlm
# IGZpbGUgPX4gL1wubGliXC5yYiQvCiAgICAgICAgICBmcm9tZmlsZQk9IGZy
# b21kaXIgKyAiLyIgKyBmaWxlCiAgICAgICAgICB0b2ZpbGUJCT0gVG9EaXIg
# KyAiLyIgKyBmaWxlLnN1YigvXC5saWJcLnJiLywgIi5yYiIpCgogICAgICAg
# ICAgcHJpbnRmICIlcyAtPiAlc1xuIiwgZnJvbWZpbGUsIHRvZmlsZQoKICAg
# ICAgICAgIEZpbGUuZGVsZXRlKHRvZmlsZSkJaWYgRmlsZS5maWxlPyh0b2Zp
# bGUpCgogICAgICAgICAgRmlsZS5vcGVuKHRvZmlsZSwgInciKSB7fGZ8IGYu
# cHV0cyBGaWxlLm5ldyhmcm9tZmlsZSkucmVhZGxpbmVzfQogICAgICAgIGVu
# ZAogICAgICBlbmQKICAgIGVuZAogIGVuZAoKZWxzZQoKICBGcm9tRGlycwk9
# IFsiLiIsICIuL2xpYiIsICIuL3J1YnlsaWIvbGliIl0KICBUb0RpcgkJPSAi
# Li9ldiIKCiAgRmlsZS5ta3BhdGgoVG9EaXIpCWlmIG5vdCBGaWxlLmRpcmVj
# dG9yeT8oVG9EaXIpCgogIEZyb21EaXJzLmVhY2ggZG8gfGZyb21kaXJ8CiAg
# ICBmcm9tZGlyCT0gRGlyLnB3ZAlpZiBmcm9tZGlyID09ICIuIgoKICAgIGlm
# IEZpbGUuZGlyZWN0b3J5Pyhmcm9tZGlyKQogICAgICBEaXIubmV3KGZyb21k
# aXIpLmVhY2ggZG8gfGZpbGV8CiAgICAgICAgaWYgZmlsZSA9fiAvXC5saWJc
# LnJiJC8KICAgICAgICAgIGZyb21maWxlCT0gZnJvbWRpciArICIvIiArIGZp
# bGUKICAgICAgICAgIHRvZmlsZQk9IFRvRGlyICsgIi8iICsgZmlsZS5zdWIo
# L1wubGliXC5yYi8sICIucmIiKQoKICAgICAgICAgICNwcmludGYgIiVzIC0+
# ICVzXG4iLCBmcm9tZmlsZSwgdG9maWxlCgogICAgICAgICAgRmlsZS5kZWxl
# dGUodG9maWxlKQlpZiBGaWxlLmZpbGU/KHRvZmlsZSkKCiAgICAgICAgICBG
# aWxlLm9wZW4odG9maWxlLCAidyIpIHt8ZnwgZi5wdXRzIEZpbGUubmV3KGZy
# b21maWxlKS5yZWFkbGluZXN9CiAgICAgICAgZW5kCiAgICAgIGVuZAogICAg
# ZW5kCiAgZW5kCgogIG9sZGxvY2F0aW9uIGRvCiAgICBmaWxlCT0gbmV3bG9j
# YXRpb24oImF1dG9yZXF1aXJlLnJiIikKCiAgICBsb2FkIGZpbGUJaWYgRmls
# ZS5maWxlPyhmaWxlKQogIGVuZAoKZW5kCgAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
