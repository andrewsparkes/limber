# frozen_string_literal: true

module Robots
  class Robot::Bed
    include Form

    class BedError < StandardError; end
    # Our robot has beds/rack-spaces
    attr_accessor :purpose, :states, :label, :parent, :target_state, :robot, :child, :barcodes

    delegate :api, :user_uuid, to: :robot
    delegate :state, to: :plate, allow_nil: true, prefix: true

    validates :barcodes, length: { maximum: 1, too_long: 'This bed has been scanned multiple times with different barcodes. Only once is expected.' }
    validates :plate, presence: { message: ->(bed, _data) { "Could not find a plate with the barcode '#{bed.barcode}'." } }, if: :barcode
    validate :correct_plate_purpose, if: :plate
    validate :correct_plate_state, if: :plate

    def transitions?
      @target_state.present?
    end

    def transition
      return if target_state.nil? || plate.nil? # We have nothing to do

      StateChangers.lookup_for(plate.purpose.uuid).new(api, plate.uuid, user_uuid).move_to!(target_state, "Robot #{robot.name} started")
    end

    def purpose_labels
      purpose
    end

    def barcode
      @barcodes&.first
    end

    def load(barcodes)
      @barcodes = Array(barcodes).uniq.reject(&:blank?) # Ensure we always deal with an array, and any accidental duplicate scans are squashed out
      @plates = Sequencescape::Api::V2::Plate.find_all(barcode: @barcodes)
    end

    def plate
      @plates&.first
    end

    def parent_plate
      return nil if recieving_labware.nil?

      parent = plate.parents.first
      return parent if parent

      error("Labware #{recieving_labware.human_barcode} doesn't seem to have a parent, and yet one was expected.")
      nil
    end

    alias recieving_labware plate

    def formatted_message
      "#{label} - #{errors.full_messages.join('; ')}"
    end

    private

    def correct_plate_purpose
      return true if plate.purpose.name == purpose

      error("Plate #{plate.human_barcode} is a #{plate.purpose.name} not a #{purpose} plate.")
    end

    def correct_plate_state
      return true if states.include?(plate.state)

      error("Plate #{plate.human_barcode} is #{plate.state} when it should be #{states.join(', ')}.")
    end

    def error(message)
      errors.add(:base, message)
      false
    end
  end
end
