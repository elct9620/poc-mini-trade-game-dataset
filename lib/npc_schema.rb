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
  # Characters a message may use: CJK ideographs, digits, and full-width punctuation.
  # Decoding then cannot emit the foreign-script or Latin fragments a small model drifts into.
  MESSAGE_CHARACTERS = "一-鿿0-9，。、！？：；「」『』（）…—～"
  MESSAGE_PATTERN = /\A[#{MESSAGE_CHARACTERS}]+\z/

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
    'properties' => { 'message' => { 'type' => 'string', 'pattern' => "^[#{MESSAGE_CHARACTERS}]+$" } },
    'required' => %w[message]
  }.freeze
end
