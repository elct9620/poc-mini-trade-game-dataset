# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/relationship_validator'

RSpec.describe Validator::RelationshipValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when relationship_status is Hostile' do
      let(:row) { CSV::Row.new(['relationship_status'], ['Hostile']) }

      it { is_expected.to be true }
    end

    context 'when relationship_status is Neutral' do
      let(:row) { CSV::Row.new(['relationship_status'], ['Neutral']) }

      it { is_expected.to be true }
    end

    context 'when relationship_status is Friendly' do
      let(:row) { CSV::Row.new(['relationship_status'], ['Friendly']) }

      it { is_expected.to be true }
    end

    context 'when relationship_status is Allied' do
      let(:row) { CSV::Row.new(['relationship_status'], ['Allied']) }

      it { is_expected.to be true }
    end

    context 'when relationship_status is nil' do
      let(:row) { CSV::Row.new(['relationship_status'], [nil]) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing relationship_status column')
      end
    end

    context 'when relationship_status is empty string' do
      let(:row) { CSV::Row.new(['relationship_status'], ['']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing relationship_status column')
      end
    end

    context 'when relationship_status is invalid' do
      let(:row) { CSV::Row.new(['relationship_status'], ['Enemy']) }

      it 'is expected to raise ValidationError with valid values' do
        expect { validation_result }.to raise_error(ValidationError, /Invalid relationship 'Enemy'/)
      end
    end
  end
end
