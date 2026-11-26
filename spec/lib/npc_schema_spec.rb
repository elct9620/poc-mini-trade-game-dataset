# frozen_string_literal: true

require 'spec_helper'
require 'csv'
require_relative '../../lib/npc_schema'
require_relative '../../lib/npc_prompt'

RSpec.describe NpcSchema do
  describe 'MESSAGE_PATTERN' do
    it { expect(NpcSchema::MESSAGE_PATTERN).to match('差太多了，{price}{currency}。') }
    it { expect(NpcSchema::MESSAGE_PATTERN).not_to match('差太多了，4606銀幣。') }
    it { expect(NpcSchema::MESSAGE_PATTERN).not_to match('這枚 embl850') }

    it 'is expected to accept every dataset message once its values are slots' do
      rows = %w[train.csv validation.csv test.csv].flat_map { |path| CSV.read(path, headers: true).map(&:to_h) }
      expect(rows.map { |row| NpcPrompt.slotted(row) }.reject { |message| NpcSchema::MESSAGE_PATTERN.match?(message) }).to be_empty
    end
  end

  describe 'EXTRACT' do
    it { expect(NpcSchema::EXTRACT['required']).to eq(%w[intent attitude offer]) }
  end

  describe 'RENDER' do
    it { expect(NpcSchema::RENDER['required']).to eq(%w[message]) }
  end
end
