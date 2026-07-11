export const globalFields = [
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

export const themeFields = [
  { key: 'brightness', label: 'Brightness', min: 0.2, max: 1.6, step: 0.01, darkDefault: 0.82, lightDefault: 1.12, description: 'Brightness multiplier.' },
  { key: 'contrast', label: 'Contrast', min: 0.2, max: 1.6, step: 0.01, darkDefault: 0.9, lightDefault: 0.92, description: 'Contrast around the midpoint.' },
  { key: 'saturation', label: 'Saturation', min: 0, max: 1.5, step: 0.01, darkDefault: 0.8, lightDefault: 0.85, description: 'Desaturation level.' },
  { key: 'vibrancy', label: 'Vibrancy', min: 0, max: 1, step: 0.01, darkDefault: 0.6, lightDefault: 0.12, description: 'Selective saturation boost.' },
  { key: 'vibrancy_darkness', label: 'Vibrancy darkness', min: 0, max: 1, step: 0.01, darkDefault: 0.0, lightDefault: 0.0, description: 'How much dark areas influence vibrancy.' },
  { key: 'adaptive_dim', label: 'Adaptive dim', min: 0, max: 1, step: 0.01, darkDefault: 0.4, lightDefault: 0.0, description: 'Dims bright areas behind the glass.' },
  { key: 'adaptive_boost', label: 'Adaptive boost', min: 0, max: 1, step: 0.01, darkDefault: 0.34, lightDefault: 0.4, description: 'Boosts dark areas behind the glass.' },
];

export const layerFields = [
  { key: 'enabled', label: 'Enable layers', description: 'Apply the glass effect to layer surfaces such as bars, docks, and widgets.' },
  { key: 'namespaces', label: 'Namespaces', description: 'Comma-separated whitelist. Empty means all layers when enabled.' },
  { key: 'exclude_namespaces', label: 'Excluded namespaces', description: 'Comma-separated blacklist. Takes priority over the whitelist.' },
  { key: 'preset', label: 'Layer preset', description: 'Preset override used by layer surfaces.' },
  { key: 'namespace_presets', label: 'Namespace presets', description: 'Comma-separated ns:preset pairs.' },
  { key: 'namespace_mask_thresholds', label: 'Mask thresholds', description: 'Comma-separated ns=value pairs.' },
];

export const defaultTheme = 'dark';
export const defaultPreset = 'default';
export const themeOptions = ['dark', 'light'];
export const presetOptions = ['glass', 'subtle', 'ui'];

export const decorationFields = [
  { key: 'active_opacity', label: 'Active opacity', min: 0, max: 1, step: 0.01, defaultValue: 0.86, description: 'Opacity of focused windows. Must be < 1.0 for glass to be visible (glass renders behind the window).' },
  { key: 'inactive_opacity', label: 'Inactive opacity', min: 0, max: 1, step: 0.01, defaultValue: 0.72, description: 'Opacity of unfocused windows. Should be lower than active.' },
  { key: 'fullscreen_opacity', label: 'Fullscreen opacity', min: 0, max: 1, step: 0.01, defaultValue: 1.0, description: 'Opacity of fullscreen windows. Usually 1.0 for no glass.' },
];

export const defaultWindowRules = [
  { enabled: true, match: 'class ^(waterfox)$', action: 'tag +browser', description: 'Tag Waterfox as browser' },
  { enabled: true, match: 'class ^(waterfox)$', action: 'opacity 0.86 0.72', description: 'Waterfox opacity override' },
  { enabled: true, match: 'tag:browser', action: 'tag +hyprglass_enabled', description: 'Enable glass on browser windows' },
  { enabled: true, match: 'tag:browser', action: 'tag +hyprglass_preset_glass', description: 'Use glass preset on browsers' },
];

export function createTintState(hex = '0x99c1f122') {
  const clean = hex.replace(/^0x/i, '').replace(/^#/, '').padEnd(8, 'f').slice(0, 8);
  return {
    rgb: `#${clean.slice(0, 6)}`.toLowerCase(),
    alpha: Number.parseInt(clean.slice(6, 8), 16),
  };
}

export function serializeTintState(state) {
  const rgb = String(state?.rgb || '#8899aa').replace(/^#/, '').padEnd(6, '0').slice(0, 6);
  const alphaValue = Number.isFinite(Number(state?.alpha)) ? Number(state.alpha) : 255;
  const alpha = Math.max(0, Math.min(255, Math.round(alphaValue))).toString(16).padStart(2, '0');
  return `0x${rgb}${alpha}`;
}

export function createDefaultState() {
  const global = Object.fromEntries(
    globalFields.map((field) => [field.key, field.defaultValue]),
  );
  global.tint_color = createTintState();

  const themes = {
    dark: Object.fromEntries(themeFields.map((field) => [field.key, field.darkDefault])),
    light: Object.fromEntries(themeFields.map((field) => [field.key, field.lightDefault])),
  };

  const decoration = Object.fromEntries(
    decorationFields.map((field) => [field.key, field.defaultValue]),
  );

  return {
    enabled: true,
    default_theme: defaultTheme,
    default_preset: defaultPreset,
    output_format: 'conf',
    preview_theme: 'dark',
    global,
    themes,
    decoration,
    layers: {
      enabled: true,
      namespaces: 'waybar, swaync, notifications, quickshell:overview, quickshell:bezel, rofi',
      exclude_namespaces: '',
      preset: 'subtle',
      namespace_presets: 'waybar:subtle, quickshell:bezel:ui',
      namespace_mask_thresholds: 'waybar=0.05, quickshell:overview=0.3, quickshell:bezel=0.3, rofi=0.05',
    },
    window_rules: defaultWindowRules.map((rule) => ({ ...rule })),
  };
}

export function parseCommaList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export function parsePairs(value, separator = ':') {
  const pairs = {};
  parseCommaList(value).forEach((entry) => {
    const idx = entry.indexOf(separator);
    if (idx === -1) return;
    const left = entry.slice(0, idx).trim();
    const right = entry.slice(idx + 1).trim();
    if (left && right) pairs[left] = right;
  });
  return pairs;
}

export function parseThresholdPairs(value) {
  const pairs = {};
  parseCommaList(value).forEach((entry) => {
    const idx = entry.indexOf('=');
    if (idx === -1) return;
    const left = entry.slice(0, idx).trim();
    const right = Number.parseFloat(entry.slice(idx + 1).trim());
    if (left && Number.isFinite(right)) pairs[left] = right;
  });
  return pairs;
}

export function formatNumber(field, value) {
  const num = Number(value);
  if (field.key === 'blur_iterations') return String(Math.round(num));
  if (field.key === 'edge_thickness') return num.toFixed(3).replace(/0+$/, '').replace(/\.$/, '') || '0';
  if (field.key === 'blur_strength') return num.toFixed(1);
  const formatted = num.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
  return formatted || '0';
}

function formatValue(field, value) {
  if (field.key === 'blur_iterations') return String(Math.round(Number(value)));
  return formatNumber(field, value);
}

export function formatConf(state) {
  const lines = [];
  lines.push('plugin:hyprglass {');
  lines.push(`  enabled = ${state.enabled ? 1 : 0}`);
  lines.push(`  default_theme = ${state.default_theme}`);
  lines.push(`  default_preset = ${state.default_preset}`);
  globalFields.forEach((field) => {
    lines.push(`  ${field.key} = ${formatValue(field, state.global[field.key])}`);
  });
  lines.push(`  tint_color = ${serializeTintState(state.global.tint_color)}`);
  themeOptions.forEach((themeName) => {
    themeFields.forEach((field) => {
      lines.push(`  ${themeName}:${field.key} = ${formatValue(field, state.themes[themeName][field.key])}`);
    });
  });
  lines.push(`  layers:enabled = ${state.layers.enabled ? 1 : 0}`);
  lines.push(`  layers:namespaces = ${state.layers.namespaces}`);
  lines.push(`  layers:exclude_namespaces = ${state.layers.exclude_namespaces}`);
  lines.push(`  layers:preset = ${state.layers.preset}`);
  lines.push(`  layers:namespace_presets = ${state.layers.namespace_presets}`);
  lines.push(`  layers:namespace_mask_thresholds = ${state.layers.namespace_mask_thresholds}`);
  lines.push('}');
  lines.push('');
  lines.push('# Override Jakoolit defaults so HyprGlass has visible transparency to work with');
  lines.push('decoration {');
  decorationFields.forEach((field) => {
    lines.push(`  ${field.key} = ${formatValue(field, state.decoration[field.key])}`);
  });
  lines.push('}');
  lines.push('');
  lines.push('# Compatibility opacity overrides so the effect is visible on opaque apps');
  const activeRules = (state.window_rules || []).filter((r) => r.enabled);
  activeRules.forEach((rule) => {
    lines.push(`windowrule = match:${rule.match}, ${rule.action}`);
  });
  if (!activeRules.length) {
    lines.push('# No window rules configured');
  }
  return lines.join('\n');
}

export function formatLua(state) {
  const lines = [];
  lines.push('local hg = require("hyprglass")');
  lines.push('');
  lines.push('hg.config({');
  lines.push(`  enabled = ${state.enabled ? 'true' : 'false'},`);
  lines.push(`  default_theme = "${state.default_theme}",`);
  lines.push(`  default_preset = "${state.default_preset}",`);
  globalFields.forEach((field) => {
    lines.push(`  ${field.key} = ${formatValue(field, state.global[field.key])},`);
  });
  lines.push(`  tint_color = "${serializeTintState(state.global.tint_color)}",`);
  lines.push('  dark = {');
  themeFields.forEach((field) => {
    lines.push(`    ${field.key} = ${formatValue(field, state.themes.dark[field.key])},`);
  });
  lines.push('  },');
  lines.push('  light = {');
  themeFields.forEach((field) => {
    lines.push(`    ${field.key} = ${formatValue(field, state.themes.light[field.key])},`);
  });
  lines.push('  },');
  lines.push('  layers = {');
  lines.push(`    enabled = ${state.layers.enabled ? 'true' : 'false'},`);
  if (state.layers.preset) lines.push(`    preset = "${state.layers.preset}",`);
  lines.push('  },');
  lines.push('})');
  lines.push('');

  const namespaces = parseCommaList(state.layers.namespaces);
  const excludes = parseCommaList(state.layers.exclude_namespaces);
  const presetPairs = parsePairs(state.layers.namespace_presets, ':');
  const thresholdPairs = parseThresholdPairs(state.layers.namespace_mask_thresholds);
  const layerPreset = state.layers.preset ? String(state.layers.preset) : '';

  namespaces.forEach((namespace) => {
    const entries = [];
    const preset = presetPairs[namespace] || layerPreset;
    if (preset) entries.push(`preset = "${preset}"`);
    if (thresholdPairs[namespace] != null) entries.push(`mask_threshold = ${thresholdPairs[namespace]}`);
    lines.push(entries.length ? `hg.layer("${namespace}", { ${entries.join(', ')} })` : `hg.layer("${namespace}")`);
  });

  excludes.forEach((namespace) => {
    lines.push(`hg.layer("${namespace}", { exclude = true })`);
  });

  return lines.join('\n');
}

export function summarizeState(state) {
  const activeTheme = state.preview_theme;
  const globals = globalFields.length;
  const themeCount = themeFields.length * 2;
  const namespaces = parseCommaList(state.layers.namespaces).length;
  const excluded = parseCommaList(state.layers.exclude_namespaces).length;
  const activeRules = (state.window_rules || []).filter((r) => r.enabled).length;
  return {
    activeTheme,
    globals,
    themeCount,
    namespaces,
    excluded,
    layersEnabled: state.layers.enabled,
    enabled: state.enabled,
    activeRules,
  };
}
