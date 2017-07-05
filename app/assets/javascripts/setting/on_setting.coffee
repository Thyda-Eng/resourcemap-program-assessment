window.onSetting ?= (callback) -> $(-> callback() if $('#setting-main').length > 0)
