# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/csv_validator'
require 'tempfile'

RSpec.describe CsvValidator do
  describe '.validate' do
    subject(:validation_errors) { described_class.validate(tempfile.path) }

    let(:tempfile) { Tempfile.new(['test', '.csv']) }

    after do
      tempfile.close
      tempfile.unlink
    end

    context 'when CSV has valid sell action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,I want to buy,"{""action"":""sell"",""message"":""Here you go"",""parameters"":{""price"":100,""friendship_change"":1}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when CSV has valid refuse action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Hostile,I want to buy,"{""action"":""refuse"",""message"":""No deal"",""parameters"":{""friendship_change"":-1}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when CSV has valid negotiate action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,How about 80?,"{""action"":""negotiate"",""message"":""Make it 90"",""parameters"":{""price"":90,""friendship_change"":0}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when CSV has valid talk action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Friendly,Hello,"{""action"":""talk"",""message"":""Nice to see you"",""parameters"":{""friendship_change"":1}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when parameters is missing' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{""action"":""talk"",""message"":""Hello""}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when friendship_change is missing' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy it,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":100}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when friendship change is negative' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Hostile,Gimme,"{""action"":""refuse"",""message"":""Get lost"",""parameters"":{""friendship_change"":-5}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when friendship change is at minimum boundary' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Hostile,Insult,"{""action"":""refuse"",""message"":""Never come back"",""parameters"":{""friendship_change"":-10}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when friendship change is at maximum boundary' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Allied,Thank you,"{""action"":""sell"",""message"":""Anytime friend"",""parameters"":{""price"":50,""friendship_change"":10}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when output is nil' do
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

    context 'when output is empty string' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,""
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly('Row 2: Missing output column') }
    end

    context 'when JSON is malformed' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{not valid json}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it 'is expected to include invalid JSON error' do
        expect(validation_errors.first).to match(/Row 2: Invalid JSON/)
      end
    end

    context 'when JSON is incomplete' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{""action"":""sell"""
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it 'is expected to include invalid JSON error' do
        expect(validation_errors.first).to match(/Row 2: Invalid JSON/)
      end
    end

    context 'when action is unknown' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{""action"":""steal"",""message"":""Haha""}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Invalid action 'steal'") }
    end

    context 'when action is nil' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Hello,"{""message"":""Hello""}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Invalid action ''") }
    end

    context 'when price is missing for sell action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Price must be greater than 0 for action 'sell'") }
    end

    context 'when price is zero for sell action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":0}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Price must be greater than 0 for action 'sell'") }
    end

    context 'when price is negative for sell action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":-10}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Price must be greater than 0 for action 'sell'") }
    end

    context 'when price is missing for negotiate action' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Negotiate,"{""action"":""negotiate"",""message"":""Let's talk"",""parameters"":{}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly("Row 2: Price must be greater than 0 for action 'negotiate'") }
    end

    context 'when refuse action has no price' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Hostile,Buy,"{""action"":""refuse"",""message"":""No"",""parameters"":{}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when talk action has no price' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Friendly,Hello,"{""action"":""talk"",""message"":""Hi"",""parameters"":{}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end

    context 'when friendship is below minimum' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Hostile,Insult,"{""action"":""refuse"",""message"":""No"",""parameters"":{""friendship_change"":-11}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly('Row 2: Friendship value must be between -10 and 10') }
    end

    context 'when friendship is above maximum' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Allied,Gift,"{""action"":""sell"",""message"":""Thanks"",""parameters"":{""price"":50,""friendship_change"":11}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly('Row 2: Friendship value must be between -10 and 10') }
    end

    context 'when multiple rows have errors' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":100}}"
          2,Shield,Rare,200,Hostile,Steal,"{""action"":""steal"",""message"":""No""}"
          3,Potion,Common,50,Friendly,Buy,"{""action"":""sell"",""message"":""Here"",""parameters"":{""price"":0}}"
          4,Armor,Epic,500,Allied,Thanks,"{""action"":""talk"",""message"":""Welcome"",""parameters"":{""friendship_change"":15}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to contain_exactly(
        "Row 3: Invalid action 'steal'",
        "Row 4: Price must be greater than 0 for action 'sell'",
        'Row 5: Friendship value must be between -10 and 10'
      ) }
    end

    context 'when multiple rows are all valid' do
      before do
        csv_content = <<~CSV
          id,item_name,item_rarity,item_expected_price,relationship_status,input,output
          1,Sword,Common,100,Neutral,Buy,"{""action"":""sell"",""message"":""Sold"",""parameters"":{""price"":100,""friendship_change"":1}}"
          2,Shield,Rare,200,Hostile,Buy,"{""action"":""refuse"",""message"":""No"",""parameters"":{""friendship_change"":-1}}"
          3,Potion,Common,50,Friendly,Buy,"{""action"":""sell"",""message"":""Here"",""parameters"":{""price"":40,""friendship_change"":1}}"
        CSV
        tempfile.write(csv_content)
        tempfile.rewind
      end

      it { is_expected.to be_empty }
    end
  end

  describe '.validate_row' do
    subject(:validation_result) { described_class.validate_row(row, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when output is missing' do
      let(:row) { CSV::Row.new(['output'], [nil]) }

      it 'is expected to add error to errors array' do
        validation_result
        expect(errors).to contain_exactly('Row 5: Missing output column')
      end
    end

    context 'when output is present' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Hello"}']) }

      it 'is expected to parse and validate JSON' do
        validation_result
        expect(errors).to be_empty
      end
    end
  end

  describe '.validate_json' do
    subject(:validation_result) { described_class.validate_json(output, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when JSON is valid with sell action' do
      let(:output) { '{"action":"sell","message":"Hello","parameters":{"price":100}}' }

      it 'is expected to validate without errors' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when JSON is invalid' do
      let(:output) { '{invalid json}' }

      it 'is expected to add JSON parse error' do
        validation_result
        expect(errors.first).to match(/Row 5: Invalid JSON/)
      end
    end
  end

  describe '.validate_action' do
    subject(:validation_result) { described_class.validate_action(action, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when action is sell' do
      let(:action) { 'sell' }

      it 'is expected to accept action' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is refuse' do
      let(:action) { 'refuse' }

      it 'is expected to accept action' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is negotiate' do
      let(:action) { 'negotiate' }

      it 'is expected to accept action' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is talk' do
      let(:action) { 'talk' }

      it 'is expected to accept action' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is invalid' do
      let(:action) { 'steal' }

      it 'is expected to add error' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Invalid action 'steal'")
      end
    end

    context 'when action is nil' do
      let(:action) { nil }

      it 'is expected to add error' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Invalid action ''")
      end
    end
  end

  describe '.validate_parameters' do
    subject(:validation_result) { described_class.validate_parameters(data, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when action is sell with valid price' do
      let(:data) { { 'action' => 'sell', 'parameters' => { 'price' => 100 } } }

      it 'is expected to validate without errors' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is talk with valid friendship' do
      let(:data) { { 'action' => 'talk', 'parameters' => { 'friendship_change' => 5 } } }

      it 'is expected to validate without errors' do
        validation_result
        expect(errors).to be_empty
      end
    end
  end

  describe '.validate_price' do
    subject(:validation_result) { described_class.validate_price(action, price, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when action is sell with valid price' do
      let(:action) { 'sell' }
      let(:price) { 100 }

      it 'is expected to accept price' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is sell with zero price' do
      let(:action) { 'sell' }
      let(:price) { 0 }

      it 'is expected to reject price' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Price must be greater than 0 for action 'sell'")
      end
    end

    context 'when action is sell with negative price' do
      let(:action) { 'sell' }
      let(:price) { -10 }

      it 'is expected to reject price' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Price must be greater than 0 for action 'sell'")
      end
    end

    context 'when action is sell with missing price' do
      let(:action) { 'sell' }
      let(:price) { nil }

      it 'is expected to reject missing price' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Price must be greater than 0 for action 'sell'")
      end
    end

    context 'when action is negotiate with valid price' do
      let(:action) { 'negotiate' }
      let(:price) { 100 }

      it 'is expected to accept price' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is negotiate with missing price' do
      let(:action) { 'negotiate' }
      let(:price) { nil }

      it 'is expected to reject missing price' do
        validation_result
        expect(errors).to contain_exactly("Row 5: Price must be greater than 0 for action 'negotiate'")
      end
    end

    context 'when action is refuse with no price' do
      let(:action) { 'refuse' }
      let(:price) { nil }

      it 'is expected to not validate price' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when action is talk with no price' do
      let(:action) { 'talk' }
      let(:price) { nil }

      it 'is expected to not validate price' do
        validation_result
        expect(errors).to be_empty
      end
    end
  end

  describe '.validate_friendship' do
    subject(:validation_result) { described_class.validate_friendship(friendship, line_number, errors) }

    let(:errors) { [] }
    let(:line_number) { 5 }

    context 'when friendship is at minimum boundary' do
      let(:friendship) { -10 }

      it 'is expected to accept value' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when friendship is at maximum boundary' do
      let(:friendship) { 10 }

      it 'is expected to accept value' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when friendship is zero' do
      let(:friendship) { 0 }

      it 'is expected to accept value' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when friendship is positive' do
      let(:friendship) { 5 }

      it 'is expected to accept value' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when friendship is negative' do
      let(:friendship) { -5 }

      it 'is expected to accept value' do
        validation_result
        expect(errors).to be_empty
      end
    end

    context 'when friendship is below minimum' do
      let(:friendship) { -11 }

      it 'is expected to reject value' do
        validation_result
        expect(errors).to contain_exactly('Row 5: Friendship value must be between -10 and 10')
      end
    end

    context 'when friendship is above maximum' do
      let(:friendship) { 11 }

      it 'is expected to reject value' do
        validation_result
        expect(errors).to contain_exactly('Row 5: Friendship value must be between -10 and 10')
      end
    end

    context 'when friendship is nil' do
      let(:friendship) { nil }

      it 'is expected to not validate' do
        validation_result
        expect(errors).to be_empty
      end
    end
  end

  describe 'constants' do
    describe 'VALID_ACTIONS' do
      subject { CsvValidator::VALID_ACTIONS }

      it { is_expected.to eq(['sell', 'refuse', 'negotiate', 'talk']) }
    end

    describe 'FRIENDSHIP_RANGE' do
      subject { CsvValidator::FRIENDSHIP_RANGE }

      it { is_expected.to eq(-10..10) }
    end
  end
end
