# Wakes flow sessions whose delay or timeout has come due.
class Flows::TriggerDueSessionsJob < ApplicationJob
  queue_as :scheduled_jobs

  SWEEP_LIMIT = 1000
  # A deadline older than this is backlog from downtime. Firing it would drop a stale message
  # into a conversation that moved on hours ago, so those sessions are ended instead.
  DUE_WINDOW = 1.day

  def perform
    expire_stale_sessions
    due_sessions.each { |id| Flows::ResumeDueSessionJob.perform_later(id) }
  end

  private

  def due_sessions
    FlowSession.active.where(resume_at: DUE_WINDOW.ago..Time.current).order(:resume_at).limit(SWEEP_LIMIT).pluck(:id)
  end

  def expire_stale_sessions
    FlowSession.active.where(resume_at: ...DUE_WINDOW.ago).find_each { |session| session.finish!(:aborted) }
  end
end
