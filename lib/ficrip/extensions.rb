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
end