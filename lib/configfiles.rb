# Copyright 2010, Guido De Rosa <guido.derosa*vemarsas.it>
# License: same of Ruby

require 'configfiles/extensions/enumerable'

module ConfigFiles

  VERSION = '0.0.2'

  class ArgumentError < ::ArgumentError; end
  class RuntimeError < ::RuntimeError; end

  class AlreadyDefinedParameter < ::Exception; end
  class DefaultAlreadySet < ::Exception; end
  AlreadyDefinedDefault = DefaultAlreadySet
  
  # You should write a read(io) method,
  # taking an IO object and returnig a key-value hash, where keys
  # are symbols, and values are Strings or Enumerators yielding Strings 
  #
  # This result will be passed to YourConfigClass#load,
  # where YourConfigClass inherits from ConfigFiles::Base
  class Base

    @@parameters  ||= {}
    @@behavior    ||= {
      :unknown_parameter => :ignore,
      :unknown_value    => :fail  # when the converter is a Hash,
                                  # whose keys represents a fixed set
                                  # of allowed strings, and values represents
                                  # their "meaning", tipically as a Symbol
    }
    @@validate    ||= lambda {|data| true} 

    # Examples: 
    #   on :unknown_parameter, :fail # or :accept, or :ignore
    #   on :unknown_parameter, {|str| str.to_i}
    #
    # There's also :unknown_value, to specify behavior when the
    # converter is an Hash and the value found if not among the
    # hash keys. Usage is similar.
    #
    def self.on(circumstance, action=nil, &block)
      actions       = [:accept, :ignore, :fail] 
      circumstances = [:unknown_parameter, :unknown_value]      
      unless circumstances.include? circumstance
        raise ArgumentError, "Invalid circumstance: #{circumstance.inspect}. Allowed values are #{circumstances.list_inspect}."
      end
      if block
        @@behavior[circumstance] = block
      elsif action == :accept
        @@behavior[circumstance] = lambda {|x| x} 
      elsif actions.include? action
        @@behavior[circumstance] = action
      else
        raise ArgumentError, "Invalid action: #{action}. Allowed values are #{actions.list_inspect}."
      end
    end

    def self.option(name)
      @@behavior[name]
    end

    def self.parameter(name, converter=nil, &converter_block)
      if @@parameters[name] and @@parameters[name][:converter]
        raise AlreadyDefinedParameter, "Already defined parameter \"#{name}\""
      end
      if converter
        if converter_block
          raise ArgumentError, 'you must either specify a symbol or a block'
        elsif converter.is_a? Hash

          converter_block = lambda do |x| # x is a String from conf file 
            if converter.keys.include? x
              return converter[x] # returns from lambda, not from method 
            elsif @@behavior[:unknown_value] == :fail
              raise ArgumentError, "Invalid value \"#{x}\" for parameter \"#{name}\". Allowed values are #{converter.keys.list_inspect}."
            elsif @@behavior[:unknown_value] == :accept
              return x
            end
          end 

        else #Symbol
          converter_block = lambda {|x| x.method(converter).call}
        end
      else
        converter_block ||= lambda {|x| x}  
      end
      @@parameters[name] ||= {} 
      @@parameters[name][:converter] = converter_block
    end

    def self.default(name, value)
      if @@parameters[name] and @@parameters[name][:default]
        raise DefaultAlreadySet, "Default for \"#{name}\" has been already set (to value: #{@@parameters[name][:default]})"
      end
      @@parameters[name] ||= {}
      @@parameters[name][:default] = value
    end

    # A special kind of parameter, with a special kind of converter, 
    # which in turn
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
      @behavior = @@behavior.dup
      @data = {}
      def @data.missing_method(id); @data[id]; end
    end

    def validate
      @@validate.call(@data)
    end

    def load(h)

      h.each_pair do |id, value|
        if @@parameters[id] and @@parameters[id][:converter]
          @data[id] = @@parameters[id][:converter].call(value)
        elsif @behavior[:unknown_parameter] == :fail
          raise RuntimeError, "unknown parameter #{key}" # otherwise ignore
        elsif @behavior[:unknown_parameter].respond_to? :call
          block = @behavior[:unknown_parameter]
          @data[id] = block.call value
        end
      end

      # assign default values to the remaining params
      @@parameters.each_pair do |name, h| 
        if !@data[name] and @@parameters[name][:default]
          @data[name] = @@parameters[name][:default]
        end
      end

      validate  
    end

    def flush
      @data = {}
    end

  end

end
