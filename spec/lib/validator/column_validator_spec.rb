# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/rows'
require_relative '../../../lib/validator/column_validator'

RSpec.describe Validator::ColumnValidator do
  describe '#validate' do
    subject(:validate) { described_class.new.validate(row) }

    context 'when every column is well formed' do
      let(:row) { VALID_ROW }

      it { is_expected.to be(true) }
    end

    context 'when a first turn leaves the previous turn and optional numbers empty' do
      let(:row) { VALID_ROW.merge('previous_player' => '', 'previous_npc' => '', 'offer' => '', 'action_price' => '') }

      it { is_expected.to be(true) }
    end

    context 'when a required column is empty' do
      let(:row) { VALID_ROW.merge('message' => ' ') }

      it { expect { validate }.to raise_error(ValidationError, "Missing 'message'") }
    end

    context 'when a number column is not a positive integer' do
      let(:row) { VALID_ROW.merge('offer' => '0') }

      it { expect { validate }.to raise_error(ValidationError, "'offer' must be a positive integer") }
    end

    context 'when only half of the previous turn is set' do
      let(:row) { VALID_ROW.merge('previous_npc' => '') }

      it { expect { validate }.to raise_error(ValidationError, "'previous_player' and 'previous_npc' must be set together") }
    end
  end
end
