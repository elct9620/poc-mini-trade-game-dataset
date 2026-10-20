# frozen_string_literal: true

##
# = Evaluation::RESPONSE_SCHEMA
# JSON schemas of the NPC reply and the bargaining extraction reply, sent as guided decoding contracts
# when evaluating a served model.
#
# == Reference
# - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
##
class Evaluation
  FRIENDSHIP_SCHEMA = { 'type' => 'integer', 'minimum' => -3, 'maximum' => 3 }.freeze

  # Characters a message may use: CJK ideographs, digits, and full-width punctuation, the set the dataset writes.
  # Guided decoding then cannot emit the foreign-script or Latin fragments a small model drifts into.
  MESSAGE_CHARACTERS = "\u4E00-\u9FFF0-9，。、！？：；「」『』（）…—～"
  MESSAGE_SCHEMA = { 'type' => 'string', 'pattern' => "^[#{MESSAGE_CHARACTERS}]+$" }.freeze

  # JSON schema of the NPC reply, for inference engines that support guided decoding.
  # Every field is required per action so a grammar cannot end the object before the price.
  RESPONSE_SCHEMA = {
    'anyOf' => [
      {
        'type' => 'object',
        'properties' => {
          'action' => { 'type' => 'string', 'enum' => %w[sell negotiate refuse] },
          'message' => MESSAGE_SCHEMA,
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
          'message' => MESSAGE_SCHEMA,
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

  # JSON schema of the bargaining extraction reply; an offer is a positive integer or null.
  EXTRACTION_SCHEMA = {
    'type' => 'object',
    'properties' => {
      'intent' => { 'type' => 'string', 'enum' => %w[offer haggle chat threat] },
      'rude' => { 'type' => 'string', 'enum' => %w[none mild severe] },
      'player_offer' => { 'anyOf' => [{ 'type' => 'integer', 'minimum' => 1 }, { 'type' => 'null' }] }
    },
    'required' => %w[intent rude player_offer]
  }.freeze
end
