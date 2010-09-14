# Copyright 2010, Guido De Rosa <guido.derosa*vemarsas.it>
# License: same of Ruby

require 'facets/enumerable/defer'

require 'configfiles/extensions/enumerable'

module ConfigFiles

  VERSION = '0.1.0'

  # You should write a read(io) method,
  # taking an IO object and returnig a key-value hash, where keys
  # are symbols, and values are Strings or Enumerable yielding Strings 
  #
  # This result will be passed to YourConfigClass#load,
  # where YourConfigClass inherits from ConfigFiles::Base
  class Base

    class ArgumentError           < ::ArgumentError;  end
    class RuntimeError            < ::RuntimeError;   end
    class NoKeyError              < ::NameError;      end
    class ValidationFailed        < ::RuntimeError;   end
    class AlreadyDefinedParameter < ::Exception;      end
    class DefaultAlreadySet       < ::Exception;      end

    AlreadyDefinedDefault = DefaultAlreadySet

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
    # converts an Enumerable yielding Strings into an Enumerator of 
    # custom objects. You may work with Enumerators instead of
    # Arrays , which is the right thing to do when you deal with very 
    # long list of names, IP adresses, URIs etc (lazy evaluation) .
    def self.enumerator(name, converter=nil, &converter_block)
      if block_given?
        raise ArgumentError, 'you must either specify a symbol or a block' if
            converter
      else
        if converter # converter may be :to_i etc.
          converter_block = lambda {|x| x.method(converter).call} 
        else
          converter_block = lambda {|x| x}
        end
      end
      #parameter name do |enumerable|
      #  Enumerator.new do |yielder|
      #    enumerable.each do |string|
      #      yielder << converter_block.call(string) 
      #    end
      #  end
      #end
      #
      # Use facets instead
      parameter name do |enumerable|
        enumerable.defer.map{|element| converter_block.call(element)} 
      end
    end

    def self.validate(&block)
      @@validate = block
    end

    attr_accessor :options #, :data

    def initialize
      @behavior = @@behavior.dup
      @data = {}
    end

    def validate
      @@validate.call(self) 
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

      @data.merge! deferred_data_h

      validate  
    end

    # behave like a Hash, but more rigidly! you cannot automagically
    # add keys without calling Configfiles::Base.parameter
    
    def data(key)
      if @data.keys.include? key
        @data[key]
      else
        raise NoKeyError, "uknown key '#{key}' for #{self.class}"
      end
    end
    def get(key); data(key);  end
    def [](key);  data(key);  end 

    def set(key, val)
      if @data.keys.include? key
        @data[key] = val
      else
        raise NoKeyError, "uknown key '#{key}' for #{self.class}"
      end
    end
    def []=(key, val); set(key, val); end

    def each(&blk) 
      @data.each(&blk)
    end

    private

    def deferred_data_h
      results_h = {} 
      @data.each do |k, v|
        if v.is_a? Proc
          results_h[k] = v.call(@data)
        end
      end
      results_h
    end

  end
end
