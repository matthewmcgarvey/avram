module Avram::Uploadable
  extend Avram::Type

  def self.parse_attribute(value : String?)
    Avram::Type::FailedCast.new
  end

  abstract def tempfile : File
  abstract def metadata : HTTP::FormData::FileMetadata
  # Typically, this should return the filename as found in the `metadata`.
  abstract def filename : String
  # This should test if the filename is a blank string.
  abstract def blank? : Bool
end
