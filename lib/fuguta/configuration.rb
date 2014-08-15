
require 'fuguta'
require 'fuguta/loader'

module Fuguta
  class Configuration
    # Backward compatiblity for namespace
    ValidationError = Fuguta::ValidationError
    Loader = Fuguta::Loader

    def self.usual_paths(paths = nil)
      if paths
        @usual_paths = paths
      else
        @usual_paths
      end
    end

    def usual_paths
      self.class.usual_paths
    end

    def self.walk_tree(conf, &blk)
      raise ArgumentError, "conf must be a 'Configuration'. Got '#{conf.class}'." unless conf.is_a?(Configuration)

      blk.call(conf)
      conf.config.values.each { |c|
        case c
        when Configuration
          walk_tree(c, &blk)
        when Hash
          c.values.each { |c1| walk_tree(c1, &blk) if c1.is_a?(Configuration) }
        when Array
          c.each { |c1| walk_tree(c1, &blk) if c1.is_a?(Configuration) }
        end
      }
    end

    class DSLProxy
      def initialize(subject)
        @subject = subject
        @config = subject.config
        @loading_path = nil
      end

      def config
        self
      end

      # Load separate configuration files from the file.
      #
      # Load relative path file.
      # ----------------
      #   load 'test2.conf'
      #
      # Load absolute path file.
      # ----------------
      #   load '/etc/test2.conf'
      def load(*paths)
        l = Loader.new(@subject)
        paths.each { |path|
          if path =~ %r{^/}
            # Load absolute path
            l.load(path)
          else
            # Load relative path
            base_conf_dir = (@loading_path.nil? ? Dir.pwd : File.dirname(@loading_path))
            l.load(File.expand_path(path, base_conf_dir))
          end
        }

        self
      end
    end

    module ConfigurationMethods
      module ClassMethods
        # Helper method to define class specific configuration class.
        #
        # def_configuration(&blk) is available when you include this module
        #
        # # Example:
        # class Base
        #   include Fuguta::Configuration::ConfigurationMethods
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
          ConfigurationMethods.find_configuration_class(self)
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

    class << self
      def on_initialize_hook(&blk)
        @on_initialize_hooks << blk
      end

      def on_initialize_hooks
        @on_initialize_hooks
      end

      DEPRECATED_WARNING_MESSAGE="WARN: Deprecated parameter: %1$s. Please use '%2$s'".freeze
      DEPRECATED_ERROR_MESSAGE="ERROR: Parameter is no longer supported: %1$s. Please use '%2$s'".freeze

      # Show warning message if the old parameter is set.
      def deprecated_warn_param(old_name, message=nil)
        on_param_create_hook do |param_name, opts|
          self.deprecated_warn_for(old_name, param_name, message)
        end
      end

      def deprecated_warn_for(old_name, param_name, message=nil)
        warn_msg = message || DEPRECATED_WARNING_MESSAGE

        alias_param old_name, param_name
        self.const_get(:DSL, false).class_eval %Q{
          def #{old_name}(v)
            STDERR.puts("#{warn_msg}" % ["#{old_name}", "#{param_name}"])
            #{param_name.to_s}(v)
          end
        }
      end

      # Raise an error if the old parameter is set.
      def deprecated_error_param(old_name, message=nil)
        on_param_create_hook do |param_name, opts|
          self.deprecated_error_for(old_name, param_name, message)
        end
      end

      def deprecated_error_for(old_name, param_name, message=nil)
        err_msg = message || DEPRECATED_ERROR_MESSAGE

        alias_param old_name, param_name
        self.const_get(:DSL, false).class_eval %Q{
          def #{old_name}(v)
            raise ("#{err_msg}" % ["#{old_name}", "#{param_name}"])
          end
        }
      end

      def alias_param (alias_name, ref_name)
        # getter
        self.class_eval %Q{
          # Ruby alias show error if the method to be defined later is
          # set. So create method to call the reference method.
          def #{alias_name.to_s}()
            #{ref_name}()
          end
        }

        # DSL setter
        self.const_get(:DSL, false).class_eval %Q{
          def #{alias_name}(v)
            #{ref_name.to_s}(v)
          end
          alias_method :#{alias_name.to_s}=, :#{alias_name.to_s}
        }
      end

      def param(name, opts={})
        opts = opts.merge(@opts)

        case opts[:default]
        when Proc
          # create getter method if proc is set as default value
          self.class_exec {
            define_method(name.to_s.to_sym) do
              @config[name.to_s.to_sym] || self.instance_exec(&opts[:default])
            end
          }
        else
          on_initialize_hook do |c|
            @config[name.to_s.to_sym] = opts[:default]
          end
        end

        @on_param_create_hooks.each { |blk|
          blk.call(name.to_s.to_sym, opts)
        }
        self.const_get(:DSL, false).class_eval %Q{
          def #{name}(v)
            @config["#{name.to_s}".to_sym] = v
          end
          alias_method :#{name.to_s}=, :#{name.to_s}
        }

        @opts.clear
        @on_param_create_hooks.clear
      end

      # Load configuration file
      #
      # 1. Simply loads single configuration file.
      #   conf = ConfigurationClass.load('1.conf')
      #
      # 2. Loads multiple files and merge.
      #
      # file1.conf:
      #   config.param1 = 1
      #
      # file2.conf:
      #   config.param1 = 2
      #
      #   conf = ConfigurationClass.load('file1.conf', 'file2.conf')
      #   conf.param1 == 2
      def load(*paths)
        c = self.new

        l = Loader.new(c)

        if paths.empty?
          l.load
        else
          paths.each { |path| l.load(path) }
        end

        l.validate

        c
      end

      # Helper method defines "module DSL" under the current conf class.
      #
      # This does mostly same things as "module DSL" but using
      # "module" statement get the "DSL" constant defined in unexpected
      # location if you combind to use with other Ruby DSL syntax.
      #
      # Usage:
      # class Conf1 < Configuration
      #   DSL do
      #   end
      # end
      def DSL(&blk)
        self.const_get(:DSL, false).class_eval(&blk)
        self
      end

      private
      def inherited(klass)
        super
        klass.const_set(:DSL, Module.new)
        klass.instance_eval {
          @on_initialize_hooks = []
          @opts = {}
          @on_param_create_hooks = []
        }

        dsl_mods = []
        c = klass
        while c < Configuration && c.superclass.const_defined?(:DSL, false)
          parent_dsl = c.superclass.const_get(:DSL, false)
          if parent_dsl && parent_dsl.class === Module
            dsl_mods << parent_dsl
          end
          c = c.superclass
        end
        # including order is ancestor -> descendants
        dsl_mods.reverse.each { |i|
          klass.const_get(:DSL, false).__send__(:include, i)
        }
      end

      def on_param_create_hook(&blk)
        @on_param_create_hooks << blk
      end
    end

    attr_reader :config, :parent

    def initialize(parent=nil)
      if !parent.nil? && !parent.is_a?(Fuguta::Configuration)
        raise ArgumentError, "parent must be a 'Fuguta::Configuration'. Got '#{parent.class}'."
      end
      @config = {}
      @parent = parent

      hook_lst = []
      c = self.class
      while c < Configuration
        hook_lst << c.instance_variable_get(:@on_initialize_hooks)
        c = c.superclass
      end

      hook_lst.reverse.each { |l|
        l.each { |c|
          self.instance_eval(&c)
        }
      }

      after_initialize
    end

    def after_initialize
    end

    def validate(errors)
    end

    SYNTAX_ERROR_SOURCES=[ScriptError, NameError].freeze

    def parse_dsl(&blk)
      dsl = self.class.const_get(:DSL, false)
      raise "DSL module was not found" unless dsl && dsl.is_a?(Module)

      cp_class = DSLProxy.dup
      cp_class.__send__(:include, dsl)
      cp = cp_class.new(self)

      begin
        cp.instance_eval(&blk)
      rescue *SYNTAX_ERROR_SOURCES => e
        raise Fuguta::SyntaxError.new(e, cp.instance_variable_get(:@loading_path))
      end

      self
    end

    private
    def method_missing(m, *args)
      if @config.has_key?(m.to_sym)
        @config[m.to_sym]
      elsif @config.has_key?(m.to_s)
        @config[m.to_s]
      else
        super
      end
    end

  end
end
