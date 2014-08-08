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

  let(:conf_path) { File.expand_path('../conf_files', __FILE__) }

  it "loads conf file" do
    conf = Test1.load("#{conf_path}/test1.conf")
    expect(conf.param1).to eq(1)
    expect(conf.param2).to eq(2)
  end

  it "loads multiple conf files" do
    conf = Test1.load("#{conf_path}/test1.conf", "#{conf_path}/test2.conf")
    expect(conf.param1).to eq(10)
    expect(conf.param2).to eq(20)
  end

  it "allows nested imports/loads" do
    conf = NestTest1.load("#{conf_path}/nest-test1.conf")
    expect(conf.param1).to eq(10)
    expect(conf.param2).to eq(20)
    expect(conf.param3).to eq(30)
  end

  context('Syntax Error') do
    it "throws syntax error" do
      expect {
        Test1.load("#{conf_path}/syntax-error.conf")
      }.to raise_error(Fuguta::SyntaxError)
    end
  end
end
