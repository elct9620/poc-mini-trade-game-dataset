# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/dataset'
require 'tempfile'

RSpec.describe Dataset do
  describe '#each' do
    subject(:dataset) { described_class.new(tempfile.path) }

    let(:tempfile) { Tempfile.new(['test', '.csv']) }

    after do
      tempfile.close
      tempfile.unlink
    end

    context 'when CSV has multiple rows' do
      before do
        csv_content = <<~CSV
          id,item_name,relationship,input
          1,Sword,allied,Buy
          2,Shield,hostile,Buy
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it 'is expected to iterate through all rows' do
        rows = []
        dataset.each { |row| rows << row }
        expect(rows.size).to eq(2)
      end

      it 'is expected to provide CSV::Row objects' do
        dataset.each do |row|
          expect(row).to be_a(CSV::Row)
        end
      end

      it 'is expected to have access to columns by name' do
        dataset.each do |row|
          expect(row['item_name']).not_to be_nil
        end
      end
    end

    context 'when CSV is empty' do
      before do
        csv_content = <<~CSV
          id,item_name,relationship,input
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it 'is expected to not iterate' do
        rows = []
        dataset.each { |row| rows << row }
        expect(rows).to be_empty
      end
    end
  end
end
