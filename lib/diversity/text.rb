# frozen_string_literal: true

class Diversity
  ##
  # = Diversity::Text
  # Normalises a line so that only its wording is compared: the item name and amounts are slots.
  #
  # == Reference
  # - {docs/tools/diversity.md}[docs/tools/diversity.md]
  ##
  module Text
    DIGIT_AMOUNT = /[0-9０-９]+(?:[,，][0-9０-９]{3})*/
    CHINESE_AMOUNT = /[零〇一二兩三四五六七八九十百千萬]+(?=金|塊|枚)/

    module_function

    # Returns the text with the item name replaced by @ and every amount by #.
    def normalize(text, item_name)
      text = text.to_s
      text = text.gsub(item_name, '@') unless item_name.to_s.empty?
      text.gsub(DIGIT_AMOUNT, '#').gsub(CHINESE_AMOUNT, '#')
    end

    # Returns the character n-grams of the text for each length in the range.
    def ngrams(text, sizes)
      sizes.flat_map { |size| (0..(text.length - size)).map { |start| text[start, size] } }
    end
  end
end
