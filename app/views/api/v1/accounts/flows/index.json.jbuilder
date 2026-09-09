json.payload do
  json.array! @flows do |flow|
    json.partial! 'api/v1/accounts/flows/partials/flow', formats: [:json], flow: flow
  end
end
