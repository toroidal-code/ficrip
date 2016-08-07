# frozen_string_literal: true

class String
  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '')
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