#= require setting/on_setting
#= require_tree ./setting/.

onSetting -> if $('#setting-main').length > 0
  $.get "/setting.json", {}, (setting) ->
    window.model = new MainViewModel(setting)
    ko.applyBindings(window.model)
    $('.hidden-until-loaded').show()
