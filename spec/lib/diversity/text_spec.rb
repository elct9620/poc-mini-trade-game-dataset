# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/diversity/text'

RSpec.describe Diversity::Text do
  describe '.normalize' do
    subject { described_class.normalize(text, '鐵劍') }

    context 'when the line names the item and an amount in digits' do
      let(:text) { '鐵劍1,200金幣賣不賣？' }

      it { is_expected.to eq('@#金幣賣不賣？') }
    end

    context 'when the amount is written in Chinese numerals' do
      let(:text) { '鐵劍一千二百金幣賣不賣？' }

      it { is_expected.to eq('@#金幣賣不賣？') }
    end

    context 'when a Chinese numeral is not an amount' do
      let(:text) { '再便宜一點嘛。' }

      it { is_expected.to eq('再便宜一點嘛。') }
    end
  end

  describe '.ngrams' do
    subject { described_class.ngrams('不夠', 1..2) }

    it { is_expected.to eq(%w[不 夠 不夠]) }
  end
end
