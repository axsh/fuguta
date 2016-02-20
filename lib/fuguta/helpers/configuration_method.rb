module Fuguta
  module Helpers
    module ConfigurationMethod
      module ClassMethods
        # Helper method to define class specific configuration class.
        #
        # def_configuration(&blk) is available when you include this module
        #
        # # Example:
        # class Base
        #   include Fuguta::Configuration::ConfigurationMethod
        #   def_configuration do
        #     param :xxxx
        #     param :yyyy
        #   end
        # end
        #
        # Above example does exactly same thing as below:
        #
        # class Base
        #   class Configuration < Fuguta::Configuration
        #     param :xxxx
        #     param :yyyy
        #   end
        #   @configuration_class = Configuration
        # end
        #
        # # Examples for new classes of Base inheritance.
        # class A < Base
        #   def_configuration do
        #     param :zzzz
        #   end
        #   def_configuration do
        #     param :xyxy
        #   end
        #
        #   p Configuration # => A::Configuration
        #   p Configuration.superclass # => Base::Configuration
        #   p @configuration_class # => A::Configuration
        # end
        #
        # class B < A
        #   p self.configuration_class # => A::Configuration
        # end
        def def_configuration(&blk)
          # create new configuration class if not exist.
          if self.const_defined?(:Configuration, false)
            unless self.const_get(:Configuration, false) < Fuguta::Configuration
              raise TypeError, "#{self}::Configuration constant is defined already for another purpose."
            end
          else
            self.const_set(:Configuration, Class.new(self.configuration_class || Fuguta::Configuration))
            @configuration_class = self.const_get(:Configuration, false)
          end
          if blk
            @configuration_class.module_eval(&blk)
          end
        end

        def configuration_class
          ConfigurationMethod.find_configuration_class(self)
        end
      end

      def self.find_configuration_class(c)
        begin
          v = c.instance_variable_get(:@configuration_class)
          return v if v
          if c.const_defined?(:Configuration, false)
            return c.const_get(:Configuration, false)
          end
        end while c = c.superclass
        nil
      end

      private
      def self.included(klass)
        klass.extend ClassMethods
      end
    end
  end
end
