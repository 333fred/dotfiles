rule = {
    matches = {
      {
        { "device.nick", "matches", "HD-Audio Generic" },
      },
    },
    apply_properties = {
      ["api.alsa.use-acp"] = true,
      ["api.acp.auto-profile"] = false,
      ["api.acp.auto-port"] = false,
      ["device.profile-set"] = "digital-analog.conf",
      ["device.profile"] = "digital_analog",
    },
  }
table.insert(alsa_monitor.rules,rule)
