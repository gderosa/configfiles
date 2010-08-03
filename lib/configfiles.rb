# Copyright 2010, Guido De Rosa <guido.derosa*vemarsas.it>
# License: same of Ruby

module ConfigFiles

  module Parser
    def self.read_file(path)
      self.read File.open path
    end
  end

  class Base

    class ArgumentError < ::ArgumentError; end
    class RuntimeError < ::RuntimeError; end

    @@parameters ||= {}
    @@options ||= {}

    # examples: 
    #   on :unknown_parameter, :fail | :accept | :ignore
    #   on :unknown_parameter, {|str| str.to_i}
    #
    def self.on(name, value=nil, &block)
      if block
        @@options[name] = block
      elsif name == :unknown_parameter and value == :accept
        @@options[name] = lambda {|x| x} 
      else
        @@options[name] = value
      end
    end

    def self.option(name)
      @@options[name]
    end

    def self.parameter(name, converter=nil, &converter_block)
      if converter
        if converter_block
          raise ArgumentError, 'you must either specify a symbol or a block'
        else
          converter_block = lambda {|x| x.method(converter).call}
        end
      else
        converter_block ||= lambda {|x| x}  
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

    attr_accessor :options, :data

    def initialize
      @options = @@options.dup
      @data = {}
      def @data.missing_method(id); @data[id]; end
    end

    def validate
      @@validate.call(@data)
    end

    def load(h)
      h.each_pair do |id, value|
        if @@parameters[id][:converter]
          @data[id] = @@parameters[id][:converter].call(value)
        elsif @options[:unknown_parameter] == :fail
          raise RuntimeError, "unknown parameter #{key}" # otherwise ignore
        elsif @options[:unknown_parameter].respond_to? :call
          block = @options[:unknown_parameter]
          @data[id] = block.call value
        end
      end
      validate  
    end

    def flush
      @data = {}
    end

  end

end
