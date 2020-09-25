struct JSON::Any
  def self.adapter
    Lucky
  end

  module Lucky
    alias ColumnType = JSON::Any
    include Avram::Type

    def from_rs(rs : PG::ResultSet)
      rs.read(JSON::Any?)
    end

    def parse(value : JSON::Any)
      SuccessfulCast(JSON::Any).new value
    end

    def parse(value)
      SuccessfulCast(JSON::Any).new JSON.parse(value.to_json)
    end

    def to_db(value)
      value.to_json
    end

    class Criteria(T, V) < Avram::Criteria(T, V)
    end
  end
end
