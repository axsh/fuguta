require 'spec_helper'

describe Fuguta::Configuration do
  class Test1 < Fuguta::Configuration
    param :param1
    param :param2
  end

  class NestTest1 < Test1
    param :param3

    def validate(errors)
      if @config[:param3].nil?
        errors << "Need to set param3"
      end
    end
  end

  class UsualPathTest < Test1
    usual_paths([ "../test1.conf", "../conf_files/test1.conf" ].map do |path|
      File.expand_path(path, __FILE__)
    end)
  end

  describe "#load" do
    let(:conf_path) { File.expand_path('../conf_files', __FILE__) }

    it "allows nested imports/loads" do
      conf = NestTest1.load("#{conf_path}/nest-test1.conf")
      expect(conf.param1).to eq(10)
      expect(conf.param2).to eq(20)
      expect(conf.param3).to eq(30)
    end

    context "with a single path (string) parameter" do
      it "loads conf file from that path" do
        conf = Test1.load("#{conf_path}/test1.conf")
        expect(conf.param1).to eq(1)
        expect(conf.param2).to eq(2)
      end
    end

    context "with multiple paths passed as parameters" do
      it "the config files override each other" do
        conf = Test1.load("#{conf_path}/test1.conf", "#{conf_path}/test2.conf")
        expect(conf.param1).to eq(10)
        expect(conf.param2).to eq(20)
      end
    end

    context "with no arguments" do
      context "when usual_paths is set" do
        it "loads configurations from the first existing path set in usual_paths" do
          conf = UsualPathTest.load
          expect(conf.param1).to eq(1)
          expect(conf.param2).to eq(2)
        end
      end

      context "when usual_paths is not set" do
        it "raises an error" do
          expect { Test1.load }.to raise_error(
            RuntimeError,
            "No path given and usual_paths not set"
          )
        end
      end
    end

    context 'when loading a config file with a faulty syntax' do
      it "throws syntax error" do
        expect {
          Test1.load("#{conf_path}/syntax-error.conf")
        }.to raise_error(Fuguta::SyntaxError)
      end
    end
  end
end
