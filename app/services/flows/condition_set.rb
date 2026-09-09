# AutomationRules::ConditionsFilterService evaluates whatever object it is handed for its
# `conditions`, so a flow's entry conditions and a condition node's own set are both presented
# through this rather than by making Flow impersonate an automation rule.
class Flows::ConditionSet
  attr_reader :id, :account, :conditions

  def initialize(id, account, conditions)
    @id = id
    @account = account
    @conditions = conditions
  end

  # Reauthorizable hook the filter service calls when a condition set stops validating. Flow
  # conditions are authored in Chatwoot rather than against an external credential, so there is
  # nothing to reauthorize.
  def authorization_error!; end
end
