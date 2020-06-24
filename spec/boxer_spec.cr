require "./spec_helper"

class PlainModelBoxer < Avram::Boxer
end

class AdminBoxer < Avram::Boxer
  name "Admin"
end

class UserBoxer < Avram::Boxer
  name "Paul Smith"
  joined_at Time.utc
  age 18
end

class SignInCredentialBoxer < Avram::Boxer
  user UserBoxer
end


describe Avram::Boxer do
  it "can create a model without additional columns" do
    PlainModelBoxer.create.id.should_not be_nil
  end

  it "does stuff" do
    AdminBoxer.create.name.should eq("Admin")
  end

  it "handles associations" do
    sign_in_credential = SignInCredentialBoxer.create

    sign_in_credential.user.should_not be_nil
  end
end
