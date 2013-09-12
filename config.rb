require 'set'

# trivial extension of Hash to allow access of keys via method call
class ConfigHash < Hash
  def method_missing(sel, *args)
    self[sel]
  end
end

# signal parse errors by raising an exception
class ConfigSyntaxError < StandardError
end


# helper functions for extracting values from parsed-out parameter values

def parse_raw_value(raw_value)
  case raw_value
  when /\A\d+\Z/ # parse numbers as numbers
    value = raw_value.to_i
  when /\A"([^"]*)"\Z/ # parse quoted strings as strings
    value = $1
    # if it contains a comma with stuff on either side AND
    # isn't wholly enclosed in quotes, it's a list
  when /.+,.+/ 
    value = raw_value.split(/,/)
  else # otherwise, it's just a raw string
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
  current_section_name = nil
  sections = ConfigHash.new(ConfigHash.new(nil)) 

  open(path) do |f|
    f.each do |line|
      # eat blank and comment lines
      next if (line =~ /^\s*$/ || line =~ /\s*;.*$/)

      if /^\s* # eat leading whitespace
                     \[(?<section_name>\w+)\] # capture the section name
         /x =~ line
        current_section_name = section_name.to_sym
        sections[current_section_name] = ConfigHash.new
      elsif /^\s* # eat leading whitespace
              (?<name>\w+)(<(?<override>\w+)>)? # capture parameter
                                                # name and optional
                                                # override
              \s*=\s* # eat whitespace on either side of the =
              (?<raw_value>.+) # capture parameter value, making no
                               # assumptions about what characters are
                               # allowed in a value, except:
              (?:\s*;.*)? # if we see a semicolon (with none or any
                          # whitespace immediately before it), treat
                          # the rest of the line as a comment
            /x =~ line
        value = parse_raw_value(raw_value)
        # String is also enumerable and responds to most of the same methods,
        # but we still want to handle arrays separately, so we have to break duck typing
        if value.is_a? Array
          value = value.map { |v| parse_raw_value(v) }
        end
        value = canonicalize_boolean(value)
        # if there's an override, unless it's in the set of overrides
        # passed in, ignore it. otherwise, set the value.  we don't
        # bother storing any other other overrides for the value,
        # since they're not needed after the file has been read.
        if (override && !override.empty? && override_set.member?(override)) || 
            (!override || override.empty?)
          sections[current_section_name][name.to_sym] = value
        end
      else
        raise ConfigSyntaxError, "Syntax error on line #{f.lineno}"
      end
    end
  end
  return sections
end
