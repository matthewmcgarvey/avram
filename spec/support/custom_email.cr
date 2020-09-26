class CustomEmail
  def initialize(@email : String)
  end

  def to_s
    value
  end

  private def value
    @email.strip.downcase
  end

  def blank?
    @email.blank?
  end

  module Lucky
    alias ColumnType = String
    extend Avram::Type

    def self._parse_attribute(value : CustomEmail)
      Avram::Type::SuccessfulCast(CustomEmail).new(value)
    end

    def self._parse_attribute(value : String)
      Avram::Type::SuccessfulCast(CustomEmail).new(CustomEmail.new(value))
    end

    def self.to_db(value : String)
      CustomEmail.new(value).to_s
    end

    def self.to_db(value : CustomEmail)
      value.to_s
    end

    class Criteria(T, V) < String::Lucky::Criteria(T, V)
      @upper = false
      @lower = false
    end
  end
end
