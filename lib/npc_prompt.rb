# frozen_string_literal: true

require 'json'

##
# = NpcPrompt
# Builds the chat messages of the extract and render calls for a dataset row, in a given currency.
# The World and NPC sections come first and match in both calls, so the game reuses their KV cache.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
module NpcPrompt
  ROLE = 'merchant'
  EMOTION = { 'polite' => 'pleased', 'plain' => 'neutral', 'mild' => 'annoyed', 'severe' => 'angry' }.freeze

  module_function

  # Returns the extract call's messages, ending with the reply the model learns.
  def extract(row, currency)
    swap = swapper(row, currency)
    turn = ["item: #{row['item_name']}", "price: #{row['price']}", *previous(row, swap)]
    reply = { 'intent' => row['intent'], 'attitude' => row['attitude'], 'offer' => integer(row['offer']) }
    messages(system(currency, 'extract', turn), swap.call(row['input']), JSON.generate(reply))
  end

  # Returns the render call's messages, ending with the reply the model learns.
  def render(row, currency)
    swap = swapper(row, currency)
    turn = ["item: #{row['item_name']}", "relationship: #{row['relationship']}", "action: #{row['action']}",
            "price: #{integer(row['action_price']) || 'none'}", "player_offer: #{integer(row['offer']) || 'none'}",
            "emotion: #{emotion(row)}"]
    reply = { 'message' => swap.call(row['message']) }
    messages(system(currency, 'render', turn), swap.call(row['input']), JSON.generate(reply))
  end

  # Returns the emotion the game gives render: it follows the attitude, and a plain line that reaches a sale pleases.
  def emotion(row)
    return 'pleased' if row['action'] == 'sell' && row['attitude'] == 'plain'

    EMOTION.fetch(row['attitude'])
  end

  def system(currency, task, turn)
    ['# World', "currency: #{currency}", '# NPC', "role: #{ROLE}", '# Task', task, '# Turn', *turn].join("\n")
  end

  def previous(row, swap)
    return ['previous: none'] if row['previous_player'].to_s.empty?

    ["previous_player: #{swap.call(row['previous_player'])}", "previous_npc: #{swap.call(row['previous_npc'])}"]
  end

  def swapper(row, currency)
    ->(text) { text.to_s.gsub(row['currency'], currency) }
  end

  def integer(value)
    value.to_s.empty? ? nil : Integer(value)
  end

  def messages(system, user, assistant)
    [
      { 'role' => 'system', 'content' => system },
      { 'role' => 'user', 'content' => user },
      { 'role' => 'assistant', 'content' => assistant }
    ]
  end

  private_class_method :system, :previous, :swapper, :integer, :messages
end
