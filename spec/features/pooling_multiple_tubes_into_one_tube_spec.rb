# frozen_string_literal: true

require 'rails_helper'

feature 'Pooling multiple tubes into a tube', js: true do
  has_a_working_api

  let(:user_uuid)         { SecureRandom.uuid }
  let(:user)              { json :user, uuid: user_uuid }
  let(:user_swipecard)    { 'abcdef' }

  let(:aliquot_set_1) { Array.new(2) { associated(:tagged_aliquot) } }

  let(:tube_barcode_1)   { SBCF::SangerBarcode.new(prefix: 'NT', number: 1).machine_barcode.to_s }
  let(:tube_uuid)        { SecureRandom.uuid }
  let(:parent_purpose_name) { 'example-purpose' }
  let(:example_tube_args) { [:tube, barcode_number: 1, state: 'passed', uuid: tube_uuid, purpose_name: parent_purpose_name, aliquots: aliquot_set_1] }
  let(:example_tube) { json(*example_tube_args) }
  let(:example_tube_listed) { associated(*example_tube_args) }

  let(:tube_barcode_2)   { SBCF::SangerBarcode.new(prefix: 'NT', number: 2).machine_barcode.to_s }
  let(:tube_uuid_2)      { SecureRandom.uuid }
  let(:example_tube2_args) { [:tube, barcode_number: 2, state: 'passed', uuid: tube_uuid_2, aliquots: aliquot_set_2] }
  let(:example_tube_2) { json(*example_tube2_args) }
  let(:example_tube_2_listed) { associated(*example_tube2_args) }

  let(:purpose_uuid) { SecureRandom.uuid }
  let(:template_uuid) { SecureRandom.uuid }

  let(:barcodes) { [tube_barcode_1, tube_barcode_2] }

  let(:child_uuid) { 'tube-0' }
  let(:child_tube) { json :tube, purpose_uuid: purpose_uuid, purpose_name: 'Pool tube', uuid: child_uuid }

  let(:tube_creation_request_uuid) { SecureRandom.uuid }

  let!(:tube_creation_request) do
    # TODO: In reality we want to link in all four parents.
    stub_api_post(
      'tube_from_tube_creations',
      payload: {
        tube_from_tube_creation: {
          user: user_uuid,
          parent: tube_uuid,
          child_purpose: purpose_uuid
        }
      },
      body: json(:tube_creation, child_uuid: child_uuid)
    )
  end

  # Find out what tubes we've just made!
  let!(:tube_creation_children_request) do
    stub_api_get(tube_creation_request_uuid, 'children', body: json(:single_study_multiplexed_library_tube_collection, names: ['DN2+']))
  end

  # Used to fetch the pools. This is the kind of thing we could pass through from a custom form
  let!(:stub_barcode_searches) do
    stub_asset_search(barcodes, [example_tube_listed, example_tube_2_listed])
  end

  let!(:transfer_creation_request) do
    stub_api_post('transfer_request_collections',
                  payload: { transfer_request_collection: {
                    user: user_uuid,
                    transfer_requests: [
                      { 'source_asset' => tube_uuid, 'target_asset' => child_uuid },
                      { 'source_asset' => tube_uuid_2, 'target_asset' => child_uuid }
                    ]
                  } },
                  body: '{}')
  end

  let!(:order_requests) do
    stub_api_get(template_uuid, body: json(:submission_template, uuid: template_uuid))
    stub_api_post(template_uuid, 'orders',
                  payload: { order: {
                    assets: [child_uuid],
                    request_options: { read_length: 150 },
                    user: user_uuid
                  } },
                  body: '{"order":{"uuid":"order-uuid"}}')
    stub_api_post('submissions',
                  payload: { submission: { orders: ['order-uuid'], user: user_uuid } },
                  body:  json(:submission, uuid: 'sub-uuid', orders: [{ uuid: 'order-uuid' }]))
    stub_api_post('sub-uuid', 'submit')
  end

  background do
    Settings.purposes = {}
    Settings.purposes['example-purpose-uuid'] = build :tube_config, name: parent_purpose_name
    Settings.purposes[purpose_uuid] = build :pooled_tube_from_tubes_purpose_config,
                                            parents: [parent_purpose_name],
                                            submission: { template_uuid: template_uuid, options: { read_length: 150 } }
    # We look up the user
    stub_swipecard_search(user_swipecard, user)
    # We'll look up both tubes.
    stub_asset_search(tube_barcode_1, example_tube)
    stub_asset_search(tube_barcode_2, example_tube_2)

    # We have a basic inbox search running
    stub_search_and_multi_result(
      'Find tubes',
      { 'search' => { states: ['passed'], tube_purpose_uuids: ['example-purpose-uuid'], include_used: false } },
      [example_tube_listed, example_tube_2_listed]
    )

    stub_api_get(tube_uuid, body: example_tube)
    stub_api_get(tube_uuid_2, body: example_tube_2)
    stub_api_get(child_uuid, body: child_tube)
    stub_api_get('barcode_printers', body: json(:barcode_printer_collection))
  end

  context 'unique tags' do
    let(:aliquot_set_2) { Array.new(2) { associated(:tagged_aliquot) } }

    scenario 'creates multiple tubes' do
      fill_in_swipecard_and_barcode(user_swipecard, tube_barcode_1)
      tube_title = find('#tube-title')
      expect(tube_title).to have_text(parent_purpose_name)
      click_on('Add an empty Pool tube tube')
      fill_in('Plate 1', with: tube_barcode_1)
      fill_in('Plate 2', with: tube_barcode_2)
      # # Trigger a blur by filling in the next box
      # fill_in('Plate 3', with: '')
      click_on('Make Pool')
      expect(page).to have_text('New empty labware added to the system')
      expect(page).to have_text('Pool tube')
      # This isn't strictly speaking correct to test. But there isn't a great way
      # of confirming that the right information got passed to the back end otherwise.
      # (Although you expect it to fail on an incorrect request)
      expect(tube_creation_request).to have_been_made
      expect(transfer_creation_request).to have_been_made
    end
  end

  context 'clashing tags' do
    let(:aliquot_set_2) { aliquot_set_1 }

    scenario 'detects tag clash' do
      fill_in_swipecard_and_barcode(user_swipecard, tube_barcode_1)
      tube_title = find('#tube-title')
      expect(tube_title).to have_text('example-purpose')
      click_on('Add an empty Pool tube tube')
      fill_in('Plate 1', with: tube_barcode_1)
      fill_in('Plate 2', with: tube_barcode_2)

      expect(page).to have_text('Scanned tubes have matching tags')
    end
  end
end