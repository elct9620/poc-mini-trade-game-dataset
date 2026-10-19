# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/evaluation/evaluation'
require_relative '../../../lib/validator'

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
      it { expect(result['friendship_match']).to be(true) }
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

    context 'when the reply is measured' do
      let(:reply) { '{"action":"talk","message":"你好","parameters":{"friendship_change":0}}' }

      it { expect(result['latency']).to be >= 0 }
    end

    context 'when the reply changes friendship differently' do
      let(:reply) { '{"action":"sell","message":"成交","parameters":{"price":120,"friendship_change":-1}}' }

      it { expect(result['friendship_match']).to be(false) }
    end

    context 'when the reply chooses a different action' do
      let(:reply) { '{"action":"refuse","message":"不賣","parameters":{"friendship_change":0}}' }

      it { expect(result['action_match']).to be(false) }
    end
  end

  describe '#execute with a bargaining row' do
    subject(:result) do
      described_class.new([bargaining_row], client_class.new(reply), Validator.all,
                          extraction_client: client_class.new(extraction)).execute.first
    end

    # An Epic sword with a Neutral merchant: floor 48, opening 60; an offer of 62 meets the counter and sells at the offer.
    let(:bargaining_row) do
      { 'id' => '9', 'item_name' => '長劍', 'item_rarity' => 'Epic', 'item_expected_price' => '40',
        'relationship_status' => 'Neutral', 'input' => '62金幣，我買了。',
        'output' => '{"action":"sell","message":"成交","parameters":{"price":62,"friendship_change":1}}',
        'round' => '2', 'patience' => '3', 'counter_price' => '60', 'best_offer' => '50', 'last_offer' => '50',
        'intent' => 'offer', 'rude' => 'none', 'player_offer' => '62' }
    end
    let(:extraction) { '{"intent":"offer","rude":"none","player_offer":62}' }
    let(:reply) { '{"action":"sell","message":"好，62金幣","parameters":{"price":62,"friendship_change":1}}' }

    context 'when both calls follow the reference' do
      it { expect(result.values_at('intent_match', 'rude_match', 'offer_match')).to eq([true, true, true]) }
      it { expect(result['deal_match']).to be(true) }
      it { expect(result['rule_pass']).to be(true) }
    end

    context 'when the extraction reply is not a JSON object' do
      let(:extraction) { 'offer 62' }

      it { expect(result.values_at('intent_match', 'rude_match', 'offer_match')).to eq([false, false, false]) }
    end

    context 'when the extraction misreads the offer' do
      let(:extraction) { '{"intent":"offer","rude":"none","player_offer":60}' }

      it { expect(result['offer_match']).to be(false) }
    end

    context 'when the reply sells at another price' do
      let(:reply) { '{"action":"sell","message":"好，60金幣","parameters":{"price":60,"friendship_change":1}}' }

      it { expect(result['deal_match']).to be(false) }
    end

    context 'when the reply counters instead of selling' do
      let(:reply) { '{"action":"negotiate","message":"再加一點","parameters":{"price":60,"friendship_change":1}}' }

      it { expect(result['rule_pass']).to be(false) }
    end
  end

  describe '.summary' do
    subject(:summary) { described_class.summary(results) }

    let(:single_result) do
      { 'bargaining' => false, 'json_valid' => true, 'rule_pass' => true, 'action_match' => true,
        'friendship_match' => true, 'latency' => 0.2 }
    end
    let(:bargaining_result) do
      { 'bargaining' => true, 'json_valid' => true, 'rule_pass' => false, 'action_match' => false,
        'friendship_match' => true, 'intent_match' => true, 'rude_match' => true, 'offer_match' => false,
        'deal' => true, 'deal_match' => false, 'latency' => 0.6 }
    end

    context 'when results mix single-turn and bargaining rows' do
      let(:results) { [single_result, bargaining_result] }

      it do
        is_expected.to include('total' => 2, 'json_valid' => 1.0, 'rule_pass' => 0.5, 'action_match' => 0.5,
                               'friendship_match' => 1.0, 'latency_mean' => 0.4, 'latency_p95' => 0.6)
      end

      it { is_expected.to include('intent_match' => 1.0, 'rude_match' => 1.0, 'offer_match' => 0.0, 'deal_match' => 0.0) }
      it { expect(summary['single']).to include('total' => 1, 'action_match' => 1.0) }
      it { expect(summary['bargaining']).to include('total' => 1, 'action_match' => 0.0) }
    end

    context 'when a bargaining row should not sell' do
      let(:results) { [bargaining_result.merge('deal' => false), bargaining_result.merge('deal_match' => true)] }

      it { expect(summary['deal_match']).to eq(1.0) }
    end

    context 'when results are empty' do
      let(:results) { [] }

      it do
        is_expected.to include('total' => 0, 'json_valid' => 0.0, 'action_match' => 0.0, 'deal_match' => 0.0,
                               'latency_mean' => 0.0, 'latency_p95' => 0.0)
      end
    end
  end
end
