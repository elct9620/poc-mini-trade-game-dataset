# frozen_string_literal: true

require 'json'
require_relative 'negotiation'

##
# = BargainingFormat
# Builds the extraction and response conversations of a bargaining row from the shared prompt templates,
# so training and the game send the model the same two calls each turn.
#
# == Reference
# - {docs/features/bargaining.md}[docs/features/bargaining.md]
# - {docs/features/bargaining/prompts.md}[docs/features/bargaining/prompts.md]
##
module BargainingFormat
  EXTRACTION_PROMPT = <<~PROMPT.chomp
    You are the merchant's assistant in a trade game. Read the player's message during bargaining and report what the player intends.

    Bargaining:
    - Item: %<item_name>s
    - Counter Price: %<counter_price>s
    - Last Exchange: %<last_exchange>s
    - Previous Turn: %<previous_turn>s

    You must respond with a JSON object with the following format:
    {
      "intent": "offer" | "haggle" | "chat" | "threat",
      "rude": "none" | "mild" | "severe" (mild: disparaging the goods or price, sharp or impatient tone; severe: insults, cursing, or demanding it for free),
      "player_offer": number (the price written in the player's message, or null unless intent is "offer")
    }
  PROMPT

  RESPONSE_PROMPT = <<~PROMPT.chomp
    You are trading with player in a trade game. You are bargaining with the player over one item. Based on the context, you will decide what action to take.

    Current Inventory:
    - Name: %<item_name>s
    - Rarity: %<item_rarity>s
    - Expected Price: %<item_expected_price>s
    - Opening Price: %<opening_price>s

    Relatioship: %<relationship_status>s

    Bargaining:
    - Round: %<round>s
    - Player Offer: %<player_offer>s
    - Counter Price: %<next_counter>s
    - Patience: %<next_patience>s
    - Outcome: %<outcome>s
    - Last Exchange: %<last_exchange>s
    - Previous Turn: %<previous_turn>s

    You must respond with a JSON object with the following format:
    {
      "action": "sell" | "refuse" | "negotiate" | "talk",
      "message": string (the message to the player),
      "parameters": {
        "price": number (only if action is "sell" or "negotiate")
        "friendship_change": number (the change in friendship points based on the user's action, can be negative)
      }
    }
  PROMPT

  module_function

  # Returns true when the row is a bargaining turn.
  def bargaining?(row)
    !row['round'].to_s.strip.empty?
  end

  # Returns the extraction call and its reference reply.
  def extraction_conversation(row)
    [
      { 'role' => 'system', 'content' => format(EXTRACTION_PROMPT, item_name: row['item_name'],
                                                                   counter_price: row['counter_price'],
                                                                   last_exchange: last_exchange(row),
                                                                   previous_turn: previous_turn(row)) },
      { 'role' => 'user', 'content' => row['input'] },
      { 'role' => 'assistant', 'content' => JSON.generate(extraction_reply(row)) }
    ]
  end

  # Returns the response call, built from the state after the game step, and its reference reply.
  def response_conversation(row)
    [
      { 'role' => 'system', 'content' => response_prompt(row) },
      { 'role' => 'user', 'content' => row['input'] },
      { 'role' => 'assistant', 'content' => row['output'] }
    ]
  end

  # Returns the extraction labels of a row as the reply the extraction call should give.
  def extraction_reply(row)
    offer = row['player_offer'].to_s.strip
    { 'intent' => row['intent'], 'rude' => row['rude'], 'player_offer' => offer.empty? ? nil : offer.to_i }
  end

  # Returns the one-sentence summary of the negotiation before the turn.
  def last_exchange(row)
    last_offer = row['last_offer'].to_s.strip
    counter = row['counter_price'].to_i
    return "You quoted #{counter}." if last_offer.empty?
    return "Player last offered #{last_offer}. You countered at #{counter}." if last_offer.to_i < counter

    deal_price = Negotiation::FRIENDS.include?(row['relationship_status']) ? counter : last_offer.to_i
    "You agreed to sell at #{deal_price}; the player has not bought it yet."
  end

  # Returns the previous turn of the negotiation quoted for context, or none on the first turn.
  def previous_turn(row)
    said = row['previous_input'].to_s.strip
    return 'none' if said.empty?

    "Player said \"#{said}\" and you replied \"#{row['previous_reply'].to_s.strip}\"."
  end

  # Returns the game step's outcome with the price the reply must use, so the model need not compare numbers.
  def outcome(turn)
    case turn[:outcome]
    when :deal then "deal at #{turn[:price]}"
    when :counter then "counter at #{turn[:price]}"
    else turn[:outcome].to_s
    end
  end

  def response_prompt(row)
    turn = Negotiation.turn(row)
    offer = row['player_offer'].to_s.strip
    format(RESPONSE_PROMPT, item_name: row['item_name'], item_rarity: row['item_rarity'],
                            item_expected_price: row['item_expected_price'],
                            opening_price: Negotiation.prices(row)[:opening],
                            relationship_status: row['relationship_status'], round: row['round'],
                            player_offer: offer.empty? ? 'none' : offer, next_counter: turn[:counter],
                            next_patience: turn[:patience], outcome: outcome(turn), last_exchange: last_exchange(row),
                            previous_turn: previous_turn(row))
  end

  private_class_method :response_prompt, :outcome
end
