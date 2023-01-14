require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::Teamspeak3VersionCheckerAgent do
  before(:each) do
    @valid_options = Agents::Teamspeak3VersionCheckerAgent.new.default_options
    @checker = Agents::Teamspeak3VersionCheckerAgent.new(:name => "Teamspeak3VersionCheckerAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
