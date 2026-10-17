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
  end
end
