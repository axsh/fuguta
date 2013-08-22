require 'spec_helper'

describe Fuguta::Configuration do
  class Test1 < Fuguta::Configuration
    param :param1
    param :param2
  end
  
  it "loads conf file" do
    conf = Test1.load(File.expand_path('../test1.conf', __FILE__))
    expect(conf.param1).to eq(1)
    expect(conf.param2).to eq(2)
  end
end
