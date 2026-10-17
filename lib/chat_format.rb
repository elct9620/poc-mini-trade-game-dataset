# frozen_string_literal: true

require 'json'

##
# = ChatFormat
# Builds chat messages from a dataset row using the game's system prompt.
# Training and evaluation share it so the model sees the same prompt the game sends.
#
# == Reference
# - {docs/features/conversion.md}[docs/features/conversion.md]
# - {docs/features/evaluation.md}[docs/features/evaluation.md]
##
module ChatFormat
  SYSTEM_PROMPT = <<~PROMPT.chomp
    You are trading with player in a trade game. Based on the context, you will decide what action to take. You can choose to sell or not sell to the player.

    Current Inventory:
    - Name: %<item_name>s
    - Rarity: %<item_rarity>s
    - Expected Price: %<item_expected_price>s
    - Asking Price: %<asking_price>s

    Relatioship: %<relationship_status>s

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

  # Asking price as a multiple of expected price, by rarity and relationship.
  # The game computes it so the model copies a number instead of multiplying.
  ASKING_RATIO = {
    'Common' => { 'Hostile' => 1.3, 'Neutral' => 1.0, 'Friendly' => 0.8, 'Allied' => 0.7 },
    'Rare' => { 'Hostile' => 1.5, 'Neutral' => 1.0, 'Friendly' => 1.0, 'Allied' => 0.85 },
    'Epic' => { 'Hostile' => 2.0, 'Neutral' => 1.2, 'Friendly' => 1.0, 'Allied' => 1.0 }
  }.freeze

  FRIENDSHIP_SCHEMA = { 'type' => 'integer', 'minimum' => -3, 'maximum' => 3 }.freeze

  # JSON schema of the NPC reply, for inference engines that support guided decoding.
  # Every field is required per action so a grammar cannot end the object before the price.
  RESPONSE_SCHEMA = {
    'anyOf' => [
      {
        'type' => 'object',
        'properties' => {
          'action' => { 'type' => 'string', 'enum' => %w[sell negotiate refuse] },
          'message' => { 'type' => 'string' },
          'parameters' => {
            'type' => 'object',
            'properties' => { 'price' => { 'type' => 'integer', 'minimum' => 0 }, 'friendship_change' => FRIENDSHIP_SCHEMA },
            'required' => %w[price friendship_change]
          }
        },
        'required' => %w[action message parameters]
      },
      {
        'type' => 'object',
        'properties' => {
          'action' => { 'const' => 'talk' },
          'message' => { 'type' => 'string' },
          'parameters' => {
            'type' => 'object',
            'properties' => { 'friendship_change' => FRIENDSHIP_SCHEMA },
            'required' => %w[friendship_change]
          }
        },
        'required' => %w[action message parameters]
      }
    ]
  }.freeze

  module_function

  # Returns the system and user messages for a row.
  def prompt(row)
    [
      { 'role' => 'system', 'content' => system_prompt(row) },
      { 'role' => 'user', 'content' => row['input'] }
    ]
  end

  # Returns the prompt followed by the expected assistant reply.
  def conversation(row)
    prompt(row) + [{ 'role' => 'assistant', 'content' => row['output'] }]
  end

  # Returns the expected price times the asking ratio, rounded up to a whole coin.
  def asking_price(row)
    ratio = ASKING_RATIO.dig(row['item_rarity'], row['relationship_status'])
    (row['item_expected_price'].to_r * Rational(ratio.to_s)).ceil
  end

  def system_prompt(row)
    format(
      SYSTEM_PROMPT,
      item_name: row['item_name'],
      item_rarity: row['item_rarity'],
      item_expected_price: row['item_expected_price'],
      asking_price: asking_price(row),
      relationship_status: row['relationship_status']
    )
  end
end
