# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/diversity/probe'

RSpec.describe Diversity::Probe do
  subject(:probe) { described_class.new(texts, labels) }

  # Twenty offer lines whose outcome alternates regardless of wording.
  let(:untied_texts) { %w[#金幣。 我出#金幣。 #金幣可以嗎？ #金幣賣不賣？ 最多#金幣。] * 4 }
  let(:untied_labels) { %w[sell negotiate] * 10 }

  describe '#measurable?' do
    context 'when there are enough rows and two labels' do
      let(:texts) { untied_texts }
      let(:labels) { untied_labels }

      it { is_expected.to be_measurable }
    end

    context 'when every row has the same label' do
      let(:texts) { untied_texts }
      let(:labels) { ['sell'] * 20 }

      it { is_expected.not_to be_measurable }
    end
  end

  describe '#accuracy' do
    subject { probe.accuracy }

    context 'when the wording gives the label away' do
      let(:texts) { (%w[行，就#金幣。 好，#金幣成交。] * 5) + (%w[#金幣可以嗎？ 最多#金幣吧？] * 5) }
      let(:labels) { (['sell'] * 10) + (['negotiate'] * 10) }

      it { is_expected.to eq(1.0) }
    end

    context 'when the wording does not decide the label' do
      let(:texts) { untied_texts }
      let(:labels) { untied_labels }

      it { is_expected.to be <= probe.majority }
    end
  end

  describe '#majority' do
    subject { probe.majority }

    let(:texts) { untied_texts }
    let(:labels) { (['sell'] * 15) + (['negotiate'] * 5) }

    it { is_expected.to eq(0.75) }
  end

  describe '#indicative' do
    subject { probe.indicative['sell'] }

    let(:texts) { (%w[行，就#金幣。 行，就#金幣吧。] * 5) + (%w[#金幣可以嗎？ 最多#金幣吧？] * 5) }
    let(:labels) { (['sell'] * 10) + (['negotiate'] * 10) }

    it { is_expected.to include('行，就') }
  end
end
