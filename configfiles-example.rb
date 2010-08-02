$LOAD_PATH.unshift 'lib'

$count ||= 1

require 'pp'
require 'ipaddr'
require 'configfiles'

class MyConfig < ConfigFiles::Base

  class MyException < Exception; end
  class MyArgumentError < ArgumentError; end

  # I find more rubystic defining a "conversion"
  # rater than statically declaring classes ;)
  parameter :par_integer, :to_i
  parameter :par_str # no conversion needed
  parameter :par_custom do |s|
    s.length 
  end

  #parameter :iplist do |list|
  #  Enumerator.new do |yielder|
  #    list.each do |ipstr|
  #      yielder << IPAddr.new(ipstr)
  #    end
  #  end
  #end

  # receive an Enumerator from Parser, and turn into another Enumerator
  #
  # NOTE: Enumerable#map_enum would be cool ;-)
  enumerator :iplist do |ipstr| 
    IPAddr.new(ipstr)
  end

  validate do 
    raise MyArgumentError if par_custom > 100
    raise MyException unless par_str =~ /\S+/
    # or you may use standard exceptions....

    return true
  end

end

class MyKeyValueParser 

  include ConfigFiles::Parser

  def self.read(io, opt_h={}) 
    h = {}
    io.eaach_line do |line|
      key_re    = '[\w\d_-\.]+'
      value_re  = '[\w\d_-\.]+'
      if line = /(#{key_re})\s*=\s*(#{value_re})/ 
        h[$1.to_sym] = $2
      end
    end
  end
end


class MyListSlurper

  include ConfigFiles::Parser

  def self.read(io, opt_h={})
    if block_given?
      io.each_line do |line|
        yield line.strip if line =~ /\S/
      end
    else
      enum_for :read, io
    end
  end

end



c = MyConfig.new

parse_result = {
  :iplist => MyListSlurper.read(File.open '../iplist.txt')
}

c.load parse_result

pp c.iplist




