require "../spec_helper"

describe "UUID column type" do
  describe ".parse" do
    it "casts a UUID successfully" do
      uuid = UUID.new("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
      UUID::Lucky._parse_attribute(uuid).value.should eq uuid
    end

    it "casts a string successfully" do
      UUID::Lucky._parse_attribute("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
        .should be_a(Avram::Type::SuccessfulCast(UUID))
    end

    it "cannot cast a non-uuid string" do
      UUID::Lucky._parse_attribute("not a uuid").should be_a(Avram::Type::FailedCast)
    end
  end

  describe ".to_db" do
    it "turns the uuid into a string" do
      uuid = UUID.new("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
      UUID::Lucky.to_db(uuid).should eq "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    end
  end
end
