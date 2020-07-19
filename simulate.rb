require_relative './parser'

#==============================================================================
# ** Util
#==============================================================================

module Util

  def self.tile_value(tile)
    return 10 if tile >= 27
    return tile % 9 + 1
  end
    
end

#==============================================================================
# ** ConfigurationNode
#==============================================================================

class ConfigurationNode

  attr_reader   :outs
  attr_reader   :shanten
  attr_reader   :children

  def initialize(hand)
    @hand = hand

    setup_configuration

    @shanten = calculate_shanten
    @outs = calculate_outs
    @children = create_child_nodes
  end

  def setup_configuration
    raise "Not Implemented"
  end

  def calculate_shanten
    raise "Not Implemented"
  end

  def calculate_outs
    raise "Not Implemented"
  end

  def create_child_nodes
    raise "Not Implemented"
  end

end

#==============================================================================
# ** ConfigurationNode_Chiitoi
#==============================================================================

class ConfigurationNode_Chiitoi < ConfigurationNode

  def setup_configuration
    @pairs = @hand.uniq.select { |tile| @hand.count(tile) >= 2 }
    @pair_candidates = @hand.uniq - @pairs
  end

  def calculate_shanten
    shanten = 6 - @pairs.length
    shanten += [shanten - @pair_candidates.length + 1, 0].max

    return shanten
  end

  def calculate_outs
    # If we don't have enough candidates for seven pairs, we need to draw into
    # more pairs, so anything that isn't already a pair is an upgrade.

    return @pair_candidates if @pair_candidates.length + @pairs.length >= 7
    return 0.upto(33).to_a - @pairs
  end

  def create_child_nodes
    children = {}
    return children if @shanten == 0

    @outs.each { |out|
      children[out] = []

      tiles_to_evict = @pairs.select { |tile| @hand.count(tile) > 2 }
      tiles_to_evict = @pair_candidates - [out] if tiles_to_evict.empty?

      tiles_to_evict.each { |tile|
        new_hand = @hand.clone

        new_hand.delete_at(new_hand.index(tile))
        new_hand.push(out)
        new_hand.sort!

        children[out].push(ConfigurationNode_Chiitoi.new(new_hand))
      }
    }

    return children
  end

end

#==============================================================================
# ** Simulator
#==============================================================================

module Simulator

  def self.simulate(node, draws_left, end_shanten, memo = {})
    return 0 if draws_left <= node.shanten - end_shanten
    
    memo[node] ||= Array.new(18, nil)
    return memo[node][draws_left] if memo[node][draws_left]

    # TODO: Eventually wall will be influenced by dora.
    wall = 123 - (18 - draws_left)

    if node.shanten == end_shanten
      agari_chance = (node.outs.length * 3.0 / wall)
      agari_chance += (1 - agari_chance) * self.simulate(node, draws_left - 1, end_shanten, memo)
      
      memo[node][draws_left] = agari_chance
      return agari_chance
    end

    agari_chance = 0
    total_advance_chance = 0

    node.outs.each { |out|
      advance_chance = (3.0 / wall)
      total_advance_chance += advance_chance

      best_agari_chance = 0

      node.children[out].each { |new_node|
        new_agari_chance = self.simulate(new_node, draws_left - 1, end_shanten, memo)
        best_agari_chance = [best_agari_chance, new_agari_chance].max
      }

      agari_chance += advance_chance * best_agari_chance
    }


    agari_chance += (1 - total_advance_chance) * self.simulate(node, draws_left - 1, end_shanten, memo)

    memo[node][draws_left] = agari_chance

    return memo[node][draws_left]
  end

end

#==============================================================================
# ** Mentsu Configuration
#==============================================================================

def calc_mentsu_configurations(hand, max_mentsu=4)
  # The queue is a list of arrays that contains information regarding the 
  # tiles that need to be parsed, the tiles that have already been parsed,
  # the number of mentsu in the hand, and whether or not the parsed tiles has a head.
  queue = [[hand, [], 0, false]]

  until queue.empty?

    # If we've already found a match, then we can filter out all the elements
    # in the queue that still have tiles remaining and disregard the rest.
    if queue[0][0].empty?
      return queue.select { |elem| elem[0].empty? }.map { |elem| elem[1] }
    end

    curr_hand, curr_groups, mentsu_count, has_atama = queue.shift

    curr_tile = curr_hand[0]
    num_curr_tile = curr_hand.count(curr_tile)

    tile_one_above = (Util.tile_value(curr_tile) < 9 ? curr_hand.index(curr_tile + 1) : nil)
    tile_two_above = (Util.tile_value(curr_tile) < 8 ? curr_hand.index(curr_tile + 2) : nil)

    if curr_hand.length > 2 and mentsu_count < max_mentsu
      # Parse Kotsu
      if num_curr_tile >= 3
        new_hand = curr_hand[3..-1]
        new_groups = curr_groups + [curr_hand[0..2]]

        queue.push([new_hand, new_groups, mentsu_count + 1, has_atama])
      end

      # Parse Shuntsu
      if tile_one_above and tile_two_above
        new_hand = curr_hand[1..-1]
        new_hand.delete_at(tile_two_above - 1)
        new_hand.delete_at(tile_one_above - 1)

        new_groups = curr_groups + [[curr_tile, curr_hand[tile_one_above], curr_hand[tile_two_above]]]

        queue.push([new_hand, new_groups, mentsu_count + 1, has_atama])
      end
    end
    
    if curr_hand.length > 1
      # Toitsu
      if num_curr_tile >= 2 and (mentsu_count < max_mentsu or not has_atama)
        new_hand = curr_hand[2..-1]
        new_groups = curr_groups + [curr_hand[0..1]]
        new_mentsu_count = (has_atama ? mentsu_count + 1 : mentsu_count)

        queue.push([new_hand, new_groups, new_mentsu_count, true])
      end

      if mentsu_count < max_mentsu
        # Ryanmen / Penchan
        if tile_one_above
          new_hand = curr_hand[1..-1]
          new_hand.delete_at(tile_one_above)

          new_groups = curr_groups + [[curr_tile, curr_hand[tile_one_above]]]

          queue.push([new_hand, new_groups, mentsu_count + 1, has_atama])
        end

        # Kanchan
        if tile_two_above
          new_hand = curr_hand[1..-1]
          new_hand.delete_at(tile_two_above)

          new_groups = curr_groups + [[curr_tile, curr_hand[tile_two_above]]]

          queue.push([new_hand, new_groups, mentsu_count + 1, has_atama])
        end
      end
    end

    # Tanki
    new_hand = curr_hand[1..-1]
    new_groups = curr_groups + [[curr_tile]]

    queue.push([new_hand, new_groups, mentsu_count, has_atama])
  end
end

#==============================================================================
# ** Main
#==============================================================================


hand = Parser.parse_hand_string('223344m2233567p')
node = ConfigurationNode_Chiitoi.new(hand)

@memo = {}

t = Time.now
# p Simulator.simulate(node, 18, 0, @memo)
p Simulator.simulate(node, 18, 1, @memo)
p Time.now - t

p @memo[node]

# p simulate_chiitoi(hand)
# p calc_mentsu_configurations(hand, 4)