# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../../../lib/validator/bargaining_validator'

RSpec.describe Validator::BargainingValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    # A Neutral merchant selling a Common item at expected price 10: floor 10, opening 13.
    let(:columns) do
      {
        'item_rarity' => 'Common', 'item_expected_price' => '10', 'relationship_status' => 'Neutral',
        'round' => '2', 'patience' => '3', 'counter_price' => '13', 'best_offer' => '8', 'last_offer' => '8',
        'intent' => 'offer', 'rude' => 'none', 'player_offer' => '9',
        'output' => reply('negotiate', 12)
      }
    end
    let(:row) { CSV::Row.new(columns.keys, columns.values) }

    def reply(action, price = nil, friendship = 0)
      parameters = { 'friendship_change' => friendship }
      parameters['price'] = price if price
      JSON.generate('action' => action, 'message' => '好吧', 'parameters' => parameters)
    end

    def with(changes)
      CSV::Row.new(columns.merge(changes).keys, columns.merge(changes).values)
    end

    context 'when the row is single-turn' do
      let(:row) do
        CSV::Row.new(%w[item_rarity item_expected_price relationship_status output],
                     ['Common', '10', 'Neutral', reply('sell', 10)])
      end

      it { is_expected.to be true }
    end

    context 'when the row has bargaining columns left empty' do
      let(:row) { with('round' => '', 'patience' => '', 'counter_price' => '', 'intent' => '', 'rude' => '') }

      it { is_expected.to be true }
    end

    context 'when the reply matches the turn outcome' do
      it { is_expected.to be true }
    end

    context 'when the relationship is unknown' do
      let(:row) { with('relationship_status' => 'Enemy') }

      it { is_expected.to be true }
    end

    context 'when a required column is empty' do
      let(:row) { with('patience' => '') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Bargaining row is missing 'patience'")
      end
    end

    context 'when the intent is unknown' do
      let(:row) { with('intent' => 'beg') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Invalid intent 'beg'")
      end
    end

    context 'when a number column is malformed' do
      let(:row) { with('counter_price' => '12.5') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "'counter_price' must be a positive integer")
      end
    end

    context 'when rude is malformed' do
      let(:row) { with('rude' => 'yes') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "'rude' must be none, mild, or severe")
      end
    end

    context 'when an offer turn has no player offer' do
      let(:row) { with('player_offer' => '') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "'player_offer' must be set only for intent 'offer'")
      end
    end

    context 'when only the previous player line is filled' do
      let(:row) { with('previous_input' => '50金幣', 'previous_reply' => '') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "'previous_input' and 'previous_reply' must be set together")
      end
    end

    context 'when a chat turn has a player offer' do
      let(:row) { with('intent' => 'chat', 'output' => reply('talk')) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "'player_offer' must be set only for intent 'offer'")
      end
    end

    context 'when patience exceeds the relationship limit' do
      let(:row) { with('patience' => '4') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Patience 4 is outside 1 to 3')
      end
    end

    context 'when the counter is below the floor' do
      let(:row) { with('counter_price' => '9') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Counter price 9 is outside floor 10 to opening 13')
      end
    end

    context 'when the counter conceded before any offer' do
      let(:row) { with('round' => '1', 'counter_price' => '12', 'best_offer' => '', 'last_offer' => '') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Counter price must be the opening 13 before any offer')
      end
    end

    context 'when the last offer exceeds the best offer' do
      let(:row) { with('best_offer' => '8', 'last_offer' => '9') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Offers must have best offer 8 at least last offer 9')
      end
    end

    context 'when only the last offer is set' do
      let(:row) { with('counter_price' => '13', 'best_offer' => '', 'last_offer' => '8') }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Offers must have best offer none at least last offer 8')
      end
    end

    context 'when the reply sells instead of countering' do
      let(:row) { with('output' => reply('sell', 9)) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Expected negotiate at 12 from the negotiation state, got sell at 9')
      end
    end

    context 'when the reply counters at the wrong price' do
      let(:row) { with('output' => reply('negotiate', 13)) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Expected negotiate at 12 from the negotiation state, got negotiate at 13')
      end
    end

    context 'when a rude turn reaches a Neutral merchant' do
      let(:row) { with('rude' => 'severe', 'output' => reply('refuse', nil, -1)) }

      it { is_expected.to be true }
    end

    context 'when a threat keeps friendship' do
      let(:row) { with('intent' => 'threat', 'player_offer' => '', 'output' => reply('refuse', nil, -1)) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Threat must change friendship by -3')
      end
    end

    context 'when a threat is refused at -3' do
      let(:row) { with('intent' => 'threat', 'player_offer' => '', 'output' => reply('refuse', nil, -3)) }

      it { is_expected.to be true }
    end

    context 'when the output is not valid JSON' do
      let(:row) { with('output' => '{invalid') }

      it { is_expected.to be true }
    end
  end
end
