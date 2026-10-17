# frozen_string_literal: true

##
# = Evaluation::RESPONSE_SCHEMA
# JSON schema of the NPC reply, sent as the guided decoding contract when evaluating a served model.
#
# == Reference
# - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
##
class Evaluation
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
end
