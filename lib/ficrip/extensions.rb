

class Array
  def find_with(str)
    r = find { |i| i.start_with? str }
    r.gsub(str, '').strip if r
  end
end

class String
  def parse_int
    gsub(/[^\d]/, '').to_i
  end

  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
end

class Object
  def as
    yield self
  end

  # From http://stackoverflow.com/a/8206537
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

class Result
  attr_accessor :result, :initial
  def initialize(val, res = nil)
    @initial = val
    @result = res
  end
end

class Object
  def try
    begin
      if instance_of? Result
        return @result ? self : Result.new(@initial, yield(@initial))
      else
        return Result.new(self, yield(self))
      end
    rescue
      return instance_of?(Result) ? self :  Result.new(self)
    end
  end
end