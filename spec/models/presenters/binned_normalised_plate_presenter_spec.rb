# frozen_string_literal: true

require 'rails_helper'
require 'presenters/binned_normalised_plate_presenter'
require_relative 'shared_labware_presenter_examples'
require 'bigdecimal'

RSpec.describe Presenters::BinnedNormalisedPlatePresenter do
  has_a_working_api

  let(:purpose_name) { 'Limber example purpose' }
  let(:title) { purpose_name }
  let(:state) { 'pending' }
  let(:summary_tab) do
    [
      ['Barcode', 'DN1S <em>1220000001831</em>'],
      ['Number of wells', '4/96'],
      ['Plate type', purpose_name],
      ['Current plate state', state],
      ['Input plate barcode', 'DN2T <em>1220000002845</em>'],
      ['PCR Cycles', '10'],
      ['Created on', '2019-06-10']
    ]
  end

  # Create binning for 4 wells in 2 bins:
  #     1   2
  # A   *   *
  # B       *
  # C       *
  let(:well_a1) do
    create(:v2_well,
           position: { 'name' => 'A1' },
           qc_results: create_list(:qc_result_concentration, 1, value: 0.6))
  end
  let(:well_a2) do
    create(:v2_well,
           position: { 'name' => 'A2' },
           qc_results: create_list(:qc_result_concentration, 1, value: 10.0))
  end
  let(:well_b2) do
    create(:v2_well,
           position: { 'name' => 'B2' },
           qc_results: create_list(:qc_result_concentration, 1, value: 12.0))
  end
  let(:well_c2) do
    create(:v2_well,
           position: { 'name' => 'C2' },
           qc_results: create_list(:qc_result_concentration, 1, value: 15.0))
  end

  let(:labware) do
    build :v2_plate,
          purpose_name: purpose_name,
          state: state,
          barcode_number: 1,
          pool_sizes: [],
          wells: [well_a1, well_a2, well_b2, well_c2],
          outer_requests: requests,
          created_at: '2019-06-10 12:00:00 +0100'
  end

  let(:requests) { Array.new(4) { |i| create :library_request, state: 'started', uuid: "request-#{i}" } }

  let(:warnings) { {} }
  let(:label_class) { 'Labels::PlateLabel' }

  before do
    stub_v2_plate(labware, stub_search: false, custom_includes: 'wells.aliquots,wells.qc_results')
  end

  subject(:presenter) do
    Presenters::BinnedNormalisedPlatePresenter.new(
      api: api,
      labware: labware
    )
  end

  context 'when configuration is missing' do
    it 'throws an exception' do
      expect { presenter.binned_normalisation_config }.to raise_error(Exception)
    end
  end

  context 'when binning configuration is present' do
    before do
      create(:binned_normalisation_purpose_config, uuid: labware.purpose.uuid, warnings: warnings, label_class: label_class)
    end

    it_behaves_like 'a labware presenter'

    context 'binned normalisation plate display' do
      it 'should create a key for the bins that will be displayed' do
        # NB. contains min/max because just using bins template, but fields not needed in presentation
        expected_bins_key = [
          { 'colour' => 1, 'max' => 0.25e2, 'min' => -0.1e1, 'pcr_cycles' => 16 },
          { 'colour' => 2, 'max' => BigDecimal('Infinity'), 'min' => 0.25e2, 'pcr_cycles' => 14 }
        ]

        expect(presenter.bins_key).to eq(expected_bins_key)
      end

      it 'should create bin details which will be used to colour and annotate the well aliquots' do
        expected_bin_details = {
          'A1' => { 'colour' => 1, 'pcr_cycles' => 16 },
          'A2' => { 'colour' => 2, 'pcr_cycles' => 14 },
          'B2' => { 'colour' => 2, 'pcr_cycles' => 14 },
          'C2' => { 'colour' => 2, 'pcr_cycles' => 14 }
        }

        expect(presenter.bin_details).to eq(expected_bin_details)
      end
    end
  end
end