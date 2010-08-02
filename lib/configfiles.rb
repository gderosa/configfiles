module ConfigFiles

  module Parser
  end

  class Base

    class ArgumentError < ::ArgumentError; end
    class RuntimeError < ::RuntimeError; end

    @@parameters ||= {}
    @@config ||= {}

    def self.parameter(name, converter=nil, &converter_block)
      if converter
        if converter_block
          raise ArgumentError, 'you must either specify a symbol or a block'
        else
          converter_block = lambda {|x| x.method(converter).call}
        end
      else
        converter_block || lambda {|x| x}  
      end
      @@parameters[name] = {
        :converter  => converter_block
      }
    end

    # A special kind of parameter, with a special kind of converter, which in turn
    # converts an Enumerator of Strings into an Enumerator of custom objects. 
    # Working with Enumerators instead of
    # Arrays is the right thing to do when you deal with very long list of
    # names, IP adresses, URIs etc. 
    def self.enumerator(name, &block)
      parameter name do |enum|
        Enumerator.new do |yielder|
          enum.each do |string|
            yielder << block.call(string) 
          end
        end
      end
    end

    def self.validate(&block)
      @@validate = block
    end

    attr_accessor :config

    def initialize
      @config = @@config
      @data = {}
    end

    def validate
      @@validate.call
    end

    def method_missing(id)
      @data[id]
    end

    def load(h)
      h.each_pair do |id, value|
        if @@parameters[id][:converter]
          @data[id] = @@parameters[id][:converter].call(value)
        elsif @config[:unknown_parameter] == :fail
          raise RuntimeError, "unknown parameter #{key}" # otherwise ignore
        end
      end
    end

    def flush
      @data = {}
    end

  end

end
