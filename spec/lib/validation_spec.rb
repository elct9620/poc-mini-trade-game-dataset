# frozen_string_literal: true

require 'spec_helper'
require 'csv'
require 'tempfile'
require_relative '../support/rows'
require_relative '../../lib/validation'
require_relative '../../lib/dataset'
require_relative '../../lib/validator'

RSpec.describe Validation do
  describe '#execute' do
    subject(:errors) { described_class.new(Dataset.new(tempfile.path), Validator.all).execute }

    let(:tempfile) { Tempfile.new(['test', '.csv']) }

    before do
      tempfile.write(CSV.generate { |csv| ([VALID_ROW.keys] + rows.map(&:values)).each { |line| csv << line } })
      tempfile.rewind
    end

    after do
      tempfile.close
      tempfile.unlink
    end

    context 'when all rows are valid' do
      let(:rows) { [VALID_ROW, VALID_ROW.merge('id' => '2')] }

      it { is_expected.to be_empty }
    end

    context 'when rows fail' do
      let(:rows) { [VALID_ROW, VALID_ROW.merge('action' => 'steal'), VALID_ROW.merge('input' => '')] }

      it { is_expected.to contain_exactly("Row 3: Invalid action 'steal'", "Row 4: Missing 'input'") }
    end

    context 'when the CSV has no rows' do
      let(:rows) { [] }

      it { is_expected.to be_empty }
    end
  end
end
