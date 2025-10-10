# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/schema_validator'

RSpec.describe Validator::SchemaValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when action is sell with valid price' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Sold","parameters":{"price":100}}']) }

      it { is_expected.to be true }
    end

    context 'when action is refuse' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"refuse","message":"No"}']) }

      it { is_expected.to be true }
    end

    context 'when action is negotiate with valid price' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"negotiate","message":"Counter offer","parameters":{"price":90}}']) }

      it { is_expected.to be true }
    end

    context 'when action is talk' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"talk","message":"Hello"}']) }

      it { is_expected.to be true }
    end

    context 'when action is invalid' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"steal","message":"Haha"}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Invalid action 'steal'")
      end
    end

    context 'when action is nil' do
      let(:row) { CSV::Row.new(['output'], ['{"message":"Hello"}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Invalid action ''")
      end
    end

    context 'when price is missing for sell action' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Sold","parameters":{}}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Price must be greater than 0 for action 'sell'")
      end
    end

    context 'when price is zero for sell action' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Sold","parameters":{"price":0}}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Price must be greater than 0 for action 'sell'")
      end
    end

    context 'when price is negative for negotiate action' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"negotiate","message":"Deal","parameters":{"price":-10}}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, "Price must be greater than 0 for action 'negotiate'")
      end
    end

    context 'when friendship is below minimum' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"refuse","message":"No","parameters":{"friendship_change":-4}}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Friendship value must be between -3 and 3')
      end
    end

    context 'when friendship is above maximum' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Thanks","parameters":{"price":50,"friendship_change":4}}']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Friendship value must be between -3 and 3')
      end
    end

    context 'when friendship is at minimum boundary' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"refuse","message":"No","parameters":{"friendship_change":-3}}']) }

      it { is_expected.to be true }
    end

    context 'when friendship is at maximum boundary' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Here","parameters":{"price":50,"friendship_change":3}}']) }

      it { is_expected.to be true }
    end

    context 'when output is nil' do
      let(:row) { CSV::Row.new(['output'], [nil]) }

      it { is_expected.to be true }
    end

    context 'when output is empty' do
      let(:row) { CSV::Row.new(['output'], ['']) }

      it { is_expected.to be true }
    end

    context 'when JSON is malformed' do
      let(:row) { CSV::Row.new(['output'], ['{invalid}']) }

      it { is_expected.to be true }
    end
  end
end
