require "./validations"
require "./callbacks"
require "./define_attribute"
require "./save_operation_errors"
require "./param_key_override"
require "./needy_initializer"

abstract class Avram::Operation(T)
  include Avram::NeedyInitializer
  include Avram::DefineAttribute
  include Avram::Validations
  include Avram::SaveOperationErrors
  include Avram::ParamKeyOverride
  include Avram::Callbacks

  register_event :before_run
  register_event :after_run, T

  @params : Avram::Paramable
  getter params

  # Yields the instance of the operation, and the return value from
  # the `run` instance method.
  #
  # ```
  # MyOperation.run do |operation, value|
  #   # operation is complete
  # end
  # ```
  def self.run(*args, **named_args)
    params = Avram::Params.new
    run(params, *args, **named_args) do |operation, value|
      yield operation, value
    end
  end

  # Returns the value from the `run` instance method.
  # or raise `Avram::FailedOperation` if the operation fails.
  #
  # ```
  # value = MyOperation.run!
  # ```
  def self.run!(*args, **named_args)
    params = Avram::Params.new
    run!(params, *args, **named_args)
  end

  # Yields the instance of the operation, and the return value from
  # the `run` instance method.
  #
  # ```
  # MyOperation.run(params) do |operation, value|
  #   # operation is complete
  # end
  # ```
  def self.run(params : Avram::Paramable, *args, **named_args)
    operation = self.new(params, *args, **named_args)
    value = operation.do_run
    yield operation, value
  end

  # Returns the value from the `run` instance method.
  # or raise `Avram::FailedOperation` if the operation fails.
  #
  # ```
  # value = MyOperation.run!(params)
  # ```
  def self.run!(params : Avram::Paramable, *args, **named_args)
    run(params, *args, **named_args) do |_operation, value|
      raise Avram::FailedOperation.new("The operation failed to return a value") unless value
      value
    end
  end

  abstract def run : T

  def initialize(@params)
  end

  def initialize
    @params = Avram::Params.new
  end

  def valid?
    attributes.all? &.valid?
  end

  def do_run
    run_event :before_run
    value = run
    if valid?
      run_event :after_run, value
    else
      value = nil
    end
  end

  def self.param_key
    name.underscore
  end
end
