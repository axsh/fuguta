require 'spec_helper'

describe Fuguta::Helpers::ConfigurationMethod do
  context "features planned to deprecate" do
    class Base < Fuguta::Configuration
      include Fuguta::Configuration::ConfigurationMethods
      def_configuration do
        param :xxxx
        param :yyyy
      end
    end
    class A < Base
      def_configuration do
        param :zzzz
      end
      def_configuration do
        param :xyxy
      end
    end
    class B < A
    end

    describe A do
      it "confirms constants and class variables to be created" do
        expect(defined?(A::Configuration)).to be_true
        expect(A::Configuration.superclass).to be(Base::Configuration)
        expect(A.configuration_class).to be(A::Configuration)
      end
    end

    describe B do
      it "confirms subclass shares configuration class from parent class's" do
        expect(B.configuration_class).to be(A::Configuration)
      end
    end
  end
end
