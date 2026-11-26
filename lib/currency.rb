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
end
