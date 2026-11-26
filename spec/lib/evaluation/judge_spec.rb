# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../../support/rows'
require_relative '../../../lib/evaluation/judge'

RSpec.describe Evaluation::Judge do
  describe '.extract' do
    subject(:checks) { described_class.extract(row, reply) }

    let(:row) { VALID_ROW }

    context 'when every field matches' do
      let(:reply) { '{"intent":"offer","attitude":"plain","offer":3619}' }

      it { is_expected.to eq('json_valid' => true, 'intent_match' => true, 'attitude_match' => true, 'offer_match' => true, 'extract_match' => true) }
    end

    context 'when the attitude differs' do
      let(:reply) { '{"intent":"offer","attitude":"polite","offer":3619}' }

      it { is_expected.to include('attitude_match' => false, 'extract_match' => false) }
    end

    context 'when a line without a price gets a null offer' do
      let(:row) { VALID_ROW.merge('intent' => 'chat', 'offer' => '') }
      let(:reply) { '{"intent":"chat","attitude":"plain","offer":null}' }

      it { is_expected.to include('offer_match' => true) }
    end

    context 'when the reply leaves out the offer' do
      let(:row) { VALID_ROW.merge('intent' => 'chat', 'offer' => '') }
      let(:reply) { '{"intent":"chat","attitude":"plain"}' }

      it { is_expected.to include('offer_match' => false) }
    end

    context 'when the reply is not a JSON object' do
      let(:reply) { 'offer' }

      it { expect(checks.values).to all(be(false)) }
    end
  end

  describe '.render' do
    subject(:checks) { described_class.render(row, JSON.generate('message' => message), '星幣') }

    let(:row) { VALID_ROW }

    context 'when the message writes the price and currency as slots' do
      let(:message) { '差太多了，{price}{currency}，這已經很低了。' }

      it 'is expected to pass every check and name no currency itself' do
        expect(checks).to eq('json_valid' => true, 'message_clean' => true, 'message_traditional' => true,
                             'currency_foreign' => false, 'price_said' => true, 'currency_own' => true)
      end
    end

    context 'when the message writes the currency word itself' do
      let(:message) { '差太多了，{price}星幣。' }

      it { is_expected.to include('currency_foreign' => true, 'currency_own' => false) }
    end

    context 'when a currency word is an ordinary noun in the message' do
      let(:message) { '靠裡面的紅寶石軸承，{price}{currency}。' }

      it { is_expected.to include('currency_foreign' => false) }
    end

    context 'when the message writes the price in digits' do
      let(:message) { '差太多了，4606{currency}。' }

      it { is_expected.to include('message_clean' => false, 'price_said' => false) }
    end

    context 'when the message drifts into Latin or simplified characters' do
      let(:message) { '这个 ok，{price}{currency}。' }

      it { is_expected.to include('message_clean' => false, 'message_traditional' => false) }
    end

    context 'when the message leaves out the price' do
      let(:message) { '差太多了，再加一點吧。' }

      it { is_expected.to include('price_said' => false) }
    end

    context 'when the action has no price and the reference names no currency' do
      let(:row) { VALID_ROW.merge('action' => 'talk', 'action_price' => '', 'message' => '慢走。') }
      let(:message) { '慢走。' }

      it { is_expected.to include('price_said' => nil, 'currency_own' => nil) }
    end

    context 'when the reply is not a JSON object' do
      subject(:checks) { described_class.render(row, 'message', '星幣') }

      it { is_expected.to include('json_valid' => false, 'message_clean' => false, 'currency_foreign' => true) }
    end
  end
end
