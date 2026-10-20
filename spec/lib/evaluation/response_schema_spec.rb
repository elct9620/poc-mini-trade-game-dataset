# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/evaluation/response_schema'

RSpec.describe Evaluation do
  describe 'RESPONSE_SCHEMA' do
    subject(:branches) { Evaluation::RESPONSE_SCHEMA['anyOf'] }

    let(:trade) { branches.find { |branch| branch.dig('properties', 'action', 'enum') } }
    let(:talk) { branches.find { |branch| branch.dig('properties', 'action', 'const') == 'talk' } }

    it { expect(trade.dig('properties', 'action', 'enum')).to contain_exactly('sell', 'negotiate', 'refuse') }
    it { expect(trade.dig('properties', 'parameters', 'required')).to include('price') }
    it { expect(talk.dig('properties', 'parameters', 'properties')).not_to have_key('price') }
    it { expect(branches.map { |branch| branch.dig('properties', 'message') }).to all(eq(Evaluation::MESSAGE_SCHEMA)) }
  end

  describe 'MESSAGE_SCHEMA' do
    subject(:pattern) { Regexp.new(Evaluation::MESSAGE_SCHEMA['pattern']) }

    it { is_expected.to match('有啊，850金幣就讓給你。') }
    it { is_expected.not_to match('這枚 embl850戴上去') }
    it { is_expected.not_to match('說 خير خير，可是誰知道。') }
    it { is_expected.not_to match('') }
  end
end
