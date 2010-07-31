require 'ipaddr'
require 'pp'

module ConfigFiles

  class Parameter
    attr_accessor :name, :properties
    def is(*args)
      raise ArgumentError, 'is what?' if args.length == 0
      @properties = args 
    end
    def is?(property)
      @properties.include? property
    end
    def convert(value=nil, &block)
      if block_given?
        @conversion = block
      end
      if @conversion.respond_to? :call 
        @conversion.call value
      else
        value
      end
    end
  end

  class Parser
    attr_accessor :name

    def code(&block)
      if block_given?
        @code = block
      else
        @code
      end
    end

    def read(io=STDIN)
      code.call io
    end
  end

  class Converter < Proc; end

  class Base
    @@parameters  ||= {}
    @@parsers     ||= {}
    @@default     ||= {}
    @@unknown     ||= {}

    # DSL/sugar
    def self.parameter;   Parameter;    end
    def self.parser;      Parser;       end
    def self.converter;   Converter;    end

    def self.parameters;  @@parameters; end
    def self.parsers;     @@parsers;    end
    
    def self.add(what, &block)
      if what == parameter
        p = Parameter.new
        block.call p
        @@parameters[p.name] = p
      elsif what == parser
        p = Parser.new
        block.call p
        @@parsers[p.name] = p
      end
    end

    def self.default(what, &block)
      if what == converter
        @@default[:converter] = block
      end
    end

    def self.unknown(what, &block)
      if what == parameter
        @@unknown[:parameter] = block
      end
    end

    def self.run_parser(id, io)
      @@parsers[id].read io
    end

    attr_reader :data

    def initialize
      @data = {}
    end

    def load(parse_result)
      @data = {}
      parse_result.each_pair do |name, value|
        if @@parameters[name]
          @data[name] = @@parameters[name].convert value
        else
          @@unknown[:parameter].call name if
            @@unknown && @@unknown[:parameter]
        end
      end
    end

  end

end

class MyIPList < ConfigFiles::Base
  add parameter do |p|
    p.name    = :list
    p.is        :required
    p.convert do |ary|
      ary.map {|ipstr| IPAddr.new ipstr}
    end
  end

  add parameter do |p|
    p.name    = :a
  end
  add parameter do |p|
    p.name    = :b
  end



  add parser do |prs|
    prs.name  = :my_ip_list_extractor
    prs.code do |io|
      ary = []
      io.each_line do |line|
        next if line =~ /^\s*$/
        ary << line.strip
      end
      {:list => ary}
    end
  end

  add parser do |prs|
    prs.name = :keyval
    prs.code do |io|
      h = {}
      io.each_line do |line|
        next if line =~ /^\s*$/
        if line =~ /(.*)=(.*)/
          h[$1.to_sym] = $2
        end
      end
      h
    end
  end

  unknown parameter do |name|
    fail "unknown param #{name}"
  end

  default converter do |value|
    value.to_f
  end

end

#pp MyIPList.parameters
#pp MyIPList.parsers

l = MyIPList.new

File.open 'ip.conf' do |f|
  l.load MyIPList.run_parser :my_ip_list_extractor, f
end

pp l.data

File.open 'kv.conf' do |f|
  l.load MyIPList.run_parser :keyval, f
end

pp l.data



