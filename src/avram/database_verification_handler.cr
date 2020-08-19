require "http"

# Verifies that no migrations are pending
# and that all models are correctly mapped to the database
class Avram::DatabaseVerificationHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    if Avram.settings.perform_database_check
      Avram::Migrator::Runner.new.ensure_migrated!
      Avram::SchemaEnforcer.ensure_correct_column_mappings!
    end

    call_next(context)
  end
end
