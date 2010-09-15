# Copyright 2010, Guido De Rosa <guido.derosa*vemarsas.it>
# License: same of Ruby

require 'facets/enumerable/defer'

require 'configfiles/extensions/enumerable'

module ConfigFiles

  VERSION = '0.3.1'

  # You should write a read(io) method,
  # taking an IO object and returnig a key-value hash, where keys
  # are symbols, and values are Strings or Enumerable yielding Strings 
  #
  # This result will be passed to YourConfigClass#load,
  # where YourConfigClass inherits from ConfigFiles::Base
  class Base

    CIRCUMSTANCES       = [:unknown_parameter, :unknown_value]
    PREDEFINED_ACTIONS  = [:accept, :ignore, :fail]

    class ArgumentError           < ::ArgumentError;  end
    class RuntimeError            < ::RuntimeError;   end
    class NoKeyError              < ::NameError;      end
    class ValidationFailed        < ::RuntimeError;   end
    class AlreadyDefinedParameter < ::Exception;      end
    class DefaultAlreadySet       < ::Exception;      end
    class VirtualParameterFound   < ::RuntimeError;   end
    
    class << self

      # NOTE: *class instance variables* to avoid overlapping when you have
      # several inherited classes! See "The Ruby Programming Language" by David
      # Flanagan and Yukihiro Matsumoto, 2008, O'Really, 978-0-596-51617-8, 
      # sec 7.1.16
      
      # *class instance variables* accessors
      attr_accessor :parameters, :behavior, :validation

      def inherited(subclass)
        subclass.class_instance_initialize
      end

      def class_instance_initialize
        @parameters  ||= {}
        @behavior    ||= {
          :unknown_parameter => :ignore,
          :unknown_value    => :fail  # when the converter is a Hash,
                                      # whose keys represents a fixed set
                                      # of allowed strings, and values represents
                                      # their "meaning", tipically as a Symbol
        }
        @validation  ||= lambda {|data| true} 
      end

      # Examples: 
      #   on :unknown_parameter, :fail # or :accept, or :ignore
      #   on :unknown_parameter, {|str| str.to_i}
      #
      # There's also :unknown_value, to specify behavior when the
      # converter is an Hash and the value found if not among the
      # hash keys. Usage is similar.
      #
      def on(circumstance, action=nil, &block)
        actions       = PREDEFINED_ACTIONS
        circumstances = CIRCUMSTANCES
        unless circumstances.include? circumstance
          raise ArgumentError, "Invalid circumstance: #{circumstance.inspect}. Allowed values are #{circumstances.list_inspect}."
        end
        if block
          @behavior[circumstance] = block
        elsif actions.include? action
          @behavior[circumstance] = action
        elsif action
          raise ArgumentError, "Invalid action: #{action}. Allowed values are #{actions.list_inspect}."
        else
          return @behavior[circumstance] 
        end
      end

      # +circumstance+ must be an element of +CIRCUMSTANCES+ .
      # Returns an element of +PREDEFINED_ACTIONS+ or a user-defined Proc
      def behavior_on(circumstance); on(circumstance); end

      # Add a parameter.
      #
      #   # keep as is
      #   parameter :myparam 
      #
      #   # convert to integer
      #   parameter :myparam, :to_i
      #
      #   # do some computation
      #   parameter :myparam do |str|
      #     ... 
      #     ...
      #     my_result
      #   end
      #
      #   # map a set of possible/admitted values; you may call the 
      #   # class method +on+(:unknown_value) to customize behavior
      #   parameter :myparam,
      #     '1' => :my_first_option,
      #     '2' => :my_second_one
      #
      def parameter(name, converter=nil, &converter_block)
        if @parameters[name] and @parameters[name][:converter]
          raise AlreadyDefinedParameter, "Already defined parameter \"#{name}\""
        end
        if converter
          if converter_block
            raise ArgumentError, 'you must either specify a symbol or a block'
          elsif converter.is_a? Hash

            converter_block = lambda do |x| # x is a String from conf file 
              if converter.keys.include? x
                return converter[x] # returns from lambda, not from method 
              elsif @behavior[:unknown_value] == :fail
                raise ArgumentError, "Invalid value \"#{x}\" for parameter \"#{name}\". Allowed values are #{converter.keys.list_inspect}."
              elsif @behavior[:unknown_value] == :accept
                return x
              end
            end 

          else #Symbol
            converter_block = lambda {|x| x.method(converter).call}
          end
        else
          converter_block ||= lambda {|x| x}  
        end
        @parameters[name] ||= {} 
        @parameters[name][:converter] = converter_block
      end

      # set default value of a parameter
      def default(name, value)
        if @parameters[name] and @parameters[name][:default]
          raise DefaultAlreadySet, "Default for \"#{name}\" has been already set (to value: #{@parameters[name][:default]})"
        end
        @parameters[name] ||= {}
        @parameters[name][:default] = value
      end

      # Define a parameter as a function of other parameters.
      # Example:
      #   virtual :delta do |confdata|
      #     confdata[:this] - confdata[:that]
      #   end
      def virtual(name, &block)
        parameter name do |str|
          raise VirtualParameterFound, 
              "'#{name}' is a virtual parameter, it shouldn't appear directly!"
        end
        default name, block 
      end

      # A special kind of parameter, with a special kind of converter, 
      # which in turn
      # converts an Enumerable yielding Strings into an Enumerator of 
      # custom objects. You may work with Enumerators instead of
      # Arrays , which is the right thing to do when you deal with very 
      # long list of names, IP adresses, URIs etc (lazy evaluation) .
      def enumerator(name, converter=nil, &converter_block)
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

      # Set validation rules. For example, if parameter 'a' must be 
      # smaller than 'b':
      #
      #   validate do |confdata|  
      #     raise ValidationFailed, "no good!" unless
      #         confdata[:a] <= confdata[:b] 
      #   end
      #
      def validate(&block)
        @validation = block
      end

    end # class << self

    def initialize
      @data = {}
    end

    # Validate configuration object, according to what declared 
    # with the class method 
    def validate
      self.class.validation.call(self) 
    end

    # Load the Hash h onto the ConfigFiles object, carrying on conversions
    # to Ruby objects, validation, and default actions
    # if needed. h's keys are Symbols, h's values are typically Strings
    # or Enumerables yielding Strings. See also ConfigFiles::Base::parameter
    # and ConfigFiles::Base::on.
    #
    # Option Hash opt_h keys:
    #
    # * +:compute_defaults+ (default +true+)
    # compute/assign default values to unset params if possible
    #
    # * +:compute_deferred+ (default +true+)
    # compute/assign parameters which are function of others
    #
    # * +:validate+ (default +true+)
    # perform validation defined in ConfigFiles::Base::validate
    #
    def load(h, opt_h={})
      opt_h_defaults = {
        :compute_defaults => true,
        :compute_deferred => true,
        :validate         => true
      }
      opt_h = opt_h_defaults.merge(opt_h) 

      h.each_pair do |id, value|
        if self.class.parameters[id] and self.class.parameters[id][:converter]
          @data[id] = self.class.parameters[id][:converter].call(value)
        elsif self.class.behavior[:unknown_parameter] == :fail
          raise RuntimeError, "unknown parameter #{key}" # otherwise ignore
        elsif self.class.behavior[:unknown_parameter] == :accept
          @data[id] = value
        elsif self.class.behavior[:unknown_parameter].respond_to? :call
          block = self.class.behavior[:unknown_parameter]
          @data[id] = block.call value
        end
      end

      if opt_h[:compute_defaults]
        # assign default values to the remaining params
        self.class.parameters.each_pair do |name, h| 
          if !@data[name] and self.class.parameters[name][:default]
            @data[name] = self.class.parameters[name][:default]
          end
        end
      end

      @data.merge! deferred_data if opt_h[:compute_deferred]

      validate if opt_h[:validate]
    end

    # Like Hash#[], but more rigidly! Raise an Exception on unknown
    # key, instead of returning nil.
    def [](key)
      if @data.keys.include? key
        @data[key]
      else
        raise NoKeyError, "unknown key '#{key}' for #{self.class}"
      end
    end

    # Like Hash#[]=, but more rigidly! New keys are not created 
    # automagically. You should have used ConfigFiles.parameter for that.
    def []=(key, val)
      if @data.keys.include? key
        @data[key] = val
      else
        raise NoKeyError, "uknown key '#{key}' for #{self.class}"
      end
    end

    # Like Hash#each, iterate over parameter names and values.
    #   conf.each{|name, value| puts "#{name} is set to #{value}"}
    def each(&blk) 
      @data.each(&blk)
    end

    private

    def deferred_data
      results = {} 
      @data.each do |k, v|
        if v.is_a? Proc
          results[k] = v.call(@data)
        end
      end
      results
    end

  end
end

ConfigFiles::Base.class_instance_initialize
