
require 'ipaddr'
require 'pp'

module ConfigFiles

  class Parameter
    attr_accessor :name, :properties
    def is(*args)
      @properties = args if args.length > 0
    end
    def is?(property)
      @properties.include? property
    end
    def convert(&block)
      @conversion = block
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

    def parser
      p = Parser.new
      def p.method_missing(id)
        @@parsers[id]
      end
      return p
    end

  end

end

class MyIPList < ConfigFiles::Base
  add parameter do |p|
    p.name = :list
    p.is :required
    p.convert do |enum|
      enum.each do |ipstr|
        yield IPAddr.new ipstr
      end
    end
  end

  add parser do |prs|
    prs.name = :my_ip_list_extractor
    prs.code do |io|
      io.each_line do |line|
        next if line =~ /^\s*$/
        yield line.strip
      end
    end
  end

end

#pp MyIPList.parameters
#pp MyIPList.parsers

l = MyIPList.new


pp l.parser.my_ip_list_extractor.code


