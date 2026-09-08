class Flows::ResumeDueSessionJob < ApplicationJob
  queue_as :medium

  def perform(session_id)
    session = FlowSession.find_by(id: session_id)
    return if session.blank?
    # Flag off pauses rather than skips: the deadline stays set and resumes on re-enable.
    return unless session.account.feature_enabled?('flows')

    Flows::TimeoutService.new(session).perform
  end
end
