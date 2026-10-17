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

  # JSON schema of the NPC reply, for inference engines that support guided decoding.
  RESPONSE_SCHEMA = {
    'type' => 'object',
    'properties' => {
      'action' => { 'type' => 'string', 'enum' => %w[sell refuse negotiate talk] },
      'message' => { 'type' => 'string' },
      'parameters' => {
        'type' => 'object',
        'properties' => {
          'price' => { 'type' => 'number' },
          'friendship_change' => { 'type' => 'integer', 'minimum' => -3, 'maximum' => 3 }
        },
        'required' => ['friendship_change']
      }
    },
    'required' => %w[action message parameters]
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

  def system_prompt(row)
    format(
      SYSTEM_PROMPT,
      item_name: row['item_name'],
      item_rarity: row['item_rarity'],
      item_expected_price: row['item_expected_price'],
      relationship_status: row['relationship_status']
    )
  end
end
