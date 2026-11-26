# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/rows'
require_relative '../../../lib/validator/label_validator'

RSpec.describe Validator::LabelValidator do
  describe '#validate' do
    subject(:validate) { described_class.new.validate(row) }

    context 'when labels take allowed values and agree' do
      let(:row) { VALID_ROW }

      it { is_expected.to be(true) }
    end

    context 'when a talk turn has no offer and no price' do
      let(:row) do
        VALID_ROW.merge('intent' => 'chat', 'offer' => '', 'action' => 'talk', 'action_price' => '', 'message' => '慢走。')
      end

      it { is_expected.to be(true) }
    end

    context 'when the message names a number that is neither the price nor the offer' do
      let(:row) { VALID_ROW.merge('message' => '上次5000金幣，這次4606金幣。') }

      it { expect { validate }.to raise_error(ValidationError, 'Message number 5000 is neither the price nor the offer') }
    end

    context 'when a label is outside its values' do
      let(:row) { VALID_ROW.merge('action' => 'negotiate') }

      it { expect { validate }.to raise_error(ValidationError, "Invalid action 'negotiate'") }
    end

    context 'when a haggle carries an offer' do
      let(:row) { VALID_ROW.merge('intent' => 'haggle') }

      it { expect { validate }.to raise_error(ValidationError, "'offer' must be set only for intent 'offer'") }
    end

    context 'when an offer has no offer value' do
      let(:row) { VALID_ROW.merge('offer' => '') }

      it { expect { validate }.to raise_error(ValidationError, "'offer' must be set only for intent 'offer'") }
    end

    context 'when a leave carries a price' do
      let(:row) { VALID_ROW.merge('action' => 'leave', 'message' => '不談了。') }

      it { expect { validate }.to raise_error(ValidationError, "'action_price' must be set only for sell or counter") }
    end

    context 'when a threat is not severe' do
      let(:row) do
        VALID_ROW.merge('intent' => 'threat', 'attitude' => 'mild', 'offer' => '', 'action' => 'leave', 'action_price' => '')
      end

      it { expect { validate }.to raise_error(ValidationError, "Threat must have attitude 'severe'") }
    end
  end
end
