# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/evaluation'
require_relative '../../lib/validator'

RSpec.describe Evaluation do
  let(:row) do
    { 'id' => '1', 'item_name' => '鐵劍', 'item_rarity' => 'Rare', 'item_expected_price' => '100',
      'relationship_status' => 'Neutral', 'input' => '我要買劍',
      'output' => '{"action":"sell","message":"好","parameters":{"price":100,"friendship_change":1}}' }
  end

  # Replies with a fixed text, standing in for a served model.
  let(:client_class) do
    Struct.new(:reply) do
      def complete(_messages) = reply
    end
  end

  describe '#execute' do
    subject(:result) { described_class.new([row], client_class.new(reply), Validator.all).execute.first }

    context 'when the reply follows the rules' do
      let(:reply) { '{"action":"sell","message":"成交","parameters":{"price":120,"friendship_change":1}}' }

      it { expect(result['rule_pass']).to be(true) }
      it { expect(result['action_match']).to be(true) }
    end

    context 'when the reply sells below the minimum price' do
      let(:reply) { '{"action":"sell","message":"便宜賣","parameters":{"price":50,"friendship_change":1}}' }

      it { expect(result['json_valid']).to be(true) }
      it { expect(result['rule_pass']).to be(false) }
    end

    context 'when the reply is not JSON' do
      let(:reply) { '好的，成交' }

      it { expect(result['json_valid']).to be(false) }
      it { expect(result['rule_pass']).to be(false) }
    end

    context 'when the reply is JSON but not an object' do
      let(:reply) { '"sell"' }

      it { expect(result['errors']).to eq(['Output is not a JSON object']) }
    end

    context 'when the reply chooses a different action' do
      let(:reply) { '{"action":"refuse","message":"不賣","parameters":{"friendship_change":0}}' }

      it { expect(result['action_match']).to be(false) }
    end
  end

  describe '.summary' do
    subject(:summary) { described_class.summary(results) }

    context 'when results are mixed' do
      let(:results) do
        [
          { 'json_valid' => true, 'rule_pass' => true, 'action_match' => true },
          { 'json_valid' => true, 'rule_pass' => false, 'action_match' => false }
        ]
      end

      it { is_expected.to eq({ 'total' => 2, 'json_valid' => 1.0, 'rule_pass' => 0.5, 'action_match' => 0.5 }) }
    end

    context 'when results are empty' do
      let(:results) { [] }

      it { is_expected.to eq({ 'total' => 0, 'json_valid' => 0.0, 'rule_pass' => 0.0, 'action_match' => 0.0 }) }
    end
  end
end
