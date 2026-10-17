# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/chat_format'

RSpec.describe ChatFormat do
  let(:row) do
    {
      'item_name' => '生命藥水',
      'item_rarity' => 'Common',
      'item_expected_price' => '50',
      'relationship_status' => 'Neutral',
      'input' => '我想買這個生命藥水',
      'output' => '{"action":"sell"}'
    }
  end

  describe '.prompt' do
    subject(:messages) { described_class.prompt(row) }

    it { expect(messages.map { |message| message['role'] }).to eq(%w[system user]) }
    it { expect(messages[0]['content']).to include('- Name: 生命藥水') }
    it { expect(messages[0]['content']).to include('- Rarity: Common') }
    it { expect(messages[0]['content']).to include('- Expected Price: 50') }
    it { expect(messages[0]['content']).to include('Relatioship: Neutral') }
    it { expect(messages[1]['content']).to eq('我想買這個生命藥水') }
  end

  describe '.conversation' do
    subject(:messages) { described_class.conversation(row) }

    it { expect(messages.last).to eq({ 'role' => 'assistant', 'content' => '{"action":"sell"}' }) }
  end
end
