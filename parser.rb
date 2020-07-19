#==============================================================================
# ** Parser
#==============================================================================

module Parser

  def self.parse_hand_string(string)
    map = {'m' => 0, 'p' => 1, 's' => 2, 'z' => 3}

    result = []
    tmp = []

    string.each_char { |c|
      if map.has_key?(c)
        result += tmp.map { |i| i + map[c] * 9 }
        tmp.clear
      else
        raise Exception('Invalid Input') if not c[/[1-9]/]
        tmp.push(c.to_i - 1)
      end
    }

    return result
  end

end