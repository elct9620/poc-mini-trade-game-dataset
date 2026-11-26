# frozen_string_literal: true

##
# = Rebalancing
# Evens out one call's training samples by cell: a large cell is capped, keeping rows with rare features first,
# and a small cell is copied, each copy in another currency so no two samples are identical.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
class Rebalancing
  CAP_SHARE = 0.15
  FLOOR_SHARE = 0.25
  MAX_COPIES = 3
  SHORT_LINE = 6
  UNITS = /塊|元|枚/

  # Creates a new Rebalancing instance.
  #
  # rows - The dataset rows of one call.
  # cell - A lambda that returns a row's cell.
  # seed - The seed that orders rows of equal rarity.
  def initialize(rows, cell, seed: 0)
    @rows = rows
    @cell = cell
    @random = Random.new(seed)
  end

  # Executes the rebalancing.
  #
  # Returns pairs of [row, copy], where copy numbers the copies of a row from 0.
  def execute
    groups = @rows.group_by(&@cell)
    floor = (FLOOR_SHARE * @rows.size / groups.size).ceil
    cap = cap_for(groups.values.map(&:size), floor)
    groups.values.flat_map do |group|
      if group.size > cap then keep(group, cap)
      elsif group.size < floor then copy(group, copies(group.size, floor))
      else group.map { |row| [row, 0] }
      end
    end
  end

  private

  # Lowers the cap until every cell holds at most CAP_SHARE of the rebalanced total, since capping shrinks it.
  def cap_for(sizes, floor)
    cap = (CAP_SHARE * @rows.size).floor
    cap -= 1 while cap > floor && cap > CAP_SHARE * total(sizes, cap, floor)
    cap
  end

  def total(sizes, cap, floor)
    sizes.sum { |size| size > cap ? cap : size < floor ? size * copies(size, floor) : size }
  end

  def copies(size, floor)
    [(floor.to_f / size).ceil, MAX_COPIES].min
  end

  def keep(group, cap)
    group.sort_by { |row| [-rarity(row), @random.rand] }.first(cap).map { |row| [row, 0] }
  end

  def copy(group, copies)
    group.flat_map { |row| Array.new(copies) { |index| [row, index] } }
  end

  # Counts the features the model sees too rarely: a short line, an offer without a unit,
  # a first-turn offer, and a hostile NPC.
  def rarity(row)
    offer = row['intent'] == 'offer'
    [
      row['input'].to_s.gsub(/\s/, '').size <= SHORT_LINE,
      offer && !row['input'].to_s.include?(row['currency'].to_s) && !row['input'].to_s.match?(UNITS),
      offer && row['previous_player'].to_s.empty?,
      row['relationship'] == 'hostile'
    ].count(true)
  end
end
