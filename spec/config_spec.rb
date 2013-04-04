require 'spec_helper'

describe Resque::Plugins::HerokuAutoscaler::Config do
  describe ".heroku_api_key" do
    it "stores the given heroku api key" do
      subject.heroku_api_key = "abcd"
      subject.heroku_api_key.should == "abcd"
    end

    it "defaults to HEROKU_API_KEY environment variable" do
      subject.heroku_api_key = nil
      ENV["HEROKU_API_KEY"]  = "abcdef"
      subject.heroku_api_key.should == "abcdef"
    end
  end

  describe ".heroku_app" do
    it "stores the given heroku application name" do
      subject.heroku_app = "my-grand-app"
      subject.heroku_app.should == "my-grand-app"
    end

    it "defaults to HEROKU_APP environment variable" do
      subject.heroku_app = nil
      ENV["HEROKU_APP"]  = "yaa"
      subject.heroku_app.should == "yaa"
    end
  end

  describe ".heroku_process" do
    it "stores the given heroku process name" do
      subject.heroku_process = "test-worker"
      subject.heroku_app.should == "test-worker"
    end

    it "defaults to worker" do
      subject.heroku_app = nil
      subject.heroku_app.should == "worker"
    end
  end

  describe ".scaling_disabled?" do

    it{ Resque::Plugins::HerokuAutoscaler::Config.scaling_disabled?.should be_false}

    it "sets scaling to disabled" do
      subject.scaling_disabled = true
      subject.scaling_disabled?.should be_true
    end
  end

  describe ".wait_time" do

    it{ Resque::Plugins::HerokuAutoscaler::Config.wait_time.should == 60}

    it "can be set" do
      subject.wait_time = 30
      subject.wait_time.should == 30
    end
  end

  describe ".new_worker_count" do
    before do
      @original_method = Resque::Plugins::HerokuAutoscaler::Config.instance_variable_get(:@new_worker_count)
    end

    after do
      Resque::Plugins::HerokuAutoscaler::Config.instance_variable_set(:@new_worker_count, @original_method)
    end

    it "should store a block as a Proc" do
      subject.new_worker_count do |pending|
        pending/5
      end

      subject.new_worker_count(10).should == 2
    end

    it "should be able to take the Resque job's payload as arguments" do
      subject.new_worker_count do |pending, queue|
        if queue == "test_queue"
          10
        else
          pending/5
        end
      end

      job_payload = ["test_queue", "more", "payload"]
      subject.new_worker_count(10, *job_payload).should == 10
    end

    context "when the proc was not yet set" do
      before do
        subject.new_worker_count do |pending, queue|
        end
        it { subject.new_worker_count(0).should == 0 }
        it { subject.new_worker_count(1).should == 1 }
      end
    end
  end
end
