require 'set'

class ConfigHash < Hash
  def method_missing(sel, *args)
    self[sel]
  end
end

class ConfigSyntaxError < StandardError
end

def parse_raw_value(raw_value)
  case raw_value
  when /\A\d+\Z/
    value = raw_value.to_i
  when /\A"([^"]*)"\Z/
    value = $1
  when /.+,.+/
    value = raw_value.split(/,/)
  else
    value = raw_value
  end
end

def canonicalize_boolean(value)
  case value
  when 1,"on","yes","true"
    true
  when 0,"off","no","false"
    false
  else
    value
  end
end
    
def load_config(path, overrides=[])
  override_set = Set.new(overrides.map(&:to_s))
  state = :toplevel
  current_section_name = nil
  sections = ConfigHash.new

  open(path) do |f|
    f.each do |line|
      # eat blank and comment lines
      next if (line =~ /^\s*$/ || line =~ /\s*;.*$/)
      if state == :toplevel
        if line =~ /^\s*\[(\w+)\]/
          current_section_name = $1.to_sym
          sections[current_section_name] = ConfigHash.new
          state = :section
        else
          raise ConfigSyntaxError, "Syntax error at toplevel"
        end
      elsif state == :section
        if line =~ /^\s*(\w+)(<(\w+)>)?\s*=\s*(.+)(?:\s*;.*)?/
          name = $1
          override = $3
          raw_value = $4
          value = parse_raw_value(raw_value)
          # String is also enumerable and responds to most of the same methods,
          # but we still want to handle arrays separately, so we have to break duck typing
          if value.is_a? Array
            value = value.map { |v| parse_raw_value(v) }
          end
          value = canonicalize_boolean(value)
          if (override && !override.empty? && override_set.member?(override)) || (!override || override.empty?)
            sections[current_section_name][name.to_sym] = value
          end
        elsif line =~ /^\s*\[(\w+)\]/
          current_section_name = $1.to_sym
          sections[current_section_name] = ConfigHash.new
        else
          raise ConfigSyntaxError, "Syntax error in section '#{current_section_name.to_s}'"
        end
      end
    end
  end
  return sections
end
