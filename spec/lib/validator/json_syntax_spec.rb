# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/json_syntax'

RSpec.describe Validator::JsonSyntax do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when output contains valid JSON' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell","message":"Hello"}']) }

      it { is_expected.to be true }
    end

    context 'when output is nil' do
      let(:row) { CSV::Row.new(['output'], [nil]) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing output column')
      end
    end

    context 'when output is empty string' do
      let(:row) { CSV::Row.new(['output'], ['']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing output column')
      end
    end

    context 'when JSON is malformed' do
      let(:row) { CSV::Row.new(['output'], ['{not valid json}']) }

      it 'is expected to raise ValidationError with JSON parse error message' do
        expect { validation_result }.to raise_error(ValidationError, /Invalid JSON/)
      end
    end

    context 'when JSON is incomplete' do
      let(:row) { CSV::Row.new(['output'], ['{"action":"sell"']) }

      it 'is expected to raise ValidationError with JSON parse error message' do
        expect { validation_result }.to raise_error(ValidationError, /Invalid JSON/)
      end
    end
  end
end
