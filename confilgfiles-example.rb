
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
      if @conversion.respond_to? :call and value
        @conversion.call value
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

  class Base
    @@parameters ||= {}
    @@parsers ||= {}

    # sugar
    def self.parameter; Parameter; end
    def self.parser; Parser; end

    def self.parameters; @@parameters; end
    def self.parsers; @@parsers; end
    
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

    attr_reader :data

    def initialize
      @data = {}
    end

    def parser
      p = Parser.new
      def p.method_missing(id)
        @@parsers[id]
      end
      return p
    end

    def load(parse_result)
      @data = {}
      parse_result.each_pair do |name, value|
        @data[name] = @@parameters[name].convert value 
      end
    end

  end

end

class MyIPList < ConfigFiles::Base
  add parameter do |p|
    p.name = :list
    p.is :required
    p.convert do |ary|
      ary.map {|ipstr| IPAddr.new ipstr}
    end
  end

  add parser do |prs|
    prs.name = :my_ip_list_extractor
    prs.code do |io|
      ary = []
      io.each_line do |line|
        next if line =~ /^\s*$/
        ary << line.strip
      end
      {:list => ary}
    end
  end

end

#pp MyIPList.parameters
#pp MyIPList.parsers

l = MyIPList.new

io = File.open 'ip.conf'
parse_result = l.parser.my_ip_list_extractor.read io
io.close

l.load parse_result

p l.data 


