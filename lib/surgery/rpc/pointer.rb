module Surgery
module RPC
class Pointer
  def initialize(base, base_name = "context", input = nil)
    @base = base
    @base_name = base_name

    if input.is_a?(String)
      parse(input)
    end
  end

  def dump
    @access_path || raise(ProcessingError, "pointer can't be empty")
  end

  def load(input)
    @access_path = input.map do |type, key|
      [type.to_sym, key]
    end

    traverse_access_path(traverse_values: false)

    self
  end

  def parse(input)
    unless input =~ Regexp.new("^#{@base_name}")
      raise PointerError, "access path should start with `#{@base_name}`"
    end

    access_path = input.scan(/(\.(\w+))|(\[(\d+)\])|(\[['"](\w+)['"]\])/).map do |match|
      if (key = match[1])
        [:struct, key]
      elsif (key = match[3])
        [:repeated, key.to_i]
      elsif (key = match[5])
        [:map, key]
      end
    end

    if access_path.empty?
      raise PointerError, "access path should not be empty"
    end

    @access_path = access_path
    traverse_access_path
  end

  def to_s
    @access_strings.join
  end

  def inspect_path
    @access_values.each_with_index do |access_value, index|
      if index > 0
        accessor_type, accessor_key = @access_path[index - 1]
        puts "Accessing #{accessor_type} with key #{accessor_key.inspect}"
      end
      puts "At #{access_value.inspect}"
    end
  end

  private

  def traverse_access_path(traverse_values: true)
    if traverse_values
      access_value = @base
      access_values = [@base]
    end
    access_strings = [@base_name]

    begin
      @access_path.each do |type, key|
        case type
        when :struct
          access_strings << ".#{key}"
          access_value = access_value.send(key) if traverse_values
        when :repeated, :map
          access_strings << "[#{key.inspect}]"
          access_value = access_value[key] if traverse_values
        end

        access_values << access_value if traverse_values
      end
    rescue StandardError
      raise PointerError, "unable to access #{access_strings.join}"
    end

    @access_values = access_values if traverse_values
    @access_strings = access_strings
  end
end
end
end
