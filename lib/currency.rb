# frozen_string_literal: true

require 'zlib'

##
# = Currency
# Picks the currency a sample is written in. Train and test use disjoint currencies,
# so test measures whether replies follow a currency the model never saw.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
module Currency
  TRAIN = %w[金幣 銀幣 銅幣 晶石 貝殼 靈石 銀兩 代幣 寶石 點數].freeze
  TEST = %w[信用點 星幣 能量幣].freeze

  module_function

  # Returns the currency for a row; the item name keeps one negotiation in one currency,
  # and each copy moves to the next currency of the list.
  def pick(row, list, copy = 0)
    list[(Zlib.crc32(row['item_name'].to_s) + copy) % list.size]
  end

  # Returns a currency that collides with the item: the item name's last two characters, such as 鎖鏈 for 銀鎖鏈.
  # A line naming the item then holds the same word as a noun and as the unit of the price.
  def collision(row)
    row['item_name'].to_s[-2..]
  end

  # Returns whether the row's line or previous turn names the collision currency as a noun.
  def collides?(row)
    word = collision(row)
    !word.nil? && [row['input'], row['previous_player']].any? { |text| text.to_s.include?(word) }
  end
end
