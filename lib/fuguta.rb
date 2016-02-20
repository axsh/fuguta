# -*- coding: utf-8 -*-

module Fuguta
  class ValidationError < StandardError
    attr_reader :errors
    def initialize(errors)
      super("validation error")
      @errors = errors
    end
  end

  class SyntaxError < StandardError
    # self.cause() is as of Ruby 2.1 so we
    # handles root error .
    attr_reader :root_cause, :source

    def initialize(root_cause, source="")
      super("Syntax Error")
      raise ArgumentError, 'root_cause' unless root_cause.is_a?(::Exception)
      @root_cause = root_cause
      @source = source
    end

    def message
      if @root_cause.backtrace.first =~ /:(\d+):in `/ ||
          @root_cause.backtrace.first =~ /:(\d+)$/
        line = $1.to_i
      end
      "%s from %s:%d" % [super(), @source, line]
    end
  end
end

require 'fuguta/configuration'
require 'fuguta/loader'
