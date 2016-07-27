# frozen_string_literal: true

class String
  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
end

class Object
  # From http://stackoverflow.com/a/8206537
  # Rubinius-compatible
  def deep_clone
    return @deep_cloning_obj if @deep_cloning
    return self if instance_of?(String) && frozen?
    @deep_cloning_obj = clone
    @deep_cloning_obj.instance_variables.each do |var|
      val = @deep_cloning_obj.instance_variable_get(var)
      begin
        @deep_cloning = true
        val = val.deep_clone
      rescue TypeError
        next
      ensure
        @deep_cloning = false
      end
      @deep_cloning_obj.instance_variable_set(var, val)
    end
    deep_cloning_obj = @deep_cloning_obj
    @deep_cloning_obj = nil
    deep_cloning_obj
  end
end


# Result class
class Result < Delegator
  attr_reader :result, :initial, :exceptions

  def __getobj__
    @result
  end

  def initialize(initial, res = nil)
    @initial = initial
    @result = res
    @exceptions = [nil]
  end

  def try_this(ignoring: StandardError)
    ignoring = [ignoring].flatten
    begin
      @result = yield(@initial) if @result.nil?
      @exceptions << nil
    rescue *ignoring => e
      @exceptions << e
    rescue # Everything else
      raise
    end
    self
  end

  alias and_this try_this
end

# Object class
class Object
  def try_this(ignoring: StandardError)
    ignoring = [ignoring].flatten
    begin
      Result.new self, yield(self)
    rescue *ignoring => e
      Result.new(self).tap do |r|
        r.instance_variable_set :@exceptions, [e]
      end
    rescue # Everything else
      raise
    end
  end
end