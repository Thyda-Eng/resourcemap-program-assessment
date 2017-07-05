#= require layers/on_layers
#= require_tree ./layers

# We do the check again so tests don't trigger this initialization
onLayers -> if $('#layers-main').length > 0
  match = window.location.toString().match(/\/collections\/(\d+)\/layers/)
  window.collectionId = parseInt(match[1])

  $('.hierarchy_upload').live 'change', ->
    $('.hierarchy_form').submit()
    window.model.startUploadHierarchy()

  $('.location_upload').live 'change', ->
    $('.location_form').submit()
    window.model.startUploadLocation()

  #show loading
  $('#loadProgress').show()

  $.get "/collections/#{collectionId}/layers/list_layers.json", {}, (layers) =>
    window.layerList = layers
    $.get "/setting.json", {}, (settings) =>
      $.get "/api/collections/#{collectionId}/settings.json", {}, (collectionSetting) ->
        createBinding(layers, settings, collectionSetting)

  window.layerList = null
  window.bindingCreated = false

  createBinding = (layers, settings, collectionSetting)->
    if window.layerList && !window.bindingCreated
      window.model = new MainViewModel(window.collectionId, layers, settings, collectionSetting)
      ko.applyBindings window.model
      window.bindingCreated = true

      $('.hidden-until-loaded').show()
      $('#loadProgress').hide() #hide loading
