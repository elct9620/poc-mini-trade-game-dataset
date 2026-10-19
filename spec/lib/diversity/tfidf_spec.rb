# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/diversity/tfidf'

RSpec.describe Diversity::Tfidf do
  let(:texts) { ['@能不能算便宜一點？', '能不能算便宜一點？', '這東西真不錯。', '行'] }
  let(:tfidf) { described_class.new(texts) }

  describe '#nearest' do
    subject(:neighbours) { tfidf.nearest([0, 2, 3], [0, 1, 2, 3]) }

    context 'when a text has a close rewording' do
      it { expect(neighbours[0][1]).to eq(1) }
      it { expect(neighbours[0][0]).to be > 0.8 }
    end

    context 'when a text shares no gram with the others' do
      it { expect(neighbours[1]).to eq([0.0, nil]) }
    end

    context 'when a text is too short to have a gram' do
      it { expect(neighbours[2]).to eq([0.0, nil]) }
    end
  end
end
