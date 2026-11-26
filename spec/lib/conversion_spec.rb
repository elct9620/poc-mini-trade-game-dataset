# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'stringio'
require_relative '../support/rows'
require_relative '../../lib/conversion'
require_relative '../../lib/currency'

RSpec.describe Conversion do
  describe '#execute' do
    subject(:execute) { described_class.new(rows, io, split: split).execute }

    let(:io) { StringIO.new }
    let(:lines) { io.string.lines.map { |line| JSON.parse(line)['messages'] } }
    let(:currencies) { lines.map { |messages| messages[0]['content'][/currency: (\S+)/, 1] } }
    let(:rows) { [VALID_ROW, VALID_ROW.merge('id' => '2', 'item_name' => '舊電路板')] }

    context 'when the split is test' do
      let(:split) { 'test' }

      it { is_expected.to eq(4) }

      it 'is expected to write every extract sample, then every render sample' do
        execute
        expect(lines.map { |messages| messages[0]['content'][/# Task\n(\w+)/, 1] }).to eq(%w[extract extract render render])
      end

      it 'is expected to use only test currencies' do
        execute
        expect(currencies).to all(satisfy { |c| Currency::TEST.include?(c) })
      end
    end

    context 'when the split is train' do
      let(:split) { 'train' }

      it 'is expected to use only train currencies' do
        execute
        expect(currencies).to all(satisfy { |c| Currency::TRAIN.include?(c) })
      end

      it 'is expected to write no identical samples' do
        execute
        expect(lines.uniq.size).to eq(lines.size)
      end
    end

    context 'when the dataset is empty' do
      let(:rows) { [] }
      let(:split) { 'test' }

      it { is_expected.to eq(0) }
    end
  end
end
