# frozen_string_literal: true

# A valid dataset row: a counter to an offer on a later turn. Specs override columns with merge.
VALID_ROW = {
  'id' => '1', 'item_name' => '林語豎琴', 'relationship' => 'allied', 'currency' => '金幣', 'price' => '5170',
  'previous_player' => '想問問價錢。', 'previous_npc' => '這把要5170金幣。',
  'input' => '我只有3619金幣，你能不能算我？', 'intent' => 'offer', 'attitude' => 'plain', 'offer' => '3619',
  'action' => 'counter', 'action_price' => '4606', 'message' => '差太多了啦，4606金幣，這已經很低了。'
}.freeze
