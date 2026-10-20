# frozen_string_literal: true

require_relative 'chat_format'

##
# = Negotiation
# Computes the locked prices of a bargaining negotiation and the game step of one turn.
# Validation, conversion, and evaluation share it so every bargaining row follows the same rules.
# The game step mirrors the TLA+ model in docs/features/bargaining/Bargain.tla.
#
# == Reference
# - {docs/features/bargaining.md}[docs/features/bargaining.md]
##
module Negotiation
  # Concession parameters by the relationship at the start of a negotiation.
  PARAMETERS = {
    'Hostile' => { markup: Rational('0.30'), alpha: Rational('0.3'), min_step: Rational('0.05'), patience: 2 },
    'Neutral' => { markup: Rational('0.25'), alpha: Rational('0.5'), min_step: Rational('0.10'), patience: 3 },
    'Friendly' => { markup: Rational('0.15'), alpha: Rational('0.7'), min_step: Rational('0.15'), patience: 4 },
    'Allied' => { markup: Rational('0.10'), alpha: Rational('0.9'), min_step: Rational('0.20'), patience: 5 }
  }.freeze
  ALLIED_FLOOR_SHARE = Rational(1, 2)
  MAX_STEP_SHARE = Rational(1, 4)
  PROGRESS_SHARE = Rational(1, 20)
  # Friends sell at the counter when offered more.
  FRIENDS = %w[Friendly Allied].freeze
  # The highest rudeness each merchant lets pass; anything ruder ends the negotiation.
  RUDE_TOLERANCE = { 'Hostile' => 'none', 'Neutral' => 'mild', 'Friendly' => 'severe', 'Allied' => 'severe' }.freeze
  RUDE_LEVELS = %w[none mild severe].freeze
  REPLY_ACTIONS = { deal: 'sell', counter: 'negotiate', walkaway: 'refuse', chat: 'talk' }.freeze
  CHINESE_DIGITS = { '零' => 0, '〇' => 0, '一' => 1, '二' => 2, '兩' => 2, '三' => 3, '四' => 4,
                     '五' => 5, '六' => 6, '七' => 7, '八' => 8, '九' => 9 }.freeze
  CHINESE_UNITS = { '十' => 10, '百' => 100, '千' => 1000 }.freeze

  module_function

  # A lone Chinese numeral is a price only before a coin unit, a final particle, or the end of a clause,
  # so words such as 一點, 一個 or 一定 are not read as 1.
  CHINESE_PRICE = /(?<![零〇一二兩三四五六七八九十百千萬])
                   (?:[零〇一二兩三四五六七八九十百千][零〇一二兩三四五六七八九十百千萬]+
                     |[零〇一二兩三四五六七八九十百千](?=[金塊元枚銀銅吧呢啊嗎啦喔哦嘛]|[\s\p{P}]|\z))/x

  # Returns every price written in a player's message, in Arabic digits (half or full width) or Chinese numerals.
  def stated_numbers(text)
    normalized = text.to_s.tr('０-９', '0-9')
    normalized.scan(/\d+/).map(&:to_i) + normalized.scan(CHINESE_PRICE).map { |run| chinese_number(run) }
  end

  # An offer counts only when the player wrote that price; the game reads any other extracted offer as a haggle.
  def offer_stated?(text, offer)
    stated_numbers(text).include?(offer.to_i)
  end

  def chinese_number(run)
    total = 0
    section = 0
    digit = nil
    run.each_char do |char|
      if CHINESE_DIGITS.key?(char)
        digit = CHINESE_DIGITS[char]
      elsif char == '萬'
        total += (section + digit.to_i) * 10_000
        section = 0
        digit = nil
      else
        section += (digit || 1) * CHINESE_UNITS[char]
        digit = nil
      end
    end
    total + section + digit.to_i
  end

  # Returns the patience a negotiation starts with for a relationship.
  def patience_limit(relationship)
    PARAMETERS.fetch(relationship)[:patience]
  end

  # Returns the floor and opening prices, locked when the negotiation starts.
  def prices(row)
    relationship = row['relationship_status']
    asking = ChatFormat.asking_price(row)
    floor = relationship == 'Allied' ? (row['item_expected_price'].to_r * ALLIED_FLOOR_SHARE).ceil : asking
    opening = (asking * (1 + PARAMETERS.fetch(relationship)[:markup])).ceil
    { floor: floor, opening: opening }
  end

  # Returns the outcome of a bargaining row's turn: the outcome, the expected reply action and price,
  # and the counter and patience after the turn.
  def turn(row)
    state = parse(row)
    outcome = outcome_of(state, prices(row), PARAMETERS.fetch(row['relationship_status']))
    outcome.merge(action: REPLY_ACTIONS.fetch(outcome[:outcome]))
  end

  def parse(row)
    {
      relationship: row['relationship_status'],
      round: row['round'].to_i,
      patience: row['patience'].to_i,
      counter: row['counter_price'].to_i,
      best_offer: row['best_offer'].to_s.empty? ? nil : row['best_offer'].to_i,
      last_offer: row['last_offer'].to_s.empty? ? nil : row['last_offer'].to_i,
      intent: row['intent'],
      rude: row['rude'],
      offer: row['player_offer'].to_i
    }
  end

  def outcome_of(state, prices, params)
    return walkaway(state) if state[:intent] == 'threat'
    return walkaway(state) if too_rude?(state)

    case state[:intent]
    when 'chat' then { outcome: :chat, price: nil, counter: state[:counter], patience: state[:patience] }
    when 'haggle' then haggle(state)
    else offer(state, prices, params)
    end
  end

  # Rudeness beyond the merchant's tolerance ends the negotiation; tolerated rudeness follows the turn's intent.
  def too_rude?(state)
    RUDE_LEVELS.index(state[:rude]).to_i > RUDE_LEVELS.index(RUDE_TOLERANCE.fetch(state[:relationship]))
  end

  # Haggling without a price is free only in the first round and never earns a concession.
  def haggle(state)
    cost = state[:round] == 1 ? 0 : 1
    return walkaway(state) if state[:patience] <= cost

    { outcome: :counter, price: state[:counter], counter: state[:counter], patience: state[:patience] - cost }
  end

  def offer(state, prices, params)
    floor = prices[:floor]
    counter = state[:counter]
    offer = state[:offer]
    raise_amount = offer_raise(state, floor)
    progress = state[:best_offer].nil? || raise_amount >= (prices[:opening] * PROGRESS_SHARE).ceil
    step = progress ? concession(raise_amount, prices, params) : 0
    next_counter = offer >= counter ? counter : [floor, counter - step].max

    return deal(state, offer, next_counter) if offer >= next_counter

    cost = if 2 * offer < floor then 2
           elsif progress then 0
           else 1
           end
    return walkaway(state) if state[:patience] <= cost

    { outcome: :counter, price: next_counter, counter: next_counter, patience: state[:patience] - cost }
  end

  # A deal only offers the purchase; accepting again after declining one stalls like a haggle.
  def deal(state, offer, next_counter)
    cost = declined?(state) ? 1 : 0
    return walkaway(state) if state[:patience] <= cost

    price = FRIENDS.include?(state[:relationship]) ? next_counter : offer
    { outcome: :deal, price: price, counter: next_counter, patience: state[:patience] - cost }
  end

  # The last offer meets the counter only when the merchant agreed to it and the player did not buy.
  def declined?(state)
    !state[:last_offer].nil? && state[:last_offer] >= state[:counter]
  end

  # Raises count from the best offer so far, floored at half the floor, so a lowball
  # cannot inflate the next raise and dropping back cannot re-earn progress.
  def offer_raise(state, floor)
    return 0 if state[:best_offer].nil?

    [state[:offer] - [state[:best_offer], (floor * Rational(1, 2)).ceil].max, 0].max
  end

  # One concession gives back a share of the raise, at least the minimum step and at most a quarter of the range.
  def concession(raise_amount, prices, params)
    range = prices[:opening] - prices[:floor]
    min_step = (range * params[:min_step]).ceil
    max_step = [min_step, (range * MAX_STEP_SHARE).floor].max
    (raise_amount * params[:alpha]).floor.clamp(min_step, max_step)
  end

  def walkaway(state)
    { outcome: :walkaway, price: nil, counter: state[:counter], patience: 0 }
  end

  private_class_method :chinese_number, :parse, :outcome_of, :too_rude?, :haggle, :offer, :deal, :declined?, :offer_raise, :concession, :walkaway
end
