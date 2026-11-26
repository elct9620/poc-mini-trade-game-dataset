# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../support/rows'
require_relative '../../lib/npc_prompt'

RSpec.describe NpcPrompt do
  let(:shared) { "# World\ncurrency: 銀幣\n# NPC\nrole: merchant\n" }

  describe '.extract' do
    subject(:messages) { described_class.extract(row, '銀幣') }

    let(:row) { VALID_ROW }

    it { expect(messages.map { |m| m['role'] }).to eq(%w[system user assistant]) }

    it 'is expected to put the task and turn after the shared sections' do
      expect(messages[0]['content']).to eq(
        "#{shared}# Task\nextract\n# Turn\nitem: 林語豎琴\nprice: 5170\n" \
        "previous_player: 想問問價錢。\nprevious_npc: 這把要5170銀幣。"
      )
    end

    it { expect(messages[1]['content']).to eq('我只有3619銀幣，你能不能算我？') }
    it { expect(JSON.parse(messages[2]['content'])).to eq('intent' => 'offer', 'attitude' => 'plain', 'offer' => 3619) }

    context 'when the turn is the first of a negotiation' do
      let(:row) { VALID_ROW.merge('previous_player' => '', 'previous_npc' => '') }

      it { expect(messages[0]['content']).to end_with("price: 5170\nprevious: none") }
    end

    context 'when the line names no price' do
      let(:row) { VALID_ROW.merge('intent' => 'chat', 'offer' => '') }

      it { expect(JSON.parse(messages[2]['content'])['offer']).to be_nil }
    end
  end

  describe '.render' do
    subject(:messages) { described_class.render(row, '銀幣') }

    let(:row) { VALID_ROW }

    it 'is expected to give the game decision as the turn' do
      expect(messages[0]['content']).to eq(
        "#{shared}# Task\nrender\n# Turn\nitem: 林語豎琴\nrelationship: allied\naction: counter\n" \
        "price: 4606\nplayer_offer: 3619\nemotion: neutral"
      )
    end

    it { expect(JSON.parse(messages[2]['content'])).to eq('message' => '差太多了啦，{price}{currency}，這已經很低了。') }

    context 'when the NPC leaves' do
      let(:row) { VALID_ROW.merge('intent' => 'chat', 'offer' => '', 'action' => 'leave', 'action_price' => '') }

      it { expect(messages[0]['content']).to include("action: leave\nprice: none\nplayer_offer: none") }
    end
  end

  describe '.slotted' do
    subject { described_class.slotted(row) }

    context 'when the message names the player offer and the counter' do
      let(:row) { VALID_ROW.merge('message' => '3619金幣太少了，4606金幣。') }

      it { is_expected.to eq('{offer}{currency}太少了，{price}{currency}。') }
    end

    context 'when the NPC sells at the player offer' do
      let(:row) { VALID_ROW.merge('action' => 'sell', 'action_price' => '3619', 'message' => '好，3619金幣成交。') }

      it { is_expected.to eq('好，{price}{currency}成交。') }
    end

    context 'when a number contains the price' do
      let(:row) { VALID_ROW.merge('action_price' => '46', 'offer' => '', 'message' => '4606金幣，不是46金幣。') }

      it { is_expected.to eq('4606{currency}，不是{price}{currency}。') }
    end
  end

  describe '.emotion' do
    subject { described_class.emotion(VALID_ROW.merge('attitude' => attitude, 'action' => action)) }

    let(:action) { 'counter' }

    context 'when the line is polite' do
      let(:attitude) { 'polite' }

      it { is_expected.to eq('pleased') }
    end

    context 'when a plain line gets a counter' do
      let(:attitude) { 'plain' }

      it { is_expected.to eq('neutral') }
    end

    context 'when a plain line reaches a sale' do
      let(:attitude) { 'plain' }
      let(:action) { 'sell' }

      it { is_expected.to eq('pleased') }
    end

    context 'when the NPC leaves a polite player' do
      let(:attitude) { 'polite' }
      let(:action) { 'leave' }

      it { is_expected.to eq('annoyed') }
    end

    context 'when the NPC leaves a plain player' do
      let(:attitude) { 'plain' }
      let(:action) { 'leave' }

      it { is_expected.to eq('annoyed') }
    end

    context 'when the NPC leaves a severely rude player' do
      let(:attitude) { 'severe' }
      let(:action) { 'leave' }

      it { is_expected.to eq('angry') }
    end

    context 'when the line is mildly rude' do
      let(:attitude) { 'mild' }

      it { is_expected.to eq('annoyed') }
    end

    context 'when the line is severely rude, even on a sale' do
      let(:attitude) { 'severe' }
      let(:action) { 'sell' }

      it { is_expected.to eq('angry') }
    end
  end
end
