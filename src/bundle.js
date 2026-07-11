(function () {
  'use strict';

  // ── schema.js ──────────────────────────────────────────────────────

  var globalFields = [
    { key: 'blur_strength', label: 'Blur strength', min: 0, max: 8, step: 0.1, defaultValue: 3.4, description: 'Blur radius scale. The plugin multiplies this by about 12 px.' },
    { key: 'blur_iterations', label: 'Blur iterations', min: 1, max: 5, step: 1, defaultValue: 2, description: 'Gaussian blur passes.' },
    { key: 'refraction_strength', label: 'Refraction strength', min: 0, max: 1, step: 0.01, defaultValue: 0.96, description: 'Edge refraction intensity.' },
    { key: 'chromatic_aberration', label: 'Chromatic aberration', min: 0, max: 1, step: 0.01, defaultValue: 0.7, description: 'Spectral dispersion at edges.' },
    { key: 'fresnel_strength', label: 'Fresnel strength', min: 0, max: 1, step: 0.01, defaultValue: 0.96, description: 'Edge glow intensity.' },
    { key: 'specular_strength', label: 'Specular strength', min: 0, max: 1, step: 0.01, defaultValue: 0.6, description: 'Specular highlight brightness.' },
    { key: 'glass_opacity', label: 'Glass opacity', min: 0, max: 1, step: 0.01, defaultValue: 1.0, description: 'Overall glass opacity.' },
    { key: 'edge_thickness', label: 'Edge thickness', min: 0, max: 0.15, step: 0.001, defaultValue: 0.14, description: 'Bezel width as a fraction of the smallest dimension.' },
    { key: 'lens_distortion', label: 'Lens distortion', min: 0, max: 1, step: 0.01, defaultValue: 0.56, description: 'Center dome magnification.' },
  ];

  var themeFields = [
    { key: 'brightness', label: 'Brightness', min: 0.2, max: 1.6, step: 0.01, darkDefault: 0.82, lightDefault: 1.12, description: 'Brightness multiplier.' },
    { key: 'contrast', label: 'Contrast', min: 0.2, max: 1.6, step: 0.01, darkDefault: 0.9, lightDefault: 0.92, description: 'Contrast around the midpoint.' },
    { key: 'saturation', label: 'Saturation', min: 0, max: 1.5, step: 0.01, darkDefault: 0.8, lightDefault: 0.85, description: 'Desaturation level.' },
    { key: 'vibrancy', label: 'Vibrancy', min: 0, max: 1, step: 0.01, darkDefault: 0.6, lightDefault: 0.12, description: 'Selective saturation boost.' },
    { key: 'vibrancy_darkness', label: 'Vibrancy darkness', min: 0, max: 1, step: 0.01, darkDefault: 0.0, lightDefault: 0.0, description: 'How much dark areas influence vibrancy.' },
    { key: 'adaptive_dim', label: 'Adaptive dim', min: 0, max: 1, step: 0.01, darkDefault: 0.4, lightDefault: 0.0, description: 'Dims bright areas behind the glass.' },
    { key: 'adaptive_boost', label: 'Adaptive boost', min: 0, max: 1, step: 0.01, darkDefault: 0.34, lightDefault: 0.4, description: 'Boosts dark areas behind the glass.' },
  ];

  var layerFields = [
    { key: 'enabled', label: 'Enable layers', description: 'Apply the glass effect to layer surfaces such as bars, docks, and widgets.' },
    { key: 'namespaces', label: 'Namespaces', description: 'Comma-separated whitelist. Empty means all layers when enabled.' },
    { key: 'exclude_namespaces', label: 'Excluded namespaces', description: 'Comma-separated blacklist. Takes priority over the whitelist.' },
    { key: 'preset', label: 'Layer preset', description: 'Preset override used by layer surfaces.' },
    { key: 'namespace_presets', label: 'Namespace presets', description: 'Comma-separated ns:preset pairs.' },
    { key: 'namespace_mask_thresholds', label: 'Mask thresholds', description: 'Comma-separated ns=value pairs.' },
  ];

  var defaultTheme = 'dark';
  var defaultPreset = 'default';
  var themeOptions = ['dark', 'light'];
  var presetOptions = ['glass', 'subtle', 'ui'];

  var decorationFields = [
    { key: 'active_opacity', label: 'Active opacity', min: 0, max: 1, step: 0.01, defaultValue: 0.86, description: 'Opacity of focused windows. Lower values make glass more visible.' },
    { key: 'inactive_opacity', label: 'Inactive opacity', min: 0, max: 1, step: 0.01, defaultValue: 0.72, description: 'Opacity of unfocused windows. Should be lower than active.' },
    { key: 'fullscreen_opacity', label: 'Fullscreen opacity', min: 0, max: 1, step: 0.01, defaultValue: 1.0, description: 'Opacity of fullscreen windows. Usually 1.0 for no glass.' },
  ];

  var defaultWindowRules = [
    { enabled: true, match: 'class ^(waterfox)$', action: 'tag +browser', description: 'Tag Waterfox as browser' },
    { enabled: true, match: 'class ^(waterfox)$', action: 'opacity 0.86 0.72', description: 'Waterfox opacity override' },
    { enabled: true, match: 'tag:browser', action: 'tag +hyprglass_enabled', description: 'Enable glass on browser windows' },
    { enabled: true, match: 'tag:browser', action: 'tag +hyprglass_preset_glass', description: 'Use glass preset on browsers' },
  ];

  function createTintState(hex) {
    if (hex === undefined) hex = '0x99c1f122';
    var clean = hex.replace(/^0x/i, '').replace(/^#/, '').padEnd(8, 'f').slice(0, 8);
    return {
      rgb: '#' + clean.slice(0, 6),
      alpha: Number.parseInt(clean.slice(6, 8), 16),
    };
  }

  function serializeTintState(state) {
    var rgb = String((state && state.rgb) || '#8899aa').replace(/^#/, '').padEnd(6, '0').slice(0, 6);
    var alphaValue = Number.isFinite(Number(state && state.alpha)) ? Number(state.alpha) : 255;
    var alpha = Math.max(0, Math.min(255, Math.round(alphaValue))).toString(16).padStart(2, '0');
    return '0x' + rgb + alpha;
  }

  function createDefaultState() {
    var global = Object.fromEntries(
      globalFields.map(function (field) { return [field.key, field.defaultValue]; }),
    );
    global.tint_color = createTintState();

    var themes = {
      dark: Object.fromEntries(themeFields.map(function (field) { return [field.key, field.darkDefault]; })),
      light: Object.fromEntries(themeFields.map(function (field) { return [field.key, field.lightDefault]; })),
    };

    var decoration = Object.fromEntries(
      decorationFields.map(function (field) { return [field.key, field.defaultValue]; }),
    );

    return {
      enabled: true,
      default_theme: defaultTheme,
      default_preset: defaultPreset,
      output_format: 'conf',
      preview_theme: 'dark',
      global: global,
      themes: themes,
      decoration: decoration,
      layers: {
        enabled: true,
        namespaces: 'waybar, swaync, notifications, quickshell:overview, quickshell:bezel, rofi',
        exclude_namespaces: '',
        preset: 'subtle',
        namespace_presets: 'waybar:subtle, quickshell:bezel:ui',
        namespace_mask_thresholds: 'waybar=0.05, quickshell:overview=0.3, quickshell:bezel=0.3, rofi=0.05',
      },
      window_rules: defaultWindowRules.map(function (r) { return Object.assign({}, r); }),
    };
  }

  function parseCommaList(value) {
    return String(value || '')
      .split(',')
      .map(function (item) { return item.trim(); })
      .filter(Boolean);
  }

  function parsePairs(value, separator) {
    if (separator === undefined) separator = ':';
    var pairs = {};
    parseCommaList(value).forEach(function (entry) {
      var idx = entry.indexOf(separator);
      if (idx === -1) return;
      var left = entry.slice(0, idx).trim();
      var right = entry.slice(idx + 1).trim();
      if (left && right) pairs[left] = right;
    });
    return pairs;
  }

  function parseThresholdPairs(value) {
    var pairs = {};
    parseCommaList(value).forEach(function (entry) {
      var idx = entry.indexOf('=');
      if (idx === -1) return;
      var left = entry.slice(0, idx).trim();
      var right = Number.parseFloat(entry.slice(idx + 1).trim());
      if (left && Number.isFinite(right)) pairs[left] = right;
    });
    return pairs;
  }

  function formatNumber(field, value) {
    var num = Number(value);
    if (field.key === 'blur_iterations') return String(Math.round(num));
    if (field.key === 'edge_thickness') return num.toFixed(3).replace(/0+$/, '').replace(/\.$/, '') || '0';
    if (field.key === 'blur_strength') return num.toFixed(1);
    var formatted = num.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
    return formatted || '0';
  }

  function formatValue(field, value) {
    if (field.key === 'blur_iterations') return String(Math.round(Number(value)));
    return formatNumber(field, value);
  }

  function formatConf(state) {
    var lines = [];
    lines.push('plugin:hyprglass {');
    lines.push('  enabled = ' + (state.enabled ? 1 : 0));
    lines.push('  default_theme = ' + state.default_theme);
    lines.push('  default_preset = ' + state.default_preset);
    globalFields.forEach(function (field) {
      lines.push('  ' + field.key + ' = ' + formatValue(field, state.global[field.key]));
    });
    lines.push('  tint_color = ' + serializeTintState(state.global.tint_color));
    themeOptions.forEach(function (themeName) {
      themeFields.forEach(function (field) {
        lines.push('  ' + themeName + ':' + field.key + ' = ' + formatValue(field, state.themes[themeName][field.key]));
      });
    });
    lines.push('  layers:enabled = ' + (state.layers.enabled ? 1 : 0));
    lines.push('  layers:namespaces = ' + state.layers.namespaces);
    lines.push('  layers:exclude_namespaces = ' + state.layers.exclude_namespaces);
    lines.push('  layers:preset = ' + state.layers.preset);
    lines.push('  layers:namespace_presets = ' + state.layers.namespace_presets);
    lines.push('  layers:namespace_mask_thresholds = ' + state.layers.namespace_mask_thresholds);
    lines.push('}');
    lines.push('');
    lines.push('# Override Jakoolit defaults so HyprGlass has visible transparency to work with');
    lines.push('decoration {');
    decorationFields.forEach(function (field) {
      lines.push('  ' + field.key + ' = ' + formatValue(field, state.decoration[field.key]));
    });
    lines.push('}');
    lines.push('');
    lines.push('# Compatibility opacity overrides so the effect is visible on opaque apps');
    var activeRules = (state.window_rules || []).filter(function (r) { return r.enabled; });
    activeRules.forEach(function (rule) {
      lines.push('windowrule = match:' + rule.match + ', ' + rule.action);
    });
    if (!activeRules.length) {
      lines.push('# No window rules configured');
    }
    return lines.join('\n');
  }

  function formatLua(state) {
    var lines = [];
    lines.push('local hg = require("hyprglass")');
    lines.push('');
    lines.push('hg.config({');
    lines.push('  enabled = ' + (state.enabled ? 'true' : 'false') + ',');
    lines.push('  default_theme = "' + state.default_theme + '",');
    lines.push('  default_preset = "' + state.default_preset + '",');
    globalFields.forEach(function (field) {
      lines.push('  ' + field.key + ' = ' + formatValue(field, state.global[field.key]) + ',');
    });
    lines.push('  tint_color = "' + serializeTintState(state.global.tint_color) + '",');
    lines.push('  dark = {');
    themeFields.forEach(function (field) {
      lines.push('    ' + field.key + ' = ' + formatValue(field, state.themes.dark[field.key]) + ',');
    });
    lines.push('  },');
    lines.push('  light = {');
    themeFields.forEach(function (field) {
      lines.push('    ' + field.key + ' = ' + formatValue(field, state.themes.light[field.key]) + ',');
    });
    lines.push('  },');
    lines.push('  layers = {');
    lines.push('    enabled = ' + (state.layers.enabled ? 'true' : 'false') + ',');
    if (state.layers.preset) lines.push('    preset = "' + state.layers.preset + '",');
    lines.push('  },');
    lines.push('})');
    lines.push('');

    var namespaces = parseCommaList(state.layers.namespaces);
    var excludes = parseCommaList(state.layers.exclude_namespaces);
    var presetPairs = parsePairs(state.layers.namespace_presets, ':');
    var thresholdPairs = parseThresholdPairs(state.layers.namespace_mask_thresholds);
    var layerPreset = state.layers.preset ? String(state.layers.preset) : '';

    namespaces.forEach(function (namespace) {
      var entries = [];
      var preset = presetPairs[namespace] || layerPreset;
      if (preset) entries.push('preset = "' + preset + '"');
      if (thresholdPairs[namespace] != null) entries.push('mask_threshold = ' + thresholdPairs[namespace]);
      lines.push(entries.length ? 'hg.layer("' + namespace + '", { ' + entries.join(', ') + ' })' : 'hg.layer("' + namespace + '")');
    });

    excludes.forEach(function (namespace) {
      lines.push('hg.layer("' + namespace + '", { exclude = true })');
    });

    return lines.join('\n');
  }

  function summarizeState(state) {
    var activeTheme = state.preview_theme;
    var globals = globalFields.length;
    var themeCount = themeFields.length * 2;
    var namespaces = parseCommaList(state.layers.namespaces).length;
    var excluded = parseCommaList(state.layers.exclude_namespaces).length;
    var activeRules = (state.window_rules || []).filter(function (r) { return r.enabled; }).length;
    return {
      activeTheme: activeTheme,
      globals: globals,
      themeCount: themeCount,
      namespaces: namespaces,
      excluded: excluded,
      layersEnabled: state.layers.enabled,
      enabled: state.enabled,
      activeRules: activeRules,
    };
  }

  // ── app.js ─────────────────────────────────────────────────────────

  var STORAGE_KEY = 'hyprglass-studio.state.v1';
  var app = document.getElementById('app');

  var savedState = loadState();
  var state = savedState.state;
  var activeSection = savedState.activeSection || 'global';

  render();
  wireEvents();
  persist();

  function loadState() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return { state: createDefaultState(), activeSection: 'global' };
      var parsed = JSON.parse(raw);
      return {
        state: mergeWithDefaults(parsed.state || parsed, createDefaultState()),
        activeSection: parsed.activeSection || 'global',
      };
    } catch (e) {
      return { state: createDefaultState(), activeSection: 'global' };
    }
  }

  function mergeWithDefaults(source, fallback) {
    var base = createDefaultState();
    var merged = structuredClone(base);

    merged.enabled = Boolean((source && source.enabled != null ? source.enabled : fallback.enabled));
    merged.default_theme = (source && source.default_theme) || fallback.default_theme;
    merged.default_preset = (source && source.default_preset) || fallback.default_preset;
    merged.output_format = (source && source.output_format) || fallback.output_format;
    merged.preview_theme = (source && source.preview_theme) || fallback.preview_theme;

    for (var i = 0; i < globalFields.length; i++) {
      var field = globalFields[i];
      merged.global[field.key] = Number((source && source.global && source.global[field.key] != null ? source.global[field.key] : fallback.global[field.key]));
    }
    merged.global.tint_color = normalizeTint((source && source.global && source.global.tint_color) || fallback.global.tint_color);

    for (var t = 0; t < themeOptions.length; t++) {
      var themeName = themeOptions[t];
      for (var j = 0; j < themeFields.length; j++) {
        var tf = themeFields[j];
        merged.themes[themeName][tf.key] = Number((source && source.themes && source.themes[themeName] && source.themes[themeName][tf.key] != null ? source.themes[themeName][tf.key] : fallback.themes[themeName][tf.key]));
      }
    }

    for (var d = 0; d < decorationFields.length; d++) {
      var df = decorationFields[d];
      merged.decoration[df.key] = Number((source && source.decoration && source.decoration[df.key] != null ? source.decoration[df.key] : fallback.decoration[df.key]));
    }

    merged.layers.enabled = Boolean((source && source.layers && source.layers.enabled != null ? source.layers.enabled : fallback.layers.enabled));
    merged.layers.namespaces = String((source && source.layers && source.layers.namespaces != null ? source.layers.namespaces : fallback.layers.namespaces));
    merged.layers.exclude_namespaces = String((source && source.layers && source.layers.exclude_namespaces != null ? source.layers.exclude_namespaces : fallback.layers.exclude_namespaces));
    merged.layers.preset = String((source && source.layers && source.layers.preset != null ? source.layers.preset : fallback.layers.preset));
    merged.layers.namespace_presets = String((source && source.layers && source.layers.namespace_presets != null ? source.layers.namespace_presets : fallback.layers.namespace_presets));
    merged.layers.namespace_mask_thresholds = String((source && source.layers && source.layers.namespace_mask_thresholds != null ? source.layers.namespace_mask_thresholds : fallback.layers.namespace_mask_thresholds));

    merged.window_rules = Array.isArray(source && source.window_rules)
      ? source.window_rules.map(function (r, i) {
          return {
            enabled: Boolean(r.enabled != null ? r.enabled : true),
            match: String(r.match || ''),
            action: String(r.action || ''),
            description: String(r.description || (defaultWindowRules[i] && defaultWindowRules[i].description) || ''),
          };
        })
      : fallback.window_rules.map(function (r) { return Object.assign({}, r); });

    return merged;
  }

  function normalizeTint(value) {
    if (!value) return createDefaultState().global.tint_color;
    if (typeof value === 'string') {
      var hex = value.replace(/^0x/i, '').replace(/^#/, '').padEnd(8, 'f').slice(0, 8);
      return { rgb: '#' + hex.slice(0, 6), alpha: Number.parseInt(hex.slice(6, 8), 16) };
    }
    return {
      rgb: String(value.rgb || '#8899aa'),
      alpha: Number.isFinite(Number(value.alpha)) ? Number(value.alpha) : 34,
    };
  }

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ state: state, activeSection: activeSection }));
    } catch (e) {
      // Some browsers restrict storage for file:// origins.
    }
  }

  function setNested(path, value) {
    var parts = path.split('.');
    var cursor = state;
    while (parts.length > 1) {
      cursor = cursor[parts.shift()];
    }
    cursor[parts[0]] = value;
    persist();
    render();
  }

  function resetState() {
    state = createDefaultState();
    activeSection = 'global';
    persist();
    render();
  }

  function exportText() {
    return state.output_format === 'lua' ? formatLua(state) : formatConf(state);
  }

  function liveConfigText() {
    return formatConf(state);
  }

  async function sendConfig(kind) {
    var response = await fetch('/api/' + kind, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ config: liveConfigText() }),
    });
    var payload = await response.json().catch(function () { return ({}); });
    if (!response.ok || payload.ok === false) {
      throw new Error(payload.error || 'failed to ' + kind);
    }
    return payload;
  }

  async function copyExport() {
    try {
      await navigator.clipboard.writeText(exportText());
      toast('Copied config to clipboard.');
    } catch (e) {
      toast('Clipboard access was blocked.');
    }
  }

  function downloadExport() {
    var output = exportText();
    var blob = new Blob([output], { type: 'text/plain;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var link = document.createElement('a');
    link.href = url;
    link.download = state.output_format === 'lua' ? 'hyprglass.lua' : 'hyprglass.conf';
    link.click();
    URL.revokeObjectURL(url);
  }

  function toast(message) {
    var node = document.getElementById('toast');
    if (!node) return;
    node.textContent = message;
    node.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(function () { node.classList.remove('show'); }, 1800);
  }

  function wireEvents() {
    app.addEventListener('input', function (event) {
      var target = event.target;
      var path = target.dataset.path;
      if (!path) return;

      if (target.tagName === 'TEXTAREA') return;

      if (target.type === 'checkbox') {
        setNested(path, target.checked);
        return;
      }

      if (target.dataset.kind === 'int') {
        if (target.value === '') return;
        var parsed = Number.parseInt(target.value, 10);
        if (Number.isFinite(parsed)) setNested(path, parsed);
        return;
      }

      if (target.dataset.kind === 'float') {
        if (target.value === '') return;
        var parsed = Number.parseFloat(target.value);
        if (Number.isFinite(parsed)) setNested(path, parsed);
        return;
      }

      if (target.dataset.kind === 'tint-rgb') {
        setNested(path, Object.assign({}, state.global.tint_color, { rgb: target.value }));
        return;
      }

      if (target.dataset.kind === 'tint-alpha') {
        setNested(path, Object.assign({}, state.global.tint_color, { alpha: Number.parseInt(target.value, 10) }));
        return;
      }

      setNested(path, target.value);
    });

    app.addEventListener('change', function (event) {
      var target = event.target;
      var path = target.dataset.path;
      if (!path) return;
      if (target.tagName === 'SELECT' || target.tagName === 'TEXTAREA') {
        setNested(path, target.value);
      }
    });

    app.addEventListener('click', async function (event) {
      var action = event.target.dataset.action;
      if (!action) return;
      if (action === 'section') {
        activeSection = event.target.dataset.section;
        persist();
        render();
        return;
      }
      if (action === 'reset') return resetState();
      if (action === 'preview') {
        try {
          await sendConfig('preview');
          toast('Preview opened in kitty.');
        } catch (error) {
          toast(error.message);
        }
        return;
      }
      if (action === 'apply') {
        try {
          await sendConfig('apply');
          toast('Applied to Hyprland.');
        } catch (error) {
          toast(error.message);
        }
        return;
      }
      if (action === 'copy') return copyExport();
      if (action === 'download') return downloadExport();
      if (action === 'set-format') return setNested('output_format', event.target.dataset.format);
      if (action === 'set-theme') return setNested('preview_theme', event.target.dataset.theme);
      if (action === 'sample-layers') {
        setNested('layers.namespaces', 'waybar, swaync, notifications, quickshell:overview, quickshell:bezel, rofi');
        setNested('layers.exclude_namespaces', '');
        setNested('layers.preset', 'subtle');
        setNested('layers.namespace_presets', 'waybar:subtle, quickshell:bezel:ui');
        setNested('layers.namespace_mask_thresholds', 'waybar=0.05, quickshell:overview=0.3, quickshell:bezel=0.3, rofi=0.05');
      }
      if (action === 'add-window-rule') {
        var rules = (state.window_rules || []).slice();
        rules.push({ enabled: false, match: '', action: '', description: '' });
        setNested('window_rules', rules);
        return;
      }
      if (action === 'remove-window-rule') {
        var idx = Number(event.target.dataset.index);
        if (Number.isFinite(idx)) {
          var rules = (state.window_rules || []).slice();
          rules.splice(idx, 1);
          setNested('window_rules', rules);
        }
        return;
      }
    });
  }

  function render() {
    var summary = summarizeState(state);
    var preview = exportText();
    app.innerHTML = '\
    <div class="shell">\
      <aside class="sidebar">\
        <div class="brand">\
          <h1>Hyprglass Studio</h1>\
          <p>Standalone editor for Hyprglass config, with reversible local export.</p>\
        </div>\
        <nav class="nav">\
          ' + navButton('global', 'Global settings') + '\
          ' + navButton('theme', 'Theme settings') + '\
          ' + navButton('layers', 'Layer surfaces') + '\
          ' + navButton('decoration', 'Decoration') + '\
          ' + navButton('windowrules', 'Window rules') + '\
          ' + navButton('export', 'Export') + '\
        </nav>\
        <div class="meta">\
          <div class="panel">\
            <h3>State</h3>\
            <div class="badge-row" style="margin-top:10px">\
              <span class="badge good">' + summary.activeTheme + ' preview</span>\
              <span class="badge ' + (summary.enabled ? 'good' : 'warn') + '">plugin ' + (summary.enabled ? 'on' : 'off') + '</span>\
              <span class="badge">' + summary.globals + ' globals</span>\
              <span class="badge">' + summary.themeCount + ' theme values</span>\
              <span class="badge ' + (summary.layersEnabled ? 'good' : 'warn') + '">layers ' + (summary.layersEnabled ? 'on' : 'off') + '</span>\
              <span class="badge">' + summary.activeRules + ' rules</span>\
            </div>\
            <p class="help" style="margin-top:10px">Resolved config is previewed in the right panel and saved in your browser\'s local storage.</p>\
          </div>\
          <button class="action" data-action="reset">Reset to defaults</button>\
        </div>\
      </aside>\
\
      <main class="content">\
        <div class="header">\
          <div>\
            <h2>' + sectionTitle(activeSection) + '</h2>\
            <p class="muted">' + sectionDescription(activeSection) + '</p>\
          </div>\
          <div class="actions">\
            ' + (activeSection === 'layers' ? '<button class="action" data-action="sample-layers">Use sample layers</button>' : '') + '\
            <button class="action" data-action="preview">Preview</button>\
            <button class="action primary" data-action="apply">Apply</button>\
            <button class="action" data-action="copy">Copy config</button>\
            <button class="action primary" data-action="download">Download</button>\
          </div>\
        </div>\
        ' + renderSection() + '\
      </main>\
\
      <aside class="preview">\
        <div class="preview-head">\
          <div class="inline-list">\
            ' + formatToggle('conf', 'CONF') + '\
            ' + formatToggle('lua', 'Lua') + '\
          </div>\
          <div class="inline-list">\
            ' + themeToggle('dark') + '\
            ' + themeToggle('light') + '\
          </div>\
          <div class="badge-row">\
            <span class="badge accent">default theme: ' + state.default_theme + '</span>\
            <span class="badge accent">default preset: ' + state.default_preset + '</span>\
            <span class="badge">' + parseCommaList(state.layers.namespaces).length + ' whitelisted</span>\
          </div>\
          <p class="help">The export panel follows the plugin\'s resolution order. Change the fields on the left and the config text updates immediately.</p>\
        </div>\
        <div class="panel">\
          <h3>Export profile</h3>\
          <div class="split">\
            <label class="field-row">\
              <span>Default theme</span>\
              <select data-path="default_theme">\
                ' + themeOptions.map(function (theme) { return '<option value="' + theme + '" ' + (state.default_theme === theme ? 'selected' : '') + '>' + theme + '</option>'; }).join('') + '\
              </select>\
            </label>\
            <label class="field-row">\
              <span>Default preset</span>\
              <select data-path="default_preset">\
                ' + presetOptions.map(function (preset) { return '<option value="' + preset + '" ' + (state.default_preset === preset ? 'selected' : '') + '>' + preset + '</option>'; }).join('') + '\
              </select>\
            </label>\
          </div>\
        </div>\
        <div class="preview-box">\
          <pre>' + escapeHtml(preview) + '</pre>\
        </div>\
      </aside>\
    </div>\
    <div id="toast" class="toast" aria-live="polite"></div>';
  }

  function navButton(section, label) {
    return '<button class="' + (activeSection === section ? 'active' : '') + '" data-action="section" data-section="' + section + '">' + label + '</button>';
  }

  function formatToggle(format, label) {
    var active = state.output_format === format;
    return '<button class="chip-button ' + (active ? 'active' : '') + '" data-action="set-format" data-format="' + format + '">' + label + '</button>';
  }

  function themeToggle(theme) {
    var active = state.preview_theme === theme;
    return '<button class="chip-button ' + (active ? 'active' : '') + '" data-action="set-theme" data-theme="' + theme + '">' + theme + '</button>';
  }

  function sectionTitle(section) {
    switch (section) {
      case 'theme':
        return 'Per-theme controls';
      case 'layers':
        return 'Layer surfaces';
      case 'decoration':
        return 'Decoration settings';
      case 'windowrules':
        return 'Window rules';
      case 'export':
        return 'Export and preview';
      default:
        return 'Global controls';
    }
  }

  function sectionDescription(section) {
    switch (section) {
      case 'theme':
        return 'Dark and light overrides for the theme-dependent values.';
      case 'layers':
        return 'Configure bars, docks, widgets, and excluded namespaces.';
      case 'decoration':
        return 'Opacity settings for focused, unfocused, and fullscreen windows.';
      case 'windowrules':
        return 'Per-window glass rules and compatibility settings.';
      case 'export':
        return 'Choose conf or Lua output, then copy or download the result.';
      default:
        return 'Global values that feed the plugin before theme-specific overrides.';
    }
  }

  function renderSection() {
    if (activeSection === 'theme') {
      return '\
      <div class="grid-two">\
        ' + themePanel('dark') + '\
        ' + themePanel('light') + '\
      </div>';
    }

    if (activeSection === 'layers') {
      return '\
      <div class="panel">\
        <div class="stack">\
          ' + toggleField('layers.enabled', 'Enable layer surfaces', layerFields[0].description) + '\
          ' + textField('layers.namespaces', 'Namespace whitelist', layerFields[1].description, 'waybar, swaync, rofi') + '\
          ' + textField('layers.exclude_namespaces', 'Namespace blacklist', layerFields[2].description, 'debug-panel, overlays') + '\
          ' + textField('layers.preset', 'Layer preset', layerFields[3].description, 'subtle') + '\
          ' + textField('layers.namespace_presets', 'Namespace presets', layerFields[4].description, 'waybar:subtle, quickshell:bezel:ui') + '\
          ' + textField('layers.namespace_mask_thresholds', 'Mask thresholds', layerFields[5].description, 'waybar=0.05, quickshell:bezel=0.3') + '\
        </div>\
      </div>';
    }

    if (activeSection === 'decoration') {
      return '\
      <div class="panel">\
        <h3>Window opacity</h3>\
        <p class="subhead">Controls how transparent windows are. Lower values make the glass effect more visible.</p>\
        <div class="stack">\
          ' + decorationFields.map(function (field) {
            return sliderCard(Object.assign({}, field, {
              path: 'decoration.' + field.key,
              value: state.decoration[field.key],
            }));
          }).join('') + '\
        </div>\
      </div>';
    }

    if (activeSection === 'windowrules') {
      return '\
      <div class="panel">\
        <h3>Window rules</h3>\
        <p class="subhead">Configure per-window glass behavior. Rules are applied in order.</p>\
        <div class="stack" id="window-rules-list">\
          ' + (state.window_rules || []).map(function (rule, index) {
            return windowRuleCard(rule, index);
          }).join('') + '\
        </div>\
        <button class="action" data-action="add-window-rule" style="margin-top:12px">Add rule</button>\
      </div>';
    }

    if (activeSection === 'export') {
      return '\
      <div class="grid-two">\
        <div class="panel">\
          <h3>Global summary</h3>\
          <p class="subhead">Current runtime state from your controls.</p>\
          <div class="badge-row">\
            <span class="badge ' + (state.enabled ? 'good' : 'warn') + '">plugin ' + (state.enabled ? 'enabled' : 'disabled') + '</span>\
            <span class="badge good">theme: ' + state.default_theme + '</span>\
            <span class="badge accent">preset: ' + state.default_preset + '</span>\
            <span class="badge">' + globalFields.length + ' global vars</span>\
            <span class="badge">' + (themeFields.length * 2) + ' theme vars</span>\
          </div>\
        </div>\
        <div class="panel">\
          <h3>Layer summary</h3>\
          <p class="subhead">Current layer config state.</p>\
          <div class="badge-row">\
            <span class="badge ' + (state.layers.enabled ? 'good' : 'warn') + '">' + (state.layers.enabled ? 'layer glass enabled' : 'layer glass disabled') + '</span>\
            <span class="badge">' + parseCommaList(state.layers.namespaces).length + ' namespaces</span>\
            <span class="badge">' + parseCommaList(state.layers.exclude_namespaces).length + ' excluded</span>\
          </div>\
        </div>\
      </div>\
      <div class="grid-two" style="margin-top:16px">\
        <div class="panel">\
          <h3>Decoration summary</h3>\
          <p class="subhead">Opacity settings for different window states.</p>\
          <div class="badge-row">\
            <span class="badge">active: ' + state.decoration.active_opacity + '</span>\
            <span class="badge">inactive: ' + state.decoration.inactive_opacity + '</span>\
            <span class="badge">fullscreen: ' + state.decoration.fullscreen_opacity + '</span>\
          </div>\
        </div>\
        <div class="panel">\
          <h3>Window rules summary</h3>\
          <p class="subhead">Active per-window rules.</p>\
          <div class="badge-row">\
            <span class="badge">' + (state.window_rules || []).filter(function (r) { return r.enabled; }).length + ' active rules</span>\
            <span class="badge">' + (state.window_rules || []).filter(function (r) { return !r.enabled; }).length + ' disabled</span>\
          </div>\
        </div>\
      </div>';
    }

    return '\
    <div class="section-grid">\
      <div class="panel">\
        <h3>Defaults</h3>\
        <p class="subhead">These apply globally before theme overrides.</p>\
        <div class="split">\
          ' + globalFields.slice(0, 5).map(function (field) { return globalCard(field); }).join('') + '\
          <div class="setting">\
            <div class="setting-head">\
              <strong>Tint color</strong>\
              <span>' + serializeTintState(state.global.tint_color) + '</span>\
            </div>\
            <p class="desc">Glass tint RRGGBBAA. Alpha controls tint strength.</p>\
            ' + tintField() + '\
          </div>\
        </div>\
      </div>\
      <div class="panel">\
        <h3>Additional globals</h3>\
        <p class="subhead">The remaining global values.</p>\
        <div class="mini-grid">\
          ' + globalFields.slice(5).map(function (field) { return globalCard(field); }).join('') + '\
        </div>\
      </div>\
      <div class="panel">\
        <h3>Plugin status</h3>\
        <p class="subhead">Enable or disable the glass effect globally.</p>\
        <div class="setting">\
          <div class="setting-head">\
            <strong>Enable plugin</strong>\
            <span>' + (state.enabled ? 'on' : 'off') + '</span>\
          </div>\
          <p class="desc">Master switch for the glass effect. When disabled, no windows will have glass.</p>\
          <label class="inline-list" style="align-items:center">\
            <input type="checkbox" ' + (state.enabled ? 'checked' : '') + ' data-path="enabled" />\
            <span>Enabled</span>\
          </label>\
        </div>\
      </div>\
    </div>';
  }

  function globalCard(field) {
    return sliderCard(Object.assign({}, field, {
      path: 'global.' + field.key,
      value: state.global[field.key],
    }));
  }

  function themePanel(theme) {
    var title = theme === 'dark' ? 'Dark theme' : 'Light theme';
    return '\
    <div class="panel">\
      <h3>' + title + '</h3>\
      <p class="subhead">' + (theme === 'dark' ? 'Dark default values and overrides.' : 'Light default values and overrides.') + '</p>\
      <div class="stack">\
        ' + themeFields.map(function (field) {
          return sliderCard(Object.assign({}, field, {
            path: 'themes.' + theme + '.' + field.key,
            value: state.themes[theme][field.key],
          }));
        }).join('') + '\
      </div>\
    </div>';
  }

  function sliderCard(field) {
    var valueText = (Number.isInteger(field.step) && field.step === 1)
      ? String(Math.round(Number(field.value)))
      : Number(field.value).toFixed(field.key === 'edge_thickness' ? 3 : 2).replace(/0+$/, '').replace(/\.$/, '');
    return '\
    <div class="setting">\
      <div class="setting-head">\
        <strong>' + field.label + '</strong>\
        <span>' + valueText + '</span>\
      </div>\
      <p class="desc">' + field.description + '</p>\
      <div class="slider-row">\
        <input\
          type="range"\
          min="' + field.min + '"\
          max="' + field.max + '"\
          step="' + field.step + '"\
          value="' + field.value + '"\
          data-path="' + field.path + '"\
          data-kind="' + (Number.isInteger(field.step) && field.step === 1 ? 'int' : 'float') + '"\
        />\
        <input\
          type="number"\
          min="' + field.min + '"\
          max="' + field.max + '"\
          step="' + field.step + '"\
          value="' + field.value + '"\
          data-path="' + field.path + '"\
          data-kind="' + (Number.isInteger(field.step) && field.step === 1 ? 'int' : 'float') + '"\
        />\
      </div>\
    </div>';
  }

  function tintField() {
    return '\
    <div class="color-row">\
      <input type="color" value="' + state.global.tint_color.rgb + '" data-path="global.tint_color" data-kind="tint-rgb" />\
      <input type="text" value="' + serializeTintState(state.global.tint_color) + '" readonly />\
      <input type="number" min="0" max="255" step="1" value="' + state.global.tint_color.alpha + '" data-path="global.tint_color" data-kind="tint-alpha" />\
    </div>';
  }

  function toggleField(path, label, description) {
    var checked = getByPath(path);
    return '\
    <div class="setting">\
      <div class="setting-head">\
        <strong>' + label + '</strong>\
        <span>' + (checked ? 'on' : 'off') + '</span>\
      </div>\
      <p class="desc">' + description + '</p>\
      <label class="inline-list" style="align-items:center">\
        <input type="checkbox" ' + (checked ? 'checked' : '') + ' data-path="' + path + '" />\
        <span>Enabled</span>\
      </label>\
    </div>';
  }

  function textField(path, label, description, placeholder) {
    if (!placeholder) placeholder = '';
    return '\
    <label class="field-row">\
      <span>' + label + '</span>\
      <textarea data-path="' + path + '" placeholder="' + placeholder + '">' + escapeHtml(getByPath(path) || '') + '</textarea>\
      <span class="help">' + description + '</span>\
    </label>';
  }

  function getByPath(path) {
    return path.split('.').reduce(function (cursor, part) { return cursor && cursor[part]; }, state);
  }

  function windowRuleCard(rule, index) {
    return '\
    <div class="setting" style="border-left: 3px solid ' + (rule.enabled ? 'var(--accent)' : 'var(--line)') + '">\
      <div class="setting-head">\
        <strong>' + (rule.description || 'Rule ' + (index + 1)) + '</strong>\
        <span>' + (rule.enabled ? 'active' : 'disabled') + '</span>\
      </div>\
      <div class="split">\
        <label class="field-row">\
          <span>Match condition</span>\
          <input type="text" value="' + escapeHtml(rule.match) + '" data-path="window_rules.' + index + '.match" placeholder="class ^(waterfox)$" />\
        </label>\
        <label class="field-row">\
          <span>Action</span>\
          <input type="text" value="' + escapeHtml(rule.action) + '" data-path="window_rules.' + index + '.action" placeholder="tag +hyprglass_enabled" />\
        </label>\
      </div>\
      <div class="inline-list" style="align-items:center; gap:12px">\
        <label class="inline-list" style="align-items:center">\
          <input type="checkbox" ' + (rule.enabled ? 'checked' : '') + ' data-path="window_rules.' + index + '.enabled" />\
          <span>Enabled</span>\
        </label>\
        <button class="action danger" data-action="remove-window-rule" data-index="' + index + '" style="padding:6px 10px; font-size:0.85rem">Remove</button>\
      </div>\
    </div>';
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  }

})();
