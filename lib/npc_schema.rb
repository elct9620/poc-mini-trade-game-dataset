# frozen_string_literal: true

##
# = NpcSchema
# JSON schemas of the extract and render replies. The game sends them as response_format,
# so decoding cannot leave the reply's shape, and evaluation sends the same ones.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
module NpcSchema
  # Slots the game fills in a render message; the model writes no number or currency word itself.
  SLOTS = %w[{price} {offer} {currency}].freeze

  # Characters a message may use besides slots: CJK ideographs and full-width punctuation. Digits are left out,
  # so a number can only come from a slot, and the foreign-script fragments a small model drifts into cannot appear.
  MESSAGE_CHARACTERS = "一-鿿，。、！？：；「」『』（）…—～"
  SLOT_ALTERNATION = SLOTS.map { |slot| Regexp.escape(slot) }.join('|')
  MESSAGE_PATTERN = /\A([#{MESSAGE_CHARACTERS}]|#{SLOT_ALTERNATION})+\z/

  EXTRACT = {
    'type' => 'object',
    'properties' => {
      'intent' => { 'type' => 'string', 'enum' => %w[offer haggle chat threat] },
      'attitude' => { 'type' => 'string', 'enum' => %w[polite plain mild severe] },
      'offer' => { 'anyOf' => [{ 'type' => 'integer', 'minimum' => 1 }, { 'type' => 'null' }] }
    },
    'required' => %w[intent attitude offer]
  }.freeze

  RENDER = {
    'type' => 'object',
    'properties' => {
      'message' => { 'type' => 'string', 'pattern' => "^([#{MESSAGE_CHARACTERS}]|#{SLOT_ALTERNATION})+$" }
    },
    'required' => %w[message]
  }.freeze
end
