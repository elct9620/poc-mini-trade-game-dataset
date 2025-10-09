# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/validation'
require_relative '../../lib/dataset'
require_relative '../../lib/validator/json_syntax'
require_relative '../../lib/validator/schema_validator'
require 'tempfile'

RSpec.describe Validation do
  describe '#execute' do
    subject(:errors) { validation.execute }

    let(:validation) { described_class.new(dataset, validators) }
    let(:dataset) { Dataset.new(tempfile.path) }
    let(:validators) { [Validator::JsonSyntax.new, Validator::SchemaValidator.new] }
    let(:tempfile) { Tempfile.new(['test', '.csv']) }

    after do
      tempfile.close
      tempfile.unlink
    end

    context 'when all rows are valid' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":100}}"
          2,Shield,Rare,200,Hostile,Buy,"{""action"":""refuse"",""message"":""No""}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when row has invalid JSON' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{invalid json}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it 'is expected to include error with row number' do
        expect(errors.first).to match(/Row 2: Invalid JSON/)
      end
    end

    context 'when row has invalid action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Steal,"{""action"":""steal"",""message"":""Haha""}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Invalid action 'steal'") }
    end

    context 'when multiple rows have errors' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":100}}"
          2,Shield,Rare,200,Hostile,Steal,"{""action"":""steal"",""message"":""No""}"
          3,Potion,Common,50,Friendly,Buy,"{""action"":""sell"",""message"":""Here"",""parameters"":{""price"":0}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly(
        "Row 3: Invalid action 'steal'",
        "Row 4: Price must be greater than 0 for action 'sell'"
      ) }
    end

    context 'when output is missing' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly('Row 2: Missing output column') }
    end

    context 'when CSV is empty' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end
  end
end
