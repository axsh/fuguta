
require 'fuguta'

module Fuguta
  class Loader
    def initialize(conf)
      @conf = conf
    end

    def load(path = nil)
      buf = case path
            when NilClass
              raise "No path given and usual_paths not set" unless @conf.usual_paths

              path = @conf.usual_paths.find { |path| File.exists?(path) } ||
                raise("None of the usual paths existed: #{@conf.usual_paths.join(", ")}")

              File.read(path)
            when String
              raise "does not exist: #{path}" unless File.exists?(path)
              File.read(path)
            when IO
              path.lines.join
            else
              raise "Unknown type: #{path.class}"
            end

      @conf.parse_dsl do |me|
        me.instance_variable_set(:@loading_path, path.to_s)
        me.instance_eval(buf, path.to_s)
        me.instance_variable_set(:@loading_path, nil)
      end
    end

    def validate
      errors = []
      Configuration.walk_tree(@conf) do |c|
        c.validate(errors)
      end
      raise ValidationError, errors if errors.size > 0
    end
  end
end
