json.payload do
  json.partial! 'api/v1/accounts/session_labels/session_label', session_label: @session_label
end
